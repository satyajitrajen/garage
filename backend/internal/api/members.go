package api

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"garage-backend/internal/auth"
	"garage-backend/internal/httputil"
	"garage-backend/internal/store"
)

func (s *Server) listMembers(w http.ResponseWriter, r *http.Request) {
	members, err := s.Store.ListMembers(r.Context(), auth.GarageID(r.Context()))
	if err != nil {
		httputil.Error(w, 500, "internal", "could not list members")
		return
	}
	httputil.JSON(w, 200, map[string]any{"items": members})
}

func (s *Server) createMember(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name        string   `json:"name"`
		Email       string   `json:"email"`
		Password    string   `json:"password"`
		Permissions []string `json:"permissions"`
	}
	if !httputil.Decode(w, r, &req) {
		return
	}
	if req.Name == "" || req.Email == "" {
		httputil.Error(w, 400, "invalid_request", "name and email are required")
		return
	}
	if req.Permissions == nil {
		req.Permissions = auth.DefaultStaffPermissions
	}
	if err := auth.ValidatePermissions(req.Permissions); err != nil {
		httputil.Error(w, 400, "invalid_request", err.Error())
		return
	}
	garageID := auth.GarageID(r.Context())

	existing, err := s.Store.UserByEmail(r.Context(), req.Email)
	switch {
	case errors.Is(err, store.ErrNotFound):
		if len(req.Password) < 8 {
			httputil.Error(w, 400, "invalid_request", "password must be at least 8 characters")
			return
		}
		hash, err := auth.HashPassword(req.Password)
		if err != nil {
			httputil.Error(w, 500, "internal", "could not hash password")
			return
		}
		member, err := s.Store.CreateUserWithMembership(r.Context(), garageID, req.Email, hash, req.Name, req.Permissions)
		if err != nil {
			s.writeMemberStoreError(w, err)
			return
		}
		httputil.JSON(w, 201, member)
	case err != nil:
		httputil.Error(w, 500, "internal", "could not look up user")
	default:
		if _, err := s.Store.MembershipFor(r.Context(), garageID, existing.ID); err == nil {
			httputil.Error(w, 409, "conflict", "user is already a member of this garage")
			return
		}
		member, err := s.Store.CreateMembership(r.Context(), garageID, existing.ID, "staff", req.Permissions)
		if err != nil {
			s.writeMemberStoreError(w, err)
			return
		}
		httputil.JSON(w, 201, member)
	}
}

func (s *Server) writeMemberStoreError(w http.ResponseWriter, err error) {
	if errors.Is(err, store.ErrDuplicate) {
		httputil.Error(w, 409, "conflict", "email or membership already exists")
		return
	}
	httputil.Error(w, 500, "internal", "could not save member")
}

func (s *Server) updateMember(w http.ResponseWriter, r *http.Request) {
	userID := chi.URLParam(r, "userId")
	garageID := auth.GarageID(r.Context())

	target, err := s.Store.Member(r.Context(), garageID, userID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "member not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load member")
		return
	}
	if target.Role == "owner" {
		httputil.Error(w, 422, "unprocessable", "cannot modify the owner")
		return
	}

	var req struct {
		Permissions []string `json:"permissions"`
		Password    *string  `json:"password"`
		IsActive    *bool    `json:"is_active"`
	}
	if !httputil.Decode(w, r, &req) {
		return
	}
	if req.Password != nil && auth.Role(r.Context()) != "owner" {
		httputil.Error(w, 403, "forbidden", "password reset is owner-only")
		return
	}
	if req.Permissions != nil {
		if err := auth.ValidatePermissions(req.Permissions); err != nil {
			httputil.Error(w, 400, "invalid_request", err.Error())
			return
		}
	}
	patch := store.MemberPatch{}
	if req.Permissions != nil {
		patch.Permissions = req.Permissions
	}
	if req.IsActive != nil {
		patch.IsActive = req.IsActive
	}
	if req.Password != nil {
		if len(*req.Password) < 8 {
			httputil.Error(w, 400, "invalid_request", "password must be at least 8 characters")
			return
		}
		hash, err := auth.HashPassword(*req.Password)
		if err != nil {
			httputil.Error(w, 500, "internal", "could not hash password")
			return
		}
		patch.PasswordHash = &hash
	}
	member, err := s.Store.UpdateMember(r.Context(), garageID, userID, patch)
	if err != nil {
		httputil.Error(w, 500, "internal", "could not update member")
		return
	}
	httputil.JSON(w, 200, member)
}

func (s *Server) deleteMember(w http.ResponseWriter, r *http.Request) {
	userID := chi.URLParam(r, "userId")
	garageID := auth.GarageID(r.Context())

	if auth.Role(r.Context()) != "owner" {
		httputil.Error(w, 403, "forbidden", "only the owner can remove members")
		return
	}
	target, err := s.Store.Member(r.Context(), garageID, userID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Error(w, 404, "not_found", "member not found")
		return
	}
	if err != nil {
		httputil.Error(w, 500, "internal", "could not load member")
		return
	}
	if target.Role == "owner" {
		httputil.Error(w, 422, "unprocessable", "cannot remove the owner")
		return
	}
	if err := s.Store.DeleteMembership(r.Context(), garageID, userID); err != nil {
		httputil.Error(w, 500, "internal", "could not remove member")
		return
	}
	w.WriteHeader(204)
}
