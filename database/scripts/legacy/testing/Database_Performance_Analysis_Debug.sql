-- =============================================================================
-- Database Performance Analysis DEBUG Version
-- Purpose: Run each section separately to identify the tablename error
-- =============================================================================

-- SECTION 1: Check what columns exist in system tables
SELECT 'Available columns in pg_stat_user_tables:' AS debug_info;
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'pg_stat_user_tables' 
AND table_schema = 'information_schema'
ORDER BY column_name;

-- SECTION 2: Check pg_stat_user_indexes columns
SELECT 'Available columns in pg_stat_user_indexes:' AS debug_info;
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'pg_stat_user_indexes' 
AND table_schema = 'information_schema'
ORDER BY column_name;

-- SECTION 3: Test basic pg_stat_user_tables query
SELECT 'Testing basic pg_stat_user_tables access:' AS debug_info;
SELECT schemaname, relname 
FROM pg_stat_user_tables 
LIMIT 5;

-- SECTION 4: Test basic pg_stat_user_indexes query  
SELECT 'Testing basic pg_stat_user_indexes access:' AS debug_info;
SELECT schemaname, relname, indexrelname
FROM pg_stat_user_indexes 
LIMIT 5;

-- SECTION 1: Response Time Analysis (Safe - no system tables)
SELECT 'Running Section 1: Response Time Analysis' AS debug_info;

WITH response_time_analysis AS (
    SELECT 
        'Database Load Test Analysis' AS test_name,
        26 AS total_requests,
        0 AS errors,
        31 AS duration_seconds,
        ROUND(26.0 / 31.0, 2) AS requests_per_second
),
performance_tiers AS (
    SELECT 
        'Excellent (< 60ms)' AS tier,
        1 AS count,
        ROUND(1.0 / 26.0 * 100, 1) AS percentage
    UNION ALL
    SELECT 
        'Good (60-80ms)' AS tier,
        15 AS count,
        ROUND(15.0 / 26.0 * 100, 1) AS percentage
    UNION ALL
    SELECT 
        'Acceptable (80-100ms)' AS tier,
        6 AS count,
        ROUND(6.0 / 26.0 * 100, 1) AS percentage
    UNION ALL
    SELECT 
        'Concerning (> 170ms)' AS tier,
        4 AS count,
        ROUND(4.0 / 26.0 * 100, 1) AS percentage
)
SELECT * FROM response_time_analysis
UNION ALL
SELECT 
    tier AS test_name,
    count AS total_requests,
    0 AS errors,
    0 AS duration_seconds,
    percentage AS requests_per_second
FROM performance_tiers;

-- SECTION 2A: Connection Pool Status (Test system table access)
SELECT 'Running Section 2A: Connection Pool Status' AS debug_info;

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

-- SECTION 2B: Table Statistics (This is likely where the error occurs)
SELECT 'Running Section 2B: Table Statistics - Testing column names' AS debug_info;

-- First, let's see what columns are actually available in pg_stat_user_tables
SELECT 'Available columns in pg_stat_user_tables:' AS debug_info;
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'pg_stat_user_tables' 
ORDER BY column_name;

-- Now let's test the actual query with correct column names
SELECT 'Running corrected table statistics query:' AS debug_info;

SELECT 
    schemaname,
    relname AS tablename,  -- relname is correct for pg_stat_user_tables
    n_tup_ins AS inserts,
    n_tup_upd AS updates,
    n_tup_del AS deletes,
    n_live_tup AS live_tuples,
    n_dead_tup AS dead_tuples,
    ROUND(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 2) AS dead_tuple_ratio,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables 
WHERE schemaname IN ('auth', 'raw', 'dv', 'audit')
ORDER BY dead_tuple_ratio DESC NULLS LAST;

-- SECTION 2C: Index Usage Analysis
SELECT 'Running Section 2C: Index Usage Analysis - Testing column names' AS debug_info;

-- Check available columns in pg_stat_user_indexes
SELECT 'Available columns in pg_stat_user_indexes:' AS debug_info;
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'pg_stat_user_indexes' 
ORDER BY column_name;

-- Test the index query with correct column names
SELECT 'Running corrected index statistics query:' AS debug_info;

SELECT 
    schemaname,
    relname AS tablename,       -- This should be correct
    indexrelname AS indexname,  -- This should be correct
    idx_tup_read,
    idx_tup_fetch,
    CASE 
        WHEN idx_tup_read = 0 THEN 'UNUSED INDEX'
        WHEN idx_tup_fetch::numeric / idx_tup_read < 0.1 THEN 'LOW EFFICIENCY'
        ELSE 'GOOD'
    END AS index_status
FROM pg_stat_user_indexes 
WHERE schemaname IN ('auth', 'raw', 'dv', 'audit')
ORDER BY idx_tup_read DESC;

-- SECTION 3: Function Performance (Test pg_stat_user_functions)
SELECT 'Running Section 3: Function Performance Analysis' AS debug_info;

-- Check what columns are available in pg_stat_user_functions
SELECT 'Available columns in pg_stat_user_functions:' AS debug_info;
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'pg_stat_user_functions' 
ORDER BY column_name;

-- Test function performance query
SELECT 
    schemaname,
    funcname,
    calls,
    total_time,
    ROUND(total_time / NULLIF(calls, 0), 4) AS avg_time_ms,
    ROUND(total_time / NULLIF((SELECT SUM(total_time) FROM pg_stat_user_functions), 0) * 100, 2) AS pct_total_time
FROM pg_stat_user_functions
WHERE schemaname IN ('api', 'auth', 'util', 'raw')
ORDER BY total_time DESC; 