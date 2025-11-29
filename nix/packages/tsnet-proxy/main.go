package main

import (
	"context"
	"flag"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"syscall"

	"tailscale.com/tsnet"
)

func main() {
	var (
		hostname = flag.String("hostname", "tsnet-proxy", "Tailscale hostname for this node")
		backend  = flag.String("backend", "http://localhost:8080", "Backend URL to proxy to")
		authKey  = flag.String("authkey", "", "Tailscale auth key (or use TS_AUTHKEY env var)")
		port     = flag.String("port", "443", "Port to listen on (80 or 443)")
	)
	flag.Parse()

	// Get auth key from env if not provided via flag
	if *authKey == "" {
		*authKey = os.Getenv("TS_AUTHKEY")
	}
	if *authKey == "" {
		log.Fatal("Auth key required via -authkey flag or TS_AUTHKEY environment variable")
	}

	// Parse backend URL
	backendURL, err := url.Parse(*backend)
	if err != nil {
		log.Fatalf("Invalid backend URL %q: %v", *backend, err)
	}

	// Create Tailscale server
	srv := &tsnet.Server{
		Hostname: *hostname,
		AuthKey:  *authKey,
	}
	defer srv.Close()

	// Create reverse proxy
	proxy := httputil.NewSingleHostReverseProxy(backendURL)

	// Add request logging and headers
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s %s", r.RemoteAddr, r.Method, r.URL.Path)

		// Extract IP without port for X-Forwarded-For
		clientIP, _, err := net.SplitHostPort(r.RemoteAddr)
		if err != nil {
			// RemoteAddr might not have a port, use as-is
			clientIP = r.RemoteAddr
		}

		// Set proxy headers
		r.Header.Set("X-Forwarded-For", clientIP)
		r.Header.Set("X-Forwarded-Proto", "https")
		r.Header.Set("X-Forwarded-Host", r.Host)

		proxy.ServeHTTP(w, r)
	})

	// Listen on the specified port
	var listener net.Listener
	if *port == "443" {
		listener, err = srv.ListenTLS("tcp", ":443")
		if err != nil {
			log.Fatalf("Failed to listen on TLS port 443: %v", err)
		}
		log.Printf("Listening on https://%s.ts.net (TLS)", *hostname)
	} else {
		listener, err = srv.Listen("tcp", ":"+*port)
		if err != nil {
			log.Fatalf("Failed to listen on port %s: %v", *port, err)
		}
		log.Printf("Listening on http://%s.ts.net:%s", *hostname, *port)
	}

	// Create HTTP server
	server := &http.Server{
		Handler: handler,
	}

	// Handle graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)
		<-sigCh
		log.Println("Received shutdown signal, shutting down gracefully...")
		server.Shutdown(context.Background())
	}()

	log.Printf("Proxying requests from %s to %s", *hostname, *backend)

	// Start serving
	if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server error: %v", err)
	}

	log.Println("Server shutdown complete")
}
