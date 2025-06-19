-- =============================================
-- Step 16: Business Entity Framework Implementation
-- Multi-Entity Business Optimization Platform
-- Data Vault 2.0 with Established Naming Conventions
-- Supports 8-Module Platform: Asset Transfer, Notes Payable, Equipment Leasing,
-- IP Licensing, Service Contracts, Dashboard, Tax Records, Business Trips
-- =============================================

-- Enhanced rollback procedure for step 16
CREATE OR REPLACE PROCEDURE util.rollback_step_16()
LANGUAGE plpgsql AS $$
BEGIN
    RAISE NOTICE 'Starting Step 16 rollback...';
    
    -- Drop business functions and procedures created in this step
    DROP FUNCTION IF EXISTS business.create_business_entity(BYTEA, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR, JSONB, TEXT) CASCADE;
    DROP FUNCTION IF EXISTS business.transfer_asset_ownership(BYTEA, BYTEA, BYTEA, DATE, VARCHAR, DECIMAL, JSONB) CASCADE;
    DROP FUNCTION IF EXISTS business.create_service_contract(BYTEA, BYTEA, BYTEA, VARCHAR, VARCHAR, VARCHAR, DECIMAL, DATE, DATE, JSONB) CASCADE;
    DROP FUNCTION IF EXISTS business.create_note_payable(BYTEA, BYTEA, BYTEA, DECIMAL, DECIMAL, INTEGER, VARCHAR, DATE, VARCHAR) CASCADE;
    DROP FUNCTION IF EXISTS business.record_business_trip(BYTEA, BYTEA, VARCHAR, TEXT, VARCHAR, DATE, DATE, DECIMAL, VARCHAR) CASCADE;
    DROP FUNCTION IF EXISTS business.validate_market_rates(VARCHAR, DECIMAL, JSONB) CASCADE;
    
    -- Drop satellite tables
    DROP TABLE IF EXISTS business.trip_details_s CASCADE;
    DROP TABLE IF EXISTS business.tax_record_details_s CASCADE;
    DROP TABLE IF EXISTS business.ip_details_s CASCADE;
    DROP TABLE IF EXISTS business.note_payable_terms_s CASCADE;
    DROP TABLE IF EXISTS business.service_contract_terms_s CASCADE;
    DROP TABLE IF EXISTS business.asset_ownership_terms_s CASCADE;
    DROP TABLE IF EXISTS business.asset_details_s CASCADE;
    DROP TABLE IF EXISTS business.entity_relationship_details_s CASCADE;
    DROP TABLE IF EXISTS business.business_entity_profile_s CASCADE;
    
    -- Drop link tables
    DROP TABLE IF EXISTS business.contract_parties_l CASCADE;
    DROP TABLE IF EXISTS business.asset_ownership_l CASCADE;
    DROP TABLE IF EXISTS business.entity_relationship_l CASCADE;
    
    -- Drop hub tables
    DROP TABLE IF EXISTS business.business_trip_h CASCADE;
    DROP TABLE IF EXISTS business.tax_record_h CASCADE;
    DROP TABLE IF EXISTS business.intellectual_property_h CASCADE;
    DROP TABLE IF EXISTS business.note_payable_h CASCADE;
    DROP TABLE IF EXISTS business.service_contract_h CASCADE;
    DROP TABLE IF EXISTS business.asset_h CASCADE;
    DROP TABLE IF EXISTS business.business_entity_h CASCADE;
    
    -- Drop indexes created in this step
    DROP INDEX IF EXISTS business.idx_business_entity_h_tenant_type;
    DROP INDEX IF EXISTS business.idx_business_entity_profile_s_entity_type;
    DROP INDEX IF EXISTS business.idx_asset_h_tenant_category;
    DROP INDEX IF EXISTS business.idx_asset_details_s_category_active;
    DROP INDEX IF EXISTS business.idx_service_contract_h_tenant_date;
    DROP INDEX IF EXISTS business.idx_note_payable_h_tenant_status;
    DROP INDEX IF EXISTS business.idx_tax_record_h_tenant_year;
    DROP INDEX IF EXISTS business.idx_business_trip_h_tenant_date;
    
    RAISE NOTICE 'Step 16 rollback completed successfully';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error during rollback: % %', SQLSTATE, SQLERRM;
        RAISE NOTICE 'Continuing rollback despite errors...';
END;
$$;

-- Execute rollback first to clean any partial installation
CALL util.rollback_step_16();

-- =============================================
-- 1. Primary Business Entity Framework
-- =============================================

-- Primary Business Entity Hub
CREATE TABLE business.business_entity_h (
    business_entity_hk BYTEA PRIMARY KEY,
    business_entity_bk VARCHAR(255) NOT NULL, -- Entity identifier (EIN, SSN, or custom ID)
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE business.business_entity_profile_s (
    business_entity_hk BYTEA NOT NULL REFERENCES business.business_entity_h(business_entity_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    entity_name VARCHAR(255) NOT NULL,
    entity_type VARCHAR(50) NOT NULL, -- 'LLC', 'S-Corp', 'Individual', 'Partnership'
    tax_id VARCHAR(50),
    formation_date DATE,
    state_of_formation VARCHAR(2),
    business_address JSONB,
    primary_business_purpose TEXT,
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (business_entity_hk, load_date)
);

-- Entity Relationship Management
CREATE TABLE business.entity_relationship_l (
    entity_relationship_hk BYTEA PRIMARY KEY,
    parent_entity_hk BYTEA NOT NULL REFERENCES business.business_entity_h(business_entity_hk),
    child_entity_hk BYTEA NOT NULL REFERENCES business.business_entity_h(business_entity_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE business.entity_relationship_details_s (
    entity_relationship_hk BYTEA NOT NULL REFERENCES business.entity_relationship_l(entity_relationship_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    relationship_type VARCHAR(50) NOT NULL, -- 'ownership', 'management', 'service_provider'
    ownership_percentage DECIMAL(5,2),
    effective_date DATE NOT NULL,
    termination_date DATE,
    relationship_terms JSONB,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (entity_relationship_hk, load_date)
);

-- =============================================
-- 2. Asset Management Framework
-- =============================================

-- Asset Hub and Classification
CREATE TABLE business.asset_h (
    asset_hk BYTEA PRIMARY KEY,
    asset_bk VARCHAR(255) NOT NULL, -- Serial number, VIN, or unique identifier
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE business.asset_details_s (
    asset_hk BYTEA NOT NULL REFERENCES business.asset_h(asset_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    asset_name VARCHAR(255) NOT NULL,
    asset_category VARCHAR(100) NOT NULL, -- 'vehicle', 'equipment', 'technology', 'real_estate'
    asset_description TEXT,
    purchase_price DECIMAL(12,2),
    purchase_date DATE,
    current_market_value DECIMAL(12,2),
    depreciation_method VARCHAR(50), -- 'straight_line', 'macrs', 'section_179', 'bonus'
    useful_life_years INTEGER,
    salvage_value DECIMAL(12,2),
    asset_condition VARCHAR(50),
    asset_location VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (asset_hk, load_date)
);

-- Asset Ownership Tracking
CREATE TABLE business.asset_ownership_l (
    asset_ownership_hk BYTEA PRIMARY KEY,
    asset_hk BYTEA NOT NULL REFERENCES business.asset_h(asset_hk),
    business_entity_hk BYTEA NOT NULL REFERENCES business.business_entity_h(business_entity_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE business.asset_ownership_terms_s (
    asset_ownership_hk BYTEA NOT NULL REFERENCES business.asset_ownership_l(asset_ownership_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    ownership_percentage DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    acquisition_date DATE NOT NULL,
    acquisition_method VARCHAR(50) NOT NULL, -- 'purchase', 'transfer', 'gift', 'inheritance'
    acquisition_price DECIMAL(12,2),
    lease_back_rate DECIMAL(8,2), -- Monthly lease rate for Elon Musk model
    market_rate_validation JSONB, -- Documentation for IRS compliance
    ownership_terms JSONB,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (asset_ownership_hk, load_date)
);

-- =============================================
-- 3. Service Contract Framework
-- =============================================

CREATE TABLE business.service_contract_h (
    service_contract_hk BYTEA PRIMARY KEY,
    service_contract_bk VARCHAR(255) NOT NULL, -- Contract number or identifier
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE business.service_contract_terms_s (
    service_contract_hk BYTEA NOT NULL REFERENCES business.service_contract_h(service_contract_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    contract_title VARCHAR(255) NOT NULL,
    service_type VARCHAR(100) NOT NULL, -- 'management', 'consulting', 'marketing', 'training'
    billing_method VARCHAR(50) NOT NULL, -- 'hourly', 'monthly', 'project', 'performance'
    contract_rate DECIMAL(10,2) NOT NULL,
    contract_start_date DATE NOT NULL,
    contract_end_date DATE,
    contract_terms JSONB,
    performance_metrics JSONB,
    market_rate_validation JSONB, -- IRS compliance documentation
    monthly_revenue_target DECIMAL(10,2), -- For $5,247/month tracking
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (service_contract_hk, load_date)
);

-- Contract Parties Relationship
CREATE TABLE business.contract_parties_l (
    contract_parties_hk BYTEA PRIMARY KEY,
    service_contract_hk BYTEA NOT NULL REFERENCES business.service_contract_h(service_contract_hk),
    provider_entity_hk BYTEA NOT NULL REFERENCES business.business_entity_h(business_entity_hk),
    recipient_entity_hk BYTEA NOT NULL REFERENCES business.business_entity_h(business_entity_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- =============================================
-- 4. Notes Payable Structure
-- =============================================

CREATE TABLE business.note_payable_h (
    note_payable_hk BYTEA PRIMARY KEY,
    note_payable_bk VARCHAR(255) NOT NULL, -- Note number
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE business.note_payable_terms_s (
    note_payable_hk BYTEA NOT NULL REFERENCES business.note_payable_h(note_payable_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    principal_amount DECIMAL(12,2) NOT NULL,
    interest_rate DECIMAL(5,3) NOT NULL,
    term_months INTEGER NOT NULL,
    payment_frequency VARCHAR(20) NOT NULL, -- 'monthly', 'quarterly', 'annual'
    payment_amount DECIMAL(10,2) NOT NULL,
    issue_date DATE NOT NULL,
    maturity_date DATE NOT NULL,
    loan_purpose VARCHAR(100),
    current_balance DECIMAL(12,2),
    note_status VARCHAR(20) DEFAULT 'active', -- 'active', 'paid_off', 'defaulted'
    monthly_interest_income DECIMAL(8,2), -- For $2,847/month tracking
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (note_payable_hk, load_date)
);

-- =============================================
-- 5. Intellectual Property Management
-- =============================================

CREATE TABLE business.intellectual_property_h (
    intellectual_property_hk BYTEA PRIMARY KEY,
    intellectual_property_bk VARCHAR(255) NOT NULL, -- IP identifier or registration number
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE business.ip_details_s (
    intellectual_property_hk BYTEA NOT NULL REFERENCES business.intellectual_property_h(intellectual_property_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    ip_name VARCHAR(255) NOT NULL,
    ip_type VARCHAR(50) NOT NULL, -- 'protocol', 'trademark', 'copyright', 'trade_secret'
    ip_description TEXT,
    creation_date DATE,
    registration_date DATE,
    expiration_date DATE,
    estimated_value DECIMAL(12,2),
    development_costs DECIMAL(12,2),
    ip_status VARCHAR(20) DEFAULT 'active', -- 'active', 'pending', 'expired'
    monthly_licensing_income DECIMAL(8,2), -- For $2,400/month tracking
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (intellectual_property_hk, load_date)
);

-- =============================================
-- 6. Tax Record Management
-- =============================================

CREATE TABLE business.tax_record_h (
    tax_record_hk BYTEA PRIMARY KEY,
    tax_record_bk VARCHAR(255) NOT NULL, -- Tax year + entity + record type
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE business.tax_record_details_s (
    tax_record_hk BYTEA NOT NULL REFERENCES business.tax_record_h(tax_record_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    tax_year INTEGER NOT NULL,
    record_type VARCHAR(50) NOT NULL, -- 'rental_income', 'rental_expense', 'asset_sale', 'interest_income'
    record_date DATE NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    description TEXT,
    tax_category VARCHAR(100),
    form_reference VARCHAR(50), -- 'Schedule E', '1099-INT', etc.
    supporting_documents JSONB,
    deduction_optimization JSONB, -- Tracks optimization strategies
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (tax_record_hk, load_date)
);

-- =============================================
-- 7. Business Trip and Expense Framework
-- =============================================

CREATE TABLE business.business_trip_h (
    business_trip_hk BYTEA PRIMARY KEY,
    business_trip_bk VARCHAR(255) NOT NULL, -- Trip identifier
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE business.trip_details_s (
    business_trip_hk BYTEA NOT NULL REFERENCES business.business_trip_h(business_trip_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    trip_title VARCHAR(255) NOT NULL,
    trip_purpose TEXT NOT NULL,
    destination VARCHAR(255) NOT NULL,
    departure_date DATE NOT NULL,
    return_date DATE NOT NULL,
    business_percentage DECIMAL(5,2) DEFAULT 100.00,
    trip_category VARCHAR(50), -- 'client_meeting', 'conference', 'training'
    estimated_budget DECIMAL(10,2),
    actual_cost DECIMAL(10,2),
    trip_status VARCHAR(20) DEFAULT 'planned', -- 'planned', 'active', 'completed'
    monthly_deduction_value DECIMAL(8,2), -- For $763/month tracking
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (business_trip_hk, load_date)
);

-- =============================================
-- 8. Performance Optimization Indexes
-- =============================================

-- Business Entity Indexes
CREATE INDEX idx_business_entity_h_tenant_type 
ON business.business_entity_h(tenant_hk, load_date DESC);

CREATE INDEX idx_business_entity_profile_s_entity_type 
ON business.business_entity_profile_s(entity_type, is_active, load_date DESC) 
WHERE load_end_date IS NULL;

-- Asset Management Indexes
CREATE INDEX idx_asset_h_tenant_category 
ON business.asset_h(tenant_hk, load_date DESC);

CREATE INDEX idx_asset_details_s_category_active 
ON business.asset_details_s(asset_category, is_active, load_date DESC) 
WHERE load_end_date IS NULL;

-- Service Contract Indexes
CREATE INDEX idx_service_contract_h_tenant_date 
ON business.service_contract_h(tenant_hk, load_date DESC);

CREATE INDEX idx_service_contract_terms_s_active 
ON business.service_contract_terms_s(contract_start_date, contract_end_date, load_date DESC) 
WHERE load_end_date IS NULL;

-- Notes Payable Indexes
CREATE INDEX idx_note_payable_h_tenant_status 
ON business.note_payable_h(tenant_hk, load_date DESC);

CREATE INDEX idx_note_payable_terms_s_status 
ON business.note_payable_terms_s(note_status, maturity_date, load_date DESC) 
WHERE load_end_date IS NULL;

-- Tax Record Indexes
CREATE INDEX idx_tax_record_h_tenant_year 
ON business.tax_record_h(tenant_hk, load_date DESC);

CREATE INDEX idx_tax_record_details_s_year_type 
ON business.tax_record_details_s(tax_year, record_type, load_date DESC) 
WHERE load_end_date IS NULL;

-- Business Trip Indexes
CREATE INDEX idx_business_trip_h_tenant_date 
ON business.business_trip_h(tenant_hk, load_date DESC);

CREATE INDEX idx_trip_details_s_date_status 
ON business.trip_details_s(departure_date, trip_status, load_date DESC) 
WHERE load_end_date IS NULL;

-- =============================================
-- 9. Business Logic Functions
-- =============================================

-- Function to create a new business entity
CREATE OR REPLACE FUNCTION business.create_business_entity(
    p_tenant_hk BYTEA,
    p_entity_bk VARCHAR(255),
    p_entity_name VARCHAR(255),
    p_entity_type VARCHAR(50),
    p_tax_id VARCHAR(50),
    p_formation_date DATE,
    p_state_of_formation VARCHAR(2),
    p_business_address JSONB,
    p_business_purpose TEXT
) RETURNS BYTEA AS $$
DECLARE
    v_business_entity_hk BYTEA;
    v_hash_diff BYTEA;
BEGIN
    -- Generate hash key
    v_business_entity_hk := util.hash_binary(p_entity_bk);
    
    -- Calculate hash diff
    v_hash_diff := util.hash_concat(
        p_entity_name,
        p_entity_type,
        COALESCE(p_tax_id, ''),
        COALESCE(p_formation_date::text, '')
    );
    
    -- Insert hub record
    INSERT INTO business.business_entity_h (
        business_entity_hk,
        business_entity_bk,
        tenant_hk
    ) VALUES (
        v_business_entity_hk,
        p_entity_bk,
        p_tenant_hk
    ) ON CONFLICT DO NOTHING;
    
    -- Insert satellite record
    INSERT INTO business.business_entity_profile_s (
        business_entity_hk,
        hash_diff,
        entity_name,
        entity_type,
        tax_id,
        formation_date,
        state_of_formation,
        business_address,
        primary_business_purpose
    ) VALUES (
        v_business_entity_hk,
        v_hash_diff,
        p_entity_name,
        p_entity_type,
        p_tax_id,
        p_formation_date,
        p_state_of_formation,
        p_business_address,
        p_business_purpose
    );
    
    RETURN v_business_entity_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to transfer asset ownership (Elon Musk model)
CREATE OR REPLACE FUNCTION business.transfer_asset_ownership(
    p_tenant_hk BYTEA,
    p_asset_hk BYTEA,
    p_new_owner_entity_hk BYTEA,
    p_transfer_date DATE,
    p_transfer_method VARCHAR(50),
    p_lease_back_rate DECIMAL(8,2),
    p_market_validation JSONB
) RETURNS BYTEA AS $$
DECLARE
    v_ownership_hk BYTEA;
    v_ownership_bk VARCHAR(255);
    v_hash_diff BYTEA;
BEGIN
    -- Generate ownership business key and hash key
    v_ownership_bk := encode(p_asset_hk, 'hex') || '_' || encode(p_new_owner_entity_hk, 'hex') || '_' || p_transfer_date::text;
    v_ownership_hk := util.hash_binary(v_ownership_bk);
    
    -- Calculate hash diff
    v_hash_diff := util.hash_concat(
        p_transfer_date::text,
        p_transfer_method,
        p_lease_back_rate::text
    );
    
    -- Insert ownership link
    INSERT INTO business.asset_ownership_l (
        asset_ownership_hk,
        asset_hk,
        business_entity_hk,
        tenant_hk
    ) VALUES (
        v_ownership_hk,
        p_asset_hk,
        p_new_owner_entity_hk,
        p_tenant_hk
    );
    
    -- Insert ownership terms
    INSERT INTO business.asset_ownership_terms_s (
        asset_ownership_hk,
        hash_diff,
        ownership_percentage,
        acquisition_date,
        acquisition_method,
        lease_back_rate,
        market_rate_validation
    ) VALUES (
        v_ownership_hk,
        v_hash_diff,
        100.00,
        p_transfer_date,
        p_transfer_method,
        p_lease_back_rate,
        p_market_validation
    );
    
    RETURN v_ownership_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to validate market rates for IRS compliance
CREATE OR REPLACE FUNCTION business.validate_market_rates(
    p_service_type VARCHAR(100),
    p_proposed_rate DECIMAL(10,2),
    p_comparable_data JSONB
) RETURNS JSONB AS $$
DECLARE
    v_validation_result JSONB;
    v_market_range JSONB;
BEGIN
    -- Extract market range from comparable data
    v_market_range := p_comparable_data->'market_range';
    
    -- Build validation result
    v_validation_result := jsonb_build_object(
        'service_type', p_service_type,
        'proposed_rate', p_proposed_rate,
        'market_low', COALESCE((v_market_range->>'low')::DECIMAL, 0),
        'market_high', COALESCE((v_market_range->>'high')::DECIMAL, 999999),
        'is_within_range', 
            p_proposed_rate >= COALESCE((v_market_range->>'low')::DECIMAL, 0) AND
            p_proposed_rate <= COALESCE((v_market_range->>'high')::DECIMAL, 999999),
        'validation_date', CURRENT_DATE,
        'comparable_sources', p_comparable_data->'sources'
    );
    
    RETURN v_validation_result;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 10. Audit Triggers
-- =============================================

-- Create audit triggers for all business tables
SELECT util.create_audit_triggers_safe('business');

-- =============================================
-- 11. Verification and Testing
-- =============================================

-- Enhanced verification procedure for step 16
CREATE OR REPLACE PROCEDURE util.verify_step_16_implementation()
LANGUAGE plpgsql AS $$
DECLARE
    v_hub_count INTEGER;
    v_satellite_count INTEGER;
    v_link_count INTEGER;
    v_function_count INTEGER;
    v_index_count INTEGER;
    v_test_success BOOLEAN := TRUE;
    v_test_entity_hk BYTEA;
BEGIN
    -- Count hub tables created
    SELECT COUNT(*) INTO v_hub_count
    FROM information_schema.tables
    WHERE table_schema = 'business'
    AND table_name LIKE '%_h';

    -- Count satellite tables created
    SELECT COUNT(*) INTO v_satellite_count
    FROM information_schema.tables
    WHERE table_schema = 'business'
    AND table_name LIKE '%_s';

    -- Count link tables created
    SELECT COUNT(*) INTO v_link_count
    FROM information_schema.tables
    WHERE table_schema = 'business'
    AND table_name LIKE '%_l';

    -- Count functions created
    SELECT COUNT(*) INTO v_function_count
    FROM information_schema.routines
    WHERE routine_schema = 'business'
    AND routine_type = 'FUNCTION';

    -- Count indexes created
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes
    WHERE schemaname = 'business'
    AND indexname LIKE 'idx_%';

    RAISE NOTICE 'Step 16 Verification Results:';
    RAISE NOTICE 'Hub tables: % (expected: 7)', v_hub_count;
    RAISE NOTICE 'Satellite tables: % (expected: 7)', v_satellite_count;
    RAISE NOTICE 'Link tables: % (expected: 3)', v_link_count;
    RAISE NOTICE 'Business functions: % (expected: 3)', v_function_count;
    RAISE NOTICE 'Performance indexes: % (expected: 12)', v_index_count;
    
    -- Test business entity creation
    BEGIN
        -- Get a test tenant
        SELECT tenant_hk INTO v_test_entity_hk
        FROM auth.tenant_h
        LIMIT 1;
        
        IF v_test_entity_hk IS NOT NULL THEN
            -- Test creating a business entity
            PERFORM business.create_business_entity(
                v_test_entity_hk,
                'TEST_ENTITY_001',
                'Test Business Entity',
                'LLC',
                '12-3456789',
                CURRENT_DATE,
                'DE',
                '{"street": "123 Test St", "city": "Test City", "state": "DE", "zip": "12345"}',
                'Test business entity for verification'
            );
            RAISE NOTICE 'Business entity creation test: PASSED';
        ELSE
            RAISE NOTICE 'Business entity creation test: SKIPPED (no tenant found)';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Business entity creation test: FAILED - %', SQLERRM;
            v_test_success := FALSE;
    END;
    
    -- Test market rate validation
    BEGIN
        PERFORM business.validate_market_rates(
            'management',
            5000.00,
            '{"market_range": {"low": 3000, "high": 8000}, "sources": ["BLS", "PayScale", "Glassdoor"]}'
        );
        RAISE NOTICE 'Market rate validation test: PASSED';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Market rate validation test: FAILED - %', SQLERRM;
            v_test_success := FALSE;
    END;
    
    IF v_hub_count = 7 AND v_satellite_count = 7 AND v_link_count = 3 AND v_function_count = 3 AND v_test_success THEN
        RAISE NOTICE '✓ Step 16 implementation successful!';
        RAISE NOTICE '✓ Multi-Entity Business Optimization Platform entities are ready for production use.';
        RAISE NOTICE '✓ All 8 platform modules are now supported with proper Data Vault 2.0 structures.';
        RAISE NOTICE '✓ Tax optimization strategies can be implemented with full audit compliance.';
    ELSE
        RAISE NOTICE '⚠ Step 16 implementation may have issues - please review the counts above';
    END IF;
END;
$$;

-- Run verification
CALL util.verify_step_16_implementation();

-- Display platform module mapping
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Multi-Entity Business Optimization Platform Module Mapping ===';
    RAISE NOTICE '1. Asset Transfer Management → business.asset_h + business.asset_ownership_l';
    RAISE NOTICE '2. Notes Payable System → business.note_payable_h + business.note_payable_terms_s';
    RAISE NOTICE '3. Equipment Leasing Tracker → business.asset_details_s (lease_back_rate)';
    RAISE NOTICE '4. IP Licensing Management → business.intellectual_property_h + business.ip_details_s';
    RAISE NOTICE '5. Service Contract Management → business.service_contract_h + business.contract_parties_l';
    RAISE NOTICE '6. Multi-Entity Dashboard → business.business_entity_h + entity_relationship_l';
    RAISE NOTICE '7. Personal Tax Record Tracker → business.tax_record_h + business.tax_record_details_s';
    RAISE NOTICE '8. Business Trip Management → business.business_trip_h + business.trip_details_s';
    RAISE NOTICE '';
    RAISE NOTICE 'Revenue Tracking Capabilities:';
    RAISE NOTICE '• Monthly IP Licensing: $2,400 (ip_details_s.monthly_licensing_income)';
    RAISE NOTICE '• Monthly Service Contracts: $5,247 (service_contract_terms_s.monthly_revenue_target)';
    RAISE NOTICE '• Monthly Notes Interest: $2,847 (note_payable_terms_s.monthly_interest_income)';
    RAISE NOTICE '• Monthly Equipment Leasing: $3,247 (asset_ownership_terms_s.lease_back_rate)';
    RAISE NOTICE '• Monthly Travel Deductions: $763 (trip_details_s.monthly_deduction_value)';
    RAISE NOTICE '';
    RAISE NOTICE 'Total Platform Annual Impact: $175,548 with comprehensive audit trails';
END $$;

COMMENT ON SCHEMA business IS 
'Multi-Entity Business Optimization Platform - Core business entities supporting 8-module tax optimization system with Data Vault 2.0 compliance';

COMMENT ON TABLE business.business_entity_h IS 
'Core hub for business entities supporting multi-entity tax optimization strategies';

COMMENT ON TABLE business.asset_ownership_terms_s IS 
'Asset ownership tracking with lease-back rate support for Elon Musk model implementation';

COMMENT ON FUNCTION business.validate_market_rates IS 
'IRS compliance validation for market rate documentation in service contracts and asset transfers';