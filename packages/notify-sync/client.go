package notifysync

import (
	"bufio"
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strings"
	"time"
)

// HTTPError exposes the status code without leaking response bodies or tokens.
type HTTPError struct{ Status int }

func (e *HTTPError) Error() string { return fmt.Sprintf("ntfy HTTP %d", e.Status) }
func permanentDeliveryError(err error) bool {
	var h *HTTPError
	return errors.As(err, &h) && h.Status >= 400 && h.Status < 500 && h.Status != 408 && h.Status != 429
}

type Client struct {
	Base, Public, Token, Button string
	HTTP                        *http.Client
}

func NewClient(base, public, token, button string) (*Client, error) {
	for _, s := range []string{base, public} {
		u, err := url.Parse(s)
		if err != nil || u.Host == "" || u.User != nil || u.RawQuery != "" || u.Fragment != "" || (u.Scheme != "http" && u.Scheme != "https") {
			return nil, errors.New("invalid ntfy URL")
		}
	}
	return &Client{Base: strings.TrimRight(base, "/"), Public: strings.TrimRight(public, "/"), Token: token, Button: button, HTTP: &http.Client{Timeout: 30 * time.Second}}, nil
}
func ReadToken(path string) (string, error) {
	if path == "" {
		return "", nil
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return "", errors.New("credential file unavailable")
	}
	t := strings.TrimSpace(string(b))
	if t == "" || strings.ContainsAny(t, "\r\n") {
		return "", errors.New("invalid credential file")
	}
	return t, nil
}
func (c *Client) request(ctx context.Context, method, path string, body any) (*http.Response, error) {
	var data []byte
	var err error
	if body != nil {
		data, err = json.Marshal(body)
		if err != nil {
			return nil, err
		}
	}
	req, err := http.NewRequestWithContext(ctx, method, c.Base+path, bytes.NewReader(data))
	if err != nil {
		return nil, errors.New("invalid ntfy request")
	}
	if c.Token != "" {
		req.Header.Set("Authorization", "Bearer "+c.Token)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	r, err := c.HTTP.Do(req)
	if err != nil {
		return nil, errors.New("ntfy transport failed")
	}
	if r.StatusCode < 200 || r.StatusCode >= 300 {
		r.Body.Close()
		return nil, &HTTPError{Status: r.StatusCode}
	}
	return r, nil
}
func (c *Client) Publish(ctx context.Context, m Message) (Message, error) {
	r, err := c.request(ctx, "POST", "", m)
	if err != nil {
		return Message{}, err
	}
	defer r.Body.Close()
	var out Message
	err = json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&out)
	if err == nil && out.ID == "" {
		err = errors.New("ntfy response has no ID")
	}
	return out, err
}
func (c *Client) Clear(ctx context.Context, seq string) error {
	if !ValidSequence(seq) {
		return errors.New("invalid sequence")
	}
	r, err := c.request(ctx, "PUT", "/"+Topic+"/"+seq+"/clear", nil)
	if err == nil {
		r.Body.Close()
	}
	return err
}
func (c *Client) Control(ctx context.Context, ctl Control) error {
	if err := ctl.Validate(); err != nil {
		return err
	}
	b, _ := json.Marshal(ctl)
	_, err := c.Publish(ctx, Message{Topic: ControlTopic, Message: string(b)})
	return err
}

// Poll uses one topic at a time. ntfy's live dispatch and multi-topic replay do
// not guarantee cache insert order. A truncated poll is never applied.
func (c *Client) Poll(ctx context.Context, topic, cursor string) ([]Message, error) {
	if topic != Topic && topic != ControlTopic {
		return nil, errors.New("invalid topic")
	}
	if cursor == "" {
		cursor = "all"
	}
	r, err := c.request(ctx, "GET", "/"+topic+"/json?poll=1&since="+url.QueryEscape(cursor), nil)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()
	if r.Header.Get("X-Messages-Truncated") == "1" {
		return nil, errors.New("ntfy cache poll exceeds the 10 MiB replay limit; refusing incomplete reconciliation")
	}
	out := []Message{}
	scanner := bufio.NewScanner(r.Body)
	scanner.Buffer(make([]byte, 4096), 1<<20)
	for scanner.Scan() {
		if len(scanner.Bytes()) == 0 {
			continue
		}
		var m Message
		if err := json.Unmarshal(scanner.Bytes(), &m); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, scanner.Err()
}
func Fold(messages []Message) map[string]Message {
	open := map[string]Message{}
	for _, m := range messages {
		switch m.Event {
		case "message":
			open[m.Seq()] = m
		case "message_clear", "message_delete":
			delete(open, m.Seq())
		}
	}
	return open
}

type Listed struct {
	Item  Item   `json:"item"`
	Trust string `json:"trust"`
}

func (c *Client) List(ctx context.Context) ([]Listed, error) {
	ms, err := c.Poll(ctx, Topic, "all")
	if err != nil {
		return nil, err
	}
	out := []Listed{}
	for _, m := range Fold(ms) {
		trust := "untrusted"
		if m.metadata().Agent {
			trust = "agent"
		}
		out = append(out, Listed{m.Remote(0), trust})
	}
	sortListed(out)
	return out, nil
}
func sortListed(items []Listed) {
	sort.Slice(items, func(i, j int) bool { return items[i].Item.Seq < items[j].Item.Seq })
}

type SendInput struct {
	Name     string   `json:"name"`
	Summary  string   `json:"summary"`
	Body     string   `json:"body,omitempty"`
	Actions  []Action `json:"actions,omitempty"`
	Resident bool     `json:"resident,omitempty"`
}

func (c *Client) Send(ctx context.Context, in SendInput) (string, error) {
	if in.Name == "" || len(in.Summary)+len(in.Body) > 3000 || len(in.Actions) > 16 {
		return "", errors.New("invalid send input (name required, text <=3000 bytes, <=16 actions)")
	}
	nonce := make([]byte, 12)
	if _, err := rand.Read(nonce); err != nil {
		return "", err
	}
	seq := "agent-" + SafeName(in.Name) + "-" + hex.EncodeToString(nonce)
	for _, a := range in.Actions {
		if a.Key == "" || len(a.Key) > 256 || len(a.Label) > 128 {
			return "", errors.New("invalid action")
		}
	}
	_, err := c.Publish(ctx, Payload(Item{Seq: seq, Host: SafeName(in.Name), AppName: "agent", Summary: in.Summary, Body: in.Body, Actions: in.Actions, Resident: in.Resident, SenderAlive: true, Urgency: 1}, c.Public, c.Button))
	return seq, err
}
func (c *Client) Wait(ctx context.Context, seq string) (Control, error) {
	if !ValidSequence(seq) {
		return Control{}, errors.New("invalid sequence")
	}
	// Each call is stateless. Return the first cached action/clear for this seq,
	// including one that arrived between send and wait.
	tick := time.NewTicker(250 * time.Millisecond)
	defer tick.Stop()
	for {
		ctls, err := c.Poll(ctx, ControlTopic, "all")
		if err != nil {
			return Control{}, err
		}
		for _, m := range ctls {
			var ctl Control
			if json.Unmarshal([]byte(m.Message), &ctl) == nil && ctl.Validate() == nil && ctl.Seq == seq {
				return ctl, nil
			}
		}
		ms, err := c.Poll(ctx, Topic, "all")
		if err != nil {
			return Control{}, err
		}
		for _, m := range ms {
			if m.Seq() == seq && (m.Event == "message_clear" || m.Event == "message_delete") {
				return Control{Version: 1, Type: "clear", Seq: seq}, nil
			}
		}
		select {
		case <-ctx.Done():
			return Control{}, ctx.Err()
		case <-tick.C:
		}
	}
}
