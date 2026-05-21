//go:build !windows

package proxy

import (
	"os"
	"os/exec"
	"syscall"
)

func configureBackgroundProcess(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
}

func signalTerminate(process *os.Process) error {
	return process.Signal(syscall.SIGTERM)
}

func processAlive(process *os.Process) bool {
	return process.Signal(syscall.Signal(0)) == nil
}
