package notifysync

import (
	"context"
	"errors"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"strings"

	"github.com/godbus/dbus/v5"
	"github.com/godbus/dbus/v5/introspect"
)

const BusName = "org.freedesktop.Notifications"
const BusPath = dbus.ObjectPath("/org/freedesktop/Notifications")

type busNotifications struct {
	conn     *dbus.Conn
	d        *Daemon
	imageDir string
}

func (n *busNotifications) GetCapabilities() ([]string, *dbus.Error) {
	return []string{"actions", "body", "persistence", "icon-static"}, nil
}
func (n *busNotifications) GetServerInformation() (string, string, string, string, *dbus.Error) {
	return "notify-sync", "mountainous", "1.0.0", "1.2", nil
}
func boolHint(h map[string]dbus.Variant, k string) bool {
	switch v := h[k].Value().(type) {
	case bool:
		return v
	case byte:
		return v != 0
	case int32:
		return v != 0
	case uint32:
		return v != 0
	}
	return false
}
func (n *busNotifications) Notify(sender dbus.Sender, app string, replaces uint32, icon, summary, body string, actions []string, hints map[string]dbus.Variant, expire int32) (uint32, *dbus.Error) {
	if len(actions)%2 != 0 {
		return 0, dbus.MakeFailedError(errors.New("actions must be key/label pairs"))
	}
	pairs := []Action{}
	for i := 0; i < len(actions); i += 2 {
		pairs = append(pairs, Action{actions[i], actions[i+1]})
	}
	urgency := byte(1)
	if v, ok := hints["urgency"].Value().(byte); ok {
		urgency = v
	}
	img, err := saveImage(n.imageDir, hints)
	if err != nil {
		return 0, dbus.MakeFailedError(err)
	}
	id, err := n.d.Notify(NotifyInput{Sender: string(sender), AppName: app, AppIcon: icon, Replaces: replaces, Summary: summary, Body: body, Actions: pairs, Urgency: urgency, Resident: boolHint(hints, "resident"), Transient: boolHint(hints, "transient"), Image: img})
	if err != nil {
		return 0, dbus.MakeFailedError(err)
	}
	// The sender may exit while Notify is dispatched in its own goroutine,
	// before NameOwnerChanged can find the new row. Recheck after the commit.
	var alive bool
	if err = n.conn.BusObject().Call("org.freedesktop.DBus.NameHasOwner", 0, string(sender)).Store(&alive); err != nil {
		return 0, dbus.MakeFailedError(err)
	}
	if !alive {
		if err = n.d.SenderGone(string(sender)); err != nil {
			return 0, dbus.MakeFailedError(err)
		}
	}
	return id, nil
}
func (n *busNotifications) CloseNotification(sender dbus.Sender, id uint32) *dbus.Error {
	if err := n.d.Close(id, 3, true, string(sender)); err != nil {
		return dbus.MakeFailedError(err)
	}
	return nil
}

// AttachBus owns the well-known name before Run may replay a single event.
func (d *Daemon) AttachBus(ctx context.Context, imageDir string) (*dbus.Conn, error) {
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		return nil, err
	}
	fail := func(err error) (*dbus.Conn, error) { conn.Close(); return nil, err }
	n := &busNotifications{d: d, imageDir: imageDir, conn: conn}
	if err = conn.Export(n, BusPath, BusName); err != nil {
		return fail(err)
	}
	node := &introspect.Node{Name: string(BusPath), Interfaces: []introspect.Interface{{Name: BusName, Methods: introspect.Methods(n), Signals: []introspect.Signal{{Name: "NotificationClosed", Args: []introspect.Arg{{Name: "id", Type: "u"}, {Name: "reason", Type: "u"}}}, {Name: "ActionInvoked", Args: []introspect.Arg{{Name: "id", Type: "u"}, {Name: "action_key", Type: "s"}}}, {Name: "ActivationToken", Args: []introspect.Arg{{Name: "id", Type: "u"}, {Name: "activation_token", Type: "s"}}}}}, introspect.IntrospectData}}
	if err = conn.Export(introspect.NewIntrospectable(node), BusPath, "org.freedesktop.DBus.Introspectable"); err != nil {
		return fail(err)
	}
	reply, err := conn.RequestName(BusName, dbus.NameFlagDoNotQueue)
	if err != nil {
		return fail(err)
	}
	if reply != dbus.RequestNameReplyPrimaryOwner {
		return fail(errors.New("notification bus name already owned"))
	}
	d.Emit = func(sig Signal) error {
		if sig.Member == "ActionInvoked" {
			return conn.Emit(BusPath, BusName+".ActionInvoked", sig.ID, sig.Key)
		}
		return conn.Emit(BusPath, BusName+".NotificationClosed", sig.ID, sig.Reason)
	}
	if err = conn.AddMatchSignal(dbus.WithMatchInterface("org.freedesktop.DBus"), dbus.WithMatchMember("NameOwnerChanged")); err != nil {
		return fail(err)
	}
	signals := make(chan *dbus.Signal, 128)
	conn.Signal(signals)
	// Install the watch first, then check stored unique names. This closes the
	// startup race where a client exits during liveness reconciliation.
	var session string
	if err = conn.BusObject().Call("org.freedesktop.DBus.GetId", 0).Store(&session); err != nil {
		return fail(err)
	}
	if err = d.Session(session); err != nil {
		return fail(err)
	}
	senders, err := d.Senders()
	if err != nil {
		return fail(err)
	}
	for _, sender := range senders {
		var exists bool
		err = conn.BusObject().Call("org.freedesktop.DBus.NameHasOwner", 0, sender).Store(&exists)
		if err != nil {
			return fail(err)
		}
		if !exists {
			if err = d.SenderGone(sender); err != nil {
				return fail(err)
			}
		}
	}
	go func() {
		defer conn.RemoveSignal(signals)
		for {
			select {
			case <-ctx.Done():
				return
			case sig := <-signals:
				if sig == nil {
					return
				}
				if len(sig.Body) == 3 {
					name, ok := sig.Body[0].(string)
					owner, ok2 := sig.Body[2].(string)
					if ok && ok2 && strings.HasPrefix(name, ":") && owner == "" {
						if err := d.SenderGone(name); err != nil {
							conn.Close()
							return
						}
					}
				}
			}
		}
	}()
	return conn, nil
}
func saveImage(dir string, hints map[string]dbus.Variant) (*string, error) {
	var raw any
	for _, k := range []string{"image-data", "image_data", "icon_data"} {
		if v, ok := hints[k]; ok {
			raw = v.Value()
			break
		}
	}
	if raw == nil {
		for _, k := range []string{"image-path", "image_path"} {
			if v, ok := hints[k].Value().(string); ok {
				if strings.HasPrefix(v, "file://") {
					v = strings.TrimPrefix(v, "file://")
				}
				if filepath.IsAbs(v) {
					return &v, nil
				}
			}
		}
		return nil, nil
	}
	fields, ok := raw.([]interface{})
	if !ok || len(fields) != 7 {
		return nil, errors.New("invalid image-data")
	}
	w, wok := fields[0].(int32)
	h, hok := fields[1].(int32)
	stride, sok := fields[2].(int32)
	alpha, aok := fields[3].(bool)
	bits, bok := fields[4].(int32)
	channels, cok := fields[5].(int32)
	data, dok := fields[6].([]byte)
	if !wok || !hok || !sok || !aok || !bok || !cok || !dok || w <= 0 || h <= 0 || w > 4096 || h > 4096 || bits != 8 || (channels != 3 && channels != 4) || stride < w*channels || int64(stride)*int64(h) > int64(len(data)) || len(data) > 64<<20 {
		return nil, errors.New("invalid image-data dimensions")
	}
	img := image.NewNRGBA(image.Rect(0, 0, int(w), int(h)))
	for y := 0; y < int(h); y++ {
		for x := 0; x < int(w); x++ {
			i := y*int(stride) + x*int(channels)
			a := byte(255)
			if alpha && channels == 4 {
				a = data[i+3]
			}
			img.SetNRGBA(x, y, color.NRGBA{R: data[i], G: data[i+1], B: data[i+2], A: a})
		}
	}
	if err := os.MkdirAll(dir, 0700); err != nil {
		return nil, err
	}
	f, err := os.CreateTemp(dir, "notification-*.png")
	if err != nil {
		return nil, err
	}
	path := f.Name()
	err = png.Encode(f, img)
	closeErr := f.Close()
	if err != nil || closeErr != nil {
		os.Remove(path)
		return nil, fmt.Errorf("cannot save notification image")
	}
	return &path, nil
}
