//go:build windows

package proxy

import (
	"os"
	"os/exec"
)

func configureBackgroundProcess(_ *exec.Cmd) {}

func signalTerminate(process *os.Process) error {
	return process.Kill()
}
