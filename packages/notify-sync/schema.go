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
