-- +goose Up

CREATE TABLE customers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    name text NOT NULL,
    phone text NOT NULL,
    whatsapp_number text,
    email text,
    address text,
    gstin text,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_customers_garage ON customers(garage_id);

CREATE TABLE vehicles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    registration_number text NOT NULL,
    make text NOT NULL,
    model text NOT NULL,
    variant text,
    year int,
    fuel_type text NOT NULL,
    current_km int NOT NULL DEFAULT 0,
    color text,
    chassis_number text,
    engine_number text,
    last_service_date date,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_vehicles_garage ON vehicles(garage_id);

CREATE TABLE staff_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    name text NOT NULL,
    role text NOT NULL,
    phone text NOT NULL,
    email text,
    monthly_salary numeric(12,2) NOT NULL,
    joining_date date NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    address text,
    emergency_contact text,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_staff_members_garage ON staff_members(garage_id);

CREATE TABLE attendance_records (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    staff_id uuid NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
    date date NOT NULL,
    status text NOT NULL,
    notes text,
    UNIQUE (garage_id, staff_id, date)
);
CREATE INDEX idx_attendance_garage ON attendance_records(garage_id);

CREATE TABLE salary_advances (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    staff_id uuid NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
    amount numeric(12,2) NOT NULL,
    date date NOT NULL,
    reason text,
    is_deducted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_salary_advances_garage ON salary_advances(garage_id);

CREATE TABLE job_cards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    job_card_number text NOT NULL,
    customer_id uuid NOT NULL REFERENCES customers(id),
    vehicle_id uuid NOT NULL REFERENCES vehicles(id),
    customer_complaints text[] NOT NULL DEFAULT '{}',
    inspection_checklist jsonb NOT NULL DEFAULT '{}',
    fuel_level text NOT NULL DEFAULT '1/2',
    km_reading int NOT NULL DEFAULT 0,
    assigned_staff_id uuid REFERENCES staff_members(id) ON DELETE SET NULL,
    status text NOT NULL,
    promised_delivery_date timestamptz NOT NULL,
    completed_at timestamptz,
    estimated_cost_note text,
    supervisor_notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (garage_id, job_card_number)
);
CREATE INDEX idx_job_cards_garage ON job_cards(garage_id);

CREATE TABLE job_card_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_card_id uuid NOT NULL REFERENCES job_cards(id) ON DELETE CASCADE,
    name text NOT NULL,
    category text NOT NULL,
    unit_price numeric(12,2) NOT NULL DEFAULT 0,
    quantity numeric(12,2) NOT NULL DEFAULT 1,
    unit text NOT NULL DEFAULT 'Pcs',
    discount_percent numeric(12,2) NOT NULL DEFAULT 0,
    tax_percent numeric(12,2) NOT NULL DEFAULT 0,
    is_labour boolean NOT NULL DEFAULT false,
    part_number text,
    notes text,
    assigned_staff_id uuid REFERENCES staff_members(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_job_card_items_parent ON job_card_items(job_card_id);

CREATE TABLE quotations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    quotation_number text NOT NULL,
    customer_id uuid NOT NULL REFERENCES customers(id),
    vehicle_id uuid NOT NULL REFERENCES vehicles(id),
    km_reading int NOT NULL DEFAULT 0,
    overall_discount numeric(12,2) NOT NULL DEFAULT 0,
    tax_percent numeric(12,2) NOT NULL DEFAULT 18,
    validity_days int NOT NULL DEFAULT 7,
    status text NOT NULL,
    notes text,
    valid_until timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (garage_id, quotation_number)
);
CREATE INDEX idx_quotations_garage ON quotations(garage_id);

CREATE TABLE quotation_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_id uuid NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
    name text NOT NULL,
    category text NOT NULL,
    unit_price numeric(12,2) NOT NULL DEFAULT 0,
    quantity numeric(12,2) NOT NULL DEFAULT 1,
    unit text NOT NULL DEFAULT 'Pcs',
    discount_percent numeric(12,2) NOT NULL DEFAULT 0,
    tax_percent numeric(12,2) NOT NULL DEFAULT 0,
    is_labour boolean NOT NULL DEFAULT false,
    part_number text,
    notes text,
    assigned_staff_id uuid REFERENCES staff_members(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_quotation_items_parent ON quotation_items(quotation_id);

CREATE TABLE invoices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    invoice_number text NOT NULL,
    job_card_id uuid REFERENCES job_cards(id),
    customer_id uuid NOT NULL REFERENCES customers(id),
    vehicle_id uuid NOT NULL REFERENCES vehicles(id),
    km_reading int NOT NULL DEFAULT 0,
    discount_amount numeric(12,2) NOT NULL DEFAULT 0,
    tax_percent numeric(12,2) NOT NULL DEFAULT 18,
    invoice_date timestamptz NOT NULL DEFAULT now(),
    due_date timestamptz,
    cancelled_at timestamptz,
    notes text,
    terms_and_conditions text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (garage_id, invoice_number)
);
CREATE INDEX idx_invoices_garage ON invoices(garage_id);

CREATE TABLE invoice_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    name text NOT NULL,
    category text NOT NULL,
    unit_price numeric(12,2) NOT NULL DEFAULT 0,
    quantity numeric(12,2) NOT NULL DEFAULT 1,
    unit text NOT NULL DEFAULT 'Pcs',
    discount_percent numeric(12,2) NOT NULL DEFAULT 0,
    tax_percent numeric(12,2) NOT NULL DEFAULT 0,
    is_labour boolean NOT NULL DEFAULT false,
    part_number text,
    notes text,
    assigned_staff_id uuid REFERENCES staff_members(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_invoice_items_parent ON invoice_items(invoice_id);

CREATE TABLE payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    customer_id uuid,
    amount numeric(12,2) NOT NULL,
    mode text NOT NULL,
    transaction_ref text,
    payment_date timestamptz NOT NULL DEFAULT now(),
    notes text,
    received_by text,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_payments_invoice ON payments(invoice_id);

CREATE TABLE expenses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    title text NOT NULL,
    category text NOT NULL,
    amount numeric(12,2) NOT NULL,
    expense_date date NOT NULL,
    payment_mode text NOT NULL DEFAULT 'cash',
    vendor_name text,
    notes text,
    receipt_path text,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_expenses_garage ON expenses(garage_id);

CREATE TABLE catalog_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    garage_id uuid NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    name text NOT NULL,
    category text NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    unit text NOT NULL DEFAULT 'Pcs',
    is_labour boolean NOT NULL DEFAULT false,
    part_number text,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_catalog_items_garage ON catalog_items(garage_id);

-- +goose Down
DROP TABLE IF EXISTS catalog_items;
DROP TABLE IF EXISTS expenses;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS invoice_items;
DROP TABLE IF EXISTS invoices;
DROP TABLE IF EXISTS quotation_items;
DROP TABLE IF EXISTS quotations;
DROP TABLE IF EXISTS job_card_items;
DROP TABLE IF EXISTS job_cards;
DROP TABLE IF EXISTS salary_advances;
DROP TABLE IF EXISTS attendance_records;
DROP TABLE IF EXISTS staff_members;
DROP TABLE IF EXISTS vehicles;
DROP TABLE IF EXISTS customers;
