package api

import (
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strings"
)

// siteHandler serves the public website (backend/site, built with Vite) from
// dir for every path outside /api. Real files (JS, CSS, images) are served
// as-is; any other path gets index.html so the React router can render
// /privacy, /terms, etc. Returns nil when dir is empty or missing, so the
// API runs on its own in development and tests.
func siteHandler(dir string) http.Handler {
	if dir == "" {
		return nil
	}
	index := filepath.Join(dir, "index.html")
	if _, err := os.Stat(index); err != nil {
		return nil
	}
	files := http.FileServer(http.Dir(dir))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		clean := path.Clean("/" + r.URL.Path)
		if clean != "/" {
			if info, err := os.Stat(filepath.Join(dir, filepath.FromSlash(clean))); err == nil && !info.IsDir() {
				// Vite fingerprints everything under /assets: cache forever.
				if strings.HasPrefix(clean, "/assets/") {
					w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
				}
				files.ServeHTTP(w, r)
				return
			}
		}
		// A missing file (anything with an extension, e.g. an old asset hash)
		// is a real 404; extensionless paths are app routes.
		if path.Ext(clean) != "" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Cache-Control", "no-cache")
		http.ServeFile(w, r, index)
	})
}
