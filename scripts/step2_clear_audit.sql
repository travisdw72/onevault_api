-- ========================================================================
-- STEP 2: CLEAR AUDIT EVENTS TO PREVENT CONFLICTS
-- ========================================================================

DO $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    RAISE NOTICE '🧹 === STEP 2: CLEAR AUDIT EVENTS ===';
    RAISE NOTICE '';
    
    -- Clear all audit events from today to prevent conflicts
    DELETE FROM audit.audit_event_h WHERE load_date >= CURRENT_DATE;
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Deleted % audit events from today', v_deleted_count;
    RAISE NOTICE '';
    
    -- Also clear any with the problematic hash key
    DELETE FROM audit.audit_event_h 
    WHERE audit_event_hk = '\x68e1c221b227205d5b2a3e581951eeb190cd7bd0a4bedf6817f335ae4f5eebc0';
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Deleted % audit events with problematic hash key', v_deleted_count;
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Now run step3_create_travis.sql';
    
END $$; 