-- Detailed Database Function Analysis Script
-- ==========================================
-- Comprehensive analysis of all functions, procedures, and their relationships
-- Compatible with PostgreSQL 12+ and Data Vault 2.0 architecture

-- Set extended display for better readability
\x on

-- Analysis timestamp
SELECT 
    'DATABASE FUNCTION ANALYSIS STARTED' as analysis_status,
    CURRENT_TIMESTAMP as analysis_timestamp,
    version() as postgresql_version,
    current_database() as database_name;

-- =============================================================================
-- 1. COMPREHENSIVE FUNCTION INVENTORY
-- =============================================================================

SELECT '📊 COMPREHENSIVE FUNCTION INVENTORY' as section_title;

CREATE TEMP TABLE temp_function_analysis AS
SELECT 
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type,
    l.lanname as language,
    CASE p.prokind 
        WHEN 'f' THEN 'function'
        WHEN 'p' THEN 'procedure'
        WHEN 'a' THEN 'aggregate'
        WHEN 'w' THEN 'window_function'
        ELSE 'unknown'
    END as function_type,
    CASE p.provolatile
        WHEN 'i' THEN 'immutable'
        WHEN 's' THEN 'stable'
        WHEN 'v' THEN 'volatile'
    END as volatility,
    p.proisstrict as is_strict,
    p.prosecdef as is_security_definer,
    r.rolname as owner,
    obj_description(p.oid, 'pg_proc') as description,
    pg_stat_get_function_calls(p.oid) as call_count,
    pg_stat_get_function_total_time(p.oid) as total_time_ms,
    pg_stat_get_function_self_time(p.oid) as self_time_ms,
    CASE 
        WHEN pg_stat_get_function_calls(p.oid) > 0 
        THEN pg_stat_get_function_total_time(p.oid) / pg_stat_get_function_calls(p.oid)
        ELSE 0 
    END as avg_time_per_call_ms,
    -- Function classification
    CASE 
        WHEN n.nspname = 'api' THEN 'API Endpoint'
        WHEN n.nspname = 'auth' THEN 'Authentication'
        WHEN n.nspname = 'backup_mgmt' THEN 'Backup/Recovery'
        WHEN n.nspname = 'monitoring' THEN 'System Monitoring'
        WHEN n.nspname = 'business' THEN 'Business Logic'
        WHEN n.nspname = 'util' THEN 'Utility'
        WHEN n.nspname = 'audit' THEN 'Compliance/Audit'
        WHEN n.nspname LIKE 'ai_%' THEN 'AI/ML Operations'
        WHEN n.nspname = 'compliance' THEN 'Regulatory Compliance'
        WHEN n.nspname = 'security' THEN 'Security'
        ELSE 'Other'
    END as function_category,
    -- Purpose classification
    CASE 
        WHEN p.proname ILIKE '%login%' OR p.proname ILIKE '%auth%' OR p.proname ILIKE '%session%' THEN 'Authentication'
        WHEN p.proname ILIKE '%backup%' OR p.proname ILIKE '%restore%' OR p.proname ILIKE '%recover%' THEN 'Backup/Recovery'
        WHEN p.proname ILIKE '%monitor%' OR p.proname ILIKE '%health%' OR p.proname ILIKE '%metric%' THEN 'Monitoring'
        WHEN p.proname ILIKE '%validate%' OR p.proname ILIKE '%check%' OR p.proname ILIKE '%verify%' THEN 'Validation'
        WHEN p.proname ILIKE '%audit%' OR p.proname ILIKE '%log%' OR p.proname ILIKE '%track%' THEN 'Audit/Logging'
        WHEN p.proname ILIKE '%hash%' OR p.proname ILIKE '%encrypt%' OR p.proname ILIKE '%security%' THEN 'Security'
        WHEN p.proname ILIKE '%tenant%' OR p.proname ILIKE '%isolation%' THEN 'Multi-Tenancy'
        WHEN p.proname ILIKE '%api_%' THEN 'API Operation'
        WHEN p.proname ILIKE '%ai_%' OR p.proname ILIKE '%ml_%' THEN 'AI/ML'
        ELSE 'General Purpose'
    END as purpose_category,
    p.oid as function_oid
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
JOIN pg_language l ON p.prolang = l.oid
JOIN pg_roles r ON p.proowner = r.oid
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY n.nspname, p.proname;

-- Display function inventory summary
SELECT 
    'Function Inventory Summary' as analysis_section,
    COUNT(*) as total_functions,
    COUNT(CASE WHEN function_type = 'function' THEN 1 END) as functions,
    COUNT(CASE WHEN function_type = 'procedure' THEN 1 END) as procedures,
    COUNT(CASE WHEN function_type = 'aggregate' THEN 1 END) as aggregates,
    COUNT(DISTINCT schema_name) as total_schemas,
    COUNT(CASE WHEN call_count > 0 THEN 1 END) as functions_with_usage,
    ROUND(AVG(avg_time_per_call_ms), 2) as avg_execution_time_ms
FROM temp_function_analysis;

-- =============================================================================
-- 2. FUNCTION DISTRIBUTION BY SCHEMA
-- =============================================================================

SELECT '🏗️ FUNCTION DISTRIBUTION BY SCHEMA' as section_title;

SELECT 
    schema_name,
    function_category,
    COUNT(*) as function_count,
    COUNT(CASE WHEN function_type = 'function' THEN 1 END) as functions,
    COUNT(CASE WHEN function_type = 'procedure' THEN 1 END) as procedures,
    ROUND(AVG(CASE WHEN call_count > 0 THEN avg_time_per_call_ms END), 2) as avg_execution_time_ms,
    SUM(call_count) as total_calls,
    MAX(call_count) as max_calls_single_function
FROM temp_function_analysis
GROUP BY schema_name, function_category
ORDER BY schema_name, function_count DESC;

-- =============================================================================
-- 3. CRITICAL PRODUCTION FUNCTIONS ANALYSIS
-- =============================================================================

SELECT '🚀 CRITICAL PRODUCTION FUNCTIONS ANALYSIS' as section_title;

-- Backup and Recovery Functions
SELECT 
    'BACKUP/RECOVERY FUNCTIONS' as function_group,
    schema_name,
    function_name,
    function_type,
    call_count,
    total_time_ms,
    avg_time_per_call_ms,
    CASE 
        WHEN schema_name = 'backup_mgmt' AND function_name ILIKE '%backup%' THEN '✅ Critical'
        WHEN schema_name = 'backup_mgmt' AND function_name ILIKE '%restore%' THEN '✅ Critical'
        WHEN schema_name = 'backup_mgmt' AND function_name ILIKE '%recover%' THEN '✅ Critical'
        ELSE '⚠️ Review'
    END as importance
FROM temp_function_analysis
WHERE schema_name IN ('backup_mgmt') OR function_name ILIKE '%backup%' OR function_name ILIKE '%restore%'
ORDER BY importance DESC, call_count DESC;

-- Monitoring Functions
SELECT 
    'MONITORING FUNCTIONS' as function_group,
    schema_name,
    function_name,
    function_type,
    call_count,
    total_time_ms,
    avg_time_per_call_ms,
    CASE 
        WHEN schema_name = 'monitoring' AND function_name ILIKE '%collect%' THEN '✅ Critical'
        WHEN schema_name = 'monitoring' AND function_name ILIKE '%alert%' THEN '✅ Critical'
        WHEN schema_name = 'monitoring' AND function_name ILIKE '%health%' THEN '✅ Critical'
        ELSE '⚠️ Review'
    END as importance
FROM temp_function_analysis
WHERE schema_name IN ('monitoring') OR function_name ILIKE '%monitor%' OR function_name ILIKE '%health%'
ORDER BY importance DESC, call_count DESC;

-- Authentication Functions
SELECT 
    'AUTHENTICATION FUNCTIONS' as function_group,
    schema_name,
    function_name,
    function_type,
    call_count,
    total_time_ms,
    avg_time_per_call_ms,
    CASE 
        WHEN function_name ILIKE '%login%' THEN '✅ Critical'
        WHEN function_name ILIKE '%session%' THEN '✅ Critical'
        WHEN function_name ILIKE '%validate%' THEN '✅ Critical'
        ELSE '⚠️ Review'
    END as importance
FROM temp_function_analysis
WHERE schema_name IN ('auth', 'api') AND (
    function_name ILIKE '%auth%' OR 
    function_name ILIKE '%login%' OR 
    function_name ILIKE '%session%' OR
    function_name ILIKE '%token%'
)
ORDER BY importance DESC, call_count DESC;

-- =============================================================================
-- 4. API ENDPOINT ANALYSIS
-- =============================================================================

SELECT '🌐 API ENDPOINT ANALYSIS' as section_title;

SELECT 
    'API ENDPOINTS BY CATEGORY' as analysis_type,
    CASE 
        WHEN function_name ILIKE '%auth%' OR function_name ILIKE '%login%' THEN 'Authentication'
        WHEN function_name ILIKE '%admin%' OR function_name ILIKE '%manage%' THEN 'Administration'
        WHEN function_name ILIKE '%ai_%' OR function_name ILIKE '%agent%' THEN 'AI Operations'
        WHEN function_name ILIKE '%business%' OR function_name ILIKE '%entity%' THEN 'Business Logic'
        WHEN function_name ILIKE '%monitor%' OR function_name ILIKE '%health%' THEN 'Monitoring'
        ELSE 'Other'
    END as endpoint_category,
    COUNT(*) as endpoint_count,
    ARRAY_AGG(function_name ORDER BY function_name) as endpoints,
    SUM(call_count) as total_api_calls,
    ROUND(AVG(avg_time_per_call_ms), 2) as avg_response_time_ms
FROM temp_function_analysis
WHERE schema_name = 'api'
GROUP BY endpoint_category
ORDER BY endpoint_count DESC;

-- =============================================================================
-- 5. PERFORMANCE ANALYSIS
-- =============================================================================

SELECT '⚡ PERFORMANCE ANALYSIS' as section_title;

-- Most Called Functions
SELECT 
    'TOP 10 MOST CALLED FUNCTIONS' as performance_metric,
    schema_name,
    function_name,
    call_count,
    total_time_ms,
    avg_time_per_call_ms,
    function_category
FROM temp_function_analysis
WHERE call_count > 0
ORDER BY call_count DESC
LIMIT 10;

-- Slowest Functions
SELECT 
    'TOP 10 SLOWEST FUNCTIONS (by average time)' as performance_metric,
    schema_name,
    function_name,
    call_count,
    avg_time_per_call_ms,
    total_time_ms,
    function_category
FROM temp_function_analysis
WHERE call_count > 0 AND avg_time_per_call_ms > 0
ORDER BY avg_time_per_call_ms DESC
LIMIT 10;

-- Most Time Consuming Functions
SELECT 
    'TOP 10 MOST TIME CONSUMING FUNCTIONS (total time)' as performance_metric,
    schema_name,
    function_name,
    call_count,
    total_time_ms,
    avg_time_per_call_ms,
    function_category
FROM temp_function_analysis
WHERE total_time_ms > 0
ORDER BY total_time_ms DESC
LIMIT 10;

-- =============================================================================
-- 6. COMPLIANCE AND SECURITY ANALYSIS
-- =============================================================================

SELECT '🛡️ COMPLIANCE AND SECURITY ANALYSIS' as section_title;

-- Security Functions
SELECT 
    'SECURITY FUNCTIONS' as compliance_category,
    schema_name,
    function_name,
    function_type,
    is_security_definer,
    call_count,
    CASE 
        WHEN function_name ILIKE '%hash%' THEN 'Cryptographic'
        WHEN function_name ILIKE '%encrypt%' THEN 'Encryption'
        WHEN function_name ILIKE '%auth%' THEN 'Authentication'
        WHEN function_name ILIKE '%validate%' THEN 'Validation'
        WHEN function_name ILIKE '%security%' THEN 'Security Control'
        ELSE 'Other Security'
    END as security_type
FROM temp_function_analysis
WHERE function_name ILIKE '%security%' 
   OR function_name ILIKE '%hash%' 
   OR function_name ILIKE '%encrypt%'
   OR function_name ILIKE '%auth%'
   OR schema_name IN ('auth', 'security')
ORDER BY security_type, call_count DESC;

-- Audit and Compliance Functions
SELECT 
    'AUDIT/COMPLIANCE FUNCTIONS' as compliance_category,
    schema_name,
    function_name,
    function_type,
    call_count,
    CASE 
        WHEN function_name ILIKE '%audit%' THEN 'Audit Trail'
        WHEN function_name ILIKE '%log%' THEN 'Logging'
        WHEN function_name ILIKE '%track%' THEN 'Tracking'
        WHEN function_name ILIKE '%compliance%' THEN 'Compliance Check'
        WHEN function_name ILIKE '%hipaa%' THEN 'HIPAA Compliance'
        WHEN function_name ILIKE '%gdpr%' THEN 'GDPR Compliance'
        ELSE 'Other Compliance'
    END as compliance_type
FROM temp_function_analysis
WHERE function_name ILIKE '%audit%' 
   OR function_name ILIKE '%log%' 
   OR function_name ILIKE '%track%'
   OR function_name ILIKE '%compliance%'
   OR function_name ILIKE '%hipaa%'
   OR function_name ILIKE '%gdpr%'
   OR schema_name IN ('audit', 'compliance')
ORDER BY compliance_type, call_count DESC;

-- =============================================================================
-- 7. PRODUCTION READINESS ASSESSMENT
-- =============================================================================

SELECT '📋 PRODUCTION READINESS ASSESSMENT' as section_title;

-- Critical Function Availability Check
WITH critical_functions AS (
    SELECT unnest(ARRAY[
        'backup_mgmt.execute_backup',
        'backup_mgmt.restore_database',
        'backup_mgmt.schedule_backup',
        'monitoring.collect_system_metrics',
        'monitoring.create_alert',
        'monitoring.process_alert',
        'auth.validate_session',
        'auth.login_user',
        'api.auth_login',
        'api.auth_validate_session',
        'util.hash_binary',
        'util.current_load_date'
    ]) as critical_function
),
function_existence AS (
    SELECT 
        cf.critical_function,
        CASE WHEN fa.function_name IS NOT NULL THEN '✅ Available' ELSE '❌ Missing' END as status,
        COALESCE(fa.call_count, 0) as usage_count,
        COALESCE(fa.avg_time_per_call_ms, 0) as avg_performance_ms
    FROM critical_functions cf
    LEFT JOIN temp_function_analysis fa ON 
        cf.critical_function = fa.schema_name || '.' || fa.function_name
)
SELECT 
    'CRITICAL FUNCTION AVAILABILITY' as assessment_type,
    critical_function,
    status,
    usage_count,
    avg_performance_ms
FROM function_existence
ORDER BY status DESC, critical_function;

-- Schema Readiness Assessment
SELECT 
    'SCHEMA READINESS ASSESSMENT' as assessment_type,
    schema_name,
    function_category,
    COUNT(*) as function_count,
    CASE 
        WHEN schema_name = 'backup_mgmt' AND COUNT(*) >= 5 THEN '✅ Production Ready'
        WHEN schema_name = 'monitoring' AND COUNT(*) >= 5 THEN '✅ Production Ready'
        WHEN schema_name = 'auth' AND COUNT(*) >= 10 THEN '✅ Production Ready'
        WHEN schema_name = 'api' AND COUNT(*) >= 15 THEN '✅ Production Ready'
        WHEN schema_name = 'audit' AND COUNT(*) >= 5 THEN '✅ Production Ready'
        WHEN schema_name = 'util' AND COUNT(*) >= 5 THEN '✅ Production Ready'
        ELSE '⚠️ Needs Review'
    END as readiness_status,
    SUM(call_count) as total_usage,
    ROUND(AVG(avg_time_per_call_ms), 2) as avg_performance
FROM temp_function_analysis
WHERE schema_name IN ('backup_mgmt', 'monitoring', 'auth', 'api', 'audit', 'util', 'business')
GROUP BY schema_name, function_category
ORDER BY schema_name;

-- =============================================================================
-- 8. DEPENDENCY ANALYSIS
-- =============================================================================

SELECT '🔗 FUNCTION DEPENDENCY ANALYSIS' as section_title;

-- Functions that call other functions (basic analysis)
WITH function_calls AS (
    SELECT 
        n.nspname as calling_schema,
        p.proname as calling_function,
        pg_get_functiondef(p.oid) as source_code
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    AND pg_get_functiondef(p.oid) IS NOT NULL
)
SELECT 
    'INTER-SCHEMA FUNCTION DEPENDENCIES' as dependency_analysis,
    calling_schema,
    calling_function,
    CASE 
        WHEN source_code ~* 'auth\.' THEN 'Calls Auth Functions'
        WHEN source_code ~* 'util\.' THEN 'Calls Utility Functions'
        WHEN source_code ~* 'business\.' THEN 'Calls Business Functions'
        WHEN source_code ~* 'monitoring\.' THEN 'Calls Monitoring Functions'
        WHEN source_code ~* 'backup_mgmt\.' THEN 'Calls Backup Functions'
        WHEN source_code ~* 'api\.' THEN 'Calls API Functions'
        ELSE 'Self-Contained'
    END as dependency_type
FROM function_calls
WHERE calling_schema IN ('api', 'auth', 'business', 'backup_mgmt', 'monitoring')
ORDER BY calling_schema, dependency_type;

-- =============================================================================
-- 9. RECOMMENDATIONS AND SUMMARY
-- =============================================================================

SELECT '💡 RECOMMENDATIONS AND SUMMARY' as section_title;

-- Generate recommendations based on analysis
WITH recommendations AS (
    SELECT 
        'Function Count Analysis' as recommendation_category,
        CASE 
            WHEN COUNT(CASE WHEN schema_name = 'backup_mgmt' THEN 1 END) < 5 
            THEN 'Implement additional backup/recovery functions'
            ELSE 'Backup functions: ✅ Adequate'
        END as recommendation
    FROM temp_function_analysis
    
    UNION ALL
    
    SELECT 
        'Performance Analysis' as recommendation_category,
        CASE 
            WHEN AVG(CASE WHEN call_count > 0 THEN avg_time_per_call_ms END) > 1000
            THEN 'Review slow functions - average execution time > 1000ms'
            ELSE 'Performance: ✅ Acceptable'
        END as recommendation
    FROM temp_function_analysis
    
    UNION ALL
    
    SELECT 
        'API Coverage Analysis' as recommendation_category,
        CASE 
            WHEN COUNT(CASE WHEN schema_name = 'api' THEN 1 END) < 15
            THEN 'Expand API endpoint coverage'
            ELSE 'API Coverage: ✅ Comprehensive'
        END as recommendation
    FROM temp_function_analysis
)
SELECT * FROM recommendations;

-- Final Summary Statistics
SELECT 
    'FINAL ANALYSIS SUMMARY' as summary_section,
    COUNT(*) as total_functions_analyzed,
    COUNT(DISTINCT schema_name) as schemas_analyzed,
    COUNT(CASE WHEN call_count > 0 THEN 1 END) as functions_with_usage,
    ROUND(
        COUNT(CASE WHEN call_count > 0 THEN 1 END)::DECIMAL / COUNT(*) * 100, 
        2
    ) as usage_percentage,
    COUNT(CASE WHEN schema_name IN ('backup_mgmt', 'monitoring', 'auth', 'api') THEN 1 END) as production_critical_functions,
    CURRENT_TIMESTAMP as analysis_completed_at
FROM temp_function_analysis;

-- Cleanup
DROP TABLE temp_function_analysis;

SELECT 
    '✅ DATABASE FUNCTION ANALYSIS COMPLETED' as analysis_status,
    CURRENT_TIMESTAMP as completion_timestamp;

-- Reset display mode
\x off 