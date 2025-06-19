-- =====================================================================
-- AI Monitoring System Deployment Script
-- Execute all AI monitoring components in correct order
-- =====================================================================

\echo 'Starting AI Monitoring System Deployment...'

-- Set session variables for safety
SET session_replication_role = 'origin';
SET search_path = ai_monitoring, business, auth, audit, util, public;

-- 1. Deploy core schema and tables
\echo 'Deploying AI Monitoring Schema and Tables...'
\i dbCreation_AI_Monitoring.sql

\echo 'AI Monitoring tables deployed successfully!'

-- 2. Deploy functions and stored procedures  
\echo 'Deploying AI Monitoring Functions...'
\i dbCreation_AI_Monitoring_Functions.sql

\echo 'AI Monitoring functions deployed successfully!'

-- 3. Deploy API endpoints
\echo 'Deploying AI Monitoring API Endpoints...'
\i dbCreation_AI_Monitoring_API.sql

\echo 'AI Monitoring API endpoints deployed successfully!'

-- 4. Final verification
\echo 'Running deployment verification...'

-- Check that all expected tables exist
SELECT 
    'Tables Created' as check_type,
    COUNT(*) as count,
    array_agg(tablename ORDER BY tablename) as items
FROM pg_tables 
WHERE schemaname = 'ai_monitoring'
AND tablename IN (
    'monitored_entity_h',
    'ai_analysis_h', 
    'alert_h',
    'monitored_entity_details_s',
    'ai_analysis_results_s',
    'alert_details_s',
    'entity_analysis_l',
    'analysis_alert_l',
    'zt_access_policies_h',
    'zt_access_policies_s',
    'zt_security_events_h',
    'zt_security_events_s'
);

-- Check that API functions exist
SELECT 
    'API Functions Created' as check_type,
    COUNT(*) as count,
    array_agg(proname ORDER BY proname) as items
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'api'
AND proname LIKE 'ai_monitoring%';

-- Check that core functions exist
SELECT 
    'Core Functions Created' as check_type,
    COUNT(*) as count,
    array_agg(proname ORDER BY proname) as items
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'ai_monitoring'
AND proname IN (
    'validate_zero_trust_access',
    'log_security_event',
    'create_monitored_entity',
    'store_ai_analysis',
    'create_alert'
);

-- Check RLS policies
SELECT 
    'RLS Policies Created' as check_type,
    COUNT(*) as count,
    array_agg(policyname ORDER BY policyname) as items
FROM pg_policies 
WHERE schemaname = 'ai_monitoring';

\echo ''
\echo '====================================================='
\echo 'AI MONITORING SYSTEM DEPLOYMENT COMPLETE!'
\echo '====================================================='
\echo ''
\echo 'Features Deployed:'
\echo '✅ Generic Entity Monitoring (Industry Agnostic)'
\echo '✅ Zero Trust Security Architecture'
\echo '✅ AI Analysis Storage with Integrity Validation'
\echo '✅ Real-time Alert Management'
\echo '✅ Encrypted Data Storage with Field-level Access'
\echo '✅ Row Level Security (RLS) with Tenant Isolation'
\echo '✅ Comprehensive Audit Logging'
\echo '✅ API Endpoints with Dynamic Access Control'
\echo ''
\echo 'Next Steps:'
\echo '1. Configure encryption keys for production'
\echo '2. Set up Zero Trust policies for your organization'  
\echo '3. Configure alert escalation chains'
\echo '4. Test API endpoints with proper authentication'
\echo '5. Review security event monitoring'
\echo ''
\echo 'API Endpoints Available:'
\echo '• POST api.ai_monitoring_ingest - Real-time data ingestion'
\echo '• GET api.ai_monitoring_get_alerts - Retrieve alerts'
\echo '• PUT api.ai_monitoring_acknowledge_alert - Acknowledge alerts'
\echo '• GET api.ai_monitoring_get_entity_timeline - Historical analysis'
\echo '• GET api.ai_monitoring_system_health - System health check'
\echo '' 