package api

import (
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"garage-backend/internal/config"
)

func TestSiteServedOutsideAPI(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "index.html"), []byte("<html>site</html>"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(dir, "assets"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "assets", "app.js"), []byte("console.log(1)"), 0o644); err != nil {
		t.Fatal(err)
	}
	h := NewRouterWithOrigins(&Server{Config: config.Config{SiteDir: dir}}, nil)

	get := func(method, p string) *httptest.ResponseRecorder {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(method, p, nil))
		return rec
	}
	for _, p := range []string{"/", "/privacy", "/delete-account"} {
		rec := get("GET", p)
		if rec.Code != 200 || !strings.Contains(rec.Body.String(), "site") {
			t.Fatalf("%s: %d %q, want the site's index.html", p, rec.Code, rec.Body.String())
		}
	}
	if rec := get("GET", "/assets/app.js"); rec.Code != 200 ||
		!strings.Contains(rec.Header().Get("Cache-Control"), "immutable") {
		t.Fatalf("asset: %d cache=%q", rec.Code, rec.Header().Get("Cache-Control"))
	}
	if rec := get("GET", "/assets/old-hash.js"); rec.Code != 404 {
		t.Fatalf("missing asset should 404, got %d", rec.Code)
	}
	for _, p := range []string{"/api/nope", "/api"} {
		if rec := get("GET", p); rec.Code != 404 || !strings.Contains(rec.Body.String(), "not_found") {
			t.Fatalf("%s must stay a JSON 404, got %d %q", p, rec.Code, rec.Body.String())
		}
	}
	if rec := get("POST", "/contact"); rec.Code != 404 {
		t.Fatalf("POST outside /api should 404, got %d", rec.Code)
	}
	if rec := get("GET", "/api/health"); rec.Code != 200 {
		t.Fatalf("health: %d", rec.Code)
	}
}

func TestNoSiteDirServesAPIOnly(t *testing.T) {
	h := NewRouterWithOrigins(&Server{}, nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/", nil))
	if rec.Code != 404 {
		t.Fatalf("without SITE_DIR, / should 404, got %d", rec.Code)
	}
}
