package codex

import (
	"reflect"
	"testing"
)

func TestPrioritizeCodexCandidates_PrefersNonWindowsApps(t *testing.T) {
	got := prioritizeCodexCandidates([]string{
		`C:\Program Files\WindowsApps\OpenAI.Codex_1\app\resources\codex.exe`,
		`C:\Users\me\.vscode\extensions\openai.chatgpt\bin\windows-x86_64\codex.exe`,
		`C:\Users\me\.vscode\extensions\openai.chatgpt\bin\windows-x86_64\codex.exe`,
		` `,
	})
	want := []string{
		`C:\Users\me\.vscode\extensions\openai.chatgpt\bin\windows-x86_64\codex.exe`,
		`C:\Program Files\WindowsApps\OpenAI.Codex_1\app\resources\codex.exe`,
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("prioritizeCodexCandidates() = %v, want %v", got, want)
	}
}
