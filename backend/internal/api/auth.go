package api

import (
	"errors"
	"net/http"
	"time"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/models"
	"garage-backend/internal/store"
)

type credentialsRequest struct {
	Name       string `json:"name"`
	Email      string `json:"email"`
	Password   string `json:"password"`
	GarageName string `json:"garageName"`
}

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if !httputil.Decode(w, r, &req) {
		return
	}
	if req.Name == "" || req.Email == "" || req.Password == "" || req.GarageName == "" {
		httputil.Error(w, 400, "invalid_request", "name, email, password and garageName are required")
		return
	}
	if len(req.Password) < 8 {
		httputil.Error(w, 400, "invalid_request", "password must be at least 8 characters")
		return
	}
	hash, err := auth.HashPassword(req.Password)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not hash password")
		return
	}
	user, membership, err := s.Store.RegisterOwner(r.Context(),
		req.Email, hash, req.Name, req.GarageName, auth.AllPermissions)
	if errors.Is(err, store.ErrDuplicate) {
		httputil.Error(w, 409, "conflict", "email already registered")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not register")
		return
	}
	// SaaS provisioning: trial window + subscription row + optional superadmin.
	trialDays := s.Config.TrialDays
	if trialDays <= 0 {
		trialDays = 14
	}
	_ = s.Store.SetGarageTrial(r.Context(), membership.GarageID, trialDays)
	_, _ = s.Store.EnsureSubscription(r.Context(), membership.GarageID, trialDays)
	for _, e := range s.Config.SuperadminEmails {
		if e != "" && e == user.Email {
			_ = s.Store.SetSuperadmin(r.Context(), user.ID, true)
			break
		}
	}
	s.Store.Audit(r.Context(), membership.GarageID, user.ID, "auth.register", "garage", membership.GarageID, nil)
	s.writeSession(w, r, 201, user, []models.Membership{membership})
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if !httputil.Decode(w, r, &req) {
		return
	}
	if req.Email == "" || req.Password == "" {
		httputil.Error(w, 400, "invalid_request", "email and password are required")
		return
	}
	user, err := s.Store.UserByEmail(r.Context(), req.Email)
	if errors.Is(err, store.ErrNotFound) {
		auth.CompareDummy(req.Password)
		httputil.Error(w, 401, "unauthorized", "invalid email or password")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load user")
		return
	}
	if !auth.CheckPassword(user.PasswordHash, req.Password) {
		httputil.Error(w, 401, "unauthorized", "invalid email or password")
		return
	}
	memberships, err := s.Store.MembershipsForUser(r.Context(), user.ID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load memberships")
		return
	}
	s.writeSession(w, r, 200, user, memberships)
}

func (s *Server) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if !httputil.Decode(w, r, &req) {
		return
	}
	if req.RefreshToken == "" {
		httputil.Error(w, 400, "invalid_request", "refresh_token is required")
		return
	}
	newRaw, newHash, expiresAt, err := auth.NewRefreshToken(time.Now())
	if err != nil {
		httputil.Error(w, 500, "internal", "could not issue refresh token")
		return
	}
	userID, err := s.Store.RotateRefreshToken(r.Context(),
		auth.HashRefreshToken(req.RefreshToken), newHash, expiresAt)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 401, "unauthorized", "invalid or expired refresh token")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not rotate refresh token")
		return
	}
	access, err := s.Issuer.Issue(userID, time.Now())
	if err != nil {
		httputil.Error(w, 500, "internal", "could not issue access token")
		return
	}
	httputil.JSON(w, 200, map[string]string{
		"access_token":  access,
		"refresh_token": newRaw,
	})
}

func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if !httputil.Decode(w, r, &req) {
		return
	}
	if req.RefreshToken == "" {
		httputil.Error(w, 400, "invalid_request", "refresh_token is required")
		return
	}
	if err := s.Store.RevokeRefreshToken(r.Context(), auth.HashRefreshToken(req.RefreshToken)); err != nil {
		httputil.Error(w, 500, "internal", "could not revoke refresh token")
		return
	}
	w.WriteHeader(204)
}

func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
	user, err := s.Store.UserByID(r.Context(), auth.UserID(r.Context()))
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 401, "unauthorized", "user no longer exists")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load user")
		return
	}
	memberships, err := s.Store.MembershipsForUser(r.Context(), user.ID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load memberships")
		return
	}
	httputil.JSON(w, 200, map[string]any{"user": user, "memberships": memberships})
}

func (s *Server) writeSession(w http.ResponseWriter, r *http.Request, status int, user models.User, memberships []models.Membership) {
	access, err := s.Issuer.Issue(user.ID, time.Now())
	if err != nil {
		httputil.Error(w, 500, "internal", "could not issue access token")
		return
	}
	raw, hash, expiresAt, err := auth.NewRefreshToken(time.Now())
	if err != nil {
		httputil.Error(w, 500, "internal", "could not issue refresh token")
		return
	}
	if err := s.Store.InsertRefreshToken(r.Context(), user.ID, hash, expiresAt); err != nil {
		httputil.Error(w, 500, "internal", "could not store refresh token")
		return
	}
	httputil.JSON(w, status, map[string]any{
		"access_token":  access,
		"refresh_token": raw,
		"user":          user,
		"memberships":   memberships,
	})
}
