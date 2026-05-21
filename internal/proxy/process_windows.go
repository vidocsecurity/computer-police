//go:build windows

package proxy

import (
	"os"
	"os/exec"
	"syscall"
)

func configureBackgroundProcess(_ *exec.Cmd) {}

func signalTerminate(process *os.Process) error {
	return process.Kill()
}

func processAlive(process *os.Process) bool {
	return process.Signal(syscall.Signal(0)) == nil
}
