package api

import (
	"context"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
)

type deviceTokenRequest struct {
	Token    string `json:"token"`
	Platform string `json:"platform"`
}

// POST /api/garages/{garageId}/devices/token → register this device for pushes.
func (s *Server) registerDeviceToken(w http.ResponseWriter, r *http.Request) {
	var req deviceTokenRequest
	if !httputil.Decode(w, r, &req) {
		return
	}
	req.Token = strings.TrimSpace(req.Token)
	if req.Token == "" || len(req.Token) > 4096 {
		httputil.Error(w, 400, "invalid_request", "token is required")
		return
	}
	switch req.Platform {
	case "android", "ios", "web", "":
	default:
		httputil.Error(w, 400, "invalid_request", "platform must be android, ios or web")
		return
	}
	if err := s.Store.UpsertDeviceToken(r.Context(), req.Token, auth.UserID(r.Context()),
		auth.GarageID(r.Context()), req.Platform); err != nil {
		httputil.Error(w, 500, "internal", "could not register device")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// DELETE /api/garages/{garageId}/devices/token → stop pushes to this device.
func (s *Server) unregisterDeviceToken(w http.ResponseWriter, r *http.Request) {
	var req deviceTokenRequest
	if !httputil.Decode(w, r, &req) {
		return
	}
	if strings.TrimSpace(req.Token) == "" {
		httputil.Error(w, 400, "invalid_request", "token is required")
		return
	}
	if err := s.Store.DeleteDeviceToken(r.Context(), strings.TrimSpace(req.Token), auth.UserID(r.Context())); err != nil {
		httputil.Error(w, 500, "internal", "could not unregister device")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// notifyGarage pushes to every device of a garage in the background; a no-op
// when FCM is not configured. Failures are logged, never returned.
func (s *Server) notifyGarage(garageID, title, body string, data map[string]string) {
	if !s.Notifier.Enabled() || garageID == "" {
		return
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		tokens, err := s.Store.ListDeviceTokensByGarage(ctx, garageID)
		if err != nil {
			slog.Warn("list device tokens failed", "garage", garageID, "err", err)
			return
		}
		s.Notifier.SendToTokens(ctx, tokens, title, body, data)
	}()
}
