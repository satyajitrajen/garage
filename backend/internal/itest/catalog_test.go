package itest

import (
	"testing"

	"garage-backend/internal/models"
)

func TestCatalogList(t *testing.T) {
	truncate(t)
	owner := registerOwner(t, "cat1")
	garageID := owner.Memberships[0].GarageID

	status, data := doJSON(t, "GET", "/api/catalog", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("empty catalog: status %d body %s", status, data)
	}
	var list struct {
		Items []models.CatalogItem `json:"items"`
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 0 {
		t.Fatalf("catalog ships empty: %+v", list.Items)
	}

	if _, err := pool.Exec(ctx,
		`INSERT INTO catalog_items (garage_id, name, category, unit_price)
		 VALUES ($1,'Engine Oil 5W-40','fluids',450)`, garageID); err != nil {
		t.Fatal(err)
	}
	status, data = doJSON(t, "GET", "/api/catalog", owner.AccessToken, garageID, nil)
	if status != 200 {
		t.Fatalf("catalog: status %d body %s", status, data)
	}
	mustUnmarshal(t, data, &list)
	if len(list.Items) != 1 || list.Items[0].Name != "Engine Oil 5W-40" || list.Items[0].UnitPrice != 450 {
		t.Fatalf("catalog = %+v", list.Items)
	}
}
