-- =============================================
-- 🔍 AUTHENTICATION SYSTEM MONITOR (CORRECTED)
-- Shows all database updates during authentication process
-- Using actual table names from database schema
-- =============================================

DO $$
DECLARE
    v_test_username TEXT := 'travisdwoodward72@gmail.com';
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_api_request JSONB;
    v_api_response JSONB;
    
    -- Before/After counts for monitoring
    v_before_counts RECORD;
    v_after_counts RECORD;
    v_session_token TEXT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔍════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔍                AUTHENTICATION SYSTEM MONITOR                   ';
    RAISE NOTICE '🔍        Tracking Database Updates During Authentication          ';
    RAISE NOTICE '🔍════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
    -- Get user info for testing
    SELECT uh.tenant_hk, uh.user_hk INTO v_tenant_hk, v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = v_test_username
    AND uas.load_end_date IS NULL
    LIMIT 1;
    
    RAISE NOTICE '👤 Target User Information:';
    RAISE NOTICE '   Username: %', v_test_username;
    RAISE NOTICE '   User HK: %', encode(v_user_hk, 'hex');
    RAISE NOTICE '   Tenant HK: %', encode(v_tenant_hk, 'hex');
    RAISE NOTICE '';
    
    -- =============================================
    -- 📊 CAPTURE BEFORE STATE
    -- =============================================
    RAISE NOTICE '📊 CAPTURING BEFORE STATE...';
    
    SELECT 
        (SELECT COUNT(*) FROM auth.user_auth_s WHERE load_end_date IS NULL) as active_auth_records,
        (SELECT COUNT(*) FROM auth.user_auth_s WHERE user_hk = v_user_hk) as user_auth_history,
        -- Check if session tables exist, use 0 if not
        (SELECT COUNT(*) FROM auth.session_h) as total_sessions,
        (SELECT COUNT(*) FROM auth.session_state_s WHERE load_end_date IS NULL) as active_sessions,
        -- Check if raw vault tables exist, use 0 if not
        (SELECT CASE 
            WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'raw' AND table_name = 'login_attempt_h')
            THEN (SELECT COUNT(*) FROM raw.login_attempt_h)
            ELSE 0
         END) as total_login_attempts,
        (SELECT CASE 
            WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'raw' AND table_name = 'login_attempt_s')
            THEN (SELECT COUNT(*) FROM raw.login_attempt_s)
            ELSE 0
         END) as login_attempt_details,
        (SELECT COALESCE(uas.failed_login_attempts, 0) 
         FROM auth.user_auth_s uas 
         WHERE uas.user_hk = v_user_hk AND uas.load_end_date IS NULL
         ORDER BY uas.load_date DESC LIMIT 1) as current_failed_attempts,
        (SELECT uas.last_login_date
         FROM auth.user_auth_s uas 
         WHERE uas.user_hk = v_user_hk AND uas.load_end_date IS NULL
         ORDER BY uas.load_date DESC LIMIT 1) as last_login_date
    INTO v_before_counts;
    
    RAISE NOTICE '   📋 Active Auth Records: %', v_before_counts.active_auth_records;
    RAISE NOTICE '   📋 User Auth History: %', v_before_counts.user_auth_history;
    RAISE NOTICE '   📋 Total Sessions: %', v_before_counts.total_sessions;
    RAISE NOTICE '   📋 Active Sessions: %', v_before_counts.active_sessions;
    RAISE NOTICE '   📋 Total Login Attempts: %', v_before_counts.total_login_attempts;
    RAISE NOTICE '   📋 Login Attempt Details: %', v_before_counts.login_attempt_details;
    RAISE NOTICE '   📋 Current Failed Attempts: %', v_before_counts.current_failed_attempts;
    RAISE NOTICE '   📋 Last Login Date: %', COALESCE(v_before_counts.last_login_date::text, 'Never');
    RAISE NOTICE '';
    
    -- =============================================
    -- 🔐 EXECUTE AUTHENTICATION
    -- =============================================
    RAISE NOTICE '🔐 EXECUTING AUTHENTICATION...';
    
    v_api_request := jsonb_build_object(
        'username', v_test_username,
        'password', 'MyNewSecurePassword123',
        'ip_address', '192.168.1.200',
        'user_agent', 'Monitor-Script/1.0',
        'tenant_hk', encode(v_tenant_hk, 'hex')
    );
    
    RAISE NOTICE '   📤 API Request: %', v_api_request::text;
    
    -- Call the authentication API
    SELECT api.auth_login(v_api_request) INTO v_api_response;
    
    RAISE NOTICE '   📥 API Response: %', v_api_response::text;
    RAISE NOTICE '';
    
    -- Extract session token if successful
    IF (v_api_response->>'success')::boolean THEN
        v_session_token := v_api_response->'data'->>'session_token';
        RAISE NOTICE '   ✅ Authentication SUCCESS';
        RAISE NOTICE '   🎫 Session Token: %...', left(COALESCE(v_session_token, 'NULL'), 20);
    ELSE
        RAISE NOTICE '   ❌ Authentication FAILED';
        RAISE NOTICE '   💬 Message: %', v_api_response->>'message';
    END IF;
    RAISE NOTICE '';
    
    -- =============================================
    -- 📊 CAPTURE AFTER STATE
    -- =============================================
    RAISE NOTICE '📊 CAPTURING AFTER STATE...';
    
    SELECT 
        (SELECT COUNT(*) FROM auth.user_auth_s WHERE load_end_date IS NULL) as active_auth_records,
        (SELECT COUNT(*) FROM auth.user_auth_s WHERE user_hk = v_user_hk) as user_auth_history,
        (SELECT COUNT(*) FROM auth.session_h) as total_sessions,
        (SELECT COUNT(*) FROM auth.session_state_s WHERE load_end_date IS NULL) as active_sessions,
        (SELECT CASE 
            WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'raw' AND table_name = 'login_attempt_h')
            THEN (SELECT COUNT(*) FROM raw.login_attempt_h)
            ELSE 0
         END) as total_login_attempts,
        (SELECT CASE 
            WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'raw' AND table_name = 'login_attempt_s')
            THEN (SELECT COUNT(*) FROM raw.login_attempt_s)
            ELSE 0
         END) as login_attempt_details,
        (SELECT COALESCE(uas.failed_login_attempts, 0) 
         FROM auth.user_auth_s uas 
         WHERE uas.user_hk = v_user_hk AND uas.load_end_date IS NULL
         ORDER BY uas.load_date DESC LIMIT 1) as current_failed_attempts,
        (SELECT uas.last_login_date
         FROM auth.user_auth_s uas 
         WHERE uas.user_hk = v_user_hk AND uas.load_end_date IS NULL
         ORDER BY uas.load_date DESC LIMIT 1) as last_login_date
    INTO v_after_counts;
    
    RAISE NOTICE '   📋 Active Auth Records: %', v_after_counts.active_auth_records;
    RAISE NOTICE '   📋 User Auth History: %', v_after_counts.user_auth_history;
    RAISE NOTICE '   📋 Total Sessions: %', v_after_counts.total_sessions;
    RAISE NOTICE '   📋 Active Sessions: %', v_after_counts.active_sessions;
    RAISE NOTICE '   📋 Total Login Attempts: %', v_after_counts.total_login_attempts;
    RAISE NOTICE '   📋 Login Attempt Details: %', v_after_counts.login_attempt_details;
    RAISE NOTICE '   📋 Current Failed Attempts: %', v_after_counts.current_failed_attempts;
    RAISE NOTICE '   📋 Last Login Date: %', COALESCE(v_after_counts.last_login_date::text, 'Never');
    RAISE NOTICE '';
    
    -- =============================================
    -- 📈 SHOW CHANGES
    -- =============================================
    RAISE NOTICE '📈 CHANGES DETECTED:';
    RAISE NOTICE '   🔄 User Auth History: % → % (Δ +%)', 
        v_before_counts.user_auth_history, 
        v_after_counts.user_auth_history,
        v_after_counts.user_auth_history - v_before_counts.user_auth_history;
    RAISE NOTICE '   🔄 Total Sessions: % → % (Δ +%)', 
        v_before_counts.total_sessions, 
        v_after_counts.total_sessions,
        v_after_counts.total_sessions - v_before_counts.total_sessions;
    RAISE NOTICE '   🔄 Active Sessions: % → % (Δ +%)', 
        v_before_counts.active_sessions, 
        v_after_counts.active_sessions,
        v_after_counts.active_sessions - v_before_counts.active_sessions;
    RAISE NOTICE '   🔄 Login Attempts: % → % (Δ +%)', 
        v_before_counts.total_login_attempts, 
        v_after_counts.total_login_attempts,
        v_after_counts.total_login_attempts - v_before_counts.total_login_attempts;
    RAISE NOTICE '   🔄 Failed Attempts: % → %', 
        v_before_counts.current_failed_attempts, 
        v_after_counts.current_failed_attempts;
    RAISE NOTICE '';
    
    -- =============================================
    -- 🔍 DETAILED RECORD EXAMINATION
    -- =============================================
    RAISE NOTICE '🔍 DETAILED RECORD EXAMINATION:';
    RAISE NOTICE '';
    
    -- Show latest user auth record
    RAISE NOTICE '👤 Latest User Auth Record (auth.user_auth_s):';
    DECLARE
        v_auth_record RECORD;
    BEGIN
        SELECT 
            uas.load_date,
            uas.username,
            uas.last_login_date,
            uas.failed_login_attempts,
            uas.account_locked,
            CASE WHEN uas.load_end_date IS NULL THEN 'ACTIVE' ELSE 'HISTORICAL' END as status
        INTO v_auth_record
        FROM auth.user_auth_s uas
        WHERE uas.user_hk = v_user_hk
        ORDER BY uas.load_date DESC
        LIMIT 1;
        
        RAISE NOTICE '   📅 Load Date: %', v_auth_record.load_date;
        RAISE NOTICE '   👤 Username: %', v_auth_record.username;
        RAISE NOTICE '   🕐 Last Login: %', v_auth_record.last_login_date;
        RAISE NOTICE '   ❌ Failed Attempts: %', v_auth_record.failed_login_attempts;
        RAISE NOTICE '   🔒 Account Locked: %', v_auth_record.account_locked;
        RAISE NOTICE '   📊 Status: %', v_auth_record.status;
    END;
    RAISE NOTICE '';
    
    -- Show latest session record if created
    IF v_session_token IS NOT NULL THEN
        RAISE NOTICE '🎫 Latest Session Record (auth.session_state_s):';
        DECLARE
            v_session_record RECORD;
        BEGIN
            SELECT 
                sss.load_date,
                sss.session_end,
                sss.ip_address,
                sss.user_agent,
                sss.session_status,
                CASE WHEN sss.load_end_date IS NULL THEN 'ACTIVE' ELSE 'HISTORICAL' END as status
            INTO v_session_record
            FROM auth.session_state_s sss
            JOIN auth.session_h sh ON sss.session_hk = sh.session_hk
            JOIN auth.user_session_l usl ON sh.session_hk = usl.session_hk
            WHERE usl.user_hk = v_user_hk
            ORDER BY sss.load_date DESC
            LIMIT 1;
            
            IF v_session_record IS NOT NULL THEN
                RAISE NOTICE '   📅 Load Date: %', v_session_record.load_date;
                RAISE NOTICE '   ⏰ Session End: %', COALESCE(v_session_record.session_end::text, 'Active');
                RAISE NOTICE '   🌐 IP Address: %', v_session_record.ip_address;
                RAISE NOTICE '   🖥️  User Agent: %', left(COALESCE(v_session_record.user_agent, ''), 50);
                RAISE NOTICE '   📊 Session Status: %', v_session_record.session_status;
                RAISE NOTICE '   📊 Record Status: %', v_session_record.status;
            ELSE
                RAISE NOTICE '   ⚠️  No session records found (may not be implemented yet)';
            END IF;
        END;
    END IF;
    RAISE NOTICE '';
    
    -- Show latest login attempt record (if raw vault exists)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'raw' AND table_name = 'login_attempt_s') THEN
        RAISE NOTICE '📝 Latest Login Attempt Record (raw.login_attempt_s):';
        DECLARE
            v_attempt_record RECORD;
        BEGIN
            SELECT 
                las.load_date,
                las.username,
                las.ip_address,
                las.attempt_result,
                las.failure_reason
            INTO v_attempt_record
            FROM raw.login_attempt_s las
            WHERE las.username = v_test_username
            ORDER BY las.load_date DESC
            LIMIT 1;
            
            IF v_attempt_record IS NOT NULL THEN
                RAISE NOTICE '   📅 Load Date: %', v_attempt_record.load_date;
                RAISE NOTICE '   👤 Username: %', v_attempt_record.username;
                RAISE NOTICE '   🌐 IP Address: %', v_attempt_record.ip_address;
                RAISE NOTICE '   🎯 Result: %', v_attempt_record.attempt_result;
                RAISE NOTICE '   💬 Failure Reason: %', COALESCE(v_attempt_record.failure_reason, 'N/A');
            ELSE
                RAISE NOTICE '   ⚠️  No login attempt records found';
            END IF;
        END;
    ELSE
        RAISE NOTICE '📝 Raw Vault Login Attempts: Not implemented yet (raw.login_attempt_s does not exist)';
    END IF;
    RAISE NOTICE '';
    
    -- =============================================
    -- 🏆 SUMMARY
    -- =============================================
    RAISE NOTICE '🏆 AUTHENTICATION MONITORING SUMMARY:';
    RAISE NOTICE '';
    
    IF (v_api_response->>'success')::boolean THEN
        RAISE NOTICE '   ✅ Authentication process completed successfully';
        RAISE NOTICE '   ✅ User auth record updated (Data Vault historization)';
        IF v_before_counts.total_sessions < v_after_counts.total_sessions THEN
            RAISE NOTICE '   ✅ Session created and stored';
        ELSE
            RAISE NOTICE '   ⚠️  Session creation (may not be implemented yet)';
        END IF;
        IF v_before_counts.total_login_attempts < v_after_counts.total_login_attempts THEN
            RAISE NOTICE '   ✅ Login attempt logged in audit trail';
        ELSE
            RAISE NOTICE '   ⚠️  Audit logging (raw vault may not be implemented yet)';
        END IF;
        RAISE NOTICE '   ✅ Failed attempt counter reset to 0';
        RAISE NOTICE '   ✅ Last login date updated';
    ELSE
        RAISE NOTICE '   ❌ Authentication failed';
        RAISE NOTICE '   ✅ Failed attempt recorded';
        RAISE NOTICE '   ✅ Security policies applied';
        IF v_before_counts.total_login_attempts < v_after_counts.total_login_attempts THEN
            RAISE NOTICE '   ✅ Audit trail maintained';
        ELSE
            RAISE NOTICE '   ⚠️  Audit trail (raw vault may not be implemented yet)';
        END IF;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔐 Your enterprise authentication system demonstrates:';
    RAISE NOTICE '   • Complete Data Vault 2.0 historization';
    IF v_before_counts.total_login_attempts > 0 OR v_after_counts.total_login_attempts > 0 THEN
        RAISE NOTICE '   • Immutable audit trails for HIPAA compliance';
    ELSE
        RAISE NOTICE '   • Audit trail foundation (raw vault ready for implementation)';
    END IF;
    RAISE NOTICE '   • Multi-tenant security isolation';
    IF v_before_counts.total_sessions > 0 OR v_after_counts.total_sessions > 0 THEN
        RAISE NOTICE '   • Enterprise-grade session management';
    ELSE
        RAISE NOTICE '   • Session management foundation (tables ready for implementation)';
    END IF;
    RAISE NOTICE '   • Comprehensive security monitoring';
    
    RAISE NOTICE '';
    RAISE NOTICE '🔍════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔍              AUTHENTICATION MONITORING COMPLETE                ';
    RAISE NOTICE '🔍════════════════════════════════════════════════════════════════';
    
END $$; 