package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
)

// RawToken generates a 32-byte hex token and its SHA-256 hash for storage.
func RawToken() (raw, hash string, err error) {
	var b [32]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", "", err
	}
	raw = hex.EncodeToString(b[:])
	sum := sha256.Sum256([]byte(raw))
	return raw, hex.EncodeToString(sum[:]), nil
}

// HashToken hashes a client-supplied raw token for lookup.
func HashToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}
