-- ============================================================================
-- CHECK BUSINESS TABLE STRUCTURE
-- Site Tracking System Debugging
-- ============================================================================
-- Purpose: Examine actual column structure of business tables
-- Issue: business.site_event_h missing expected "event_hk" column
-- ============================================================================

\echo '🔍 CHECKING BUSINESS TABLE COLUMN STRUCTURE...'

-- 1. Check site_event_h table structure
\echo '📋 SITE_EVENT_H TABLE STRUCTURE:'
SELECT 
    '📋 site_event_h COLUMNS' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default,
    ordinal_position
FROM information_schema.columns
WHERE table_schema = 'business' 
  AND table_name = 'site_event_h'
ORDER BY ordinal_position;

-- 2. Check site_session_h table structure
\echo '📋 SITE_SESSION_H TABLE STRUCTURE:'
SELECT 
    '📋 site_session_h COLUMNS' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default,
    ordinal_position
FROM information_schema.columns
WHERE table_schema = 'business' 
  AND table_name = 'site_session_h'
ORDER BY ordinal_position;

-- 3. Check site_visitor_h table structure
\echo '📋 SITE_VISITOR_H TABLE STRUCTURE:'
SELECT 
    '📋 site_visitor_h COLUMNS' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default,
    ordinal_position
FROM information_schema.columns
WHERE table_schema = 'business' 
  AND table_name = 'site_visitor_h'
ORDER BY ordinal_position;

-- 4. Check site_page_h table structure
\echo '📋 SITE_PAGE_H TABLE STRUCTURE:'
SELECT 
    '📋 site_page_h COLUMNS' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default,
    ordinal_position
FROM information_schema.columns
WHERE table_schema = 'business' 
  AND table_name = 'site_page_h'
ORDER BY ordinal_position;

-- 5. Check one satellite table structure
\echo '📋 SITE_EVENT_DETAILS_S TABLE STRUCTURE:'
SELECT 
    '📋 site_event_details_s COLUMNS' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default,
    ordinal_position
FROM information_schema.columns
WHERE table_schema = 'business' 
  AND table_name = 'site_event_details_s'
ORDER BY ordinal_position;

-- 6. Check for any Data Vault 2.0 pattern columns across all business tables
\echo '📋 DATA VAULT 2.0 PATTERN CHECK:'
SELECT 
    '📋 DV2.0 PATTERN CHECK' as check_type,
    table_name,
    column_name,
    CASE 
        WHEN column_name LIKE '%_hk' THEN '✅ Hash Key Column'
        WHEN column_name LIKE '%_bk' THEN '✅ Business Key Column'
        WHEN column_name = 'load_date' THEN '✅ Load Date Column'
        WHEN column_name = 'record_source' THEN '✅ Record Source Column'
        WHEN column_name = 'tenant_hk' THEN '✅ Tenant Hash Key'
        ELSE '❓ Other Column'
    END as dv_pattern
FROM information_schema.columns
WHERE table_schema = 'business' 
  AND table_name LIKE 'site_%'
  AND (column_name LIKE '%_hk' 
       OR column_name LIKE '%_bk' 
       OR column_name IN ('load_date', 'record_source', 'tenant_hk'))
ORDER BY table_name, column_name;

-- 7. Check table creation timestamps to understand deployment
\echo '📋 TABLE CREATION ANALYSIS:'
SELECT 
    '📋 TABLE CREATION INFO' as info_type,
    schemaname,
    tablename,
    hasindexes,
    hasrules,
    hastriggers
FROM pg_tables 
WHERE schemaname = 'business' 
  AND tablename LIKE 'site_%'
ORDER BY tablename;

-- 8. Show actual table definitions (first few lines)
\echo '📋 SAMPLE TABLE DEFINITION:'
SELECT 
    '📋 SITE_EVENT_H DEFINITION' as definition_type,
    'Use \\d business.site_event_h in psql to see full definition' as instruction;

\echo ''
\echo '🎯 STRUCTURE ANALYSIS COMPLETE!'
\echo ''
\echo '📋 WHAT TO LOOK FOR:'
\echo '   1. Expected DV2.0 columns: event_hk, event_bk, tenant_hk, load_date, record_source'
\echo '   2. Missing hash key columns (_hk suffix)'
\echo '   3. Missing business key columns (_bk suffix)'
\echo '   4. Wrong table structure (non-DV2.0 format)'
\echo ''
\echo '🔧 LIKELY ISSUE:'
\echo '   - Tables exist but are not Data Vault 2.0 format'
\echo '   - Old table structure from previous deployment'
\echo '   - Need to drop and recreate with correct DV2.0 structure' 