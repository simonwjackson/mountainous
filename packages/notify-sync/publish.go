package notifysync

import (
	"bytes"
	"encoding/json"
)

const (
	ntfyMessageMaxBytes = 4095
	// ntfy v2.28.0 server/config.go:69 defaults MessageSizeLimit to 4096.
	// server/server.go:2050 reads JSON with MessageSizeLimit*2 (8192).
	// util/util.go:402-409 and util/peek.go:24-38 reject reaching that limit.
	// Thus 8191 is the largest accepted encoded JSON request, not 8192.
	ntfyJSONMaxBytes = 8191
)

// PublishSizeError means metadata alone leaves no room for a message. Retrying
// unchanged input cannot fix it; the outbox must park it, not block other rows.
type PublishSizeError struct{}

func (*PublishSizeError) Error() string {
	return "notification metadata leaves no text budget within ntfy's 8191-byte JSON request limit"
}

func encodePublish(m Message) ([]byte, error) {
	if m.Topic == Topic {
		m.Message = clip(m.Message, ntfyMessageMaxBytes)
	}
	encode := func() ([]byte, error) {
		var buffer bytes.Buffer
		encoder := json.NewEncoder(&buffer)
		// This is an HTTP JSON document, not inline HTML. Escaping <>& wastes the
		// limited request budget without adding protection at this boundary.
		encoder.SetEscapeHTML(false)
		if err := encoder.Encode(m); err != nil {
			return nil, err
		}
		return bytes.TrimSuffix(buffer.Bytes(), []byte{'\n'}), nil
	}
	data, err := encode()
	if err != nil {
		return nil, err
	}
	if len(data) <= ntfyJSONMaxBytes {
		return data, nil
	}
	if m.Topic != Topic {
		return nil, &PublishSizeError{}
	}
	text := m.Message
	ends := []int{0}
	for offset := range text {
		if offset > 0 {
			ends = append(ends, offset)
		}
	}
	ends = append(ends, len(text))
	// Search decoded rune boundaries, then encode the COMPLETE document. This
	// never slices an encoded escape and retains the longest prefix that fits.
	low, high := 0, len(ends)-1
	var best []byte
	bestEnd := 0
	for low <= high {
		middle := (low + high) / 2
		m.Message = text[:ends[middle]]
		candidate, err := encode()
		if err != nil {
			return nil, err
		}
		if len(candidate) <= ntfyJSONMaxBytes {
			best = candidate
			bestEnd = ends[middle]
			low = middle + 1
		} else {
			high = middle - 1
		}
	}
	if best == nil || bestEnd == 0 {
		return nil, &PublishSizeError{}
	}
	return best, nil
}
