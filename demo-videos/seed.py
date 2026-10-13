"""Seed a realistic demo garage on the LOCAL dev server for store screenshots."""
import json, urllib.request, datetime as dt

B = "http://localhost:8080"


def call(method, path, body=None, tok=None, gid=None):
    req = urllib.request.Request(B + path, method=method,
                                 data=None if body is None else json.dumps(body).encode())
    req.add_header("content-type", "application/json")
    if tok:
        req.add_header("authorization", "Bearer " + tok)
    if gid:
        req.add_header("x-garage-id", gid)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {path}: {e.code} {e.read().decode()}")


import os
reg = call("POST", "/api/auth/login", {"email": os.environ["EMAIL"], "password": os.environ["PASS"]})
T, G = reg["access_token"], reg["memberships"][0]["garage_id"]
c = lambda m, p, b=None: call(m, p, b, T, G)

now = dt.datetime.now(dt.timezone.utc)
iso = lambda d: d.isoformat().replace("+00:00", "Z")
today = dt.date.today()

def item(name, cat, price, tax, qty=1, labour=False, unit="Pcs"):
    return {"name": name, "category": cat, "unitPrice": price, "quantity": qty,
            "unit": unit, "taxPercent": tax, "isLabour": labour, "discountPercent": 0}

for it in [
    item("Oil filter", "sparePart", 320, 18),
    item("Front brake pads", "sparePart", 1800, 18, unit="Set"),
    item("Tyre 185/65 R15", "tyresBattery", 4400, 28),
    item("Battery 35Ah", "tyresBattery", 5200, 28),
    item("Wheel alignment", "labour", 600, 18, labour=True, unit="Job"),
    item("AC gas refill", "labour", 1500, 18, labour=True, unit="Job"),
]:
    c("POST", "/api/catalog", {k: it[k] for k in ("name", "category", "unitPrice", "unit", "isLabour", "taxPercent")})

staff = {}
for name, role, sal in [("Suresh Jadhav", "headMechanic", 24000),
                        ("Imran Shaikh", "seniorTechnician", 18000),
                        ("Akash More", "autoElectrician", 16000)]:
    s = c("POST", "/api/staff", {"name": name, "role": role, "phone": "98" + str(abs(hash(name)))[:8],
                                 "monthlySalary": sal, "joiningDate": "2025-06-01", "isActive": True})
    staff[name] = s["id"]
for sid in staff.values():
    for d in range(1, today.day):
        day = today.replace(day=d)
        if day.weekday() == 6:
            continue
        st = "present" if (d + len(sid)) % 9 else "halfDay"
        c("POST", "/api/attendance", {"staffId": sid, "date": day.isoformat(), "status": st})
c("POST", "/api/salary-advances", {"staffId": staff["Imran Shaikh"], "amount": 2000,
                                   "date": today.isoformat(), "reason": "Festival advance"})

people = [("Ravi Kumar", "9876543210", "MH12AB1234", "Maruti Suzuki", "Swift", "petrol", 45200),
          ("Anita Desai", "9823456789", "MH14XY9999", "Hyundai", "i20", "petrol", 31800),
          ("Sanjay Kulkarni", "9890011223", "MH12QK4521", "Mahindra", "XUV500", "diesel", 88400),
          ("Priya Nair", "9765432109", "MH12RT7788", "Honda", "City", "petrol", 52300),
          ("Vikram Singh", "9881234567", "MH14DS3030", "Tata", "Nexon EV", "electric", 21500)]
veh = []
for n, ph, reg_no, make, model, fuel, km in people:
    cu = c("POST", "/api/customers", {"name": n, "phone": ph, "whatsappNumber": ph})
    v = c("POST", "/api/vehicles", {"customerId": cu["id"], "registrationNumber": reg_no, "make": make,
                                    "model": model, "fuelType": fuel, "currentKm": km})
    veh.append((cu["id"], v["id"], km))

checklist = {k: True for k in ["Engine Oil Level", "Brake System", "Coolant & Fluids", "Battery & Terminals",
                               "Tyres & Pressure", "AC & Heating", "Lights & Horn", "Body Scratches Checked"]}
jobs = [
    (1, "inProgress", "Imran Shaikh", ["AC not cooling"],
     [item("AC gas refill", "labour", 1500, 18, labour=True, unit="Job")], 13),
    (2, "waitingParts", "Suresh Jadhav", ["Clutch hard", "Check suspension noise"],
     [item("General service labour", "labour", 900, 18, labour=True, unit="Job")], 41),
    (3, "inspection", "Akash More", ["Battery drains overnight"], [], 17),
]
def promise(h):
    # h = local hour tomorrow (or day after when > 24)
    base = dt.datetime.combine(today + dt.timedelta(days=1 + (h > 24)), dt.time(h % 24 or 12))
    return base.astimezone(dt.timezone.utc)

for i, (vi, status, mech, complaints, items, hours) in enumerate(jobs):
    cid, vid, km = veh[vi]
    c("POST", "/api/jobcards", {
        "jobCardNumber": f"JC-{1001 + i}", "customerId": cid, "vehicleId": vid,
        "customerComplaints": complaints, "inspectionChecklist": checklist, "fuelLevel": "1/2",
        "kmReading": km, "assignedStaffId": staff[mech], "status": status,
        "promisedDeliveryDate": iso(promise(hours)), "items": items,
        "createdAt": iso(now - dt.timedelta(hours=4))})

def bill(num, vi, items, paid=None, mode="upi", days_ago=0):
    cid, vid, km = veh[vi]
    inv = c("POST", "/api/invoices", {
        "invoiceNumber": num, "customerId": cid, "vehicleId": vid, "kmReading": km,
        "items": items, "discountAmount": 0, "taxPercent": 18, "perItemTax": True,
        "invoiceDate": iso(now - dt.timedelta(days=days_ago)), "dueDate": iso(now + dt.timedelta(days=7)),
        "notes": "Thank you for choosing NT Garage & Body Shop!"})
    if paid:
        c("POST", f"/api/invoices/{inv['id']}/payments", {"customerId": cid, "amount": paid, "mode": mode})
    return inv

bill("INV-2026-1001", 4, [item("Tyre 185/65 R15", "tyresBattery", 4400, 28, qty=2),
                          item("Wheel alignment", "labour", 600, 18, labour=True, unit="Job")], paid=11972, mode="card")
bill("INV-2026-1002", 3, [item("Battery 35Ah", "tyresBattery", 5200, 28)], paid=6656, mode="cash")
bill("INV-2026-1003", 2, [item("General service labour", "labour", 900, 18, labour=True, unit="Job"),
                          item("Engine oil 5W-30 (3.5 L)", "fluids", 1650, 18, unit="Set")], paid=1500)

for title, cat, amt, vendor, d in [("Workshop rent - October", "rent", 25000, "Landlord", today.replace(day=1)),
                                ("Engine oil stock", "partsStock", 8400, "Castrol distributor", today - dt.timedelta(days=3)),
                                ("Tea and snacks", "staffFood", 350, None, today),
                                ("Brake cleaner spray", "consumables", 480, "Auto parts store", today)]:
    c("POST", "/api/expenses", {"title": title, "category": cat, "amount": amt,
                               "expenseDate": d.isoformat(), "paymentMode": "upi", "vendorName": vendor})
print("seeded garage", G)
