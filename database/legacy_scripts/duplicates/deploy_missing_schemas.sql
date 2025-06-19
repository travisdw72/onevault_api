-- =====================================================
-- ONE BARN MISSING SCHEMAS DEPLOYMENT
-- Adds only the missing business schemas to existing one_barn_db
-- Uses existing auth, audit, util infrastructure
-- =====================================================

-- Connect to one_barn_db database

-- Start transaction for atomic deployment
BEGIN;

-- =====================================================
-- CREATE APPLICATION USER WITH LIMITED PERMISSIONS
-- =====================================================

-- Create barn_user for application access (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'barn_user') THEN
        CREATE USER barn_user WITH PASSWORD 'secure_barn_password_change_in_production';
        RAISE NOTICE 'Created barn_user';
    ELSE
        RAISE NOTICE 'barn_user already exists';
    END IF;
END $$;

-- =====================================================
-- CREATE MISSING SCHEMAS
-- =====================================================

-- Create equestrian schema (horse management)
CREATE SCHEMA IF NOT EXISTS equestrian;
COMMENT ON SCHEMA equestrian IS 'Equestrian-specific entities: horses, owners, stalls, boarding';

-- Create health schema (veterinary management)
CREATE SCHEMA IF NOT EXISTS health;
COMMENT ON SCHEMA health IS 'Health management: veterinary appointments, treatments, health documents';

-- Create finance schema (financial management)
CREATE SCHEMA IF NOT EXISTS finance;
COMMENT ON SCHEMA finance IS 'Financial management: invoicing, payments, transactions';

-- Create performance schema (training and competition tracking)
CREATE SCHEMA IF NOT EXISTS performance;
COMMENT ON SCHEMA performance IS 'Performance tracking: training sessions, competitions, goals';


-- =====================================================
-- GRANT APPROPRIATE PERMISSIONS TO BARN_USER
-- =====================================================

-- Grant schema usage permissions
GRANT USAGE ON SCHEMA auth TO barn_user;
GRANT USAGE ON SCHEMA audit TO barn_user;
GRANT USAGE ON SCHEMA util TO barn_user;
GRANT USAGE ON SCHEMA equestrian TO barn_user;
GRANT USAGE ON SCHEMA health TO barn_user;
GRANT USAGE ON SCHEMA finance TO barn_user;
GRANT USAGE ON SCHEMA performance TO barn_user;
GRANT USAGE ON SCHEMA business TO barn_user;
GRANT USAGE ON SCHEMA ref TO barn_user;

-- Grant specific table permissions (not ALL PRIVILEGES)
-- Auth schema - read access to tenant/user data, write to sessions
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO barn_user;
GRANT INSERT, UPDATE ON auth.session_h, auth.session_state_s TO barn_user;
GRANT INSERT, UPDATE ON auth.user_session_l TO barn_user;

-- Audit schema - insert only for logging
GRANT INSERT ON ALL TABLES IN SCHEMA audit TO barn_user;

-- Util schema - execute functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA util TO barn_user;

-- Business schemas - read/write access for application data (NO DELETE - use soft deletes)
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA equestrian TO barn_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA health TO barn_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA finance TO barn_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA performance TO barn_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA business TO barn_user;

-- Reference schema - read access only
GRANT SELECT ON ALL TABLES IN SCHEMA ref TO barn_user;

-- Grant permissions on future tables (NO DELETE - use soft deletes)
ALTER DEFAULT PRIVILEGES IN SCHEMA equestrian GRANT SELECT, INSERT, UPDATE ON TABLES TO barn_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA health GRANT SELECT, INSERT, UPDATE ON TABLES TO barn_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA finance GRANT SELECT, INSERT, UPDATE ON TABLES TO barn_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA performance GRANT SELECT, INSERT, UPDATE ON TABLES TO barn_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA business GRANT SELECT, INSERT, UPDATE ON TABLES TO barn_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA ref GRANT SELECT ON TABLES TO barn_user;

-- =====================================================
-- EQUESTRIAN SCHEMA TABLES
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
    registered_name VARCHAR(255),
    barn_name VARCHAR(255) NOT NULL,
    breed VARCHAR(100),
    color VARCHAR(100),
    markings TEXT,
    sex VARCHAR(20),
    date_of_birth DATE,
    height_hands DECIMAL(4,2),
    weight_pounds INTEGER,
    microchip_number VARCHAR(50),
    registration_number VARCHAR(100),
    passport_number VARCHAR(100),
    insurance_company VARCHAR(255),
    insurance_policy_number VARCHAR(100),
    insurance_value DECIMAL(15,2),
    purchase_price DECIMAL(15,2),
    purchase_date DATE,
    current_value DECIMAL(15,2),
    is_active BOOLEAN DEFAULT true,
    notes TEXT,
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
    mobile_phone VARCHAR(50),
    emergency_contact_name VARCHAR(255),
    emergency_contact_phone VARCHAR(50),
    address_street VARCHAR(255),
    address_city VARCHAR(100),
    address_state VARCHAR(50),
    address_zip VARCHAR(20),
    billing_same_as_address BOOLEAN DEFAULT true,
    billing_address_street VARCHAR(255),
    billing_address_city VARCHAR(100),
    billing_address_state VARCHAR(50),
    billing_address_zip VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    notes TEXT,
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

-- Ownership Details Satellite
CREATE TABLE equestrian.ownership_details_s (
    link_horse_owner_hk BYTEA NOT NULL REFERENCES equestrian.horse_owner_l(link_horse_owner_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    ownership_type VARCHAR(50) NOT NULL DEFAULT 'FULL', -- FULL, PARTIAL, LEASE, CARE
    ownership_percentage DECIMAL(5,2) DEFAULT 100.00,
    start_date DATE NOT NULL,
    end_date DATE,
    is_primary_contact BOOLEAN DEFAULT false,
    is_emergency_contact BOOLEAN DEFAULT false,
    can_authorize_vet_care BOOLEAN DEFAULT false,
    can_authorize_training BOOLEAN DEFAULT false,
    billing_responsibility BOOLEAN DEFAULT false,
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
    barn_section VARCHAR(100),
    stall_type VARCHAR(50), -- STANDARD, FOALING, QUARANTINE, PADDOCK
    size_length_feet DECIMAL(5,2),
    size_width_feet DECIMAL(5,2),
    has_automatic_waterer BOOLEAN DEFAULT false,
    has_feed_door BOOLEAN DEFAULT false,
    has_window BOOLEAN DEFAULT false,
    has_fan BOOLEAN DEFAULT false,
    has_camera BOOLEAN DEFAULT false,
    monthly_rate DECIMAL(10,2),
    is_available BOOLEAN DEFAULT true,
    notes TEXT,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (stall_hk, load_date)
);

-- Horse-Stall Link (Current boarding assignment)
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
    agreement_start_date DATE NOT NULL,
    agreement_end_date DATE,
    monthly_rate DECIMAL(10,2) NOT NULL,
    feed_included BOOLEAN DEFAULT true,
    bedding_included BOOLEAN DEFAULT true,
    turnout_included BOOLEAN DEFAULT true,
    care_level VARCHAR(50) DEFAULT 'STANDARD', -- BASIC, STANDARD, PREMIUM, FULL_CARE
    billing_cycle VARCHAR(20) DEFAULT 'MONTHLY', -- MONTHLY, QUARTERLY, ANNUAL
    payment_due_day INTEGER DEFAULT 1,
    late_fee_amount DECIMAL(10,2) DEFAULT 25.00,
    deposit_amount DECIMAL(10,2),
    special_instructions TEXT,
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (link_horse_stall_hk, load_date)
);

-- =====================================================
-- BASIC REFERENCE DATA
-- =====================================================

-- Horse Breeds Reference
CREATE TABLE ref.horse_breed_r (
    breed_code VARCHAR(20) PRIMARY KEY,
    breed_name VARCHAR(100) NOT NULL,
    breed_category VARCHAR(50), -- WARMBLOOD, THOROUGHBRED, QUARTER_HORSE, etc.
    origin_country VARCHAR(50),
    typical_height_min DECIMAL(4,2),
    typical_height_max DECIMAL(4,2),
    common_disciplines TEXT[],
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Horse Colors Reference
CREATE TABLE ref.horse_color_r (
    color_code VARCHAR(20) PRIMARY KEY,
    color_name VARCHAR(100) NOT NULL,
    color_description TEXT,
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
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- =====================================================
-- CREATE ESSENTIAL INDEXES
-- =====================================================

-- Equestrian schema indexes
CREATE INDEX idx_horse_h_horse_bk_tenant ON equestrian.horse_h(horse_bk, tenant_hk);
CREATE INDEX idx_horse_details_s_barn_name ON equestrian.horse_details_s(barn_name) WHERE load_end_date IS NULL;
CREATE INDEX idx_horse_details_s_active ON equestrian.horse_details_s(is_active) WHERE load_end_date IS NULL;

CREATE INDEX idx_owner_h_owner_bk_tenant ON equestrian.owner_h(owner_bk, tenant_hk);
CREATE INDEX idx_owner_details_s_name ON equestrian.owner_details_s(last_name, first_name) WHERE load_end_date IS NULL;
CREATE INDEX idx_owner_details_s_email ON equestrian.owner_details_s(email) WHERE load_end_date IS NULL;

CREATE INDEX idx_stall_h_stall_bk_tenant ON equestrian.stall_h(stall_bk, tenant_hk);
CREATE INDEX idx_stall_details_s_number ON equestrian.stall_details_s(stall_number) WHERE load_end_date IS NULL;
CREATE INDEX idx_stall_details_s_available ON equestrian.stall_details_s(is_available) WHERE load_end_date IS NULL;

-- Link table indexes
CREATE INDEX idx_horse_owner_l_horse ON equestrian.horse_owner_l(horse_hk);
CREATE INDEX idx_horse_owner_l_owner ON equestrian.horse_owner_l(owner_hk);
CREATE INDEX idx_horse_stall_l_horse ON equestrian.horse_stall_l(horse_hk);
CREATE INDEX idx_horse_stall_l_stall ON equestrian.horse_stall_l(stall_hk);

-- =====================================================
-- INSERT INITIAL REFERENCE DATA
-- =====================================================

-- Insert common horse breeds
INSERT INTO ref.horse_breed_r (breed_code, breed_name, breed_category, origin_country, typical_height_min, typical_height_max, common_disciplines) VALUES
('TB', 'Thoroughbred', 'HOT_BLOOD', 'England', 15.2, 17.0, ARRAY['Racing', 'Eventing', 'Show Jumping']),
('WB', 'Warmblood', 'WARMBLOOD', 'Europe', 15.3, 17.2, ARRAY['Dressage', 'Show Jumping', 'Eventing']),
('QH', 'Quarter Horse', 'STOCK_HORSE', 'United States', 14.3, 16.0, ARRAY['Western Pleasure', 'Reining', 'Cutting']),
('ARAB', 'Arabian', 'HOT_BLOOD', 'Arabian Peninsula', 14.1, 15.3, ARRAY['Endurance', 'Dressage', 'Show']),
('PAINT', 'Paint Horse', 'STOCK_HORSE', 'United States', 14.3, 16.0, ARRAY['Western Pleasure', 'Trail', 'Ranch Work']);

-- Insert common horse colors
INSERT INTO ref.horse_color_r (color_code, color_name, color_description) VALUES
('BAY', 'Bay', 'Brown body with black mane and tail'),
('CHEST', 'Chestnut', 'Reddish-brown body, mane, and tail'),
('BLACK', 'Black', 'Black body, mane, and tail'),
('GRAY', 'Gray', 'Mixed black and white hairs'),
('BROWN', 'Brown', 'Dark brown body with brown or black mane and tail'),
('PINTO', 'Pinto', 'Large patches of white and another color'),
('PALOM', 'Palomino', 'Golden body with white or light mane and tail');

-- Insert common disciplines
INSERT INTO ref.discipline_r (discipline_code, discipline_name, discipline_category, governing_body) VALUES
('DRES', 'Dressage', 'ENGLISH', 'USEF'),
('JUMP', 'Show Jumping', 'ENGLISH', 'USEF'),
('EVENT', 'Eventing', 'ENGLISH', 'USEF'),
('HUNT', 'Hunter', 'ENGLISH', 'USEF'),
('WP', 'Western Pleasure', 'WESTERN', 'AQHA'),
('REIN', 'Reining', 'WESTERN', 'NRHA'),
('TRAIL', 'Trail', 'WESTERN', 'AQHA');

-- =====================================================
-- GRANT PERMISSIONS ON NEW TABLES
-- =====================================================

-- Grant permissions to barn_user on all new tables (NO DELETE - use soft deletes)
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA equestrian TO barn_user;
GRANT SELECT ON ALL TABLES IN SCHEMA ref TO barn_user;

-- =====================================================
-- LOG DEPLOYMENT SUCCESS
-- =====================================================

-- Create deployment log table if it doesn't exist
CREATE TABLE IF NOT EXISTS util.deployment_log (
    deployment_id SERIAL PRIMARY KEY,
    deployment_name VARCHAR(255) NOT NULL,
    deployment_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deployment_notes TEXT,
    rollback_script TEXT,
    deployed_by VARCHAR(100) DEFAULT SESSION_USER
);

-- Insert deployment log entry
INSERT INTO util.deployment_log (deployment_name, deployment_notes, rollback_script) 
VALUES (
    'Missing Schemas Deployment v1.0',
    'Successfully deployed equestrian schema with basic reference data. Health, finance, and performance schemas created but tables will be added separately.',
    'DROP SCHEMA IF EXISTS equestrian CASCADE; DROP SCHEMA IF EXISTS health CASCADE; DROP SCHEMA IF EXISTS finance CASCADE; DROP SCHEMA IF EXISTS performance CASCADE; DROP USER IF EXISTS barn_user;'
);

-- Commit the transaction
COMMIT;

-- Final success message
SELECT 
    'DEPLOYMENT SUCCESSFUL!' as status,
    'Equestrian schema deployed with reference data' as message,
    'Health, Finance, Performance schemas created (tables to be added)' as next_steps,
    CURRENT_TIMESTAMP as completed_at,
    SESSION_USER as deployed_by;

-- Display schema summary
SELECT 
    schemaname,
    COUNT(*) as table_count
FROM pg_tables 
WHERE schemaname IN ('equestrian', 'health', 'finance', 'performance', 'ref')
GROUP BY schemaname
ORDER BY schemaname; 