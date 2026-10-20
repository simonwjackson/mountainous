package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"strings"

	ns "github.com/simonwjackson/mountainous/notify-sync"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

type actions []ns.Action

func (a *actions) String() string { return "key=Label" }
func (a *actions) Set(s string) error {
	k, v, ok := strings.Cut(s, "=")
	if !ok || k == "" || v == "" {
		return errors.New("action must be key=Label")
	}
	*a = append(*a, ns.Action{Key: k, Label: v})
	return nil
}
func run(args []string) error {
	if len(args) == 0 {
		return errors.New("usage: notify send|list|clear|wait [options]")
	}
	op := args[0]
	fs := flag.NewFlagSet("notify "+op, flag.ContinueOnError)
	cf := ns.RegisterClientFlags(fs)
	name := fs.String("name", "agent", "agent name")
	body := fs.String("body", "", "message body")
	summary := fs.String("summary", "", "summary")
	jsonOut := fs.Bool("json", false, "JSON output")
	timeout := fs.Duration("timeout", 0, "wait timeout (e.g. 30s)")
	resident := fs.Bool("resident", false, "keep open after an action")
	var acts actions
	fs.Var(&acts, "action", "key=Label (repeatable)")
	if err := parseInterspersed(fs, args[1:]); err != nil {
		return err
	}
	c, err := cf.Client()
	if err != nil {
		return err
	}
	ctx := context.Background()
	if *timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, *timeout)
		defer cancel()
	}
	switch op {
	case "send":
		if fs.NArg() > 0 && *summary == "" {
			*summary = fs.Arg(0)
		}
		if fs.NArg() > 1 && *body == "" {
			*body = fs.Arg(1)
		}
		seq, err := c.Send(ctx, ns.SendInput{Name: *name, Summary: *summary, Body: *body, Actions: acts, Resident: *resident})
		if err != nil {
			return err
		}
		fmt.Println(seq)
	case "list":
		items, err := c.List(ctx)
		if err != nil {
			return err
		}
		if *jsonOut {
			return json.NewEncoder(os.Stdout).Encode(items)
		}
		for _, i := range items {
			fmt.Printf("%s\t[%s] %s: %s\n", i.Item.Seq, i.Trust, i.Item.Summary, i.Item.Body)
		}
	case "clear", "wait":
		if fs.NArg() != 1 {
			return errors.New("one sequence ID is required")
		}
		if op == "clear" {
			return c.Clear(ctx, fs.Arg(0))
		}
		ctl, err := c.Wait(ctx, fs.Arg(0))
		if err != nil {
			return err
		}
		return json.NewEncoder(os.Stdout).Encode(ctl)
	default:
		return errors.New("unknown operation")
	}
	return nil
}

// The public CLI permits flags after the sequence, e.g. wait SEQ --timeout 30s.
func parseInterspersed(fs *flag.FlagSet, args []string) error {
	flags := []string{}
	positionals := []string{}
	for i := 0; i < len(args); i++ {
		arg := args[i]
		if arg == "--" {
			positionals = append(positionals, args[i+1:]...)
			break
		}
		if !strings.HasPrefix(arg, "-") || arg == "-" {
			positionals = append(positionals, arg)
			continue
		}
		flags = append(flags, arg)
		name, _, hasValue := strings.Cut(strings.TrimLeft(arg, "-"), "=")
		f := fs.Lookup(name)
		if f == nil || hasValue {
			continue
		}
		if b, ok := f.Value.(interface{ IsBoolFlag() bool }); ok && b.IsBoolFlag() {
			continue
		}
		if i+1 < len(args) {
			i++
			flags = append(flags, args[i])
		}
	}
	return fs.Parse(append(flags, append([]string{"--"}, positionals...)...))
}
