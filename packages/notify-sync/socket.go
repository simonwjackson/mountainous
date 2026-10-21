package notifysync

import (
	"bufio"
	"context"
	"errors"
	"log/slog"
	"net"
	"os"
	"path/filepath"
	"time"
)

func (d *Daemon) ServeSocket(ctx context.Context, path string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return err
	}
	// Never unlink an active socket, or a regular file supplied by a caller.
	if info, err := os.Lstat(path); err == nil {
		if info.Mode()&os.ModeSocket == 0 {
			return errors.New("UI socket path is not a socket")
		}
		c, err := net.DialTimeout("unix", path, 100*time.Millisecond)
		if err == nil {
			c.Close()
			return errors.New("UI socket is already active")
		}
		if err = os.Remove(path); err != nil {
			return err
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	listener, err := net.Listen("unix", path)
	if err != nil {
		return err
	}
	defer listener.Close()
	if err = os.Chmod(path, 0600); err != nil {
		return err
	}
	go func() { <-ctx.Done(); listener.Close() }()
	for {
		conn, err := listener.Accept()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return err
		}
		go d.socketClient(ctx, conn)
	}
}
func (d *Daemon) socketClient(ctx context.Context, conn net.Conn) {
	defer conn.Close()
	scan := bufio.NewScanner(conn)
	scan.Buffer(make([]byte, 4096), 65536)
	var cancel func()
	defer func() {
		if cancel != nil {
			cancel()
		}
	}()
	// One writer owns the connection. Slow views are disconnected and resnapshot.
	for scan.Scan() {
		op, err := DecodeUIOperation(scan.Bytes())
		if err != nil {
			return
		}
		if op.Op == "subscribe" {
			if cancel != nil {
				return
			}
			events, unsub, err := d.Subscribe()
			if err != nil {
				return
			}
			cancel = unsub
			go func() {
				for {
					select {
					case <-ctx.Done():
						conn.Close()
						return
					case event, ok := <-events:
						if !ok {
							conn.Close()
							return
						}
						data, err := EncodeUIEvent(event)
						if err != nil {
							// Do not log the event body or validator values.
							slog.Error("refusing invalid outgoing notification event", "type", event.Type)
							conn.Close()
							return
						}
						conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
						if _, err = conn.Write(append(data, '\n')); err != nil {
							conn.Close()
							return
						}
					}
				}
			}()
		} else {
			if d.Operation(op) != nil {
				return
			}
		}
	}
}
