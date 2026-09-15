package store

import "context"

// Page caps list responses. Handlers parse ?limit=&offset=; absent params
// keep the legacy unbounded behaviour (large limit) so old clients/tests pass.
const (
	DefaultPageLimit = 50
	MaxPageLimit     = 200
)

// ClampLimit normalises client pagination input.
func ClampLimit(limit, offset int) (int, int) {
	if limit <= 0 {
		limit = DefaultPageLimit
	}
	if limit > MaxPageLimit {
		limit = MaxPageLimit
	}
	if offset < 0 {
		offset = 0
	}
	return limit, offset
}

type Page struct {
	Items  any `json:"items"`
	Total  int `json:"total"`
	Limit  int `json:"limit"`
	Offset int `json:"offset"`
}

func countByGarage(ctx context.Context, s *Store, table, garageID string) (int, error) {
	var n int
	err := s.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM `+table+` WHERE garage_id = $1`, garageID).Scan(&n)
	return n, err
}
