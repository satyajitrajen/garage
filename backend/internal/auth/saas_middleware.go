package auth

import (
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"garage-backend/internal/httputil"
	"garage-backend/internal/store"
)

// RateLimit is a tiny per-IP fixed window for auth endpoints (no new deps).
func RateLimit(maxReq int, window time.Duration) func(http.Handler) http.Handler {
	type bucket struct {
		n     int
		reset time.Time
	}
	var mu sync.Mutex
	buckets := map[string]*bucket{}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			key := clientIP(r)
			now := time.Now()
			mu.Lock()
			// Opportunistic sweep so the map can't grow without bound.
			if len(buckets) > 10000 {
				for k, b := range buckets {
					if now.After(b.reset) {
						delete(buckets, k)
					}
				}
			}
			b := buckets[key]
			if b == nil || now.After(b.reset) {
				b = &bucket{n: 0, reset: now.Add(window)}
				buckets[key] = b
			}
			b.n++
			n := b.n
			mu.Unlock()
			if n > maxReq {
				httputil.Error(w, 429, "rate_limited", "too many requests, try again later")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// clientIP prefers X-Forwarded-For (behind Caddy/proxies) and strips the
// port from RemoteAddr — without the split every connection gets its own
// bucket and limiting never triggers.
func clientIP(r *http.Request) string {
	if fwd := r.Header.Get("X-Forwarded-For"); fwd != "" {
		if i := strings.Index(fwd, ","); i >= 0 {
			return strings.TrimSpace(fwd[:i])
		}
		return strings.TrimSpace(fwd)
	}
	if host, _, err := net.SplitHostPort(r.RemoteAddr); err == nil {
		return host
	}
	return r.RemoteAddr
}

// SubscriptionGate blocks mutating calls when the garage subscription is
// expired/suspended. Reads pass through so owners can always view + pay.
func SubscriptionGate(st *store.Store) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Method == http.MethodGet || r.Method == http.MethodOptions {
				next.ServeHTTP(w, r)
				return
			}
			ok, state := st.Writable(r.Context(), GarageID(r.Context()))
			if !ok {
				msg := "subscription " + state + "; renew to continue"
				if state == "trial_expired" {
					msg = "trial expired; subscribe to continue"
				}
				httputil.Error(w, 402, "payment_required", msg)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// RequireSuperadmin allows only users flagged is_superadmin.
func RequireSuperadmin(st *store.Store) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			on, err := st.IsSuperadmin(r.Context(), UserID(r.Context()))
			if err != nil || !on {
				httputil.Error(w, 403, "forbidden", "superadmin only")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
