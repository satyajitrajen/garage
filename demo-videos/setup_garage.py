"""Recreate the state at the end of clip 00 (sign-up, garage details, two
price-list items) on the LOCAL dev server, so later clips can be re-recorded
after the dev database is reset. Then run seed.py for the demo history."""
import json, os, urllib.request, urllib.error

B = "http://localhost:8080"


def call(m, p, b=None, t=None, g=None):
    r = urllib.request.Request(B + p, method=m, data=None if b is None else json.dumps(b).encode())
    r.add_header("content-type", "application/json")
    if t:
        r.add_header("authorization", "Bearer " + t)
    if g:
        r.add_header("x-garage-id", g)
    try:
        with urllib.request.urlopen(r) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{m} {p}: {e.code} {e.read().decode()}")


reg = call("POST", "/api/auth/register", {
    "name": "Nitin Thorat", "email": os.environ["EMAIL"],
    "password": os.environ["PASS"], "garageName": "NT Garage & Body Shop"})
T, G = reg["access_token"], reg["memberships"][0]["garage_id"]
call("PATCH", f"/api/garages/{G}/settings", {"profile": {
    "name": "NT Garage & Body Shop", "tagline": "Multi-brand car service & body shop",
    "address_line": "Shop 14, Hadapsar Industrial Estate", "city": "Pune, Maharashtra",
    "phone": "9822012345", "email": "", "gstin": "27AAKFN1234M1Z5", "upi_id": "ntgarage@upi"}}, T, G)
call("POST", "/api/catalog", {"name": "Engine Oil (3.5 L)", "category": "sparePart",
                              "unitPrice": 1650, "unit": "Pcs", "isLabour": False, "taxPercent": 18}, T, G)
call("POST", "/api/catalog", {"name": "General Service labour", "category": "labour",
                              "unitPrice": 900, "unit": "Job", "isLabour": True, "taxPercent": 18}, T, G)
print("garage", G)
