-- ========================================================================
-- AUDIT HASH KEY COLLISION DIAGNOSTIC
-- ========================================================================
-- Let's figure out what's causing the duplicate audit_event_h_pkey issue

-- Check current audit events
SELECT 
    encode(audit_event_hk, 'hex') as audit_event_hk_hex,
    load_date,
    record_source,
    audit_event_bk
FROM audit.audit_event_h 
ORDER BY load_date DESC 
LIMIT 10;

-- Check if there are any audit events from today
SELECT COUNT(*) as todays_audit_events
FROM audit.audit_event_h 
WHERE load_date >= CURRENT_DATE;

-- Try to understand the hash key generation
-- Let's see what the register_user procedure definition looks like
\df+ auth.register_user

-- Check what's in the audit schema
\dt audit.* 