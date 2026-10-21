package notifysync_test

import (
	"bufio"
	"context"
	"encoding/json"
	ns "github.com/simonwjackson/mountainous/notify-sync"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

func privateBus(t *testing.T) {
	t.Helper()
	bin, err := exec.LookPath("dbus-daemon")
	if err != nil {
		t.Skip("dbus-daemon is required")
	}
	config := filepath.Join(t.TempDir(), "session.conf")
	if err := os.WriteFile(config, []byte(`<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen><auth>EXTERNAL</auth><policy context="default"><allow send_destination="*" eavesdrop="true"/><allow receive_sender="*" eavesdrop="true"/><allow own="*"/></policy></busconfig>`), 0600); err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command(bin, "--config-file="+config, "--nofork", "--print-address=1")
	var busErrors strings.Builder
	cmd.Stderr = &busErrors
	out, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err = cmd.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { cmd.Process.Kill(); cmd.Wait() })
	line, err := bufio.NewReader(out).ReadString('\n')
	if err != nil {
		t.Fatalf("%v: %s", err, busErrors.String())
	}
	t.Setenv("DBUS_SESSION_BUS_ADDRESS", strings.TrimSpace(line))
}
func eventually(t *testing.T, f func() bool) {
	t.Helper()
	until := time.Now().Add(8 * time.Second)
	for time.Now().Before(until) {
		if f() {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatal("condition did not become true")
}
func TestDesktopDBusAndSocket(t *testing.T) {
	base := ntfyServer(t)
	privateBus(t)
	r := newRig(t, base)
	r.d.Emit = nil
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	bus, err := r.d.AttachBus(ctx, filepath.Join(t.TempDir(), "images"))
	r.check(err)
	defer bus.Close()
	socket := filepath.Join(t.TempDir(), "notify-sync/ui.sock")
	go func() { _ = r.d.ServeSocket(ctx, socket) }()
	done := make(chan error, 1)
	go func() { done <- r.d.Run(ctx) }()
	defer func() { cancel(); <-done }()
	var ui net.Conn
	eventually(t, func() bool { ui, err = net.Dial("unix", socket); return err == nil })
	defer ui.Close()
	_, err = ui.Write([]byte("{\"op\":\"subscribe\"}\n"))
	r.check(err)
	decoder := json.NewDecoder(ui)
	snapshot := decodeSocketEvent(t, decoder)
	if snapshot.Type != "snapshot" || snapshot.Items == nil || snapshot.Status == nil {
		t.Fatalf("socket snapshot %+v", snapshot)
	}
	app, err := dbus.ConnectSessionBus()
	r.check(err)
	defer app.Close()
	r.check(app.AddMatchSignal(dbus.WithMatchSender(ns.BusName), dbus.WithMatchInterface(ns.BusName)))
	signals := make(chan *dbus.Signal, 32)
	app.Signal(signals)
	proxy := app.Object(ns.BusName, ns.BusPath)
	var caps []string
	r.check(proxy.Call(ns.BusName+".GetCapabilities", 0).Store(&caps))
	var name, vendor, version, spec string
	r.check(proxy.Call(ns.BusName+".GetServerInformation", 0).Store(&name, &vendor, &version, &spec))
	if spec != "1.2" || len(caps) < 3 {
		t.Fatalf("info %s %v", spec, caps)
	}
	notify := func(replaces uint32, hints map[string]dbus.Variant) uint32 {
		t.Helper()
		var id uint32
		r.check(proxy.Call(ns.BusName+".Notify", 0, "test-app", replaces, "dialog-information", "test", "body", []string{"go", "Go"}, hints, int32(300)).Store(&id))
		return id
	}
	waitSignal := func(member string, id uint32) *dbus.Signal {
		t.Helper()
		timer := time.NewTimer(8 * time.Second)
		defer timer.Stop()
		for {
			select {
			case s := <-signals:
				if s.Name == ns.BusName+"."+member && s.Body[0] == id {
					return s
				}
			case <-timer.C:
				t.Fatalf("missing %s for %d", member, id)
			}
		}
	}
	id := notify(0, map[string]dbus.Variant{})
	seq := ""
	eventually(t, func() bool {
		for _, item := range socketSnapshot(t, r.d).Items {
			if item.ID == id {
				seq = item.Seq
				ms, e := r.c.Poll(r.ctx, ns.Topic, "all")
				return e == nil && ns.Fold(ms)[seq].ID != ""
			}
		}
		return false
	})
	time.Sleep(350 * time.Millisecond)
	if !r.isOpen(id) {
		t.Fatal("expire_timeout closed centre item")
	}
	r.check(r.c.Clear(r.ctx, seq))
	sig := waitSignal("NotificationClosed", id)
	if sig.Body[1] != uint32(2) {
		t.Fatalf("reason %v", sig.Body[1])
	}
	id2 := notify(0, map[string]dbus.Variant{})
	eventually(t, func() bool { return len(r.events(id2)) > 0 })
	r.control(id2, "action", "go")
	waitSignal("ActionInvoked", id2)
	sig = waitSignal("NotificationClosed", id2)
	if sig.Body[1] != uint32(2) {
		t.Fatal("action close reason")
	}
	id3 := notify(0, map[string]dbus.Variant{})
	if notify(id3, map[string]dbus.Variant{}) != id3 {
		t.Fatal("replace ID changed")
	}
	id4 := notify(0, map[string]dbus.Variant{"transient": dbus.MakeVariant(true)})
	time.Sleep(350 * time.Millisecond)
	if len(r.events(id4)) != 0 {
		t.Fatal("transient published")
	}
	// Liveness uses the actual unique bus sender, not a caller-supplied app name.
	app.Close()
	eventually(t, func() bool {
		for _, item := range socketSnapshot(t, r.d).Items {
			if item.ID == id3 {
				return !item.SenderAlive
			}
		}
		return false
	})
	cancel()
}

func TestRealLibnotifyClients(t *testing.T) {
	bin := os.Getenv("NOTIFY_SEND")
	if bin == "" {
		var err error
		bin, err = exec.LookPath("notify-send")
		if err != nil {
			t.Skip("notify-send required")
		}
	}
	base := ntfyServer(t)
	privateBus(t)
	r := newRig(t, base)
	ctx, cancel := context.WithCancel(context.Background())
	bus, err := r.d.AttachBus(ctx, t.TempDir())
	r.check(err)
	defer bus.Close()
	defer cancel()
	done := make(chan error, 1)
	go func() { done <- r.d.Run(ctx) }()
	defer func() { cancel(); <-done }()
	for _, action := range []bool{false, true} {
		t.Run(strconv.FormatBool(action), func(t *testing.T) {
			args := []string{"-p", "-w"}
			if action {
				args = append(args, "-A", "archive=Archive")
			}
			args = append(args, "Real libnotify", "phone round trip")
			cmd := exec.Command(bin, args...)
			out, err := cmd.StdoutPipe()
			r.check(err)
			r.check(cmd.Start())
			t.Cleanup(func() {
				if cmd.Process != nil {
					cmd.Process.Kill()
				}
			})
			reader := bufio.NewReader(out)
			line, err := reader.ReadString('\n')
			r.check(err)
			n, err := strconv.ParseUint(strings.TrimSpace(line), 10, 32)
			r.check(err)
			id := uint32(n)
			var seq string
			eventually(t, func() bool {
				for _, item := range socketSnapshot(t, r.d).Items {
					if item.ID == id {
						seq = item.Seq
						messages, e := r.c.Poll(r.ctx, ns.Topic, "all")
						return e == nil && ns.Fold(messages)[seq].ID != ""
					}
				}
				return false
			})
			if action {
				r.control(id, "action", "archive")
				line, err = reader.ReadString('\n')
				r.check(err)
				if strings.TrimSpace(line) != "archive" {
					t.Fatal(line)
				}
			} else {
				r.check(r.c.Clear(r.ctx, seq))
			}
			exited := make(chan error, 1)
			go func() { exited <- cmd.Wait() }()
			select {
			case err := <-exited:
				r.check(err)
			case <-time.After(8 * time.Second):
				t.Fatal("libnotify did not exit")
			}
		})
	}
}
