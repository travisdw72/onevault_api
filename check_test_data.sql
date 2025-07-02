-- 🔍 Check Test Data from AI API Calls
-- Run these queries to see what data made it into the database

-- ================================================
-- 1. CHECK AI INTERACTIONS (Main table for AI calls)
-- ================================================
SELECT 
    aid.load_date as interaction_timestamp,
    aid.model_used,
    aid.context_type,
    aid.processing_time_ms,
    aid.token_count_input,
    aid.token_count_output,
    aid.security_level,
    LEFT(aid.question_text, 100) as query_preview,
    LEFT(aid.response_text, 100) as response_preview
FROM business.ai_interaction_details_s aid
WHERE aid.load_end_date IS NULL
AND aid.load_date >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
ORDER BY aid.load_date DESC
LIMIT 10;

-- ================================================
-- 2. CHECK AI AGENT SESSIONS (Our test sessions)
-- ================================================
SELECT 
    aih.ai_interaction_bk as interaction_id,
    aid.load_date as interaction_timestamp,
    aid.model_used,
    aid.context_type,
    aid.processing_time_ms,
    LEFT(aid.question_text, 50) as question_preview,
    LEFT(aid.response_text, 50) as response_preview
FROM business.ai_interaction_h aih
JOIN business.ai_interaction_details_s aid ON aih.ai_interaction_hk = aid.ai_interaction_hk
WHERE aid.load_end_date IS NULL
AND aid.context_type LIKE '%test_%'  -- Our test sessions
ORDER BY aid.load_date DESC;

-- ================================================
-- 3. CHECK AI OBSERVATIONS (If using observation API)
-- ================================================
-- Check if ai_observation tables exist first
SELECT 
    COUNT(*) as observation_table_count
FROM information_schema.tables 
WHERE table_name = 'ai_observation_h' 
AND table_schema = 'business';

-- ================================================
-- 4. CHECK TENANT-SPECIFIC DATA (one_spa tenant)
-- ================================================
SELECT 
    t.tenant_name,
    COUNT(aid.ai_interaction_hk) as total_interactions,
    MAX(aid.load_date) as last_interaction,
    AVG(aid.processing_time_ms) as avg_response_time,
    SUM(aid.token_count_input + aid.token_count_output) as total_tokens
FROM auth.tenant_h th
JOIN auth.tenant_profile_s t ON th.tenant_hk = t.tenant_hk
LEFT JOIN business.ai_interaction_h aih ON th.tenant_hk = aih.tenant_hk
LEFT JOIN business.ai_interaction_details_s aid ON aih.ai_interaction_hk = aid.ai_interaction_hk
WHERE t.load_end_date IS NULL
AND (aid.load_end_date IS NULL OR aid.load_end_date IS NULL)
AND t.tenant_name = 'The One Spa Oregon'
AND aid.load_date >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
GROUP BY t.tenant_name;

-- ================================================
-- 5. CHECK AI MODEL PERFORMANCE (If Phase 1 tables exist)
-- ================================================
-- First check if the table exists
SELECT 
    COUNT(*) as performance_table_count
FROM information_schema.tables 
WHERE table_name = 'ai_model_performance_h' 
AND table_schema = 'business';

-- ================================================
-- 6. CHECK RECENT AUDIT LOGS
-- ================================================
SELECT 
    execution_timestamp,
    execution_status,
    function_name,
    LEFT(execution_details, 100) as details_preview,
    LEFT(error_message, 100) as error_preview
FROM util.audit_log
WHERE execution_timestamp >= CURRENT_TIMESTAMP - INTERVAL '2 hours'
AND (function_name LIKE '%ai_%' OR execution_details LIKE '%ai_%')
ORDER BY execution_timestamp DESC
LIMIT 10;

-- ================================================
-- 7. CHECK AI AGENT STATUS DATA
-- ================================================
-- This might be in a different table depending on implementation
SELECT 
    'Check if agent status data exists' as note,
    COUNT(*) as record_count
FROM information_schema.tables 
WHERE table_name LIKE '%agent%' 
AND table_schema = 'business';

-- ================================================
-- 8. CHECK SESSION ACTIVITY (Our specific test contexts)
-- ================================================
SELECT 
    aid.load_date as interaction_timestamp,
    aid.model_used,
    aid.context_type,
    LEFT(aid.question_text, 50) as question_preview,
    aid.processing_time_ms,
    aid.token_count_input,
    aid.token_count_output,
    aid.confidence_score
FROM business.ai_interaction_details_s aid
WHERE aid.load_end_date IS NULL
AND aid.context_type IN (
    'business_analysis',
    'data_science', 
    'customer_insight',
    'photo_analysis'
)
ORDER BY aid.load_date DESC;

-- ================================================
-- 9. CHECK WHAT TABLES ACTUALLY EXIST (Diagnostic)
-- ================================================
SELECT 
    table_schema,
    table_name,
    'TABLE' as object_type
FROM information_schema.tables
WHERE table_schema IN ('business', 'ai_agents', 'util')
AND table_name LIKE '%ai%'

UNION ALL

SELECT 
    routine_schema,
    routine_name,
    'FUNCTION' as object_type
FROM information_schema.routines
WHERE routine_schema IN ('business', 'ai_agents', 'util', 'api')
AND routine_name LIKE '%ai%'
ORDER BY object_type, table_schema, table_name;

-- ================================================
-- 10. SIMPLE COUNT CHECK (Quick overview)
-- ================================================
SELECT 
    'AI Interactions (last hour)' as data_type,
    COUNT(*) as count
FROM business.ai_interaction_details_s
WHERE load_end_date IS NULL
AND load_date >= CURRENT_TIMESTAMP - INTERVAL '1 hour'

UNION ALL

SELECT 
    'Total AI Interactions (today)',
    COUNT(*)
FROM business.ai_interaction_details_s
WHERE load_end_date IS NULL
AND load_date >= CURRENT_DATE;

-- ================================================
-- 11. CHECK STORED AI FUNCTION CALLS
-- ================================================
-- Check if we have any stored AI function calls in the database
SELECT 
    f.function_name,
    f.function_description,
    f.last_executed,
    f.execution_count
FROM util.ai_function_registry f
WHERE f.is_active = true
AND f.function_name LIKE '%ai_%'
ORDER BY f.last_executed DESC
LIMIT 10; 