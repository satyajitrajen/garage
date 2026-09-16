package api

import (
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/store"
)

// POST /api/auth/verify-request {email} → creates token, emails link.
func (s *Server) handleVerifyRequest(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email string `json:"email"`
	}
	if !httputil.Decode(w, r, &req) || req.Email == "" {
		httputil.Error(w, 400, "invalid_request", "email is required")
		return
	}
	// Always 200 to avoid account enumeration.
	user, err := s.Store.UserByEmail(r.Context(), req.Email)
	if err == nil {
		raw, hash, err := auth.RawToken()
		if err == nil {
			_ = s.Store.CreateEmailVerification(r.Context(), user.ID, hash, 24*time.Hour)
			_ = s.Mail.Send(user.Email, "Verify your email",
				"Verify: "+s.Config.AppBaseURL+"/verify?token="+raw)
		}
	}
	httputil.JSON(w, 200, map[string]string{"status": "ok"})
}

// POST /api/auth/verify {token} → marks email verified.
func (s *Server) handleVerify(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Token string `json:"token"`
	}
	if !httputil.Decode(w, r, &req) || req.Token == "" {
		httputil.Error(w, 400, "invalid_request", "token is required")
		return
	}
	if _, err := s.Store.ConsumeEmailVerification(r.Context(), auth.HashToken(req.Token)); err != nil {
		httputil.Error(w, 400, "invalid_request", "invalid or expired token")
		return
	}
	httputil.JSON(w, 200, map[string]string{"status": "verified"})
}

// POST /api/auth/forgot {email} → creates reset token (always 200).
func (s *Server) handleForgot(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email string `json:"email"`
	}
	if !httputil.Decode(w, r, &req) || req.Email == "" {
		httputil.Error(w, 400, "invalid_request", "email is required")
		return
	}
	user, err := s.Store.UserByEmail(r.Context(), req.Email)
	if err == nil {
		raw, hash, err := auth.RawToken()
		if err == nil {
			_ = s.Store.CreatePasswordReset(r.Context(), user.ID, hash, time.Hour)
			_ = s.Mail.Send(user.Email, "Reset your password",
				"Reset: "+s.Config.AppBaseURL+"/reset?token="+raw)
		}
	}
	httputil.JSON(w, 200, map[string]string{"status": "ok"})
}

// POST /api/auth/reset {token, password} → sets new password, revokes sessions.
func (s *Server) handleReset(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Token    string `json:"token"`
		Password string `json:"password"`
	}
	if !httputil.Decode(w, r, &req) || req.Token == "" || len(req.Password) < 8 {
		httputil.Error(w, 400, "invalid_request", "token and password (min 8) are required")
		return
	}
	hash, err := auth.HashPassword(req.Password)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not hash password")
		return
	}
	if _, err := s.Store.ConsumePasswordReset(r.Context(), auth.HashToken(req.Token), hash); err != nil {
		httputil.Error(w, 400, "invalid_request", "invalid or expired token")
		return
	}
	httputil.JSON(w, 200, map[string]string{"status": "ok"})
}

// POST /api/garages/{garageId}/invites {email, role?, permissions?} (staff.manage)
func (s *Server) createInvite(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email       string   `json:"email"`
		Role        string   `json:"role"`
		Permissions []string `json:"permissions"`
	}
	if !httputil.Decode(w, r, &req) || req.Email == "" {
		httputil.Error(w, 400, "invalid_request", "email is required")
		return
	}
	role := req.Role
	if role == "" {
		role = "staff"
	}
	if role != "owner" && role != "staff" {
		httputil.Error(w, 400, "invalid_request", "role must be owner or staff")
		return
	}
	// Minting an OWNER invite escalates the invitee to unrestricted access,
	// so only the garage owner may issue one (staff.manage is not enough).
	if role == "owner" && auth.Role(r.Context()) != "owner" {
		httputil.Error(w, 403, "forbidden", "only the owner can invite owners")
		return
	}
	perms := req.Permissions
	if perms == nil {
		perms = auth.DefaultStaffPermissions
	}
	if err := auth.ValidatePermissions(perms); err != nil {
		httputil.Error(w, 400, "invalid_request", err.Error())
		return
	}
	// Inviting someone who is already a member is a no-op conflict, not a
	// second invite.
	if u, err := s.Store.UserByEmail(r.Context(), req.Email); err == nil {
		if _, err := s.Store.MembershipFor(r.Context(), auth.GarageID(r.Context()), u.ID); err == nil {
			httputil.Error(w, 409, "conflict", "user is already a member of this garage")
			return
		}
	}
	raw, hash, err := auth.RawToken()
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create invite")
		return
	}
	inv, err := s.Store.CreateInvite(r.Context(), auth.GarageID(r.Context()),
		req.Email, role, perms, hash, auth.UserID(r.Context()))
	if errors.Is(err, store.ErrDuplicate) {
		httputil.Error(w, 409, "conflict", "invite already exists")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not create invite")
		return
	}
	_ = s.Mail.Send(req.Email, "You are invited",
		"Accept: "+s.Config.AppBaseURL+"/invite?token="+raw)
	httputil.JSON(w, 201, inv)
}

// GET /api/invites/{token} → public invite preview.
func (s *Server) getInvite(w http.ResponseWriter, r *http.Request) {
	inv, err := s.Store.InviteByToken(r.Context(), auth.HashToken(chi.URLParam(r, "token")))
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "invite not found or expired")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load invite")
		return
	}
	httputil.JSON(w, 200, inv)
}

// POST /api/invites/{token}/accept (authed) → creates membership.
func (s *Server) acceptInvite(w http.ResponseWriter, r *http.Request) {
	inv, err := s.Store.AcceptInvite(r.Context(),
		auth.HashToken(chi.URLParam(r, "token")), auth.UserID(r.Context()))
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "invite not found or expired")
		return
	}
	if errors.Is(err, store.ErrForbidden) {
		httputil.Error(w, 403, "forbidden", "invite was issued to a different email")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not accept invite")
		return
	}
	s.Store.Audit(r.Context(), inv.GarageID, auth.UserID(r.Context()), "invite.accept", "invite", inv.ID, nil)
	httputil.JSON(w, 200, inv)
}

// DELETE /api/garages/{garageId}/invites/{inviteId} (staff.manage)
func (s *Server) revokeInvite(w http.ResponseWriter, r *http.Request) {
	if err := s.Store.RevokeInvite(r.Context(), auth.GarageID(r.Context()), chi.URLParam(r, "inviteId")); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			httputil.Error(w, 404, "not_found", "invite not found")
			return
		}
		httputil.Error(w, 500, "internal", "could not revoke invite")
		return
	}
	w.WriteHeader(204)
}

// GET /api/doc-numbers/next?kind=jobcard|quotation|invoice → server number.
func (s *Server) nextDocNumber(w http.ResponseWriter, r *http.Request) {
	kind := r.URL.Query().Get("kind")
	if kind == "" {
		httputil.Error(w, 400, "invalid_request", "kind is required")
		return
	}
	num, err := s.Store.NextDocNumber(r.Context(), auth.GarageID(r.Context()), kind)
	if err != nil {
		httputil.Error(w, 400, "invalid_request", "kind must be jobcard, quotation or invoice")
		return
	}
	httputil.JSON(w, 200, map[string]string{"number": num})
}
