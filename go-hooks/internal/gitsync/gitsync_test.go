package gitsync

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func TestIsEnabled(t *testing.T) {
	tests := []struct {
		val  string
		want bool
	}{
		{"1", true},
		{"true", true},
		{"TRUE", true},
		{"True", true},
		{"0", false},
		{"false", false},
		{"", false},
		{"yes", false},
		{"  1  ", true},
		{"  true  ", true},
	}
	for _, tt := range tests {
		t.Run(tt.val, func(t *testing.T) {
			t.Setenv("CLAUDE_VAULT_GIT_PUSH", tt.val)
			if got := isEnabled(); got != tt.want {
				t.Errorf("isEnabled() with %q = %v, want %v", tt.val, got, tt.want)
			}
		})
	}
}

func TestIsGitRepo(t *testing.T) {
	// Directory with .git
	dir := t.TempDir()
	os.Mkdir(filepath.Join(dir, ".git"), 0755)
	if !isGitRepo(dir) {
		t.Error("expected true for directory with .git")
	}

	// Directory without .git
	dir2 := t.TempDir()
	if isGitRepo(dir2) {
		t.Error("expected false for directory without .git")
	}
}

func TestSyncIfEnabled_NotEnabled(t *testing.T) {
	t.Setenv("CLAUDE_VAULT_GIT_PUSH", "0")
	// Should return immediately without error even with invalid dir
	SyncIfEnabled("/nonexistent/path")
}

func TestSyncIfEnabled_NotGitRepo(t *testing.T) {
	t.Setenv("CLAUDE_VAULT_GIT_PUSH", "1")
	dir := t.TempDir()
	// No .git dir — should return immediately
	SyncIfEnabled(dir)
}

func initBareAndClone(t *testing.T) (bare, clone string) {
	t.Helper()
	bare = filepath.Join(t.TempDir(), "bare.git")
	clone = filepath.Join(t.TempDir(), "work")

	run(t, "", "git", "init", "--bare", bare)
	run(t, "", "git", "clone", bare, clone)
	run(t, clone, "git", "config", "user.email", "test@test.com")
	run(t, clone, "git", "config", "user.name", "Test")

	// Create initial commit so push works
	os.WriteFile(filepath.Join(clone, "init.txt"), []byte("init"), 0644)
	run(t, clone, "git", "add", "-A")
	run(t, clone, "git", "commit", "-m", "initial")
	run(t, clone, "git", "push")

	return bare, clone
}

func run(t *testing.T, dir, name string, args ...string) {
	t.Helper()
	cmd := exec.Command(name, args...)
	if dir != "" {
		cmd.Dir = dir
	}
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("%s %v failed: %v\n%s", name, args, err, out)
	}
}

func TestSyncIfEnabled_CommitsAndPushes(t *testing.T) {
	t.Setenv("CLAUDE_VAULT_GIT_PUSH", "1")
	bare, clone := initBareAndClone(t)

	// Create a new file in the clone
	os.WriteFile(filepath.Join(clone, "session.md"), []byte("# Session"), 0644)

	SyncIfEnabled(clone)

	// Verify commit exists in clone
	cmd := exec.Command("git", "-C", clone, "log", "--oneline", "-1")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git log failed: %v\n%s", err, out)
	}
	if got := string(out); !contains(got, "claude: sync session") {
		t.Errorf("expected commit message containing 'claude: sync session', got: %s", got)
	}

	// Verify pushed to bare
	cmd = exec.Command("git", "-C", bare, "log", "--oneline", "-1")
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git log on bare failed: %v\n%s", err, out)
	}
	if got := string(out); !contains(got, "claude: sync session") {
		t.Errorf("expected pushed commit in bare, got: %s", got)
	}
}

func TestSyncIfEnabled_NothingToCommit(t *testing.T) {
	t.Setenv("CLAUDE_VAULT_GIT_PUSH", "1")
	_, clone := initBareAndClone(t)

	// No changes — should complete without error
	SyncIfEnabled(clone)

	// Verify no new commit beyond the initial one
	cmd := exec.Command("git", "-C", clone, "rev-list", "--count", "HEAD")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git rev-list failed: %v\n%s", err, out)
	}
	if got := string(out); !contains(got, "1") {
		t.Errorf("expected 1 commit, got: %s", got)
	}
}

func TestAcquireLock_Exclusive(t *testing.T) {
	dir := t.TempDir()
	lockPath := filepath.Join(dir, "test.lock")

	// First acquire should succeed
	if !acquireLock(lockPath) {
		t.Fatal("first acquire should succeed")
	}

	// Second acquire should fail (lock held)
	if acquireLock(lockPath) {
		t.Fatal("second acquire should fail while lock held")
	}

	// Release and reacquire
	releaseLock(lockPath)
	if !acquireLock(lockPath) {
		t.Fatal("acquire after release should succeed")
	}
	releaseLock(lockPath)
}

func TestAcquireLock_StaleRemoval(t *testing.T) {
	dir := t.TempDir()
	lockPath := filepath.Join(dir, "test.lock")

	// Create a lock file with old mtime
	os.WriteFile(lockPath, []byte{}, 0644)
	old := time.Now().Add(-(lockTimeout + time.Minute))
	os.Chtimes(lockPath, old, old)

	// Should remove stale lock and acquire
	if !acquireLock(lockPath) {
		t.Fatal("should acquire after removing stale lock")
	}
	releaseLock(lockPath)
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && searchString(s, substr)
}

func searchString(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
