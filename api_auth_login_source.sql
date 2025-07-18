                                                          pg_get_functiondef                                                          
--------------------------------------------------------------------------------------------------------------------------------------
 CREATE OR REPLACE FUNCTION api.auth_login(p_request jsonb)                                                                          +
  RETURNS jsonb                                                                                                                      +
  LANGUAGE plpgsql                                                                                                                   +
  SECURITY DEFINER                                                                                                                   +
 AS $function$                                                                                                                       +
 DECLARE                                                                                                                             +
     v_username VARCHAR(255);                                                                                                        +
     v_password TEXT;                                                                                                                +
     v_ip_address INET;                                                                                                              +
     v_user_agent TEXT;                                                                                                              +
     v_auto_login BOOLEAN;                                                                                                           +
                                                                                                                                     +
     v_tenant_hk BYTEA;                                                                                                              +
     v_user_hk BYTEA;                                                                                                                +
     v_user_auth RECORD;                                                                                                             +
     v_session_hk BYTEA;                                                                                                             +
     v_session_bk VARCHAR(255);                                                                                                      +
     v_session_token TEXT;                                                                                                           +
                                                                                                                                     +
     -- Session and profile variables                                                                                                +
     v_session_expires TIMESTAMP WITH TIME ZONE;                                                                                     +
     v_profile_data JSONB;                                                                                                           +
                                                                                                                                     +
     v_tenant_list JSONB;                                                                                                            +
     v_user_data JSONB;                                                                                                              +
     v_user_roles JSONB;                                                                                                             +
     v_credentials_valid BOOLEAN := FALSE;                                                                                           +
     v_stored_hash TEXT;                                                                                                             +
                                                                                                                                     +
     -- Security logging variables                                                                                                   +
     v_security_event_hk BYTEA;                                                                                                      +
 BEGIN                                                                                                                               +
     -- Extract parameters from JSON request                                                                                         +
     v_username := p_request->>'username';                                                                                           +
     v_password := p_request->>'password';                                                                                           +
     v_ip_address := (p_request->>'ip_address')::INET;                                                                               +
     v_user_agent := p_request->>'user_agent';                                                                                       +
     v_auto_login := COALESCE((p_request->>'auto_login')::BOOLEAN, TRUE);                                                            +
                                                                                                                                     +
     -- Validate required parameters                                                                                                 +
     IF v_username IS NULL OR v_password IS NULL THEN                                                                                +
         -- LOG: Invalid request                                                                                                     +
         PERFORM audit.log_security_event(                                                                                           +
             'INVALID_LOGIN_REQUEST',                                                                                                +
             'MEDIUM',                                                                                                               +
             'Login request missing required credentials',                                                                           +
             COALESCE(v_ip_address, '0.0.0.0'::inet),                                                                                +
             COALESCE(v_user_agent, 'Unknown'),                                                                                      +
             NULL,                                                                                                                   +
             'MEDIUM',                                                                                                               +
             jsonb_build_object(                                                                                                     +
                 'username_provided', (v_username IS NOT NULL),                                                                      +
                 'password_provided', (v_password IS NOT NULL),                                                                      +
                 'timestamp', NOW()                                                                                                  +
             )                                                                                                                       +
         );                                                                                                                          +
                                                                                                                                     +
         RETURN jsonb_build_object(                                                                                                  +
             'success', false,                                                                                                       +
             'message', 'Username and password are required',                                                                        +
             'error_code', 'MISSING_CREDENTIALS'                                                                                     +
         );                                                                                                                          +
     END IF;                                                                                                                         +
                                                                                                                                     +
     -- STEP 1: Find user and get current account status                                                                             +
     SELECT                                                                                                                          +
         uh.user_hk,                                                                                                                 +
         uh.tenant_hk,                                                                                                               +
         uas.password_hash,                                                                                                          +
         uas.password_salt,                                                                                                          +
         uas.username,                                                                                                               +
         uas.account_locked,                                                                                                         +
         uas.account_locked_until,                                                                                                   +
         uas.failed_login_attempts,                                                                                                  +
         uas.last_login_date,                                                                                                        +
         uas.password_last_changed,                                                                                                  +
         uas.must_change_password,                                                                                                   +
         uas.password_reset_token,                                                                                                   +
         uas.password_reset_expiry,                                                                                                  +
         uas.load_date                                                                                                               +
     INTO v_user_auth                                                                                                                +
     FROM auth.user_h uh                                                                                                             +
     JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk                                                                           +
     WHERE uas.username = v_username                                                                                                 +
     AND uas.load_end_date IS NULL                                                                                                   +
     ORDER BY uas.load_date DESC                                                                                                     +
     LIMIT 1;                                                                                                                        +
                                                                                                                                     +
     -- Check if user exists                                                                                                         +
     IF v_user_auth.user_hk IS NULL THEN                                                                                             +
         -- LOG: User not found                                                                                                      +
         PERFORM audit.log_security_event(                                                                                           +
             'FAILED_LOGIN_USER_NOT_FOUND',                                                                                          +
             'MEDIUM',                                                                                                               +
             'Login attempt for non-existent user: ' || v_username,                                                                  +
             v_ip_address,                                                                                                           +
             v_user_agent,                                                                                                           +
             NULL,                                                                                                                   +
             'MEDIUM',                                                                                                               +
             jsonb_build_object(                                                                                                     +
                 'username', v_username,                                                                                             +
                 'timestamp', NOW(),                                                                                                 +
                 'reason', 'user_not_found'                                                                                          +
             )                                                                                                                       +
         );                                                                                                                          +
                                                                                                                                     +
         RETURN jsonb_build_object(                                                                                                  +
             'success', false,                                                                                                       +
             'message', 'Invalid username or password',                                                                              +
             'error_code', 'INVALID_CREDENTIALS'                                                                                     +
         );                                                                                                                          +
     END IF;                                                                                                                         +
                                                                                                                                     +
     -- Get user context                                                                                                             +
     v_user_hk := v_user_auth.user_hk;                                                                                               +
     v_tenant_hk := v_user_auth.tenant_hk;                                                                                           +
                                                                                                                                     +
     -- Check if account is currently locked                                                                                         +
     IF v_user_auth.account_locked AND                                                                                               +
        v_user_auth.account_locked_until IS NOT NULL AND                                                                             +
        v_user_auth.account_locked_until > CURRENT_TIMESTAMP THEN                                                                    +
                                                                                                                                     +
         -- LOG: Account locked access attempt                                                                                       +
         PERFORM audit.log_security_event(                                                                                           +
             'LOCKED_ACCOUNT_ACCESS_ATTEMPT',                                                                                        +
             'HIGH',                                                                                                                 +
             'Login attempt on locked account: ' || v_username,                                                                      +
             v_ip_address,                                                                                                           +
             v_user_agent,                                                                                                           +
             v_user_hk,                                                                                                              +
             'HIGH',                                                                                                                 +
             jsonb_build_object(                                                                                                     +
                 'username', v_username,                                                                                             +
                 'locked_until', v_user_auth.account_locked_until,                                                                   +
                 'timestamp', NOW()                                                                                                  +
             )                                                                                                                       +
         );                                                                                                                          +
                                                                                                                                     +
         RETURN jsonb_build_object(                                                                                                  +
             'success', false,                                                                                                       +
             'message', 'Account is temporarily locked due to multiple failed login attempts',                                       +
             'error_code', 'ACCOUNT_LOCKED',                                                                                         +
             'data', jsonb_build_object(                                                                                             +
                 'locked_until', v_user_auth.account_locked_until,                                                                   +
                 'retry_after_minutes', CEIL(EXTRACT(EPOCH FROM (v_user_auth.account_locked_until - CURRENT_TIMESTAMP))/60)          +
             )                                                                                                                       +
         );                                                                                                                          +
     END IF;                                                                                                                         +
                                                                                                                                     +
     -- STEP 2: Validate password                                                                                                    +
     IF v_user_auth.password_hash IS NOT NULL THEN                                                                                   +
         BEGIN                                                                                                                       +
             v_stored_hash := convert_from(v_user_auth.password_hash, 'UTF8');                                                       +
             IF v_stored_hash LIKE '$2%$%$%' THEN                                                                                    +
                 v_credentials_valid := (crypt(v_password, v_stored_hash) = v_stored_hash);                                          +
             ELSE                                                                                                                    +
                 v_credentials_valid := FALSE;                                                                                       +
             END IF;                                                                                                                 +
         EXCEPTION WHEN OTHERS THEN                                                                                                  +
             v_credentials_valid := FALSE;                                                                                           +
         END;                                                                                                                        +
     ELSE                                                                                                                            +
         v_credentials_valid := FALSE;                                                                                               +
     END IF;                                                                                                                         +
                                                                                                                                     +
     -- STEP 3: Handle authentication result                                                                                         +
     IF NOT v_credentials_valid THEN                                                                                                 +
         -- LOG: Failed login - invalid password                                                                                     +
         PERFORM audit.log_security_event(                                                                                           +
             'FAILED_LOGIN_INVALID_PASSWORD',                                                                                        +
             'MEDIUM',                                                                                                               +
             'Failed login attempt - invalid password for user: ' || v_username,                                                     +
             v_ip_address,                                                                                                           +
             v_user_agent,                                                                                                           +
             v_user_hk,                                                                                                              +
             'MEDIUM',                                                                                                               +
             jsonb_build_object(                                                                                                     +
                 'username', v_username,                                                                                             +
                 'failed_attempts', COALESCE(v_user_auth.failed_login_attempts, 0) + 1,                                              +
                 'timestamp', NOW(),                                                                                                 +
                 'reason', 'invalid_password'                                                                                        +
             )                                                                                                                       +
         );                                                                                                                          +
                                                                                                                                     +
         RETURN jsonb_build_object(                                                                                                  +
             'success', false,                                                                                                       +
             'message', 'Invalid username or password',                                                                              +
             'error_code', 'INVALID_CREDENTIALS'                                                                                     +
         );                                                                                                                          +
     END IF;                                                                                                                         +
                                                                                                                                     +
     -- STEP 4: SUCCESSFUL LOGIN - Update user auth record                                                                           +
     UPDATE auth.user_auth_s                                                                                                         +
     SET load_end_date = util.current_load_date()                                                                                    +
     WHERE user_hk = v_user_hk                                                                                                       +
     AND load_end_date IS NULL;                                                                                                      +
                                                                                                                                     +
     INSERT INTO auth.user_auth_s (                                                                                                  +
         user_hk, load_date, hash_diff, username, password_hash, password_salt,                                                      +
         last_login_date, password_last_changed, failed_login_attempts,                                                              +
         account_locked, account_locked_until, must_change_password,                                                                 +
         password_reset_token, password_reset_expiry, record_source                                                                  +
     ) VALUES (                                                                                                                      +
         v_user_auth.user_hk, util.current_load_date(),                                                                              +
         util.hash_binary(v_user_auth.username || 'LOGIN_SUCCESS' || CURRENT_TIMESTAMP::text),                                       +
         v_user_auth.username, v_user_auth.password_hash, v_user_auth.password_salt,                                                 +
         CURRENT_TIMESTAMP, v_user_auth.password_last_changed, 0,                                                                    +
         FALSE, NULL, v_user_auth.must_change_password,                                                                              +
         v_user_auth.password_reset_token, v_user_auth.password_reset_expiry,                                                        +
         util.get_record_source()                                                                                                    +
     );                                                                                                                              +
                                                                                                                                     +
     -- STEP 5: Get user roles and permissions                                                                                       +
     SELECT jsonb_agg(                                                                                                               +
         jsonb_build_object(                                                                                                         +
             'role_id', encode(r.role_hk, 'hex'),                                                                                    +
             'role_name', rd.role_name,                                                                                              +
             'role_description', rd.role_description,                                                                                +
             'is_system_role', rd.is_system_role,                                                                                    +
             'permissions', rd.permissions                                                                                           +
         )                                                                                                                           +
     ) INTO v_user_roles                                                                                                             +
     FROM auth.user_role_l url                                                                                                       +
     JOIN auth.role_h r ON url.role_hk = r.role_hk                                                                                   +
     JOIN auth.role_definition_s rd ON r.role_hk = rd.role_hk                                                                        +
     WHERE url.user_hk = v_user_hk                                                                                                   +
     AND url.tenant_hk = v_tenant_hk                                                                                                 +
     AND rd.load_end_date IS NULL;                                                                                                   +
                                                                                                                                     +
     IF v_user_roles IS NULL THEN                                                                                                    +
         v_user_roles := '[]'::jsonb;                                                                                                +
     END IF;                                                                                                                         +
                                                                                                                                     +
     -- STEP 6: Get tenant list with role information                                                                                +
     SELECT jsonb_agg(                                                                                                               +
         jsonb_build_object(                                                                                                         +
             'tenant_id', encode(t.tenant_hk, 'hex'),                                                                                +
             'tenant_name', td.tenant_name,                                                                                          +
             'user_roles', tenant_roles.roles                                                                                        +
         )                                                                                                                           +
     ) INTO v_tenant_list                                                                                                            +
     FROM auth.tenant_h t                                                                                                            +
     JOIN auth.tenant_definition_s td ON t.tenant_hk = td.tenant_hk                                                                  +
     JOIN auth.user_role_l url ON t.tenant_hk = url.tenant_hk                                                                        +
     LEFT JOIN LATERAL (                                                                                                             +
         SELECT jsonb_agg(rd.role_name) as roles                                                                                     +
         FROM auth.role_h r                                                                                                          +
         JOIN auth.role_definition_s rd ON r.role_hk = rd.role_hk                                                                    +
         WHERE r.role_hk = url.role_hk                                                                                               +
         AND rd.load_end_date IS NULL                                                                                                +
     ) tenant_roles ON true                                                                                                          +
     WHERE url.user_hk = v_user_hk                                                                                                   +
     AND td.load_end_date IS NULL                                                                                                    +
     GROUP BY t.tenant_hk, td.tenant_name;                                                                                           +
                                                                                                                                     +
     IF v_tenant_list IS NULL THEN                                                                                                   +
         v_tenant_list := '[]'::jsonb;                                                                                               +
     END IF;                                                                                                                         +
                                                                                                                                     +
     -- STEP 6.5: Get user profile data                                                                                              +
     SELECT jsonb_build_object(                                                                                                      +
         'first_name', up.first_name,                                                                                                +
         'last_name', up.last_name,                                                                                                  +
         'email', up.email,                                                                                                          +
         'phone', up.phone,                                                                                                          +
         'job_title', up.job_title,                                                                                                  +
         'department', up.department,                                                                                                +
         'is_active', up.is_active,                                                                                                  +
         'last_updated', up.last_updated_date                                                                                        +
     ) INTO v_profile_data                                                                                                           +
     FROM auth.user_profile_s up                                                                                                     +
     WHERE up.user_hk = v_user_hk                                                                                                    +
     AND up.load_end_date IS NULL                                                                                                    +
     ORDER BY up.load_date DESC                                                                                                      +
     LIMIT 1;                                                                                                                        +
                                                                                                                                     +
     -- STEP 7: Build comprehensive user data                                                                                        +
     v_user_data := jsonb_build_object(                                                                                              +
         'user_id', encode(v_user_hk, 'hex'),                                                                                        +
         'username', v_username,                                                                                                     +
         'profile', COALESCE(v_profile_data, '{}'::jsonb),                                                                           +
         'login_time', CURRENT_TIMESTAMP,                                                                                            +
         'roles', v_user_roles,                                                                                                      +
         'permissions', COALESCE(                                                                                                    +
             (SELECT jsonb_object_agg(permission_key, permission_value)                                                              +
             FROM (                                                                                                                  +
                 SELECT DISTINCT p.key as permission_key, p.value as permission_value                                                +
                 FROM auth.user_role_l url                                                                                           +
                 JOIN auth.role_h r ON url.role_hk = r.role_hk                                                                       +
                 JOIN auth.role_definition_s rd ON r.role_hk = rd.role_hk                                                            +
                 CROSS JOIN LATERAL jsonb_each(rd.permissions) p                                                                     +
                 WHERE url.user_hk = v_user_hk                                                                                       +
                 AND url.tenant_hk = v_tenant_hk                                                                                     +
                 AND rd.load_end_date IS NULL                                                                                        +
             ) permissions_flat),                                                                                                    +
             '{}'::jsonb                                                                                                             +
         )                                                                                                                           +
     );                                                                                                                              +
                                                                                                                                     +
     -- STEP 7.5: Create session token if auto_login is true                                                                         +
     IF v_auto_login THEN                                                                                                            +
         v_session_token := auth.generate_session_token();                                                                           +
         v_session_bk := util.generate_bk(encode(v_tenant_hk, 'hex') || '_SESSION_' || v_session_token);                             +
         v_session_hk := util.hash_binary(v_session_bk);                                                                             +
         v_session_expires := CURRENT_TIMESTAMP + INTERVAL '24 hours';                                                               +
                                                                                                                                     +
         -- Create session (proper Data Vault 2.0 sequence)                                                                          +
         INSERT INTO auth.session_h (                                                                                                +
             session_hk, session_bk, tenant_hk, load_date, record_source                                                             +
         ) VALUES (                                                                                                                  +
             v_session_hk, v_session_bk, v_tenant_hk, util.current_load_date(), util.get_record_source()                             +
         );                                                                                                                          +
                                                                                                                                     +
         INSERT INTO auth.session_state_s (                                                                                          +
             session_hk, load_date, hash_diff, session_start, session_end,                                                           +
             ip_address, user_agent, session_data, session_status, last_activity, record_source                                      +
         ) VALUES (                                                                                                                  +
             v_session_hk, util.current_load_date(),                                                                                 +
             util.hash_binary(v_session_bk || 'ACTIVE' || COALESCE(v_ip_address::text, '') || COALESCE(v_user_agent, '')),           +
             CURRENT_TIMESTAMP, v_session_expires, v_ip_address, v_user_agent,                                                       +
             jsonb_build_object('token', v_session_token, 'login_timestamp', CURRENT_TIMESTAMP, 'user_id', encode(v_user_hk, 'hex')),+
             'ACTIVE', CURRENT_TIMESTAMP, util.get_record_source()                                                                   +
         );                                                                                                                          +
                                                                                                                                     +
         INSERT INTO auth.user_session_l (                                                                                           +
             link_user_session_hk, user_hk, session_hk, tenant_hk, load_date, record_source                                          +
         ) VALUES (                                                                                                                  +
             util.hash_binary(encode(v_user_hk, 'hex') || encode(v_session_hk, 'hex')),                                              +
             v_user_hk, v_session_hk, v_tenant_hk, util.current_load_date(), util.get_record_source()                                +
         );                                                                                                                          +
     END IF;                                                                                                                         +
                                                                                                                                     +
     -- LOG: Successful login (NEW - THIS IS THE KEY ADDITION!)                                                                      +
     PERFORM audit.log_security_event(                                                                                               +
         'LOGIN_SUCCESS',                                                                                                            +
         'LOW',                                                                                                                      +
         'Successful login for user: ' || v_username,                                                                                +
         v_ip_address,                                                                                                               +
         v_user_agent,                                                                                                               +
         v_user_hk,                                                                                                                  +
         'LOW',                                                                                                                      +
         jsonb_build_object(                                                                                                         +
             'username', v_username,                                                                                                 +
             'session_token', CASE WHEN v_auto_login THEN left(v_session_token, 8) || '...' ELSE NULL END,                           +
             'auto_login', v_auto_login,                                                                                             +
             'tenant_count', jsonb_array_length(v_tenant_list),                                                                      +
             'role_count', jsonb_array_length(v_user_roles),                                                                         +
             'timestamp', NOW()                                                                                                      +
         )                                                                                                                           +
     );                                                                                                                              +
                                                                                                                                     +
     -- STEP 8: Return success with complete information                                                                             +
     RETURN jsonb_build_object(                                                                                                      +
         'success', true,                                                                                                            +
         'message', 'Login successful',                                                                                              +
         'data', jsonb_build_object(                                                                                                 +
             'requires_tenant_selection', false,                                                                                     +
             'tenant_list', v_tenant_list,                                                                                           +
             'user_data', v_user_data,                                                                                               +
             'session_token', v_session_token,                                                                                       +
             'session_expires', v_session_expires                                                                                    +
         )                                                                                                                           +
     );                                                                                                                              +
                                                                                                                                     +
 EXCEPTION WHEN OTHERS THEN                                                                                                          +
     -- LOG: System error during login                                                                                               +
     PERFORM audit.log_security_event(                                                                                               +
         'LOGIN_SYSTEM_ERROR',                                                                                                       +
         'CRITICAL',                                                                                                                 +
         'System error during login for user: ' || COALESCE(v_username, 'unknown'),                                                  +
         COALESCE(v_ip_address, '0.0.0.0'::inet),                                                                                    +
         COALESCE(v_user_agent, 'unknown'),                                                                                          +
         v_user_hk,                                                                                                                  +
         'CRITICAL',                                                                                                                 +
         jsonb_build_object(                                                                                                         +
             'username', v_username,                                                                                                 +
             'error_message', SQLERRM,                                                                                               +
             'error_state', SQLSTATE,                                                                                                +
             'timestamp', NOW()                                                                                                      +
         )                                                                                                                           +
     );                                                                                                                              +
                                                                                                                                     +
     RETURN jsonb_build_object(                                                                                                      +
         'success', false,                                                                                                           +
         'message', 'An unexpected error occurred during authentication',                                                            +
         'error_code', 'AUTHENTICATION_ERROR',                                                                                       +
         'debug_info', jsonb_build_object(                                                                                           +
             'error', SQLERRM,                                                                                                       +
             'sqlstate', SQLSTATE                                                                                                    +
         )                                                                                                                           +
     );                                                                                                                              +
 END;                                                                                                                                +
 $function$                                                                                                                          +
 
(1 row)

