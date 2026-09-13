package auth

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
)

const testGarageID = "11111111-1111-1111-1111-111111111111"

type fakeUsers struct {
	user models.User
	err  error
}

func (f fakeUsers) UserByID(context.Context, string) (models.User, error) { return f.user, f.err }

type fakeMemberships struct {
	member models.Membership
	err    error
}

func (f fakeMemberships) MembershipFor(context.Context, string, string) (models.Membership, error) {
	return f.member, f.err
}

func newRequest(t *testing.T, url string, urlParams map[string]string, token, garageHeader string) *http.Request {
	t.Helper()
	r := httptest.NewRequest("GET", url, nil)
	rctx := chi.NewRouteContext()
	for k, v := range urlParams {
		rctx.URLParams.Add(k, v)
	}
	r = r.WithContext(context.WithValue(r.Context(), chi.RouteCtxKey, rctx))
	if token != "" {
		r.Header.Set("Authorization", "Bearer "+token)
	}
	if garageHeader != "" {
		r.Header.Set("X-Garage-Id", garageHeader)
	}
	return r
}

func ctxHandler(w http.ResponseWriter, r *http.Request) {
	httputil.JSON(w, 200, map[string]any{
		"user_id":     UserID(r.Context()),
		"garage_id":   GarageID(r.Context()),
		"role":        Role(r.Context()),
		"permissions": Permissions(r.Context()),
	})
}

func TestRequireAuth(t *testing.T) {
	issuer := NewTokenIssuer("secret")
	users := fakeUsers{user: models.User{ID: "u-1"}}
	h := RequireAuth(issuer, users)(http.HandlerFunc(ctxHandler))

	t.Run("missing header is 401", func(t *testing.T) {
		rr := httptest.NewRecorder()
		h.ServeHTTP(rr, newRequest(t, "/api/me", nil, "", ""))
		if rr.Code != 401 {
			t.Fatalf("status = %d, want 401", rr.Code)
		}
		if !strings.Contains(rr.Body.String(), `"unauthorized"`) {
			t.Fatalf("body = %s", rr.Body.String())
		}
	})

	t.Run("valid token reaches handler with user id", func(t *testing.T) {
		token, _ := issuer.Issue("u-1", time.Now())
		rr := httptest.NewRecorder()
		h.ServeHTTP(rr, newRequest(t, "/api/me", nil, token, ""))
		if rr.Code != 200 {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
		if !strings.Contains(rr.Body.String(), `"u-1"`) {
			t.Fatalf("body = %s", rr.Body.String())
		}
	})

	t.Run("bearer scheme is case-insensitive", func(t *testing.T) {
		token, _ := issuer.Issue("u-1", time.Now())
		r := newRequest(t, "/api/me", nil, "", "")
		r.Header.Set("Authorization", "bearer "+token)
		rr := httptest.NewRecorder()
		h.ServeHTTP(rr, r)
		if rr.Code != 200 {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})

	t.Run("user lookup failure is 401", func(t *testing.T) {
		token, _ := issuer.Issue("u-1", time.Now())
		h := RequireAuth(issuer, fakeUsers{err: errors.New("db down")})(http.HandlerFunc(ctxHandler))
		rr := httptest.NewRecorder()
		h.ServeHTTP(rr, newRequest(t, "/api/me", nil, token, ""))
		if rr.Code != 401 || !strings.Contains(rr.Body.String(), "user no longer exists") {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})

	t.Run("expired token is 401", func(t *testing.T) {
		token, _ := issuer.Issue("u-1", time.Now().Add(-AccessTokenTTL-time.Minute))
		rr := httptest.NewRecorder()
		h.ServeHTTP(rr, newRequest(t, "/api/me", nil, token, ""))
		if rr.Code != 401 {
			t.Fatalf("status = %d, want 401", rr.Code)
		}
	})
}

func TestRequireGarage(t *testing.T) {
	issuer := NewTokenIssuer("secret")
	token, _ := issuer.Issue("u-1", time.Now())
	activeMember := models.Membership{
		GarageID: testGarageID, GarageName: "G", Role: "staff",
		Permissions: []string{"customers.manage"}, IsActive: true,
	}

	newChain := func(m fakeMemberships) http.Handler {
		return RequireAuth(issuer, fakeUsers{user: models.User{ID: "u-1"}})(
			RequireGarage(m)(http.HandlerFunc(ctxHandler)))
	}

	t.Run("header only", func(t *testing.T) {
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: activeMember}).ServeHTTP(rr,
			newRequest(t, "/api/stuff", nil, token, testGarageID))
		if rr.Code != 200 || !strings.Contains(rr.Body.String(), testGarageID) {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
		if !strings.Contains(rr.Body.String(), `"role":"staff"`) {
			t.Fatalf("role not in context: %s", rr.Body.String())
		}
	})

	t.Run("url param used when header missing", func(t *testing.T) {
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: activeMember}).ServeHTTP(rr,
			newRequest(t, "/api/garages/x/members", map[string]string{"garageId": testGarageID}, token, ""))
		if rr.Code != 200 || !strings.Contains(rr.Body.String(), testGarageID) {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})

	t.Run("header and url param mismatch is 400", func(t *testing.T) {
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: activeMember}).ServeHTTP(rr,
			newRequest(t, "/api/garages/x/members", map[string]string{"garageId": testGarageID},
				token, "22222222-2222-2222-2222-222222222222"))
		if rr.Code != 400 || !strings.Contains(rr.Body.String(), `"invalid_request"`) {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})

	t.Run("missing garage id entirely is 400", func(t *testing.T) {
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: activeMember}).ServeHTTP(rr,
			newRequest(t, "/api/stuff", nil, token, ""))
		if rr.Code != 400 {
			t.Fatalf("status = %d, want 400", rr.Code)
		}
	})

	t.Run("non-member is 403", func(t *testing.T) {
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{err: errors.New("no rows")}).ServeHTTP(rr,
			newRequest(t, "/api/stuff", nil, token, testGarageID))
		if rr.Code != 403 || !strings.Contains(rr.Body.String(), `"forbidden"`) {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})

	t.Run("deactivated member is 403", func(t *testing.T) {
		inactive := activeMember
		inactive.IsActive = false
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: inactive}).ServeHTTP(rr,
			newRequest(t, "/api/stuff", nil, token, testGarageID))
		if rr.Code != 403 || !strings.Contains(rr.Body.String(), "membership is deactivated") {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})
}

func TestRequirePermission(t *testing.T) {
	issuer := NewTokenIssuer("secret")
	token, _ := issuer.Issue("u-1", time.Now())
	base := RequireAuth(issuer, fakeUsers{user: models.User{ID: "u-1"}})

	newChain := func(m fakeMemberships) http.Handler {
		return base(RequireGarage(m)(
			RequirePermission("expenses.manage")(http.HandlerFunc(ctxHandler))))
	}
	staffURL := "/api/garages/x/expenses"

	t.Run("owner bypasses", func(t *testing.T) {
		owner := models.Membership{GarageID: testGarageID, Role: "owner", Permissions: nil, IsActive: true}
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: owner}).ServeHTTP(rr,
			newRequest(t, staffURL, nil, token, testGarageID))
		if rr.Code != 200 {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})

	t.Run("staff with permission passes", func(t *testing.T) {
		m := models.Membership{GarageID: testGarageID, Role: "staff",
			Permissions: []string{"expenses.manage"}, IsActive: true}
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: m}).ServeHTTP(rr,
			newRequest(t, staffURL, nil, token, testGarageID))
		if rr.Code != 200 {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})

	t.Run("staff without permission is 403 naming the key", func(t *testing.T) {
		m := models.Membership{GarageID: testGarageID, Role: "staff",
			Permissions: []string{"customers.manage"}, IsActive: true}
		rr := httptest.NewRecorder()
		newChain(fakeMemberships{member: m}).ServeHTTP(rr,
			newRequest(t, staffURL, nil, token, testGarageID))
		if rr.Code != 403 || !strings.Contains(rr.Body.String(), "expenses.manage") {
			t.Fatalf("status = %d body %s", rr.Code, rr.Body.String())
		}
	})
}
