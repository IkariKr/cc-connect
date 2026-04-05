package core

import (
	"os"
	"path/filepath"
	"testing"
)

func TestStageFilesToDisk_ReusesExistingLocalPath(t *testing.T) {
	workDir := t.TempDir()
	existingPath := filepath.Join(workDir, "existing.txt")
	if err := os.WriteFile(existingPath, []byte("hello"), 0o644); err != nil {
		t.Fatalf("write existing file: %v", err)
	}

	staged, paths := StageFilesToDisk(workDir, []FileAttachment{{
		FileName:  "ignored.txt",
		LocalPath: existingPath,
	}})
	if len(staged) != 1 || len(paths) != 1 {
		t.Fatalf("unexpected staged result: %d attachments, %d paths", len(staged), len(paths))
	}
	if staged[0].LocalPath != existingPath || paths[0] != existingPath {
		t.Fatalf("expected existing path reuse, got attachment=%q path=%q", staged[0].LocalPath, paths[0])
	}
}

func TestStageFilesToDisk_WritesNewFiles(t *testing.T) {
	workDir := t.TempDir()
	staged, paths := StageFilesToDisk(workDir, []FileAttachment{{
		FileName: "report.txt",
		Data:     []byte("payload"),
	}})
	if len(staged) != 1 || len(paths) != 1 {
		t.Fatalf("unexpected staged result: %d attachments, %d paths", len(staged), len(paths))
	}

	data, err := os.ReadFile(paths[0])
	if err != nil {
		t.Fatalf("read staged file: %v", err)
	}
	if string(data) != "payload" {
		t.Fatalf("staged file content = %q, want %q", string(data), "payload")
	}
	if staged[0].LocalPath != paths[0] {
		t.Fatalf("attachment local path = %q, want %q", staged[0].LocalPath, paths[0])
	}
}

func TestStageImagesToDisk_WritesNewImages(t *testing.T) {
	workDir := t.TempDir()
	staged, paths := StageImagesToDisk(workDir, []ImageAttachment{{
		MimeType: "image/png",
		Data:     []byte("pngdata"),
	}})
	if len(staged) != 1 || len(paths) != 1 {
		t.Fatalf("unexpected staged result: %d attachments, %d paths", len(staged), len(paths))
	}
	if filepath.Ext(paths[0]) != ".png" {
		t.Fatalf("staged image ext = %q, want .png", filepath.Ext(paths[0]))
	}
	data, err := os.ReadFile(paths[0])
	if err != nil {
		t.Fatalf("read staged image: %v", err)
	}
	if string(data) != "pngdata" {
		t.Fatalf("staged image content = %q, want %q", string(data), "pngdata")
	}
}
