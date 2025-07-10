-- step2_clear_audit_template.sql
-- Template for clearing audit conflicts during tenant setup
-- 
-- Usage Instructions:
-- 1. Copy this file to a new file (e.g., step2_clear_audit_onevault.sql)
-- 2. Replace {PLATFORM_NAME} with your platform name
-- 3. Run this script after tenant creation and before user creation
--
-- Required Replacements:
-- {PLATFORM_NAME} - Platform identifier (must match step1)

-- Clear audit conflicts that might interfere with user creation
RAISE NOTICE 'Clearing audit conflicts for platform: {PLATFORM_NAME}';

-- Remove any audit events for this platform from today
DELETE FROM audit.audit_event_h 
WHERE audit_event_bk LIKE '%{PLATFORM_NAME}%'
AND load_date >= CURRENT_DATE - INTERVAL '1 day';

-- Remove orphaned audit event satellites
DELETE FROM audit.audit_event_s 
WHERE audit_event_hk NOT IN (
    SELECT audit_event_hk FROM audit.audit_event_h
);

-- Clean up any duplicate hash conflicts
DELETE FROM audit.audit_event_h a1
USING audit.audit_event_h a2
WHERE a1.audit_event_hk = a2.audit_event_hk
AND a1.load_date < a2.load_date
AND a1.audit_event_bk LIKE '%{PLATFORM_NAME}%';

RAISE NOTICE '✅ Audit conflicts cleared for {PLATFORM_NAME}';

-- Verify cleanup
SELECT 
    'Audit Cleanup Verification' as check_type,
    COUNT(*) as remaining_events
FROM audit.audit_event_h 
WHERE audit_event_bk LIKE '%{PLATFORM_NAME}%'
AND load_date >= CURRENT_DATE - INTERVAL '1 day'; 