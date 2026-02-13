package hookdata

import (
	"encoding/json"
	"io"
	"os"
)

// PromptInput is the JSON sent to UserPromptSubmit hooks.
type PromptInput struct {
	SessionID string `json:"session_id"`
	Cwd       string `json:"cwd"`
	Prompt    string `json:"prompt"`
}

// StopInput is the JSON sent to Stop hooks.
type StopInput struct {
	SessionID      string `json:"session_id"`
	TranscriptPath string `json:"transcript_path"`
}

// ReadStdin reads all of stdin and JSON-decodes it into target.
func ReadStdin(target any) error {
	data, err := io.ReadAll(os.Stdin)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, target)
}
