package notifysync

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"sync"

	"github.com/google/jsonschema-go/jsonschema"
)

// UISocketSchema defines the versioned client and daemon wire contract.
//
//go:embed schema/ui-socket.v1.json
var UISocketSchema []byte

var socketSchema = sync.OnceValues(func() (*jsonschema.Resolved, error) {
	var schema jsonschema.Schema
	if err := json.Unmarshal(UISocketSchema, &schema); err != nil {
		return nil, err
	}
	return schema.Resolve(nil)
})

// ValidateSocketMessage validates an operation or event against the shared
// JSON Schema, including required fields and rejection of unknown fields.
func ValidateSocketMessage(data []byte) error {
	schema, err := socketSchema()
	if err != nil {
		return err
	}
	var value any
	if err = json.Unmarshal(data, &value); err != nil {
		return err
	}
	return schema.Validate(value)
}
func DecodeUIOperation(data []byte) (UIOperation, error) {
	if err := ValidateSocketMessage(data); err != nil {
		return UIOperation{}, err
	}
	var op UIOperation
	if err := json.Unmarshal(data, &op); err != nil {
		return op, err
	}
	if op.Op == "" {
		return op, fmt.Errorf("expected a client operation")
	}
	return op, nil
}

// EncodeUIEvent is the runtime output boundary. The socket writes only the
// bytes returned here, so no event variant can bypass the frozen schema.
func EncodeUIEvent(event UIEvent) ([]byte, error) {
	data, err := json.Marshal(event)
	if err != nil {
		return nil, err
	}
	if err = ValidateSocketMessage(data); err != nil {
		return nil, fmt.Errorf("invalid outgoing UI event: %w", err)
	}
	return data, nil
}

func validateUIItem(item Item) error {
	_, err := EncodeUIEvent(UIEvent{Type: "upsert", Item: &item})
	return err
}
