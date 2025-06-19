-- =====================================================
-- ONE BARN FINANCIAL MANAGEMENT SCHEMA
-- Data Vault 2.0 Implementation
-- =====================================================

-- Create finance schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS finance;
GRANT USAGE ON SCHEMA finance TO barn_user;

-- =====================================================
-- TRANSACTION MANAGEMENT
-- =====================================================

-- Transaction Hub (All financial transactions)
CREATE TABLE finance.transaction_h (
    transaction_hk BYTEA PRIMARY KEY,
    transaction_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(transaction_bk, tenant_hk)
);

-- Transaction Details Satellite
CREATE TABLE finance.transaction_details_s (
    transaction_hk BYTEA NOT NULL REFERENCES finance.transaction_h(transaction_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    transaction_date DATE NOT NULL,
    transaction_time TIME DEFAULT CURRENT_TIME,
    transaction_type VARCHAR(50) NOT NULL, -- INCOME, EXPENSE, TRANSFER, REFUND, ADJUSTMENT
    transaction_category VARCHAR(100) NOT NULL, -- BOARDING, TRAINING, VET_BILLS, FEED, SUPPLIES, etc.
    transaction_subcategory VARCHAR(100),
    amount DECIMAL(15,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    description TEXT NOT NULL,
    reference_number VARCHAR(100),
    payment_method VARCHAR(50), -- CASH, CHECK, CREDIT_CARD, BANK_TRANSFER, ACH
    payment_processor VARCHAR(100), -- STRIPE, SQUARE, PAYPAL, etc.
    processor_transaction_id VARCHAR(255),
    processor_fee DECIMAL(10,2),
    net_amount DECIMAL(15,2), -- Amount after fees
    tax_amount DECIMAL(10,2),
    tax_rate DECIMAL(5,4),
    is_taxable BOOLEAN DEFAULT false,
    fiscal_year INTEGER,
    fiscal_quarter INTEGER,
    accounting_period VARCHAR(7), -- YYYY-MM format
    gl_account_code VARCHAR(50), -- General ledger account
    cost_center VARCHAR(50),
    project_code VARCHAR(50),
    status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, COMPLETED, FAILED, CANCELLED, REFUNDED
    processed_timestamp TIMESTAMP WITH TIME ZONE,
    reconciled BOOLEAN DEFAULT false,
    reconciled_date DATE,
    notes TEXT,
    created_by VARCHAR(255),
    approved_by VARCHAR(255),
    approval_date TIMESTAMP WITH TIME ZONE,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (transaction_hk, load_date)
);

-- =====================================================
-- INVOICE MANAGEMENT
-- =====================================================

-- Invoice Hub
CREATE TABLE finance.invoice_h (
    invoice_hk BYTEA PRIMARY KEY,
    invoice_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(invoice_bk, tenant_hk)
);

-- Invoice Details Satellite
CREATE TABLE finance.invoice_details_s (
    invoice_hk BYTEA NOT NULL REFERENCES finance.invoice_h(invoice_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    invoice_number VARCHAR(100) NOT NULL,
    invoice_date DATE NOT NULL,
    due_date DATE NOT NULL,
    billing_period_start DATE,
    billing_period_end DATE,
    invoice_type VARCHAR(50) NOT NULL, -- MONTHLY, QUARTERLY, ANNUAL, ONE_TIME, RECURRING
    billing_frequency VARCHAR(50), -- MONTHLY, QUARTERLY, ANNUAL
    subtotal DECIMAL(15,2) NOT NULL,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    tax_rate DECIMAL(5,4) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    discount_percentage DECIMAL(5,2) DEFAULT 0,
    total_amount DECIMAL(15,2) NOT NULL,
    amount_paid DECIMAL(15,2) DEFAULT 0,
    amount_due DECIMAL(15,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(50) DEFAULT 'DRAFT', -- DRAFT, SENT, VIEWED, PARTIAL_PAID, PAID, OVERDUE, CANCELLED, REFUNDED
    payment_terms VARCHAR(100), -- NET_30, NET_15, DUE_ON_RECEIPT
    late_fee_rate DECIMAL(5,4),
    late_fee_amount DECIMAL(10,2) DEFAULT 0,
    sent_date TIMESTAMP WITH TIME ZONE,
    viewed_date TIMESTAMP WITH TIME ZONE,
    first_payment_date TIMESTAMP WITH TIME ZONE,
    last_payment_date TIMESTAMP WITH TIME ZONE,
    paid_in_full_date TIMESTAMP WITH TIME ZONE,
    payment_method VARCHAR(50),
    payment_processor VARCHAR(100),
    processor_fee DECIMAL(10,2),
    net_received DECIMAL(15,2),
    billing_address_street VARCHAR(255),
    billing_address_city VARCHAR(100),
    billing_address_state VARCHAR(50),
    billing_address_zip VARCHAR(20),
    billing_address_country VARCHAR(50),
    special_instructions TEXT,
    internal_notes TEXT,
    auto_generated BOOLEAN DEFAULT false,
    recurring_invoice_id VARCHAR(255),
    parent_invoice_hk BYTEA, -- For credit memos, adjustments
    created_by VARCHAR(255),
    approved_by VARCHAR(255),
    approval_date TIMESTAMP WITH TIME ZONE,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (invoice_hk, load_date)
);

-- Invoice Line Items Satellite
CREATE TABLE finance.invoice_line_item_s (
    invoice_hk BYTEA NOT NULL REFERENCES finance.invoice_h(invoice_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    line_item_number INTEGER NOT NULL,
    item_type VARCHAR(100) NOT NULL, -- BOARDING, TRAINING, VET_BILL, SUPPLIES, SERVICES
    item_code VARCHAR(100),
    item_description TEXT NOT NULL,
    service_period_start DATE,
    service_period_end DATE,
    quantity DECIMAL(10,2) DEFAULT 1,
    unit_of_measure VARCHAR(50), -- MONTH, DAY, HOUR, EACH
    unit_price DECIMAL(15,2) NOT NULL,
    line_total DECIMAL(15,2) NOT NULL,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    discount_percentage DECIMAL(5,2) DEFAULT 0,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    tax_rate DECIMAL(5,4) DEFAULT 0,
    is_taxable BOOLEAN DEFAULT false,
    gl_account_code VARCHAR(50),
    cost_center VARCHAR(50),
    project_code VARCHAR(50),
    notes TEXT,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (invoice_hk, load_date, line_item_number)
);

-- =====================================================
-- PAYMENT MANAGEMENT
-- =====================================================

-- Payment Hub
CREATE TABLE finance.payment_h (
    payment_hk BYTEA PRIMARY KEY,
    payment_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(payment_bk, tenant_hk)
);

-- Payment Details Satellite
CREATE TABLE finance.payment_details_s (
    payment_hk BYTEA NOT NULL REFERENCES finance.payment_h(payment_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    payment_date DATE NOT NULL,
    payment_time TIME DEFAULT CURRENT_TIME,
    payment_amount DECIMAL(15,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    payment_method VARCHAR(50) NOT NULL, -- CASH, CHECK, CREDIT_CARD, DEBIT_CARD, ACH, WIRE_TRANSFER
    payment_processor VARCHAR(100), -- STRIPE, SQUARE, PAYPAL, BANK
    processor_transaction_id VARCHAR(255),
    processor_fee DECIMAL(10,2),
    net_amount DECIMAL(15,2), -- Amount after fees
    check_number VARCHAR(100),
    bank_name VARCHAR(255),
    routing_number VARCHAR(20),
    account_last_four VARCHAR(4),
    card_last_four VARCHAR(4),
    card_type VARCHAR(50), -- VISA, MASTERCARD, AMEX, DISCOVER
    authorization_code VARCHAR(100),
    reference_number VARCHAR(100),
    payment_status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, COMPLETED, FAILED, CANCELLED, REFUNDED, CHARGEBACK
    failure_reason TEXT,
    processed_timestamp TIMESTAMP WITH TIME ZONE,
    settled_date DATE,
    refunded_amount DECIMAL(15,2) DEFAULT 0,
    refund_date DATE,
    refund_reason TEXT,
    chargeback_amount DECIMAL(15,2) DEFAULT 0,
    chargeback_date DATE,
    chargeback_reason TEXT,
    reconciled BOOLEAN DEFAULT false,
    reconciled_date DATE,
    deposit_date DATE,
    deposit_reference VARCHAR(100),
    notes TEXT,
    received_by VARCHAR(255),
    processed_by VARCHAR(255),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (payment_hk, load_date)
);

-- =====================================================
-- ACCOUNT MANAGEMENT
-- =====================================================

-- Account Hub (Customer accounts, vendor accounts)
CREATE TABLE finance.account_h (
    account_hk BYTEA PRIMARY KEY,
    account_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(account_bk, tenant_hk)
);

-- Account Details Satellite
CREATE TABLE finance.account_details_s (
    account_hk BYTEA NOT NULL REFERENCES finance.account_h(account_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    account_number VARCHAR(100) NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50) NOT NULL, -- CUSTOMER, VENDOR, EMPLOYEE, BANK, CREDIT_CARD
    account_category VARCHAR(100), -- BOARDING_CLIENT, TRAINING_CLIENT, SUPPLIER, SERVICE_PROVIDER
    credit_limit DECIMAL(15,2),
    current_balance DECIMAL(15,2) DEFAULT 0,
    available_credit DECIMAL(15,2),
    payment_terms VARCHAR(100), -- NET_30, NET_15, DUE_ON_RECEIPT, COD
    discount_percentage DECIMAL(5,2) DEFAULT 0,
    tax_exempt BOOLEAN DEFAULT false,
    tax_id VARCHAR(50),
    preferred_payment_method VARCHAR(50),
    auto_pay_enabled BOOLEAN DEFAULT false,
    billing_cycle VARCHAR(50), -- MONTHLY, QUARTERLY, ANNUAL
    billing_day INTEGER, -- Day of month for billing
    late_fee_rate DECIMAL(5,4),
    interest_rate DECIMAL(5,4),
    account_status VARCHAR(50) DEFAULT 'ACTIVE', -- ACTIVE, INACTIVE, SUSPENDED, CLOSED
    opened_date DATE NOT NULL,
    closed_date DATE,
    last_activity_date DATE,
    last_statement_date DATE,
    next_billing_date DATE,
    contact_name VARCHAR(255),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    billing_address_street VARCHAR(255),
    billing_address_city VARCHAR(100),
    billing_address_state VARCHAR(50),
    billing_address_zip VARCHAR(20),
    billing_address_country VARCHAR(50),
    notes TEXT,
    created_by VARCHAR(255),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (account_hk, load_date)
);

-- =====================================================
-- RELATIONSHIP LINKS
-- =====================================================

-- Horse-Transaction Link (Track costs/revenue per horse)
CREATE TABLE finance.horse_transaction_l (
    link_horse_transaction_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    transaction_hk BYTEA NOT NULL REFERENCES finance.transaction_h(transaction_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Person-Transaction Link (Track client billing)
CREATE TABLE finance.person_transaction_l (
    link_person_transaction_hk BYTEA PRIMARY KEY,
    owner_hk BYTEA NOT NULL REFERENCES equestrian.owner_h(owner_hk),
    transaction_hk BYTEA NOT NULL REFERENCES finance.transaction_h(transaction_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Invoice-Payment Link
CREATE TABLE finance.invoice_payment_l (
    link_invoice_payment_hk BYTEA PRIMARY KEY,
    invoice_hk BYTEA NOT NULL REFERENCES finance.invoice_h(invoice_hk),
    payment_hk BYTEA NOT NULL REFERENCES finance.payment_h(payment_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Invoice Payment Allocation Satellite
CREATE TABLE finance.invoice_payment_allocation_s (
    link_invoice_payment_hk BYTEA NOT NULL REFERENCES finance.invoice_payment_l(link_invoice_payment_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    allocated_amount DECIMAL(15,2) NOT NULL,
    allocation_date DATE NOT NULL,
    allocation_type VARCHAR(50) DEFAULT 'PAYMENT', -- PAYMENT, CREDIT, ADJUSTMENT
    notes TEXT,
    allocated_by VARCHAR(255),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (link_invoice_payment_hk, load_date)
);

-- Account-Owner Link
CREATE TABLE finance.account_owner_l (
    link_account_owner_hk BYTEA PRIMARY KEY,
    account_hk BYTEA NOT NULL REFERENCES finance.account_h(account_hk),
    owner_hk BYTEA NOT NULL REFERENCES equestrian.owner_h(owner_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- =====================================================
-- RECURRING BILLING
-- =====================================================

-- Recurring Billing Template Hub
CREATE TABLE finance.recurring_billing_h (
    recurring_billing_hk BYTEA PRIMARY KEY,
    recurring_billing_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(recurring_billing_bk, tenant_hk)
);

-- Recurring Billing Details Satellite
CREATE TABLE finance.recurring_billing_details_s (
    recurring_billing_hk BYTEA NOT NULL REFERENCES finance.recurring_billing_h(recurring_billing_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    template_name VARCHAR(255) NOT NULL,
    billing_frequency VARCHAR(50) NOT NULL, -- MONTHLY, QUARTERLY, ANNUAL
    billing_day INTEGER NOT NULL, -- Day of month
    start_date DATE NOT NULL,
    end_date DATE,
    next_billing_date DATE NOT NULL,
    last_billing_date DATE,
    amount DECIMAL(15,2) NOT NULL,
    description TEXT NOT NULL,
    auto_generate BOOLEAN DEFAULT true,
    auto_send BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_by VARCHAR(255),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (recurring_billing_hk, load_date)
);

-- =====================================================
-- REFERENCE DATA FOR FINANCIAL MANAGEMENT
-- =====================================================

-- Chart of Accounts Reference
CREATE TABLE ref.chart_of_accounts_r (
    account_code VARCHAR(50) PRIMARY KEY,
    account_name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50) NOT NULL, -- ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE
    account_category VARCHAR(100), -- CURRENT_ASSET, FIXED_ASSET, OPERATING_EXPENSE, etc.
    parent_account_code VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    description TEXT,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Payment Terms Reference
CREATE TABLE ref.payment_terms_r (
    payment_terms_code VARCHAR(20) PRIMARY KEY,
    payment_terms_name VARCHAR(100) NOT NULL,
    net_days INTEGER NOT NULL,
    discount_days INTEGER,
    discount_percentage DECIMAL(5,2),
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Transaction indexes
CREATE INDEX idx_transaction_h_transaction_bk_tenant ON finance.transaction_h(transaction_bk, tenant_hk);
CREATE INDEX idx_transaction_details_s_date ON finance.transaction_details_s(transaction_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_transaction_details_s_type ON finance.transaction_details_s(transaction_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_transaction_details_s_category ON finance.transaction_details_s(transaction_category) WHERE load_end_date IS NULL;
CREATE INDEX idx_transaction_details_s_status ON finance.transaction_details_s(status) WHERE load_end_date IS NULL;
CREATE INDEX idx_transaction_details_s_amount ON finance.transaction_details_s(amount) WHERE load_end_date IS NULL;

-- Invoice indexes
CREATE INDEX idx_invoice_h_invoice_bk_tenant ON finance.invoice_h(invoice_bk, tenant_hk);
CREATE INDEX idx_invoice_details_s_number ON finance.invoice_details_s(invoice_number) WHERE load_end_date IS NULL;
CREATE INDEX idx_invoice_details_s_date ON finance.invoice_details_s(invoice_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_invoice_details_s_due_date ON finance.invoice_details_s(due_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_invoice_details_s_status ON finance.invoice_details_s(status) WHERE load_end_date IS NULL;
CREATE INDEX idx_invoice_details_s_total ON finance.invoice_details_s(total_amount) WHERE load_end_date IS NULL;

-- Payment indexes
CREATE INDEX idx_payment_h_payment_bk_tenant ON finance.payment_h(payment_bk, tenant_hk);
CREATE INDEX idx_payment_details_s_date ON finance.payment_details_s(payment_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_payment_details_s_method ON finance.payment_details_s(payment_method) WHERE load_end_date IS NULL;
CREATE INDEX idx_payment_details_s_status ON finance.payment_details_s(payment_status) WHERE load_end_date IS NULL;
CREATE INDEX idx_payment_details_s_amount ON finance.payment_details_s(payment_amount) WHERE load_end_date IS NULL;

-- Account indexes
CREATE INDEX idx_account_h_account_bk_tenant ON finance.account_h(account_bk, tenant_hk);
CREATE INDEX idx_account_details_s_number ON finance.account_details_s(account_number) WHERE load_end_date IS NULL;
CREATE INDEX idx_account_details_s_type ON finance.account_details_s(account_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_account_details_s_status ON finance.account_details_s(account_status) WHERE load_end_date IS NULL;

-- Link table indexes
CREATE INDEX idx_horse_transaction_l_horse ON finance.horse_transaction_l(horse_hk);
CREATE INDEX idx_horse_transaction_l_transaction ON finance.horse_transaction_l(transaction_hk);
CREATE INDEX idx_person_transaction_l_owner ON finance.person_transaction_l(owner_hk);
CREATE INDEX idx_person_transaction_l_transaction ON finance.person_transaction_l(transaction_hk);
CREATE INDEX idx_invoice_payment_l_invoice ON finance.invoice_payment_l(invoice_hk);
CREATE INDEX idx_invoice_payment_l_payment ON finance.invoice_payment_l(payment_hk);
CREATE INDEX idx_account_owner_l_account ON finance.account_owner_l(account_hk);
CREATE INDEX idx_account_owner_l_owner ON finance.account_owner_l(owner_hk);

-- =====================================================
-- INITIAL REFERENCE DATA
-- =====================================================

-- Insert basic chart of accounts
INSERT INTO ref.chart_of_accounts_r (account_code, account_name, account_type, account_category, description) VALUES
-- Assets
('1000', 'Cash - Operating', 'ASSET', 'CURRENT_ASSET', 'Primary operating cash account'),
('1100', 'Accounts Receivable', 'ASSET', 'CURRENT_ASSET', 'Money owed by customers'),
('1200', 'Inventory - Feed', 'ASSET', 'CURRENT_ASSET', 'Feed and hay inventory'),
('1210', 'Inventory - Supplies', 'ASSET', 'CURRENT_ASSET', 'Barn supplies and equipment'),
('1500', 'Equipment', 'ASSET', 'FIXED_ASSET', 'Barn equipment and machinery'),
('1600', 'Buildings', 'ASSET', 'FIXED_ASSET', 'Barn buildings and structures'),
('1700', 'Land', 'ASSET', 'FIXED_ASSET', 'Land and property'),

-- Liabilities
('2000', 'Accounts Payable', 'LIABILITY', 'CURRENT_LIABILITY', 'Money owed to vendors'),
('2100', 'Accrued Expenses', 'LIABILITY', 'CURRENT_LIABILITY', 'Accrued but unpaid expenses'),
('2500', 'Long-term Debt', 'LIABILITY', 'LONG_TERM_LIABILITY', 'Mortgages and long-term loans'),

-- Equity
('3000', 'Owner Equity', 'EQUITY', 'OWNER_EQUITY', 'Owner investment and retained earnings'),

-- Revenue
('4000', 'Boarding Revenue', 'REVENUE', 'OPERATING_REVENUE', 'Monthly boarding fees'),
('4100', 'Training Revenue', 'REVENUE', 'OPERATING_REVENUE', 'Training and lesson fees'),
('4200', 'Show Revenue', 'REVENUE', 'OPERATING_REVENUE', 'Show and competition fees'),
('4300', 'Other Revenue', 'REVENUE', 'OTHER_REVENUE', 'Miscellaneous income'),

-- Expenses
('5000', 'Feed Expense', 'EXPENSE', 'OPERATING_EXPENSE', 'Feed and hay costs'),
('5100', 'Veterinary Expense', 'EXPENSE', 'OPERATING_EXPENSE', 'Veterinary services'),
('5200', 'Farrier Expense', 'EXPENSE', 'OPERATING_EXPENSE', 'Farrier services'),
('5300', 'Utilities', 'EXPENSE', 'OPERATING_EXPENSE', 'Electricity, water, gas'),
('5400', 'Insurance', 'EXPENSE', 'OPERATING_EXPENSE', 'Property and liability insurance'),
('5500', 'Maintenance', 'EXPENSE', 'OPERATING_EXPENSE', 'Facility maintenance and repairs'),
('5600', 'Labor', 'EXPENSE', 'OPERATING_EXPENSE', 'Employee wages and benefits'),
('5700', 'Professional Services', 'EXPENSE', 'OPERATING_EXPENSE', 'Legal, accounting, consulting'),
('5800', 'Office Expense', 'EXPENSE', 'OPERATING_EXPENSE', 'Office supplies and equipment'),
('5900', 'Other Expense', 'EXPENSE', 'OTHER_EXPENSE', 'Miscellaneous expenses');

-- Insert common payment terms
INSERT INTO ref.payment_terms_r (payment_terms_code, payment_terms_name, net_days, discount_days, discount_percentage, description) VALUES
('NET30', 'Net 30', 30, NULL, NULL, 'Payment due within 30 days'),
('NET15', 'Net 15', 15, NULL, NULL, 'Payment due within 15 days'),
('DUE', 'Due on Receipt', 0, NULL, NULL, 'Payment due immediately upon receipt'),
('210NET30', '2/10 Net 30', 30, 10, 2.00, '2% discount if paid within 10 days, otherwise net 30'),
('COD', 'Cash on Delivery', 0, NULL, NULL, 'Payment required at time of delivery');

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA finance TO barn_user;

-- Success message
SELECT 'Financial Management Schema Successfully Created!' as status; 