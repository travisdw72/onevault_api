-- =============================================
-- RECREATE AUDIT TABLES FOR PROJECT GOAL 3
-- =============================================
-- This script recreates the audit tables that may have been accidentally dropped

-- Ensure audit schema exists
CREATE SCHEMA IF NOT EXISTS audit;

-- Create audit event hub table
CREATE TABLE IF NOT EXISTS audit.audit_event_h (
    audit_event_hk BYTEA PRIMARY KEY,
    audit_event_bk VARCHAR(255),
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100)
);

-- Create audit detail satellite table
CREATE TABLE IF NOT EXISTS audit.audit_detail_s (
    audit_event_hk BYTEA REFERENCES audit.audit_event_h(audit_event_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA,
    table_name VARCHAR(100),
    operation VARCHAR(10),
    changed_by VARCHAR(100),
    old_data JSONB,
    new_data JSONB,
    PRIMARY KEY (audit_event_hk, load_date)
);

-- Verification
DO $$ BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'AUDIT TABLES RECREATED!';
    RAISE NOTICE 'audit.audit_event_h and audit.audit_detail_s now exist';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Now run the fixed audit triggers script:';
    RAISE NOTICE '\i dbCreation_18_audit_fix.sql';
    RAISE NOTICE 'Then test with: SELECT util.test_registration();';
    RAISE NOTICE '===========================================';
END $$; 