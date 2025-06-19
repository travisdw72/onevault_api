-- OneVault Database Creation Script
-- Customer: Elite Equestrian Center (one_barn)
-- Database: one_barn_db
-- Industry: Equestrian Management
-- Created: 2024-01-15

-- =====================================================
-- STEP 1: CREATE DATABASE AND USER
-- =====================================================

-- Connect as superuser first
-- CREATE DATABASE one_barn_db;
-- CREATE USER barn_user WITH PASSWORD 'secure_barn_password_change_in_production';
-- GRANT ALL PRIVILEGES ON DATABASE one_barn_db TO barn_user;

-- Connect to one_barn_db as barn_user
-- \c one_barn_db barn_user;

-- =====================================================
-- STEP 2: CREATE SCHEMAS (Data Vault 2.0 Structure)
-- =====================================================

CREATE SCHEMA IF NOT EXISTS auth;           -- Authentication and authorization
CREATE SCHEMA IF NOT EXISTS business;       -- Core business entities
CREATE SCHEMA IF NOT EXISTS equestrian;     -- Equestrian-specific entities
CREATE SCHEMA IF NOT EXISTS audit;          -- Audit trails and compliance
CREATE SCHEMA IF NOT EXISTS util;           -- Utility functions and procedures
CREATE SCHEMA IF NOT EXISTS ref;            -- Reference data and lookups
CREATE SCHEMA IF NOT EXISTS staging;        -- Data staging and processing
CREATE SCHEMA IF NOT EXISTS raw;            -- Raw data ingestion

-- Grant permissions
GRANT USAGE ON SCHEMA auth TO barn_user;
GRANT USAGE ON SCHEMA business TO barn_user;
GRANT USAGE ON SCHEMA equestrian TO barn_user;
GRANT USAGE ON SCHEMA audit TO barn_user;
GRANT USAGE ON SCHEMA util TO barn_user;
GRANT USAGE ON SCHEMA ref TO barn_user;
GRANT USAGE ON SCHEMA staging TO barn_user;
GRANT USAGE ON SCHEMA raw TO barn_user;

-- =====================================================
-- STEP 3: UTILITY FUNCTIONS
-- =====================================================

-- Hash function for generating hash keys
CREATE OR REPLACE FUNCTION util.hash_binary(input_text TEXT)
RETURNS BYTEA AS $$
BEGIN
    RETURN decode(encode(digest(input_text, 'sha256'), 'hex'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Current load date function
CREATE OR REPLACE FUNCTION util.current_load_date()
RETURNS TIMESTAMP WITH TIME ZONE AS $$
BEGIN
    RETURN CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql STABLE;

-- Record source function
CREATE OR REPLACE FUNCTION util.get_record_source()
RETURNS VARCHAR(100) AS $$
BEGIN
    RETURN 'ONEVAULT_EQUESTRIAN_API';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =====================================================
-- STEP 4: AUTHENTICATION SCHEMA (Core Data Vault)
-- =====================================================

-- Tenant Hub (Foundation for multi-tenancy)
CREATE TABLE auth.tenant_h (
    tenant_hk BYTEA PRIMARY KEY,
    tenant_bk VARCHAR(255) NOT NULL UNIQUE,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Tenant Satellite
CREATE TABLE auth.tenant_profile_s (
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    tenant_name VARCHAR(255) NOT NULL,
    tenant_type VARCHAR(100) NOT NULL, -- MANAGEMENT, TRAINING, CLIENTS
    domain_name VARCHAR(255),
    subdomain VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    max_users INTEGER DEFAULT 50,
    features_enabled TEXT[],
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (tenant_hk, load_date)
);

-- User Hub
CREATE TABLE auth.user_h (
    user_hk BYTEA PRIMARY KEY,
    user_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(user_bk, tenant_hk)
);

-- User Profile Satellite
CREATE TABLE auth.user_profile_s (
    user_hk BYTEA NOT NULL REFERENCES auth.user_h(user_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    username VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(50),
    job_title VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (user_hk, load_date)
);

-- User Authentication Satellite
CREATE TABLE auth.user_auth_s (
    user_hk BYTEA NOT NULL REFERENCES auth.user_h(user_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    password_hash BYTEA NOT NULL,
    password_salt BYTEA NOT NULL,
    mfa_enabled BOOLEAN DEFAULT false,
    mfa_secret BYTEA,
    last_login TIMESTAMP WITH TIME ZONE,
    failed_login_attempts INTEGER DEFAULT 0,
    account_locked BOOLEAN DEFAULT false,
    password_last_changed TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (user_hk, load_date)
);

-- =====================================================
-- STEP 5: BUSINESS SCHEMA (Core Business Entities)
-- =====================================================

-- Entity Hub (Business entities - facilities, companies, etc.)
CREATE TABLE business.entity_h (
    entity_hk BYTEA PRIMARY KEY,
    entity_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(entity_bk, tenant_hk)
);

-- Entity Details Satellite
CREATE TABLE business.entity_details_s (
    entity_hk BYTEA NOT NULL REFERENCES business.entity_h(entity_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    entity_name VARCHAR(255) NOT NULL,
    entity_type VARCHAR(100) NOT NULL, -- FACILITY, COMPANY, INDIVIDUAL
    legal_name VARCHAR(255),
    tax_id VARCHAR(50),
    address_street VARCHAR(255),
    address_city VARCHAR(100),
    address_state VARCHAR(50),
    address_zip VARCHAR(20),
    address_country VARCHAR(50),
    phone VARCHAR(50),
    email VARCHAR(255),
    website VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (entity_hk, load_date)
);

-- =====================================================
-- STEP 6: EQUESTRIAN SCHEMA (Industry-Specific)
-- =====================================================

-- Horse Hub
CREATE TABLE equestrian.horse_h (
    horse_hk BYTEA PRIMARY KEY,
    horse_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(horse_bk, tenant_hk)
);

-- Horse Details Satellite
CREATE TABLE equestrian.horse_details_s (
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    registered_name VARCHAR(255) NOT NULL,
    barn_name VARCHAR(255),
    breed VARCHAR(100),
    color VARCHAR(50),
    gender VARCHAR(20), -- STALLION, MARE, GELDING
    date_of_birth DATE,
    height_hands DECIMAL(4,2),
    weight_pounds INTEGER,
    microchip_number VARCHAR(50),
    registration_number VARCHAR(100),
    registration_organization VARCHAR(100),
    discipline VARCHAR(100), -- DRESSAGE, JUMPING, WESTERN, etc.
    training_level VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (horse_hk, load_date)
);

-- Horse Health Satellite
CREATE TABLE equestrian.horse_health_s (
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    veterinarian_name VARCHAR(255),
    veterinarian_phone VARCHAR(50),
    last_vet_visit DATE,
    vaccination_status VARCHAR(100),
    vaccination_due_date DATE,
    coggins_test_date DATE,
    coggins_expiry_date DATE,
    health_notes TEXT,
    allergies TEXT,
    medications TEXT,
    special_needs TEXT,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (horse_hk, load_date)
);

-- Owner Hub
CREATE TABLE equestrian.owner_h (
    owner_hk BYTEA PRIMARY KEY,
    owner_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(owner_bk, tenant_hk)
);

-- Owner Details Satellite
CREATE TABLE equestrian.owner_details_s (
    owner_hk BYTEA NOT NULL REFERENCES equestrian.owner_h(owner_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    emergency_contact_name VARCHAR(255),
    emergency_contact_phone VARCHAR(50),
    address_street VARCHAR(255),
    address_city VARCHAR(100),
    address_state VARCHAR(50),
    address_zip VARCHAR(20),
    billing_same_as_address BOOLEAN DEFAULT true,
    billing_street VARCHAR(255),
    billing_city VARCHAR(100),
    billing_state VARCHAR(50),
    billing_zip VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (owner_hk, load_date)
);

-- Horse-Owner Link
CREATE TABLE equestrian.horse_owner_l (
    link_horse_owner_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    owner_hk BYTEA NOT NULL REFERENCES equestrian.owner_h(owner_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Horse-Owner Relationship Satellite
CREATE TABLE equestrian.horse_owner_relationship_s (
    link_horse_owner_hk BYTEA NOT NULL REFERENCES equestrian.horse_owner_l(link_horse_owner_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    ownership_type VARCHAR(100) NOT NULL, -- FULL_OWNER, PARTIAL_OWNER, LESSEE, AGENT
    ownership_percentage DECIMAL(5,2) DEFAULT 100.00,
    start_date DATE NOT NULL,
    end_date DATE,
    is_primary_contact BOOLEAN DEFAULT false,
    is_billing_contact BOOLEAN DEFAULT false,
    is_emergency_contact BOOLEAN DEFAULT false,
    notes TEXT,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (link_horse_owner_hk, load_date)
);

-- Stall Hub
CREATE TABLE equestrian.stall_h (
    stall_hk BYTEA PRIMARY KEY,
    stall_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(stall_bk, tenant_hk)
);

-- Stall Details Satellite
CREATE TABLE equestrian.stall_details_s (
    stall_hk BYTEA NOT NULL REFERENCES equestrian.stall_h(stall_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    stall_number VARCHAR(50) NOT NULL,
    barn_name VARCHAR(100),
    stall_size VARCHAR(50), -- 12x12, 12x14, etc.
    stall_type VARCHAR(50), -- STANDARD, FOALING, QUARANTINE
    has_run BOOLEAN DEFAULT false,
    run_size VARCHAR(50),
    monthly_rate DECIMAL(10,2),
    is_occupied BOOLEAN DEFAULT false,
    is_available BOOLEAN DEFAULT true,
    notes TEXT,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (stall_hk, load_date)
);

-- Horse-Stall Link (Boarding)
CREATE TABLE equestrian.horse_stall_l (
    link_horse_stall_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    stall_hk BYTEA NOT NULL REFERENCES equestrian.stall_h(stall_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Boarding Agreement Satellite
CREATE TABLE equestrian.boarding_agreement_s (
    link_horse_stall_hk BYTEA NOT NULL REFERENCES equestrian.horse_stall_l(link_horse_stall_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    monthly_rate DECIMAL(10,2) NOT NULL,
    services_included TEXT[],
    feed_type VARCHAR(100),
    feed_amount VARCHAR(100),
    turnout_schedule VARCHAR(255),
    special_instructions TEXT,
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (link_horse_stall_hk, load_date)
);

-- =====================================================
-- STEP 7: REFERENCE DATA
-- =====================================================

-- Horse Breeds Reference
CREATE TABLE ref.horse_breed_r (
    breed_code VARCHAR(10) PRIMARY KEY,
    breed_name VARCHAR(100) NOT NULL,
    breed_category VARCHAR(50), -- WARMBLOOD, THOROUGHBRED, QUARTER_HORSE, etc.
    origin_country VARCHAR(50),
    typical_height_min DECIMAL(4,2),
    typical_height_max DECIMAL(4,2),
    is_active BOOLEAN DEFAULT true,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Disciplines Reference
CREATE TABLE ref.discipline_r (
    discipline_code VARCHAR(20) PRIMARY KEY,
    discipline_name VARCHAR(100) NOT NULL,
    discipline_category VARCHAR(50), -- ENGLISH, WESTERN, DRIVING, etc.
    governing_body VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- =====================================================
-- STEP 8: AUDIT SCHEMA
-- =====================================================

-- Audit Event Hub
CREATE TABLE audit.audit_event_h (
    audit_event_hk BYTEA PRIMARY KEY,
    audit_event_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Audit Event Details Satellite
CREATE TABLE audit.audit_detail_s (
    audit_event_hk BYTEA NOT NULL REFERENCES audit.audit_event_h(audit_event_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    user_hk BYTEA REFERENCES auth.user_h(user_hk),
    event_type VARCHAR(100) NOT NULL, -- LOGIN, LOGOUT, CREATE, UPDATE, DELETE, VIEW
    table_name VARCHAR(100),
    record_id VARCHAR(255),
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(255),
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (audit_event_hk, load_date)
);

-- =====================================================
-- STEP 9: INDEXES FOR PERFORMANCE
-- =====================================================

-- Authentication indexes
CREATE INDEX idx_tenant_h_tenant_bk ON auth.tenant_h(tenant_bk);
CREATE INDEX idx_user_h_user_bk_tenant ON auth.user_h(user_bk, tenant_hk);
CREATE INDEX idx_user_profile_s_email ON auth.user_profile_s(email) WHERE load_end_date IS NULL;

-- Business indexes
CREATE INDEX idx_entity_h_entity_bk_tenant ON business.entity_h(entity_bk, tenant_hk);
CREATE INDEX idx_entity_details_s_name ON business.entity_details_s(entity_name) WHERE load_end_date IS NULL;

-- Equestrian indexes
CREATE INDEX idx_horse_h_horse_bk_tenant ON equestrian.horse_h(horse_bk, tenant_hk);
CREATE INDEX idx_horse_details_s_name ON equestrian.horse_details_s(registered_name) WHERE load_end_date IS NULL;
CREATE INDEX idx_horse_details_s_barn_name ON equestrian.horse_details_s(barn_name) WHERE load_end_date IS NULL;
CREATE INDEX idx_owner_h_owner_bk_tenant ON equestrian.owner_h(owner_bk, tenant_hk);
CREATE INDEX idx_stall_h_stall_bk_tenant ON equestrian.stall_h(stall_bk, tenant_hk);
CREATE INDEX idx_stall_details_s_number ON equestrian.stall_details_s(stall_number) WHERE load_end_date IS NULL;

-- Audit indexes
CREATE INDEX idx_audit_event_h_tenant ON audit.audit_event_h(tenant_hk);
CREATE INDEX idx_audit_detail_s_timestamp ON audit.audit_detail_s(event_timestamp) WHERE load_end_date IS NULL;
CREATE INDEX idx_audit_detail_s_user ON audit.audit_detail_s(user_hk) WHERE load_end_date IS NULL;

-- =====================================================
-- STEP 10: INITIAL DATA
-- =====================================================

-- Insert default tenant for Elite Equestrian
INSERT INTO auth.tenant_h (tenant_hk, tenant_bk) VALUES 
(util.hash_binary('ELITE_EQUESTRIAN_MANAGEMENT'), 'ELITE_EQUESTRIAN_MANAGEMENT');

INSERT INTO auth.tenant_profile_s (tenant_hk, hash_diff, tenant_name, tenant_type, domain_name, subdomain, max_users, features_enabled) VALUES 
(util.hash_binary('ELITE_EQUESTRIAN_MANAGEMENT'), 
 util.hash_binary('ELITE_EQUESTRIAN_MANAGEMENT_PROFILE'), 
 'Elite Equestrian Management', 
 'MANAGEMENT', 
 'management.eliteequestrian.com', 
 'management', 
 15, 
 ARRAY['horse_management', 'boarding_management', 'financial_reporting', 'staff_scheduling']);

-- Insert sample horse breeds
INSERT INTO ref.horse_breed_r (breed_code, breed_name, breed_category, origin_country, typical_height_min, typical_height_max) VALUES
('TB', 'Thoroughbred', 'HOTBLOOD', 'England', 15.2, 17.0),
('QH', 'Quarter Horse', 'STOCK', 'United States', 14.0, 16.0),
('WB', 'Warmblood', 'WARMBLOOD', 'Europe', 15.2, 17.2),
('ARAB', 'Arabian', 'HOTBLOOD', 'Arabian Peninsula', 14.1, 15.1),
('PAINT', 'Paint Horse', 'STOCK', 'United States', 14.0, 16.0);

-- Insert sample disciplines
INSERT INTO ref.discipline_r (discipline_code, discipline_name, discipline_category, governing_body) VALUES
('DRES', 'Dressage', 'ENGLISH', 'FEI'),
('JUMP', 'Show Jumping', 'ENGLISH', 'FEI'),
('EVEN', 'Eventing', 'ENGLISH', 'FEI'),
('HUNT', 'Hunter', 'ENGLISH', 'USEF'),
('WEST', 'Western Pleasure', 'WESTERN', 'AQHA'),
('REIN', 'Reining', 'WESTERN', 'NRHA');

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

-- Grant final permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO barn_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA business TO barn_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA equestrian TO barn_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA audit TO barn_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA util TO barn_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ref TO barn_user;

GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA util TO barn_user;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Elite Equestrian Center (one_barn) database created successfully!';
    RAISE NOTICE '📊 Database: one_barn_db';
    RAISE NOTICE '🏇 Industry: Equestrian Management';
    RAISE NOTICE '🏗️ Architecture: Data Vault 2.0';
    RAISE NOTICE '🔐 Tenant Isolation: Enabled';
    RAISE NOTICE '📈 Monthly Revenue: $7,398 ($6,999 base + $399 additional location)';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '1. Update .env with ONE_BARN_DATABASE_URL';
    RAISE NOTICE '2. Start FastAPI application';
    RAISE NOTICE '3. Test API endpoints with customer_id=one_barn';
    RAISE NOTICE '4. Configure frontend for Elite Equestrian branding';
END $$; 