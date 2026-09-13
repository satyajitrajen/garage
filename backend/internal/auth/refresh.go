package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"time"
)

const RefreshTokenTTL = 30 * 24 * time.Hour

// NewRefreshToken returns (raw token, SHA-256 hash to store, expiry). Only the
// hash ever touches the database.
func NewRefreshToken(now time.Time) (raw string, hash string, expiresAt time.Time, err error) {
	buf := make([]byte, 32)
	if _, err = rand.Read(buf); err != nil {
		return "", "", time.Time{}, err
	}
	raw = hex.EncodeToString(buf)
	sum := sha256.Sum256([]byte(raw))
	return raw, hex.EncodeToString(sum[:]), now.Add(RefreshTokenTTL), nil
}

func HashRefreshToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}
