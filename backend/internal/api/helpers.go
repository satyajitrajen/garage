package api

import (
	"github.com/google/uuid"
)

// parseID parses a client-supplied resource id from a URL parameter.
func parseID(raw string) (uuid.UUID, error) {
	return uuid.Parse(raw)
}
