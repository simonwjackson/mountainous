package main

import (
	"context"
	"flag"
	"log/slog"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"

	ns "github.com/simonwjackson/mountainous/notify-sync"
)

func main() {
	if err := run(); err != nil {
		slog.Error("notifyd stopped", "error", err)
		os.Exit(1)
	}
}
func run() error {
	flags := ns.RegisterClientFlags(flag.CommandLine)
	host, _ := os.Hostname()
	name := flag.String("host", host, "stable host label")
	state := flag.String("state-dir", ns.StateDirectory(), "state directory")
	socket := flag.String("socket", filepath.Join(os.Getenv("XDG_RUNTIME_DIR"), "notify-sync/ui.sock"), "UI socket")
	apps := flag.String("local-only-apps", "", "comma separated app names")
	flag.Parse()
	client, err := flags.Client()
	if err != nil {
		return err
	}
	store, err := ns.OpenStore(filepath.Join(*state, "store.db"))
	if err != nil {
		return err
	}
	defer store.Close()
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	d := ns.NewDaemon(store, client, *name)
	if *apps != "" {
		d.LocalOnlyApps = strings.Split(*apps, ",")
	}
	bus, err := d.AttachBus(ctx, filepath.Join(*state, "images"))
	if err != nil {
		return err
	}
	defer bus.Close()
	errors := make(chan error, 2)
	go func() { errors <- d.ServeSocket(ctx, *socket) }()
	go func() { errors <- d.Run(ctx) }()
	slog.Info("notifyd ready", "host", *name)
	select {
	case <-ctx.Done():
		return nil
	case err := <-errors:
		stop()
		return err
	}
}
