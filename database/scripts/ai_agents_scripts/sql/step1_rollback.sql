-- ==========================================
-- STEP 1 ROLLBACK: AI AGENT IDENTITY & PKI FOUNDATION
-- ==========================================
-- Rollback script to clean up step1 deployment
-- Run this if step1 deployment fails or needs to be redeployed

BEGIN;

-- ==========================================
-- DROP FUNCTIONS (First - to remove dependencies)
-- ==========================================

DROP FUNCTION IF EXISTS ai_agents.validate_agent_certificate(VARCHAR(128)) CASCADE;
DROP FUNCTION IF EXISTS ai_agents.generate_agent_certificate(BYTEA, BYTEA) CASCADE;
DROP FUNCTION IF EXISTS ai_agents.create_agent_identity(BYTEA, VARCHAR(200), VARCHAR(100), VARCHAR(100), JSONB, TEXT[]) CASCADE;

-- ==========================================
-- DROP INDEXES (Before dropping tables)
-- ==========================================

DROP INDEX IF EXISTS ai_agents.idx_hsm_integration_s_health_status;
DROP INDEX IF EXISTS ai_agents.idx_hsm_integration_s_hsm_status;
DROP INDEX IF EXISTS ai_agents.idx_hsm_integration_h_tenant_hk;

DROP INDEX IF EXISTS ai_agents.idx_agent_authentication_s_certificate_fingerprint;
DROP INDEX IF EXISTS ai_agents.idx_agent_authentication_s_result;
DROP INDEX IF EXISTS ai_agents.idx_agent_authentication_s_timestamp;
DROP INDEX IF EXISTS ai_agents.idx_agent_authentication_h_tenant_hk;
DROP INDEX IF EXISTS ai_agents.idx_agent_authentication_h_agent_identity_hk;

DROP INDEX IF EXISTS ai_agents.idx_agent_certificate_s_expiration_date;
DROP INDEX IF EXISTS ai_agents.idx_agent_certificate_s_fingerprint;
DROP INDEX IF EXISTS ai_agents.idx_agent_certificate_s_certificate_status;
DROP INDEX IF EXISTS ai_agents.idx_agent_certificate_h_tenant_hk;
DROP INDEX IF EXISTS ai_agents.idx_agent_certificate_h_ca_hk;
DROP INDEX IF EXISTS ai_agents.idx_agent_certificate_h_agent_identity_hk;

DROP INDEX IF EXISTS ai_agents.idx_certificate_authority_s_ca_status;
DROP INDEX IF EXISTS ai_agents.idx_certificate_authority_s_ca_type;
DROP INDEX IF EXISTS ai_agents.idx_certificate_authority_h_tenant_hk;

DROP INDEX IF EXISTS ai_agents.idx_agent_identity_s_agent_category;
DROP INDEX IF EXISTS ai_agents.idx_agent_identity_s_agent_status;
DROP INDEX IF EXISTS ai_agents.idx_agent_identity_s_agent_type;
DROP INDEX IF EXISTS ai_agents.idx_agent_identity_h_tenant_hk;

-- ==========================================
-- DROP SATELLITE TABLES (Data first)
-- ==========================================

DROP TABLE IF EXISTS ai_agents.hsm_integration_s CASCADE;
DROP TABLE IF EXISTS ai_agents.agent_authentication_s CASCADE;
DROP TABLE IF EXISTS ai_agents.agent_certificate_s CASCADE;
DROP TABLE IF EXISTS ai_agents.certificate_authority_s CASCADE;
DROP TABLE IF EXISTS ai_agents.agent_identity_s CASCADE;

-- ==========================================
-- DROP HUB TABLES (Structure last)
-- ==========================================

DROP TABLE IF EXISTS ai_agents.hsm_integration_h CASCADE;
DROP TABLE IF EXISTS ai_agents.agent_authentication_h CASCADE;
DROP TABLE IF EXISTS ai_agents.agent_certificate_h CASCADE;
DROP TABLE IF EXISTS ai_agents.certificate_authority_h CASCADE;
DROP TABLE IF EXISTS ai_agents.agent_identity_h CASCADE;

-- ==========================================
-- DROP SCHEMA (Only if completely empty)
-- ==========================================

-- Check if schema has any remaining objects
DO $$
DECLARE
    obj_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO obj_count
    FROM information_schema.tables 
    WHERE table_schema = 'ai_agents';
    
    IF obj_count = 0 THEN
        DROP SCHEMA IF EXISTS ai_agents CASCADE;
        RAISE NOTICE '✅ ai_agents schema dropped (was empty)';
    ELSE
        RAISE NOTICE '⚠️  ai_agents schema retained (% objects remaining)', obj_count;
    END IF;
END $$;

COMMIT;

-- ==========================================
-- ROLLBACK VERIFICATION
-- ==========================================

-- Verify clean rollback
DO $$
DECLARE
    v_schema_exists BOOLEAN;
    v_table_count INTEGER;
    v_function_count INTEGER;
BEGIN
    -- Check if schema exists
    SELECT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'ai_agents') 
    INTO v_schema_exists;
    
    -- Count remaining objects
    SELECT COUNT(*) INTO v_table_count 
    FROM information_schema.tables WHERE table_schema = 'ai_agents';
    
    SELECT COUNT(*) INTO v_function_count 
    FROM information_schema.routines WHERE routine_schema = 'ai_agents';
    
    -- Report results
    RAISE NOTICE '🔄 STEP 1 ROLLBACK VERIFICATION:';
    RAISE NOTICE '   Schema exists: %', v_schema_exists;
    RAISE NOTICE '   Remaining tables: %', v_table_count;
    RAISE NOTICE '   Remaining functions: %', v_function_count;
    
    IF v_schema_exists AND v_table_count = 0 AND v_function_count = 0 THEN
        RAISE NOTICE '✅ ROLLBACK COMPLETED SUCCESSFULLY - Schema empty and ready for fresh deployment';
    ELSIF NOT v_schema_exists THEN
        RAISE NOTICE '✅ ROLLBACK COMPLETED SUCCESSFULLY - Schema completely removed';
    ELSE
        RAISE NOTICE '⚠️  ROLLBACK INCOMPLETE - % tables and % functions remain', v_table_count, v_function_count;
    END IF;
END $$;

-- Final verification query
SELECT 
    'STEP 1 ROLLBACK VERIFICATION' as status,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'ai_agents') 
        THEN 'ai_agents schema exists'
        ELSE 'ai_agents schema removed'
    END as schema_status,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'ai_agents') as remaining_tables,
    (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'ai_agents') as remaining_functions; 