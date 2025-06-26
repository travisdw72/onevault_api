-- =============================================================================
-- Rollback: V015__rollback_secure_tenant_isolated_auth.sql
-- Description: SAFELY rollback tenant-isolated authentication security enhancement
-- Author: OneVault Security Team
-- Date: 2025-06-26
-- CRITICAL WARNING: This rollback RESTORES the cross-tenant vulnerability!
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '🔄 Starting SECURITY ROLLBACK V015: Tenant-Isolated Authentication';
    RAISE WARNING '⚠️  WARNING: This rollback will RESTORE the cross-tenant login vulnerability!';
    RAISE WARNING '⚠️  Only proceed if absolutely necessary and with security team approval!';
    
    INSERT INTO util.migration_log (
        migration_version,
        migration_name,
        migration_type,
        started_at,
        executed_by
    ) VALUES (
        'V015',
        'rollback_secure_tenant_isolated_auth',
        'ROLLBACK',
        CURRENT_TIMESTAMP,
        SESSION_USER
    );
END $$;

-- 1. PRE-ROLLBACK SECURITY VALIDATION
DO $$
DECLARE
    v_active_sessions INTEGER;
    v_recent_logins INTEGER;
    v_dependent_objects INTEGER;
BEGIN
    -- Check for active sessions using new security features
    SELECT COUNT(*) INTO v_active_sessions
    FROM audit.auth_success_s 
    WHERE auth_method = 'SECURE_TENANT_LOGIN'
    AND load_date > CURRENT_TIMESTAMP - INTERVAL '1 hour';
    
    -- Check for recent security incidents that might be blocked by rollback
    SELECT COUNT(*) INTO v_recent_logins
    FROM audit.security_incident_s
    WHERE incident_type = 'CROSS_TENANT_LOGIN_ATTEMPT'
    AND incident_timestamp > CURRENT_TIMESTAMP - INTERVAL '24 hours';
    
    -- Check for dependent application code
    SELECT COUNT(*) INTO v_dependent_objects
    FROM information_schema.routines
    WHERE routine_body LIKE '%auth_login_secure%'
    OR routine_body LIKE '%validate_login_credentials_secure%';
    
    RAISE NOTICE '🔍 SECURITY ROLLBACK VALIDATION:';
    RAISE NOTICE '   Active secure sessions: %', v_active_sessions;
    RAISE NOTICE '   Recent blocked attacks: %', v_recent_logins;
    RAISE NOTICE '   Dependent objects: %', v_dependent_objects;
    
    IF v_active_sessions > 0 THEN
        RAISE WARNING '⚠️  Found % active sessions using secure authentication!', v_active_sessions;
        RAISE WARNING '⚠️  These sessions may be invalidated by rollback!';
    END IF;
    
    IF v_recent_logins > 0 THEN
        RAISE WARNING '🚨 CRITICAL: % cross-tenant attacks were blocked in last 24 hours!', v_recent_logins;
        RAISE WARNING '🚨 Rolling back will allow these attacks to succeed!';
    END IF;
    
    IF v_dependent_objects > 0 THEN
        RAISE WARNING '⚠️  Found % dependent objects that may break after rollback!', v_dependent_objects;
    END IF;
END $$;

-- 2. OPTIONAL SECURITY DATA BACKUP
DO $$
DECLARE
    v_backup_table_name TEXT;
    v_audit_records INTEGER;
    v_security_incidents INTEGER;
BEGIN
    -- Create timestamped backup tables for security audit data
    v_backup_table_name := 'security_audit_backup_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    
    -- Backup successful secure authentications
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'audit' AND table_name = 'auth_success_s') THEN
        
        EXECUTE format('CREATE TABLE audit.%I AS 
                       SELECT * FROM audit.auth_success_s 
                       WHERE auth_method = ''SECURE_TENANT_LOGIN''', 
                       'auth_success_' || v_backup_table_name);
        
        EXECUTE format('SELECT COUNT(*) FROM audit.%I', 
                       'auth_success_' || v_backup_table_name) INTO v_audit_records;
        
        RAISE NOTICE '💾 Backed up % secure authentication records', v_audit_records;
    END IF;
    
    -- Backup security incidents
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'audit' AND table_name = 'security_incident_s') THEN
        
        EXECUTE format('CREATE TABLE audit.%I AS 
                       SELECT * FROM audit.security_incident_s 
                       WHERE incident_type = ''CROSS_TENANT_LOGIN_ATTEMPT''', 
                       'security_incidents_' || v_backup_table_name);
        
        EXECUTE format('SELECT COUNT(*) FROM audit.%I', 
                       'security_incidents_' || v_backup_table_name) INTO v_security_incidents;
        
        RAISE NOTICE '💾 Backed up % security incident records', v_security_incidents;
    END IF;
    
    -- Log backup information
    INSERT INTO util.rollback_backup_log (
        migration_version,
        backup_type,
        backup_name,
        record_count,
        created_at
    ) VALUES 
    ('V015', 'SECURITY_AUDIT', 'auth_success_' || v_backup_table_name, v_audit_records, CURRENT_TIMESTAMP),
    ('V015', 'SECURITY_INCIDENTS', 'security_incidents_' || v_backup_table_name, v_security_incidents, CURRENT_TIMESTAMP);
    
END $$;

-- 3. REMOVE SECURE FUNCTIONS (Newest first)
-- Remove secure API function
DROP FUNCTION IF EXISTS api.auth_login_secure(JSONB) CASCADE;
RAISE NOTICE '🗑️  Removed function: api.auth_login_secure';

-- Remove secure validation function
DROP FUNCTION IF EXISTS staging.validate_login_credentials_secure(BYTEA, BYTEA) CASCADE;
RAISE NOTICE '🗑️  Removed function: staging.validate_login_credentials_secure';

-- 4. RESTORE ORIGINAL AUTH PROCEDURE
DO $$
DECLARE
    v_original_function TEXT;
BEGIN
    -- Attempt to restore from backup
    SELECT backup_data INTO v_original_function
    FROM util.migration_backup
    WHERE migration_version = 'V015'
    AND object_type = 'PROCEDURE'
    AND object_name = 'auth.login_user';
    
    IF v_original_function IS NOT NULL THEN
        -- Execute the original function definition
        EXECUTE v_original_function;
        RAISE NOTICE '✅ Restored original auth.login_user from backup';
    ELSE
        -- Fallback: Create basic version if backup doesn't exist
        RAISE WARNING '⚠️  No backup found - creating fallback version';
        
        -- Create minimal functional version (INSECURE - for emergency only)
        EXECUTE $RESTORE$
            CREATE OR REPLACE PROCEDURE auth.login_user(
                IN p_username character varying,
                IN p_password text,
                IN p_ip_address inet,
                IN p_user_agent text,
                OUT p_success boolean,
                OUT p_message text,
                OUT p_tenant_list jsonb,
                OUT p_session_token text,
                OUT p_user_data jsonb,
                IN p_auto_login boolean DEFAULT true
            )
            LANGUAGE 'plpgsql'
            SECURITY DEFINER 
            AS $BODY$
            DECLARE
                v_tenant_hk BYTEA;
                v_login_attempt_hk BYTEA;
                v_user_hk BYTEA;
                v_validation_result JSONB;
            BEGIN
                -- Initialize outputs
                p_success := FALSE;
                p_message := 'Authentication failed';
                p_tenant_list := NULL;
                p_session_token := NULL;
                p_user_data := NULL;

                -- Get system tenant for validation (INSECURE - any tenant)
                SELECT tenant_hk INTO v_tenant_hk
                FROM auth.tenant_h
                LIMIT 1;
                
                IF v_tenant_hk IS NULL THEN
                    p_message := 'No tenant available for authentication';
                    RETURN;
                END IF;
                
                -- Record login attempt
                v_login_attempt_hk := raw.capture_login_attempt(
                    v_tenant_hk,
                    p_username,
                    p_password,
                    p_ip_address,
                    p_user_agent
                );
                
                -- Validate credentials (INSECURE - cross-tenant possible)
                v_validation_result := staging.validate_login_credentials(v_login_attempt_hk);
                
                -- Process results
                IF (v_validation_result->>'status') != 'VALID' THEN
                    p_success := FALSE;
                    p_message := CASE 
                        WHEN (v_validation_result->>'status') = 'INVALID_USER' THEN 'User not found'
                        WHEN (v_validation_result->>'status') = 'INVALID_PASSWORD' THEN 'Invalid password'
                        WHEN (v_validation_result->>'status') = 'LOCKED' THEN 'Account is locked'
                        ELSE 'Login failed'
                    END;
                    RETURN;
                END IF;
                
                -- Success!
                p_success := TRUE;
                p_message := 'Authentication successful';
                v_user_hk := decode(v_validation_result->>'user_hk', 'hex');
                
                -- Get tenant list for this user (INSECURE - all tenants)
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'tenant_id', t.tenant_bk,
                        'tenant_name', COALESCE(tps.tenant_name, t.tenant_bk)
                    )
                ) INTO p_tenant_list
                FROM auth.user_h u
                JOIN auth.tenant_h t ON u.tenant_hk = t.tenant_hk
                LEFT JOIN auth.tenant_profile_s tps ON t.tenant_hk = tps.tenant_hk 
                    AND tps.load_end_date IS NULL
                WHERE u.user_hk = v_user_hk;
                
                -- If single tenant, auto-create session
                IF p_auto_login AND jsonb_array_length(p_tenant_list) = 1 THEN
                    -- Create session token
                    p_session_token := encode(gen_random_bytes(32), 'hex');
                    
                    -- Get user data
                    SELECT jsonb_build_object(
                        'user_id', u.user_bk,
                        'email', uas.username,
                        'first_name', COALESCE(ups.first_name, ''),
                        'last_name', COALESCE(ups.last_name, '')
                    ) INTO p_user_data
                    FROM auth.user_h u
                    JOIN auth.user_auth_s uas ON u.user_hk = uas.user_hk
                    LEFT JOIN auth.user_profile_s ups ON u.user_hk = ups.user_hk
                    WHERE u.user_hk = v_user_hk
                    AND uas.load_end_date IS NULL
                    AND (ups.load_end_date IS NULL OR ups.load_end_date IS NULL);
                END IF;
                
            EXCEPTION WHEN OTHERS THEN
                p_success := FALSE;
                p_message := 'System error during authentication';
            END;
            $BODY$;
        $RESTORE$;
        
        RAISE WARNING '🚨 CRITICAL: Restored INSECURE version of auth.login_user!';
        RAISE WARNING '🚨 Cross-tenant login vulnerability is now ACTIVE!';
    END IF;
END $$;

-- 5. CLEAN UP SECURITY ENHANCEMENTS
DO $$
BEGIN
    -- Remove security-related permissions
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user') THEN
        -- Note: Cannot selectively revoke, permissions will be reset by restored function
        RAISE NOTICE 'ℹ️  Security permissions reset by function restoration';
    END IF;
    
    -- Log security rollback
    INSERT INTO audit.security_rollback_s (
        rollback_hk,
        migration_version,
        rollback_reason,
        security_impact,
        rollback_timestamp,
        executed_by,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary('V015_ROLLBACK_' || CURRENT_TIMESTAMP::text),
        'V015',
        'Security enhancement rollback executed',
        'CRITICAL: Cross-tenant login vulnerability restored',
        CURRENT_TIMESTAMP,
        SESSION_USER,
        util.current_load_date(),
        'SECURITY_ROLLBACK'
    );
    
    RAISE NOTICE '🔒 Security rollback logged for audit trail';
END $$;

-- 6. ROLLBACK VALIDATION AND COMPLETION
DO $$
DECLARE
    v_secure_functions_removed BOOLEAN;
    v_original_function_restored BOOLEAN;
    v_security_functions_count INTEGER;
BEGIN
    -- Validate secure functions were removed
    SELECT NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE (n.nspname = 'api' AND p.proname = 'auth_login_secure')
        OR (n.nspname = 'staging' AND p.proname = 'validate_login_credentials_secure')
    ) INTO v_secure_functions_removed;
    
    -- Validate original function was restored
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'auth' AND p.proname = 'login_user'
        AND array_length(p.proargtypes, 1) = 6  -- Original parameter count
    ) INTO v_original_function_restored;
    
    -- Count any remaining security functions
    SELECT COUNT(*) INTO v_security_functions_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE (p.proname LIKE '%secure%' OR p.proname LIKE '%tenant_isolated%')
    AND n.nspname IN ('auth', 'api', 'staging');
    
    RAISE NOTICE '🔄 SECURITY ROLLBACK VALIDATION:';
    RAISE NOTICE '   Secure functions removed: %', 
                 CASE WHEN v_secure_functions_removed THEN '✅ SUCCESS' ELSE '❌ FAILED' END;
    RAISE NOTICE '   Original function restored: %', 
                 CASE WHEN v_original_function_restored THEN '✅ SUCCESS' ELSE '❌ FAILED' END;
    RAISE NOTICE '   Remaining security functions: %', v_security_functions_count;
    
    IF v_secure_functions_removed AND v_original_function_restored THEN
        RAISE NOTICE '✅ SECURITY ROLLBACK V015 COMPLETED';
        
        UPDATE util.migration_log 
        SET completed_at = CURRENT_TIMESTAMP,
            status = 'SUCCESS'
        WHERE migration_version = 'V015' AND migration_type = 'ROLLBACK';
        
        -- CRITICAL SECURITY WARNINGS
        RAISE WARNING '';
        RAISE WARNING '🚨🚨🚨 CRITICAL SECURITY ALERT 🚨🚨🚨';
        RAISE WARNING '==========================================';
        RAISE WARNING '⚠️  CROSS-TENANT LOGIN VULNERABILITY IS NOW ACTIVE!';
        RAISE WARNING '⚠️  Users can potentially login to wrong tenants!';
        RAISE WARNING '⚠️  Enhanced security features have been REMOVED!';
        RAISE WARNING '⚠️  Immediate security review and re-deployment recommended!';
        RAISE WARNING '';
        RAISE WARNING '📋 REQUIRED ACTIONS:';
        RAISE WARNING '   1. Review why rollback was necessary';
        RAISE WARNING '   2. Fix any issues that caused rollback';
        RAISE WARNING '   3. Re-deploy security enhancement ASAP';
        RAISE WARNING '   4. Monitor for cross-tenant login attempts';
        RAISE WARNING '   5. Notify security team immediately';
        RAISE WARNING '';
        
    ELSE
        RAISE EXCEPTION '❌ SECURITY ROLLBACK VALIDATION FAILED!';
    END IF;
END $$; 