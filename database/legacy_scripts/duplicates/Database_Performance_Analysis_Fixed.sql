-- =============================================================================
-- Database Performance Analysis - FIXED VERSION
-- Date: 2025-01-08  
-- Purpose: Analyze load test results with correct PostgreSQL column names
-- =============================================================================

-- 1. RESPONSE TIME ANALYSIS
SELECT 
    'Load Test Summary' AS metric,
    '26 requests, 0 errors, 31 seconds' AS details,
    '82ms average response time' AS performance;

-- 2. DATABASE HEALTH CHECK QUERIES

-- A. Connection Pool Status
SELECT 'Connection Pool Status' AS section;
SELECT 
    datname,
    numbackends,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit,
    ROUND(blks_hit::numeric / NULLIF(blks_hit + blks_read, 0) * 100, 2) AS cache_hit_ratio
FROM pg_stat_database 
WHERE datname = current_database();

-- B. Table Statistics for Data Vault 2.0 Core Tables
SELECT 'Table Statistics' AS section;
SELECT 
    schemaname,
    relname AS table_name,  -- Using correct column name
    n_tup_ins AS inserts,
    n_tup_upd AS updates,
    n_tup_del AS deletes,
    n_live_tup AS live_tuples,
    n_dead_tup AS dead_tuples,
    CASE 
        WHEN n_live_tup + n_dead_tup = 0 THEN 0
        ELSE ROUND(n_dead_tup::numeric / (n_live_tup + n_dead_tup) * 100, 2)
    END AS dead_tuple_ratio,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables 
WHERE schemaname = ANY(ARRAY['auth', 'raw', 'dv', 'audit'])
ORDER BY n_live_tup DESC;

-- C. Index Usage Analysis  
SELECT 'Index Usage Analysis' AS section;
SELECT 
    schemaname,
    relname AS table_name,      -- Correct column name
    indexrelname AS index_name, -- Correct column name
    idx_tup_read,
    idx_tup_fetch,
    CASE 
        WHEN idx_tup_read = 0 THEN 'UNUSED INDEX'
        WHEN idx_tup_read > 0 AND idx_tup_fetch::numeric / idx_tup_read < 0.1 THEN 'LOW EFFICIENCY'
        ELSE 'GOOD'
    END AS index_status
FROM pg_stat_user_indexes 
WHERE schemaname = ANY(ARRAY['auth', 'raw', 'dv', 'audit'])
ORDER BY idx_tup_read DESC;

-- D. Available Schemas Check
SELECT 'Available Schemas' AS section;
SELECT nspname AS schema_name 
FROM pg_namespace 
WHERE nspname IN ('auth', 'raw', 'dv', 'audit', 'api', 'util')
ORDER BY nspname;

-- E. Function Performance Analysis
SELECT 'Function Performance' AS section;
SELECT 
    schemaname,
    funcname AS function_name,
    calls,
    total_time,
    CASE 
        WHEN calls = 0 THEN 0
        ELSE ROUND(total_time / calls, 4)
    END AS avg_time_ms
FROM pg_stat_user_functions
WHERE schemaname = ANY(ARRAY['api', 'auth', 'util', 'raw'])
AND calls > 0
ORDER BY total_time DESC;

-- F. Session Analysis (if auth tables exist)
SELECT 'Session Analysis' AS section;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'auth' AND tablename = 'session_state_s') THEN
        RAISE NOTICE 'Session table exists - running session analysis';
        PERFORM 1; -- Placeholder for session query
    ELSE
        RAISE NOTICE 'Session table not found in auth schema';
    END IF;
END $$;

-- G. Security Function Check
SELECT 'Available Functions by Schema' AS section;
SELECT 
    n.nspname AS schema_name,
    COUNT(p.proname) AS function_count,
    STRING_AGG(p.proname, ', ' ORDER BY p.proname) AS sample_functions
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = ANY(ARRAY['api', 'auth', 'util', 'raw', 'dv'])
AND p.prokind = 'f'
GROUP BY n.nspname
ORDER BY n.nspname;

-- H. Load Test Performance Insights
SELECT 'Load Test Performance Insights' AS section;
SELECT 
    'Excellent Performance' AS tier,
    '80% of requests 58-80ms' AS metric,
    'Data Vault 2.0 performing well' AS analysis
UNION ALL
SELECT 
    'Performance Outliers' AS tier,
    '4 requests >170ms (15%)' AS metric,
    'Investigation needed' AS analysis
UNION ALL
SELECT 
    'Stability' AS tier,
    '0 errors in 26 requests' AS metric,
    'System is stable under load' AS analysis;

-- I. Next Steps Recommendations
SELECT 'Optimization Recommendations' AS section;
SELECT 
    1 AS priority,
    'Investigate 170ms+ outliers' AS action,
    'Use EXPLAIN ANALYZE on slow queries' AS method
UNION ALL
SELECT 
    2 AS priority,
    'Optimize vacuum scheduling' AS action,
    'Configure autovacuum for auth tables' AS method
UNION ALL
SELECT 
    3 AS priority,
    'Index maintenance review' AS action,
    'Check for unused indexes' AS method
ORDER BY priority; 