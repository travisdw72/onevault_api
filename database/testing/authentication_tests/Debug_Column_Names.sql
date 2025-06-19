-- Debug script to identify correct column names in PostgreSQL system tables

-- Check columns in pg_stat_user_tables
SELECT 'pg_stat_user_tables columns:' AS table_info;
\d pg_stat_user_tables

-- Check columns in pg_stat_user_indexes  
SELECT 'pg_stat_user_indexes columns:' AS table_info;
\d pg_stat_user_indexes

-- Test basic queries to see what works
SELECT 'Basic pg_stat_user_tables test:' AS test_info;
SELECT schemaname, relname FROM pg_stat_user_tables LIMIT 3;

SELECT 'Basic pg_stat_user_indexes test:' AS test_info;  
SELECT schemaname, relname, indexrelname FROM pg_stat_user_indexes LIMIT 3; 