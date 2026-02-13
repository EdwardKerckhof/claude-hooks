package session

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// SessionData holds the session-to-file mapping.
type SessionData struct {
	FilePath  string
	PromptNum int
}

func mapPath(sessionID string) string {
	return filepath.Join(os.TempDir(), "claude_session_"+sessionID+".txt")
}

// Read reads the session mapping file. Returns nil if not found.
func Read(sessionID string) (*SessionData, error) {
	data, err := os.ReadFile(mapPath(sessionID))
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	lines := strings.SplitN(strings.TrimSpace(string(data)), "\n", 2)
	if len(lines) < 2 {
		return nil, fmt.Errorf("invalid session map format")
	}
	num, err := strconv.Atoi(strings.TrimSpace(lines[1]))
	if err != nil {
		return nil, err
	}
	return &SessionData{FilePath: strings.TrimSpace(lines[0]), PromptNum: num}, nil
}

// Write writes the session mapping file (filepath\npromptNum, UTF-8 no BOM).
func Write(sessionID, filePath string, promptNum int) error {
	content := filePath + "\n" + strconv.Itoa(promptNum)
	return os.WriteFile(mapPath(sessionID), []byte(content), 0644)
}

// CleanupStale removes session temp files older than 24 hours.
func CleanupStale() {
	pattern := filepath.Join(os.TempDir(), "claude_session_*.txt")
	matches, err := filepath.Glob(pattern)
	if err != nil {
		return
	}
	cutoff := time.Now().Add(-24 * time.Hour)
	for _, m := range matches {
		info, err := os.Stat(m)
		if err != nil {
			continue
		}
		if info.ModTime().Before(cutoff) {
			os.Remove(m)
		}
	}
}
