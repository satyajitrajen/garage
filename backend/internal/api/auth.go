package api

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strings"
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

// PATCH /api/me {name} → updates the signed-in user's display name.
func (s *Server) updateMe(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name string `json:"name"`
	}
	if !httputil.Decode(w, r, &req) {
		return
	}
	name := strings.TrimSpace(req.Name)
	if name == "" || len(name) > 100 {
		httputil.Error(w, 400, "invalid_request", "name is required (max 100 characters)")
		return
	}
	user, err := s.Store.UpdateUserName(r.Context(), auth.UserID(r.Context()), name)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update profile")
		return
	}
	httputil.JSON(w, 200, map[string]any{"user": user})
}

// POST /api/me/password {current_password, new_password, refresh_token?}
// → changes the password after checking the current one. Other sessions
// are signed out; the caller's refresh token (if sent) stays valid.
func (s *Server) changePassword(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CurrentPassword string `json:"current_password"`
		NewPassword     string `json:"new_password"`
		RefreshToken    string `json:"refresh_token"`
	}
	if !httputil.Decode(w, r, &req) {
		return
	}
	if len(req.NewPassword) < 8 {
		httputil.Error(w, 400, "invalid_request", "new password must be at least 8 characters")
		return
	}
	userID := auth.UserID(r.Context())
	user, err := s.Store.UserByID(r.Context(), userID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load user")
		return
	}
	if !auth.CheckPassword(user.PasswordHash, req.CurrentPassword) {
		httputil.Error(w, 400, "invalid_request", "current password is incorrect")
		return
	}
	hash, err := auth.HashPassword(req.NewPassword)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not hash password")
		return
	}
	keep := ""
	if req.RefreshToken != "" {
		keep = auth.HashToken(req.RefreshToken)
	}
	if err := s.Store.ChangeUserPassword(r.Context(), userID, hash, keep); err != nil {
		httputil.Error(w, 500, "internal", "could not change password")
		return
	}
	httputil.JSON(w, 200, map[string]string{"status": "ok"})
}

// DELETE /api/me {password} → permanently deletes the signed-in user's
// account (App Store guideline 5.1.1(v)). Garages they solely own are
// deleted with all their data; shared garages keep their other owners.
func (s *Server) deleteMe(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Password string `json:"password"`
		Confirm  string `json:"confirm"`
	}
	if !httputil.Decode(w, r, &req) {
		return
	}
	if req.Confirm != "DELETE" {
		httputil.Error(w, 400, "invalid_request", `type DELETE to confirm`)
		return
	}
	userID := auth.UserID(r.Context())
	user, err := s.Store.UserByID(r.Context(), userID)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load user")
		return
	}
	if !auth.CheckPassword(user.PasswordHash, req.Password) {
		httputil.Error(w, 400, "invalid_request", "password is incorrect")
		return
	}
	when, err := s.Store.ScheduleAccountDeletion(r.Context(), userID, time.Now().Add(AccountDeletionGrace))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not schedule deletion")
		return
	}
	slog.Info("account deletion scheduled", "user", userID, "at", when)
	date := when.Format("2 Jan 2006")
	_ = s.Mail.Send(user.Email, "Your NT Garage account will be deleted on "+date,
		"You asked us to delete your NT Garage account. It will be permanently deleted on "+date+
			", together with any garage you are the only owner of.\n\n"+
			"Changed your mind? Sign in to the app before then and tap Cancel deletion.")
	httputil.JSON(w, 200, map[string]any{"status": "scheduled", "deletion_scheduled_at": when})
}

// AccountDeletionGrace is how long a deletion request can still be cancelled.
const AccountDeletionGrace = 7 * 24 * time.Hour

// POST /api/me/deletion/cancel → keep the account.
func (s *Server) cancelDeleteMe(w http.ResponseWriter, r *http.Request) {
	if err := s.Store.CancelAccountDeletion(r.Context(), auth.UserID(r.Context())); err != nil {
		httputil.Error(w, 500, "internal", "could not cancel deletion")
		return
	}
	httputil.JSON(w, 200, map[string]string{"status": "active"})
}

// PurgeDueAccounts deletes every account whose grace period has ended and
// returns how many were deleted. Errors are logged per user, never fatal.
func (s *Server) PurgeDueAccounts(ctx context.Context) int {
	ids, err := s.Store.DueAccountDeletions(ctx, time.Now())
	if err != nil {
		slog.Error("list due account deletions failed", "err", err)
		return 0
	}
	n := 0
	for _, id := range ids {
		garages, err := s.Store.DeleteUserAccount(ctx, id)
		if err != nil {
			slog.Error("account deletion failed", "user", id, "err", err)
			continue
		}
		slog.Info("account deleted", "user", id, "garages_deleted", len(garages))
		n++
	}
	return n
}

// RunAccountPurger runs PurgeDueAccounts now and then hourly until ctx ends.
func (s *Server) RunAccountPurger(ctx context.Context) {
	s.PurgeDueAccounts(ctx)
	t := time.NewTicker(time.Hour)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			s.PurgeDueAccounts(ctx)
		}
	}
}
