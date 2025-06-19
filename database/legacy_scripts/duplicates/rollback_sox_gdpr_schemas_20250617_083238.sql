-- =====================================================================================
-- ROLLBACK: Remove Incorrectly Created SOX and GDPR Schemas
-- =====================================================================================
-- This script removes the sox_compliance and gdpr_compliance schemas that were
-- created outside of the existing compliance schema structure
-- =====================================================================================

\echo 'Starting rollback of sox_compliance and gdpr_compliance schemas...'
\echo 'This will remove tables created outside the existing compliance schema'
\echo ''

-- ==================================================
-- DROP SOX_COMPLIANCE SCHEMA TABLES (if they exist)
-- ==================================================

\echo 'Removing sox_compliance schema tables...'

-- Drop SOX tables in dependency order
DROP TABLE IF EXISTS sox_compliance.sox_evidence_s CASCADE;
DROP TABLE IF EXISTS sox_compliance.sox_evidence_h CASCADE;
DROP TABLE IF EXISTS sox_compliance.sox_certification_s CASCADE;
DROP TABLE IF EXISTS sox_compliance.sox_certification_h CASCADE;
DROP TABLE IF EXISTS sox_compliance.sox_control_test_s CASCADE;
DROP TABLE IF EXISTS sox_compliance.sox_control_test_h CASCADE;
DROP TABLE IF EXISTS sox_compliance.sox_control_s CASCADE;
DROP TABLE IF EXISTS sox_compliance.sox_control_h CASCADE;
DROP TABLE IF EXISTS sox_compliance.sox_control_period_s CASCADE;
DROP TABLE IF EXISTS sox_compliance.sox_control_period_h CASCADE;

-- Drop SOX functions
DROP FUNCTION IF EXISTS sox_compliance.create_sox_control_period CASCADE;
DROP FUNCTION IF EXISTS sox_compliance.create_sox_control CASCADE;
DROP FUNCTION IF EXISTS sox_compliance.execute_sox_control_test CASCADE;
DROP FUNCTION IF EXISTS sox_compliance.create_sox_certification CASCADE;
DROP FUNCTION IF EXISTS sox_compliance.setup_default_sox_controls CASCADE;

-- Drop SOX views
DROP VIEW IF EXISTS sox_compliance.sox_compliance_dashboard CASCADE;

-- Drop SOX schema
DROP SCHEMA IF EXISTS sox_compliance CASCADE;

\echo 'SOX compliance schema removed successfully'

-- ==================================================
-- DROP GDPR_COMPLIANCE SCHEMA TABLES (if they exist)
-- ==================================================

\echo 'Removing gdpr_compliance schema tables...'

-- Drop GDPR tables in dependency order
DROP TABLE IF EXISTS gdpr_compliance.gdpr_erasure_s CASCADE;
DROP TABLE IF EXISTS gdpr_compliance.gdpr_erasure_h CASCADE;
DROP TABLE IF EXISTS gdpr_compliance.gdpr_data_export_s CASCADE;
DROP TABLE IF EXISTS gdpr_compliance.gdpr_data_export_h CASCADE;
DROP TABLE IF EXISTS gdpr_compliance.gdpr_consent_s CASCADE;
DROP TABLE IF EXISTS gdpr_compliance.gdpr_consent_h CASCADE;
DROP TABLE IF EXISTS gdpr_compliance.gdpr_processing_activity_s CASCADE;
DROP TABLE IF EXISTS gdpr_compliance.gdpr_processing_activity_h CASCADE;
DROP TABLE IF EXISTS gdpr_compliance.gdpr_rights_request_s CASCADE;
DROP TABLE IF EXISTS gdpr_compliance.gdpr_rights_request_h CASCADE;
DROP TABLE IF EXISTS gdpr_compliance.gdpr_data_subject_s CASCADE;
DROP TABLE IF EXISTS gdpr_compliance.gdpr_data_subject_h CASCADE;

-- Drop GDPR functions
DROP FUNCTION IF EXISTS gdpr_compliance.register_gdpr_data_subject CASCADE;
DROP FUNCTION IF EXISTS gdpr_compliance.submit_gdpr_rights_request CASCADE;
DROP FUNCTION IF EXISTS gdpr_compliance.record_gdpr_consent CASCADE;
DROP FUNCTION IF EXISTS gdpr_compliance.process_data_portability_request CASCADE;
DROP FUNCTION IF EXISTS gdpr_compliance.process_erasure_request CASCADE;
DROP FUNCTION IF EXISTS gdpr_compliance.setup_default_gdpr_activities CASCADE;
DROP FUNCTION IF EXISTS gdpr_compliance.create_gdpr_processing_activity CASCADE;

-- Drop GDPR views
DROP VIEW IF EXISTS gdpr_compliance.gdpr_compliance_dashboard CASCADE;

-- Drop GDPR schema
DROP SCHEMA IF EXISTS gdpr_compliance CASCADE;

\echo 'GDPR compliance schema removed successfully'

-- ==================================================
-- VERIFY CLEANUP
-- ==================================================

\echo 'Verifying schema cleanup...'

-- Check if schemas still exist
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'sox_compliance') 
        THEN 'ERROR: sox_compliance schema still exists'
        ELSE 'SUCCESS: sox_compliance schema removed'
    END as sox_status,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'gdpr_compliance') 
        THEN 'ERROR: gdpr_compliance schema still exists'
        ELSE 'SUCCESS: gdpr_compliance schema removed'
    END as gdpr_status;

-- Verify existing compliance schema is intact
SELECT 
    'compliance' as schema_name,
    COUNT(*) as table_count,
    'Should have 4+ tables' as expected
FROM information_schema.tables 
WHERE table_schema = 'compliance'
GROUP BY table_schema;

\echo 'Rollback completed successfully!'
\echo 'Ready to deploy SOX and GDPR tables into existing compliance schema'
\echo '' 