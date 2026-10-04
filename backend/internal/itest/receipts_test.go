package itest

import (
	"bytes"
	"io"
	"net/http"
	"testing"

	"garage-backend/internal/models"
)

func doRaw(t *testing.T, method, path, token, garageID string, body []byte) (int, http.Header, []byte) {
	t.Helper()
	req, err := http.NewRequest(method, ts.URL+path, bytes.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("X-Garage-Id", garageID)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	return resp.StatusCode, resp.Header, data
}

func TestExpenseReceipt(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "rcpt1")
	garageID := owner.Memberships[0].GarageID

	status, data := doJSON(t, "POST", "/api/expenses", owner.AccessToken, garageID, map[string]any{
		"title": "Brake pads", "category": "partsStock", "amount": 1200,
		"expenseDate": "2026-10-01", "paymentMode": "cash",
		"receiptPath": "/sdcard/forged.jpg", // client value is ignored
	})
	if status != 201 {
		t.Fatalf("create expense: %d %s", status, data)
	}
	var exp models.Expense
	mustUnmarshal(t, data, &exp)
	if exp.ReceiptPath != nil {
		t.Fatalf("receiptPath should start empty, got %q", *exp.ReceiptPath)
	}
	path := "/api/expenses/" + exp.ID + "/receipt"

	if s, _, _ := doRaw(t, "GET", path, owner.AccessToken, garageID, nil); s != 404 {
		t.Fatalf("missing receipt: want 404, got %d", s)
	}
	if s, _, b := doRaw(t, "PUT", path, owner.AccessToken, garageID, []byte("not an image")); s != 415 {
		t.Fatalf("text body: want 415, got %d %s", s, b)
	}

	png := []byte("\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00")
	if s, _, b := doRaw(t, "PUT", path, owner.AccessToken, garageID, png); s != 200 {
		t.Fatalf("upload: %d %s", s, b)
	}
	s, h, b := doRaw(t, "GET", path, owner.AccessToken, garageID, nil)
	if s != 200 || h.Get("Content-Type") != "image/png" || !bytes.Equal(b, png) {
		t.Fatalf("download: %d %s len=%d", s, h.Get("Content-Type"), len(b))
	}

	// An edit keeps the server-owned receipt link.
	exp.Title = "Brake pads (front)"
	status, data = doJSON(t, "PUT", "/api/expenses/"+exp.ID, owner.AccessToken, garageID, exp)
	if status != 200 {
		t.Fatalf("update expense: %d %s", status, data)
	}
	mustUnmarshal(t, data, &exp)
	if exp.ReceiptPath == nil || *exp.ReceiptPath != path {
		t.Fatalf("receiptPath after edit = %v", exp.ReceiptPath)
	}

	// Another garage cannot read it.
	other := registerOwner(t, "rcpt2")
	if s, _, _ := doRaw(t, "GET", path, other.AccessToken, other.Memberships[0].GarageID, nil); s != 404 {
		t.Fatalf("cross-garage read: want 404, got %d", s)
	}

	if s, _, b := doRaw(t, "DELETE", path, owner.AccessToken, garageID, nil); s != 204 {
		t.Fatalf("delete: %d %s", s, b)
	}
	if s, _, _ := doRaw(t, "GET", path, owner.AccessToken, garageID, nil); s != 404 {
		t.Fatalf("after delete: want 404, got %d", s)
	}
}
