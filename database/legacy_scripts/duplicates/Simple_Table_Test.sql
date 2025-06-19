-- Simple test to isolate the tablename column error

-- Test 1: Basic system table access
SELECT 'Test 1: Basic pg_tables access' AS test_name;
SELECT schemaname, tablename FROM pg_tables WHERE schemaname = 'auth' LIMIT 3;

-- Test 2: Basic pg_stat_user_tables access  
SELECT 'Test 2: Basic pg_stat_user_tables access' AS test_name;
SELECT schemaname, relname FROM pg_stat_user_tables WHERE schemaname = 'auth' LIMIT 3;

-- Test 3: The problematic query from our script
SELECT 'Test 3: Our original query' AS test_name;
SELECT 
    schemaname,
    relname AS tablename,
    n_live_tup AS live_tuples
FROM pg_stat_user_tables 
WHERE schemaname IN ('auth', 'raw', 'dv', 'audit')
LIMIT 5; 