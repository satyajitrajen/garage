package auth

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

type UserProvider interface {
	UserByID(ctx context.Context, id string) (models.User, error)
}

type MembershipProvider interface {
	MembershipFor(ctx context.Context, garageID, userID string) (models.Membership, error)
}

// RequireAuth verifies the bearer JWT, checks the user still exists, and puts
// the user id into the request context.
func RequireAuth(issuer *TokenIssuer, users UserProvider) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			tokenStr, ok := cutBearer(r.Header.Get("Authorization"))
			if !ok {
				httputil.Error(w, 401, "unauthorized", "missing bearer token")
				return
			}
			userID, err := issuer.Verify(tokenStr)
			if err != nil {
				httputil.Error(w, 401, "unauthorized", "invalid or expired token")
				return
			}
			// Issue only signs server-generated UUIDs; a signed-but-malformed
			// sub must 401 here instead of surfacing as a store query error.
			if _, err := uuid.Parse(userID); err != nil {
				httputil.Error(w, 401, "unauthorized", "invalid or expired token")
				return
			}
			user, err := users.UserByID(r.Context(), userID)
			if err != nil {
				if errors.Is(err, store.ErrNotFound) {
					httputil.Error(w, 401, "unauthorized", "user no longer exists")
				} else {
					httputil.Error(w, 500, "internal", "internal error")
				}
				return
			}
			ctx := context.WithValue(r.Context(), ctxUserID, user.ID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// RFC 6750: the auth-scheme token is case-insensitive.
func cutBearer(header string) (string, bool) {
	const prefix = "Bearer "
	if len(header) <= len(prefix) || !strings.EqualFold(header[:len(prefix)], prefix) {
		return "", false
	}
	return header[len(prefix):], true
}

// RequireGarage resolves the garage context from the X-Garage-Id header
// (falling back to the {garageId} URL segment when the header is absent),
// rejects mismatches, and loads the caller's membership into context.
func RequireGarage(memberships MembershipProvider) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			garageID := r.Header.Get("X-Garage-Id")
			if urlGarage := chi.URLParam(r, "garageId"); urlGarage != "" {
				if garageID == "" {
					garageID = urlGarage
				} else if garageID != urlGarage {
					httputil.Error(w, 400, "invalid_request", "X-Garage-Id does not match garage in URL")
					return
				}
			}
			if _, err := uuid.Parse(garageID); err != nil {
				httputil.Error(w, 400, "invalid_request", "missing or invalid X-Garage-Id")
				return
			}
			m, err := memberships.MembershipFor(r.Context(), garageID, UserID(r.Context()))
			if err != nil {
				if errors.Is(err, store.ErrNotFound) {
					httputil.Error(w, 403, "forbidden", "not a member of this garage")
				} else {
					httputil.Error(w, 500, "internal", "internal error")
				}
				return
			}
			if !m.IsActive {
				httputil.Error(w, 403, "forbidden", "membership is deactivated")
				return
			}
			ctx := r.Context()
			ctx = context.WithValue(ctx, ctxGarageID, m.GarageID)
			ctx = context.WithValue(ctx, ctxRole, m.Role)
			ctx = context.WithValue(ctx, ctxPermissions, m.Permissions)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// RequirePermission lets owners through unconditionally and checks staff
// against the membership's permission array.
func RequirePermission(key string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if Role(r.Context()) != "owner" {
				found := false
				for _, p := range Permissions(r.Context()) {
					if p == key {
						found = true
						break
					}
				}
				if !found {
					httputil.Error(w, 403, "forbidden", "missing permission: "+key)
					return
				}
			}
			next.ServeHTTP(w, r)
		})
	}
}
