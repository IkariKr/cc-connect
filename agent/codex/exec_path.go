package codex

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"time"
)

var (
	codexPathOnce sync.Once
	codexPath     string
	codexPathErr  error
)

func getCodexCommandPath() (string, error) {
	codexPathOnce.Do(func() {
		codexPath, codexPathErr = resolveCodexCommandPath()
	})
	if codexPathErr != nil {
		return "", codexPathErr
	}
	return codexPath, nil
}

func resetCodexCommandPathCache() {
	codexPathOnce = sync.Once{}
	codexPath = ""
	codexPathErr = nil
}

func resolveCodexCommandPath() (string, error) {
	if override := strings.TrimSpace(os.Getenv("CC_CONNECT_CODEX_PATH")); override != "" {
		if err := validateCodexCandidate(override); err != nil {
			return "", fmt.Errorf("validate CC_CONNECT_CODEX_PATH %q: %w", override, err)
		}
		return override, nil
	}

	lookPath, lookErr := exec.LookPath("codex")
	if runtime.GOOS != "windows" {
		if lookErr != nil {
			return "", fmt.Errorf("codex CLI not found in PATH: %w", lookErr)
		}
		return lookPath, nil
	}

	var candidates []string
	if lookErr == nil {
		candidates = append(candidates, lookPath)
	}
	if out, err := exec.Command("where.exe", "codex").Output(); err == nil {
		for _, line := range strings.Split(string(out), "\n") {
			if p := strings.TrimSpace(line); p != "" {
				candidates = append(candidates, p)
			}
		}
	}
	candidates = prioritizeCodexCandidates(candidates)

	var lastErr error
	for _, candidate := range candidates {
		if err := validateCodexCandidate(candidate); err == nil {
			return candidate, nil
		} else {
			lastErr = err
		}
	}

	if lastErr != nil {
		return "", fmt.Errorf("no usable codex executable found; candidates=%q: %w", candidates, lastErr)
	}
	if lookErr != nil {
		return "", fmt.Errorf("codex CLI not found in PATH: %w", lookErr)
	}
	return "", errors.New("no usable codex executable found")
}

func prioritizeCodexCandidates(candidates []string) []string {
	seen := make(map[string]struct{}, len(candidates))
	normal := make([]string, 0, len(candidates))
	windowsApps := make([]string, 0, 1)
	for _, candidate := range candidates {
		candidate = strings.TrimSpace(candidate)
		if candidate == "" {
			continue
		}
		key := strings.ToLower(candidate)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		if isWindowsAppsPath(candidate) {
			windowsApps = append(windowsApps, candidate)
			continue
		}
		normal = append(normal, candidate)
	}
	return append(normal, windowsApps...)
}

func isWindowsAppsPath(path string) bool {
	return strings.Contains(strings.ToLower(path), `\windowsapps\`)
}

func validateCodexCandidate(path string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, path, "--version")
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard

	if err := cmd.Start(); err != nil {
		return err
	}

	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()

	select {
	case err := <-done:
		var exitErr *exec.ExitError
		if err != nil && !errors.As(err, &exitErr) {
			return err
		}
		return nil
	case <-ctx.Done():
		_ = cmd.Process.Kill()
		<-done
		return fmt.Errorf("timed out probing %s", path)
	}
}
