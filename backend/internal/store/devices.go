package store

import "context"

// UpsertDeviceToken registers an FCM token for a user in a garage, moving it
// if the device was previously registered to someone else.
func (s *Store) UpsertDeviceToken(ctx context.Context, token, userID, garageID, platform string) error {
	_, err := s.Pool.Exec(ctx,
		`INSERT INTO device_tokens (token, user_id, garage_id, platform, updated_at)
		 VALUES ($1, $2, $3, $4, now())
		 ON CONFLICT (token) DO UPDATE SET
		   user_id = excluded.user_id, garage_id = excluded.garage_id,
		   platform = excluded.platform, updated_at = now()`,
		token, userID, garageID, platform)
	return mapPGError(err)
}

// DeleteDeviceToken removes a token on logout; only its owner may remove it.
func (s *Store) DeleteDeviceToken(ctx context.Context, token, userID string) error {
	_, err := s.Pool.Exec(ctx,
		`DELETE FROM device_tokens WHERE token = $1 AND user_id = $2`, token, userID)
	return mapPGError(err)
}

// ListDeviceTokensByGarage returns every token registered to a garage.
func (s *Store) ListDeviceTokensByGarage(ctx context.Context, garageID string) ([]string, error) {
	rows, err := s.Pool.Query(ctx, `SELECT token FROM device_tokens WHERE garage_id = $1`, garageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var tokens []string
	for rows.Next() {
		var tok string
		if err := rows.Scan(&tok); err != nil {
			return nil, err
		}
		tokens = append(tokens, tok)
	}
	return tokens, rows.Err()
}
