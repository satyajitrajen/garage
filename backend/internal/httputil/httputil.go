// Package httputil holds the shared JSON response and error-envelope helpers.
// Error envelope: {"error":{"code":"...","message":"..."}}.
package httputil

import (
	"encoding/json"
	"net/http"
)

type APIError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

type errorEnvelope struct {
	Error APIError `json:"error"`
}

func JSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func Error(w http.ResponseWriter, status int, code, message string) {
	JSON(w, status, errorEnvelope{Error: APIError{Code: code, Message: message}})
}

// Decode reads a bounded JSON request body into dst and answers with the
// standard 400 envelope on failure, returning whether to continue.
func Decode(w http.ResponseWriter, r *http.Request, dst any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		Error(w, 400, "invalid_request", "malformed JSON")
		return false
	}
	return true
}
