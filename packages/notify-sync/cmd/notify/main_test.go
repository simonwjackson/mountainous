package main

import (
	"flag"
	"io"
	"testing"
	"time"
)

func TestFlagsMayFollowSequence(t *testing.T) {
	fs := flag.NewFlagSet("notify wait", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	timeout := fs.Duration("timeout", 0, "timeout")
	jsonOut := fs.Bool("json", false, "JSON")
	if err := parseInterspersed(fs, []string{"host-epoch-1", "--timeout", "30s", "--json"}); err != nil {
		t.Fatal(err)
	}
	if fs.NArg() != 1 || fs.Arg(0) != "host-epoch-1" || *timeout != 30*time.Second || !*jsonOut {
		t.Fatal("interspersed flag contract failed")
	}
}
func TestUnknownCommandAndMissingSequence(t *testing.T) {
	for _, args := range [][]string{nil, {"unknown"}, {"clear"}, {"wait", "seq", "other"}} {
		if run(args) == nil {
			t.Fatalf("accepted invalid args %v", args)
		}
	}
}
