package main

import (
	"flag"
	"testing"
)

func TestLocalOnlyAppsPreservePunctuation(t *testing.T) {
	fs := flag.NewFlagSet("notifyd", flag.ContinueOnError)
	var apps appNames
	fs.Var(&apps, "local-only-app", "exact app name")
	if err := fs.Parse([]string{"--local-only-app", "Foo, Inc.", "--local-only-app", "Other app"}); err != nil {
		t.Fatal(err)
	}
	if len(apps) != 2 || apps[0] != "Foo, Inc." || apps[1] != "Other app" {
		t.Fatalf("app names changed: %v", apps)
	}
}
