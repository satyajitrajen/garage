package api

import (
	"net/http"
	"strconv"

	"garage-backend/internal/store"
)

// pageParams parses ?limit=&offset=. ok=false means legacy unbounded mode:
// handlers return the old {"items": [...]} shape. When either param is
// present, handlers return {"items","total","limit","offset"}.
func pageParams(r *http.Request) (limit, offset int, ok bool) {
	q := r.URL.Query()
	_, hasLimit := q["limit"]
	_, hasOffset := q["offset"]
	if !hasLimit && !hasOffset {
		return 0, 0, false
	}
	limit = store.DefaultPageLimit
	offset = 0
	if v := q.Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			limit = n
		}
	}
	if v := q.Get("offset"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			offset = n
		}
	}
	limit, offset = store.ClampLimit(limit, offset)
	return limit, offset, true
}
