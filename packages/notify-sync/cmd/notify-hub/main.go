package main

import (
	"context"
	"errors"
	"flag"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	ns "github.com/simonwjackson/mountainous/notify-sync"
)

func main() {
	if err := run(); err != nil {
		slog.Error("notify-hub stopped", "error", err)
		os.Exit(1)
	}
}
func run() error {
	cf := ns.RegisterClientFlags(flag.CommandLine)
	listen := flag.String("listen", "127.0.0.1:2587", "loopback listen address; expose through tailnet proxy only")
	mcpToken := flag.String("mcp-token-file", "", "MCP bearer token file")
	flag.Parse()
	host, _, err := net.SplitHostPort(*listen)
	if err != nil || net.ParseIP(host) == nil || !net.ParseIP(host).IsLoopback() {
		return errors.New("hub must listen on a loopback IP")
	}
	c, err := cf.Client()
	if err != nil {
		return err
	}
	bearer, err := ns.ReadToken(*mcpToken)
	if err != nil {
		return err
	}
	hub := &ns.Hub{Client: c}
	handler, err := hub.Handler(bearer)
	if err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	server := &http.Server{Addr: *listen, Handler: handler, ReadHeaderTimeout: 10 * time.Second, IdleTimeout: 90 * time.Second, MaxHeaderBytes: 65536}
	done := make(chan error, 2)
	go func() { done <- hub.Run(ctx) }()
	go func() {
		err := server.ListenAndServe()
		if errors.Is(err, http.ErrServerClosed) {
			err = nil
		}
		done <- err
	}()
	slog.Info("notify-hub ready")
	select {
	case <-ctx.Done():
	case err = <-done:
	}
	stop()
	shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = server.Shutdown(shutdown)
	return err
}
