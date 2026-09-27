package itest

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"garage-backend/internal/api"
	"garage-backend/internal/auth"
	"garage-backend/internal/config"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

func TestSettingsSeedProfileNameFromGarage(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "seed")
	gid := owner.Memberships[0].GarageID
	status, data := doJSON(t, "GET", "/api/garages/"+gid+"/settings", owner.AccessToken, gid, nil)
	if status != 200 {
		t.Fatalf("settings: %d %s", status, data)
	}
	var s struct {
		Profile struct {
			Name string `json:"name"`
		} `json:"profile"`
	}
	mustUnmarshal(t, data, &s)
	if s.Profile.Name != "Garage seed" {
		t.Fatalf("profile name = %q, want the registered garage name", s.Profile.Name)
	}
}

func TestCatalogCRUD(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "catcrud")
	gid := owner.Memberships[0].GarageID

	status, data := doJSON(t, "POST", "/api/catalog", owner.AccessToken, gid,
		map[string]any{"name": "Oil filter", "category": "sparePart", "unitPrice": 250})
	if status != 201 {
		t.Fatalf("create: %d %s", status, data)
	}
	var ci models.CatalogItem
	mustUnmarshal(t, data, &ci)
	if ci.Unit != "Pcs" || ci.UnitPrice != 250 {
		t.Fatalf("created = %+v", ci)
	}
	if status, _ := doJSON(t, "POST", "/api/catalog", owner.AccessToken, gid,
		map[string]any{"name": "Bad", "category": "nope", "unitPrice": 1}); status != 400 {
		t.Fatalf("bad category: %d", status)
	}
	status, data = doJSON(t, "PUT", "/api/catalog/"+ci.ID, owner.AccessToken, gid,
		map[string]any{"name": "Oil filter", "category": "sparePart", "unitPrice": 300, "unit": "Pcs"})
	if status != 200 {
		t.Fatalf("update: %d %s", status, data)
	}
	mustUnmarshal(t, data, &ci)
	if ci.UnitPrice != 300 {
		t.Fatalf("updated = %+v", ci)
	}
	if status, _ := doJSON(t, "DELETE", "/api/catalog/"+ci.ID, owner.AccessToken, gid, nil); status != 204 {
		t.Fatalf("delete: %d", status)
	}
	if status, _ := doJSON(t, "DELETE", "/api/catalog/"+ci.ID, owner.AccessToken, gid, nil); status != 404 {
		t.Fatalf("second delete: %d", status)
	}
}

func TestCheckoutCreatesRazorpaySubscription(t *testing.T) {
	truncate(t)
	var gotNotes map[string]string
	fake := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if u, p, ok := r.BasicAuth(); !ok || u != "rzp_key" || p != "rzp_secret" || r.URL.Path != "/v1/subscriptions" {
			w.WriteHeader(401)
			return
		}
		var body struct {
			PlanID string            `json:"plan_id"`
			Notes  map[string]string `json:"notes"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		gotNotes = body.Notes
		_, _ = w.Write([]byte(`{"id":"sub_123","short_url":"https://rzp.io/i/abc","status":"created"}`))
	}))
	defer fake.Close()

	orig := ts
	ts = httptest.NewServer(api.NewRouter(&api.Server{
		Store:  store.New(pool),
		Issuer: auth.NewTokenIssuer("test-secret-16-chars"),
		Config: config.Config{
			RazorpayKeyID: "rzp_key", RazorpayKeySecret: "rzp_secret",
			RazorpayPlanMonthly: "plan_m", RazorpayAPIBase: fake.URL,
		},
	}))
	defer func() { ts.Close(); ts = orig }()

	owner := registerOwner(t, "rzp")
	gid := owner.Memberships[0].GarageID
	status, data := doJSON(t, "POST", "/api/garages/"+gid+"/billing/checkout", owner.AccessToken, gid,
		map[string]string{"plan": "monthly"})
	if status != 200 {
		t.Fatalf("checkout: %d %s", status, data)
	}
	var res map[string]any
	mustUnmarshal(t, data, &res)
	if res["short_url"] != "https://rzp.io/i/abc" || res["subscription_id"] != "sub_123" {
		t.Fatalf("checkout = %v", res)
	}
	if gotNotes["garage_id"] != gid {
		t.Fatalf("notes = %v", gotNotes)
	}
	if found, err := store.New(pool).GarageIDByProviderSubscription(ctx, "sub_123"); err != nil || found != gid {
		t.Fatalf("provider sub not stored: %q %v", found, err)
	}
}
