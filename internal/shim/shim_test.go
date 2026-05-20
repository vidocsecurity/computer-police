package shim

import "testing"

func TestIsObserved(t *testing.T) {
	tests := []struct {
		pm   string
		args []string
		want bool
	}{
		{"npm", []string{"install", "zod"}, true},
		{"npm", []string{"i"}, true},
		{"npm", []string{"run", "build"}, false},
		{"pnpm", []string{"add", "axios"}, true},
		{"yarn", []string{"dev"}, false},
		{"bun", []string{"remove", "hono"}, true},
	}
	for _, tt := range tests {
		if got := IsObserved(tt.pm, tt.args); got != tt.want {
			t.Fatalf("IsObserved(%q, %v) = %v, want %v", tt.pm, tt.args, got, tt.want)
		}
	}
}
