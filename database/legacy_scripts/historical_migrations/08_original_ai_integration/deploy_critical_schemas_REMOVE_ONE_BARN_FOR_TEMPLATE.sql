-- =====================================================
-- ONE BARN CRITICAL SCHEMAS DEPLOYMENT
-- Master deployment script for Health, Finance, and Performance schemas
-- Data Vault 2.0 Implementation
-- =====================================================

-- Start transaction for atomic deployment
BEGIN;

-- Set session variables for deployment tracking
SET session_replication_role = replica; -- Disable triggers during deployment
SET work_mem = '256MB'; -- Increase memory for large operations

-- Create deployment log table if it doesn't exist
CREATE TABLE IF NOT EXISTS util.deployment_log (
    deployment_id SERIAL PRIMARY KEY,
    deployment_name VARCHAR(255) NOT NULL,
    deployment_start TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deployment_end TIMESTAMP WITH TIME ZONE,
    deployment_status VARCHAR(50) DEFAULT 'IN_PROGRESS',
    deployment_notes TEXT,
    deployed_by VARCHAR(255) DEFAULT SESSION_USER,
    rollback_script TEXT
);

-- Log deployment start
INSERT INTO util.deployment_log (deployment_name, deployment_notes, rollback_script) 
VALUES (
    'Critical Schemas Deployment v1.0',
    'Deploying Health Management, Financial Management, and Performance Tracking schemas',
    'DROP SCHEMA IF EXISTS health CASCADE; DROP SCHEMA IF EXISTS finance CASCADE; DROP SCHEMA IF EXISTS performance CASCADE;'
);

-- Get deployment ID for tracking
DO $$
DECLARE
    deployment_id INTEGER;
BEGIN
    SELECT currval('util.deployment_log_deployment_id_seq') INTO deployment_id;
    RAISE NOTICE 'Starting deployment ID: %', deployment_id;
    RAISE NOTICE 'Deploying Health Management Schema...';
END $$;

-- =====================================================
-- HEALTH MANAGEMENT SCHEMA DEPLOYMENT
-- =====================================================

-- Create health schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS health;
GRANT USAGE ON SCHEMA health TO app_user;

-- Practitioner Hub (Veterinarians, Farriers, etc.)
CREATE TABLE health.practitioner_h (
    practitioner_hk BYTEA PRIMARY KEY,
    practitioner_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(practitioner_bk, tenant_hk)
);

-- Practitioner Details Satellite
CREATE TABLE health.practitioner_details_s (
    practitioner_hk BYTEA NOT NULL REFERENCES health.practitioner_h(practitioner_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    practitioner_type VARCHAR(50) NOT NULL,
    license_number VARCHAR(100),
    license_state VARCHAR(50),
    license_expiry_date DATE,
    clinic_name VARCHAR(255),
    phone VARCHAR(50),
    mobile_phone VARCHAR(50),
    email VARCHAR(255),
    emergency_phone VARCHAR(50),
    address_street VARCHAR(255),
    address_city VARCHAR(100),
    address_state VARCHAR(50),
    address_zip VARCHAR(20),
    specializations TEXT[],
    service_area_radius INTEGER,
    hourly_rate DECIMAL(10,2),
    emergency_rate DECIMAL(10,2),
    travel_fee DECIMAL(10,2),
    minimum_charge DECIMAL(10,2),
    payment_terms VARCHAR(100),
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    is_emergency_available BOOLEAN DEFAULT false,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (practitioner_hk, load_date)
);

-- Appointment Hub
CREATE TABLE health.appointment_h (
    appointment_hk BYTEA PRIMARY KEY,
    appointment_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(appointment_bk, tenant_hk)
);

-- Appointment Details Satellite
CREATE TABLE health.appointment_details_s (
    appointment_hk BYTEA NOT NULL REFERENCES health.appointment_h(appointment_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    estimated_duration INTEGER,
    appointment_type VARCHAR(100) NOT NULL,
    service_type VARCHAR(100) NOT NULL,
    purpose VARCHAR(255) NOT NULL,
    location VARCHAR(255),
    status VARCHAR(50) DEFAULT 'SCHEDULED',
    priority VARCHAR(20) DEFAULT 'NORMAL',
    estimated_cost DECIMAL(10,2),
    actual_cost DECIMAL(10,2),
    travel_fee DECIMAL(10,2),
    emergency_fee DECIMAL(10,2),
    special_instructions TEXT,
    preparation_notes TEXT,
    weather_dependent BOOLEAN DEFAULT false,
    requires_sedation BOOLEAN DEFAULT false,
    requires_assistant BOOLEAN DEFAULT false,
    completed_timestamp TIMESTAMP WITH TIME ZONE,
    cancelled_reason TEXT,
    no_show_reason TEXT,
    follow_up_required BOOLEAN DEFAULT false,
    follow_up_date DATE,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (appointment_hk, load_date)
);

-- Treatment Hub
CREATE TABLE health.treatment_h (
    treatment_hk BYTEA PRIMARY KEY,
    treatment_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(treatment_bk, tenant_hk)
);

-- Treatment Details Satellite
CREATE TABLE health.treatment_details_s (
    treatment_hk BYTEA NOT NULL REFERENCES health.treatment_h(treatment_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    treatment_date DATE NOT NULL,
    treatment_time TIME,
    treatment_type VARCHAR(100) NOT NULL,
    treatment_category VARCHAR(50) NOT NULL,
    procedure_name VARCHAR(255) NOT NULL,
    diagnosis VARCHAR(255),
    symptoms_observed TEXT,
    treatment_description TEXT NOT NULL,
    medications_administered TEXT[],
    dosage_instructions TEXT,
    administration_method VARCHAR(100),
    treatment_location VARCHAR(100),
    anesthesia_used BOOLEAN DEFAULT false,
    anesthesia_type VARCHAR(100),
    complications TEXT,
    treatment_outcome VARCHAR(100),
    follow_up_required BOOLEAN DEFAULT false,
    follow_up_instructions TEXT,
    next_treatment_date DATE,
    restrictions TEXT,
    cost DECIMAL(10,2),
    insurance_claim_number VARCHAR(100),
    practitioner_notes TEXT,
    owner_instructions TEXT,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (treatment_hk, load_date)
);

-- Health Document Hub
CREATE TABLE health.health_document_h (
    health_document_hk BYTEA PRIMARY KEY,
    health_document_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(health_document_bk, tenant_hk)
);

-- Health Document Details Satellite
CREATE TABLE health.health_document_details_s (
    health_document_hk BYTEA NOT NULL REFERENCES health.health_document_h(health_document_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    document_type VARCHAR(100) NOT NULL,
    document_name VARCHAR(255) NOT NULL,
    document_number VARCHAR(100),
    issue_date DATE NOT NULL,
    expiry_date DATE,
    issuing_authority VARCHAR(255),
    issuing_practitioner VARCHAR(255),
    test_results TEXT,
    test_method VARCHAR(100),
    laboratory_name VARCHAR(255),
    compliance_status VARCHAR(50) DEFAULT 'CURRENT',
    required_for TEXT[],
    document_url VARCHAR(500),
    document_hash VARCHAR(64),
    verification_code VARCHAR(100),
    notes TEXT,
    reminder_sent BOOLEAN DEFAULT false,
    renewal_reminder_days INTEGER DEFAULT 30,
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (health_document_hk, load_date)
);

-- Health relationship links
CREATE TABLE health.horse_appointment_l (
    link_horse_appointment_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    appointment_hk BYTEA NOT NULL REFERENCES health.appointment_h(appointment_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE health.practitioner_appointment_l (
    link_practitioner_appointment_hk BYTEA PRIMARY KEY,
    practitioner_hk BYTEA NOT NULL REFERENCES health.practitioner_h(practitioner_hk),
    appointment_hk BYTEA NOT NULL REFERENCES health.appointment_h(appointment_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE health.horse_treatment_l (
    link_horse_treatment_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    treatment_hk BYTEA NOT NULL REFERENCES health.treatment_h(treatment_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE health.horse_health_document_l (
    link_horse_health_document_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    health_document_hk BYTEA NOT NULL REFERENCES health.health_document_h(health_document_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

DO $$ BEGIN
    RAISE NOTICE 'Health Management Schema deployed successfully';
    RAISE NOTICE 'Deploying Financial Management Schema...';
END $$;

-- =====================================================
-- FINANCIAL MANAGEMENT SCHEMA DEPLOYMENT
-- =====================================================

-- Create finance schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS finance;
GRANT USAGE ON SCHEMA finance TO app_user;

-- Transaction Hub
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
    transaction_type VARCHAR(50) NOT NULL,
    transaction_category VARCHAR(100) NOT NULL,
    transaction_subcategory VARCHAR(100),
    amount DECIMAL(15,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    description TEXT NOT NULL,
    reference_number VARCHAR(100),
    payment_method VARCHAR(50),
    payment_processor VARCHAR(100),
    processor_transaction_id VARCHAR(255),
    processor_fee DECIMAL(10,2),
    net_amount DECIMAL(15,2),
    tax_amount DECIMAL(10,2),
    tax_rate DECIMAL(5,4),
    is_taxable BOOLEAN DEFAULT false,
    fiscal_year INTEGER,
    fiscal_quarter INTEGER,
    accounting_period VARCHAR(7),
    gl_account_code VARCHAR(50),
    cost_center VARCHAR(50),
    project_code VARCHAR(50),
    status VARCHAR(50) DEFAULT 'PENDING',
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
    invoice_type VARCHAR(50) NOT NULL,
    billing_frequency VARCHAR(50),
    subtotal DECIMAL(15,2) NOT NULL,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    tax_rate DECIMAL(5,4) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    discount_percentage DECIMAL(5,2) DEFAULT 0,
    total_amount DECIMAL(15,2) NOT NULL,
    amount_paid DECIMAL(15,2) DEFAULT 0,
    amount_due DECIMAL(15,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(50) DEFAULT 'DRAFT',
    payment_terms VARCHAR(100),
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
    parent_invoice_hk BYTEA,
    created_by VARCHAR(255),
    approved_by VARCHAR(255),
    approval_date TIMESTAMP WITH TIME ZONE,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (invoice_hk, load_date)
);

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
    payment_method VARCHAR(50) NOT NULL,
    payment_processor VARCHAR(100),
    processor_transaction_id VARCHAR(255),
    processor_fee DECIMAL(10,2),
    net_amount DECIMAL(15,2),
    check_number VARCHAR(100),
    bank_name VARCHAR(255),
    routing_number VARCHAR(20),
    account_last_four VARCHAR(4),
    card_last_four VARCHAR(4),
    card_type VARCHAR(50),
    authorization_code VARCHAR(100),
    reference_number VARCHAR(100),
    payment_status VARCHAR(50) DEFAULT 'PENDING',
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

-- Financial relationship links
CREATE TABLE finance.horse_transaction_l (
    link_horse_transaction_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    transaction_hk BYTEA NOT NULL REFERENCES finance.transaction_h(transaction_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE finance.person_transaction_l (
    link_person_transaction_hk BYTEA PRIMARY KEY,
    owner_hk BYTEA NOT NULL REFERENCES equestrian.owner_h(owner_hk),
    transaction_hk BYTEA NOT NULL REFERENCES finance.transaction_h(transaction_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE finance.invoice_payment_l (
    link_invoice_payment_hk BYTEA PRIMARY KEY,
    invoice_hk BYTEA NOT NULL REFERENCES finance.invoice_h(invoice_hk),
    payment_hk BYTEA NOT NULL REFERENCES finance.payment_h(payment_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

DO $$ BEGIN
    RAISE NOTICE 'Financial Management Schema deployed successfully';
    RAISE NOTICE 'Deploying Performance Tracking Schema...';
END $$;

-- =====================================================
-- PERFORMANCE TRACKING SCHEMA DEPLOYMENT
-- =====================================================

-- Create performance schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS performance;
GRANT USAGE ON SCHEMA performance TO app_user;

-- Training Session Hub
CREATE TABLE performance.training_session_h (
    training_session_hk BYTEA PRIMARY KEY,
    training_session_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(training_session_bk, tenant_hk)
);

-- Training Session Details Satellite
CREATE TABLE performance.training_session_details_s (
    training_session_hk BYTEA NOT NULL REFERENCES performance.training_session_h(training_session_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    session_date DATE NOT NULL,
    session_time TIME NOT NULL,
    duration_minutes INTEGER NOT NULL,
    session_type VARCHAR(100) NOT NULL,
    discipline VARCHAR(100),
    training_level VARCHAR(100),
    location VARCHAR(255),
    weather_conditions VARCHAR(100),
    footing_conditions VARCHAR(100),
    trainer_name VARCHAR(255),
    assistant_trainer VARCHAR(255),
    session_focus TEXT,
    exercises_performed TEXT[],
    goals_for_session TEXT,
    goals_achieved TEXT,
    areas_improved TEXT,
    areas_needing_work TEXT,
    horse_attitude VARCHAR(100),
    horse_energy_level VARCHAR(50),
    horse_cooperation VARCHAR(50),
    gait_quality JSONB,
    technical_scores JSONB,
    overall_session_rating INTEGER CHECK (overall_session_rating BETWEEN 1 AND 10),
    trainer_satisfaction INTEGER CHECK (trainer_satisfaction BETWEEN 1 AND 10),
    horse_fitness_level INTEGER CHECK (horse_fitness_level BETWEEN 1 AND 10),
    session_notes TEXT,
    homework_assigned TEXT,
    next_session_focus TEXT,
    video_links TEXT[],
    photo_links TEXT[],
    equipment_used TEXT[],
    supplements_given TEXT[],
    injuries_noted TEXT,
    veterinary_concerns TEXT,
    farrier_concerns TEXT,
    created_by VARCHAR(255),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (training_session_hk, load_date)
);

-- Competition Hub
CREATE TABLE performance.competition_h (
    competition_hk BYTEA PRIMARY KEY,
    competition_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(competition_bk, tenant_hk)
);

-- Competition Details Satellite
CREATE TABLE performance.competition_details_s (
    competition_hk BYTEA NOT NULL REFERENCES performance.competition_h(competition_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    competition_name VARCHAR(255) NOT NULL,
    competition_type VARCHAR(100) NOT NULL,
    discipline VARCHAR(100) NOT NULL,
    competition_level VARCHAR(100),
    governing_body VARCHAR(100),
    competition_date_start DATE NOT NULL,
    competition_date_end DATE NOT NULL,
    venue_name VARCHAR(255) NOT NULL,
    venue_address_street VARCHAR(255),
    venue_address_city VARCHAR(100),
    venue_address_state VARCHAR(50),
    venue_address_zip VARCHAR(20),
    venue_address_country VARCHAR(50),
    distance_from_barn INTEGER,
    travel_time_hours DECIMAL(4,2),
    entry_deadline DATE,
    entry_fee DECIMAL(10,2),
    stall_fee DECIMAL(10,2),
    drug_fee DECIMAL(10,2),
    office_fee DECIMAL(10,2),
    total_fees DECIMAL(10,2),
    prize_money DECIMAL(10,2),
    weather_conditions VARCHAR(100),
    footing_conditions VARCHAR(100),
    competition_status VARCHAR(50) DEFAULT 'PLANNED',
    entry_confirmation VARCHAR(100),
    stall_assignment VARCHAR(100),
    arrival_date DATE,
    departure_date DATE,
    transportation_arranged BOOLEAN DEFAULT false,
    transportation_cost DECIMAL(10,2),
    accommodation_needed BOOLEAN DEFAULT false,
    accommodation_cost DECIMAL(10,2),
    groom_required BOOLEAN DEFAULT false,
    special_requirements TEXT,
    notes TEXT,
    created_by VARCHAR(255),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (competition_hk, load_date)
);

-- Performance relationship links
CREATE TABLE performance.horse_training_l (
    link_horse_training_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    training_session_hk BYTEA NOT NULL REFERENCES performance.training_session_h(training_session_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE performance.horse_competition_l (
    link_horse_competition_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    competition_hk BYTEA NOT NULL REFERENCES performance.competition_h(competition_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

DO $$ BEGIN
    RAISE NOTICE 'Performance Tracking Schema deployed successfully';
    RAISE NOTICE 'Creating performance indexes...';
END $$;

-- =====================================================
-- CREATE ESSENTIAL INDEXES
-- =====================================================

-- Health schema indexes
CREATE INDEX idx_practitioner_h_practitioner_bk_tenant ON health.practitioner_h(practitioner_bk, tenant_hk);
CREATE INDEX idx_appointment_h_appointment_bk_tenant ON health.appointment_h(appointment_bk, tenant_hk);
CREATE INDEX idx_appointment_details_s_date ON health.appointment_details_s(appointment_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_treatment_h_treatment_bk_tenant ON health.treatment_h(treatment_bk, tenant_hk);
CREATE INDEX idx_treatment_details_s_date ON health.treatment_details_s(treatment_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_health_document_h_document_bk_tenant ON health.health_document_h(health_document_bk, tenant_hk);
CREATE INDEX idx_health_document_details_s_expiry ON health.health_document_details_s(expiry_date) WHERE load_end_date IS NULL;

-- Finance schema indexes
CREATE INDEX idx_transaction_h_transaction_bk_tenant ON finance.transaction_h(transaction_bk, tenant_hk);
CREATE INDEX idx_transaction_details_s_date ON finance.transaction_details_s(transaction_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_invoice_h_invoice_bk_tenant ON finance.invoice_h(invoice_bk, tenant_hk);
CREATE INDEX idx_invoice_details_s_number ON finance.invoice_details_s(invoice_number) WHERE load_end_date IS NULL;
CREATE INDEX idx_payment_h_payment_bk_tenant ON finance.payment_h(payment_bk, tenant_hk);
CREATE INDEX idx_payment_details_s_date ON finance.payment_details_s(payment_date) WHERE load_end_date IS NULL;

-- Performance schema indexes
CREATE INDEX idx_training_session_h_session_bk_tenant ON performance.training_session_h(training_session_bk, tenant_hk);
CREATE INDEX idx_training_session_details_s_date ON performance.training_session_details_s(session_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_competition_h_competition_bk_tenant ON performance.competition_h(competition_bk, tenant_hk);
CREATE INDEX idx_competition_details_s_date ON performance.competition_details_s(competition_date_start) WHERE load_end_date IS NULL;

-- Link table indexes
CREATE INDEX idx_horse_appointment_l_horse ON health.horse_appointment_l(horse_hk);
CREATE INDEX idx_horse_treatment_l_horse ON health.horse_treatment_l(horse_hk);
CREATE INDEX idx_horse_transaction_l_horse ON finance.horse_transaction_l(horse_hk);
CREATE INDEX idx_horse_training_l_horse ON performance.horse_training_l(horse_hk);
CREATE INDEX idx_horse_competition_l_horse ON performance.horse_competition_l(horse_hk);

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

DO $$ BEGIN
    RAISE NOTICE 'Granting permissions...';
END $$;

-- Grant permissions on all new schemas
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA health TO app_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA finance TO app_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA performance TO app_user;

-- =====================================================
-- DEPLOYMENT COMPLETION
-- =====================================================

-- Simple deployment log update
DO $$
BEGIN
    -- Only update the notes field which we know exists
    UPDATE util.deployment_log 
    SET deployment_notes = COALESCE(deployment_notes, '') || ' - Successfully deployed all critical schemas with indexes and permissions'
    WHERE deployment_id = currval('util.deployment_log_deployment_id_seq');
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Could not update deployment log, but deployment was successful';
END $$;

-- Reset session variables
RESET session_replication_role;
RESET work_mem;

-- Commit the transaction
COMMIT;

-- Final success message
SELECT 
    'DEPLOYMENT SUCCESSFUL!' as status,
    'Health, Finance, and Performance schemas deployed' as message,
    CURRENT_TIMESTAMP as completed_at,
    SESSION_USER as deployed_by;

-- Display deployment summary
SELECT 
    schemaname,
    COUNT(*) as table_count
FROM pg_tables 
WHERE schemaname IN ('health', 'finance', 'performance')
GROUP BY schemaname
ORDER BY schemaname;

DO $$ BEGIN
    RAISE NOTICE 'Critical schemas deployment completed successfully!';
    RAISE NOTICE 'One Barn is now ready for full business operations.';
END $$; 