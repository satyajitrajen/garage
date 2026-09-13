package auth

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const AccessTokenTTL = 15 * time.Minute

// TokenIssuer issues and verifies HS256 access tokens whose only claims are
// sub (user id) and exp. Garage context is not in the token — it comes from
// the X-Garage-Id header per request so multi-garage users never re-login.
type TokenIssuer struct {
	secret []byte
}

func NewTokenIssuer(secret string) *TokenIssuer {
	return &TokenIssuer{secret: []byte(secret)}
}

func (t *TokenIssuer) Issue(userID string, now time.Time) (string, error) {
	claims := jwt.RegisteredClaims{
		Subject:   userID,
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(AccessTokenTTL)),
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(t.secret)
}

func (t *TokenIssuer) Verify(tokenStr string) (string, error) {
	parsed, err := jwt.Parse(tokenStr, func(token *jwt.Token) (any, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return t.secret, nil
	})
	if err != nil || !parsed.Valid {
		return "", errors.New("invalid token")
	}
	sub, err := parsed.Claims.GetSubject()
	if err != nil || sub == "" {
		return "", errors.New("missing subject")
	}
	return sub, nil
}
