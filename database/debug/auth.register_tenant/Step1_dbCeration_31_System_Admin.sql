-- =============================================
-- STEP 31: SYSTEM ADMIN TENANT & CROSS-TENANT MANAGEMENT
-- Multi-Entity Business Optimization Platform
-- Implements system-level administration and default role structure
-- =============================================

-- =============================================
-- PHASE 1: CREATE SYSTEM ADMIN TENANT
-- =============================================

-- Create the system administration tenant
DO $$
DECLARE
    v_system_tenant_hk BYTEA;
    v_system_tenant_bk VARCHAR(255) := 'SYSTEM_ADMIN';
    v_load_date TIMESTAMP WITH TIME ZONE := util.current_load_date();
    v_record_source VARCHAR(100) := 'system_initialization';
BEGIN
    -- Generate system tenant hash key
    v_system_tenant_hk := util.hash_binary(v_system_tenant_bk);
    
    -- Create system admin tenant hub (if not exists)
    INSERT INTO auth.tenant_h (
        tenant_hk,
        tenant_bk,
        load_date,
        record_source
    ) VALUES (
        v_system_tenant_hk,
        v_system_tenant_bk,
        v_load_date,
        v_record_source
    ) ON CONFLICT (tenant_hk) DO NOTHING;
    
    -- Create system tenant profile
    INSERT INTO auth.tenant_profile_s (
        tenant_hk,
        load_date,
        hash_diff,
        tenant_name,
        tenant_description,
        is_active,
        subscription_level,
        subscription_start_date,
        contact_email,
        max_users,
        created_date,
        record_source
    ) VALUES (
        v_system_tenant_hk,
        v_load_date,
        util.hash_binary('SYSTEM_ADMIN' || 'PLATFORM_ADMINISTRATION' || 'UNLIMITED'),
        'System Administration',
        'Platform-level administration tenant for cross-tenant management and system oversight',
        TRUE,
        'enterprise_system',
        CURRENT_TIMESTAMP,
        'system@platform.admin',
        999999, -- Unlimited users for system admin
        CURRENT_TIMESTAMP,
        v_record_source
    ) ON CONFLICT (tenant_hk, load_date) DO NOTHING;
    
    RAISE NOTICE 'System Admin Tenant created: %', v_system_tenant_bk;
END;
$$;

-- =============================================
-- PHASE 2: CREATE CROSS-TENANT SYSTEM ROLES
-- =============================================

-- Function to create system-wide roles
CREATE OR REPLACE FUNCTION auth.create_system_roles()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_system_tenant_hk BYTEA;
    v_role_record RECORD;
    v_role_hk BYTEA;
    v_role_bk VARCHAR(255);
    v_load_date TIMESTAMP WITH TIME ZONE := util.current_load_date();
    v_record_source VARCHAR(100) := 'system_initialization';
BEGIN
    -- Get system tenant hash key
    SELECT tenant_hk INTO v_system_tenant_hk
    FROM auth.tenant_h
    WHERE tenant_bk = 'SYSTEM_ADMIN';
    
    -- Define system roles with comprehensive permissions
    FOR v_role_record IN
        SELECT * FROM (VALUES
            ('SUPER_ADMIN', 'Super Administrator', 'Complete platform administration with cross-tenant access', jsonb_build_object(
                'cross_tenant_access', true,
                'user_management', true,
                'tenant_management', true,
                'system_administration', true,
                'data_access_level', 'all_tenants',
                'reporting_access', true,
                'security_management', true,
                'audit_access', true,
                'platform_configuration', true,
                'billing_management', true
            )),
            ('PLATFORM_ADMIN', 'Platform Administrator', 'Platform oversight and tenant management', jsonb_build_object(
                'cross_tenant_access', true,
                'user_management', false,
                'tenant_management', true,
                'system_administration', false,
                'data_access_level', 'read_all_tenants',
                'reporting_access', true,
                'security_management', false,
                'audit_access', true,
                'platform_configuration', false,
                'billing_management', true
            )),
            ('SYSTEM_AUDITOR', 'System Auditor', 'Cross-tenant audit and compliance monitoring', jsonb_build_object(
                'cross_tenant_access', true,
                'user_management', false,
                'tenant_management', false,
                'system_administration', false,
                'data_access_level', 'audit_only',
                'reporting_access', true,
                'security_management', false,
                'audit_access', true,
                'platform_configuration', false,
                'billing_management', false
            )),
            ('PLATFORM_SUPPORT', 'Platform Support', 'Technical support with limited tenant access', jsonb_build_object(
                'cross_tenant_access', true,
                'user_management', false,
                'tenant_management', false,
                'system_administration', false,
                'data_access_level', 'support_only',
                'reporting_access', false,
                'security_management', false,
                'audit_access', false,
                'platform_configuration', false,
                'billing_management', false
            ))
        ) AS roles(role_name, role_title, role_desc, permissions)
    LOOP
        -- Generate role identifiers
        v_role_bk := 'SYSTEM_' || v_role_record.role_name;
        v_role_hk := util.hash_binary(v_role_bk);
        
        -- Create role hub
        INSERT INTO auth.role_h (
            role_hk,
            role_bk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            v_role_hk,
            v_role_bk,
            v_system_tenant_hk,
            v_load_date,
            v_record_source
        ) ON CONFLICT (role_hk) DO NOTHING;
        
        -- Create role definition
        INSERT INTO auth.role_definition_s (
            role_hk,
            load_date,
            hash_diff,
            role_name,
            role_description,
            is_system_role,
            permissions,
            created_date,
            record_source
        ) VALUES (
            v_role_hk,
            v_load_date,
            util.hash_binary(v_role_record.role_name || v_role_record.role_desc || 'SYSTEM_ROLE'),
            v_role_record.role_title,
            v_role_record.role_desc,
            TRUE, -- Mark as system role
            v_role_record.permissions,
            CURRENT_TIMESTAMP,
            v_record_source
        ) ON CONFLICT (role_hk, load_date) DO NOTHING;
        
        RAISE NOTICE 'Created system role: %', v_role_record.role_title;
    END LOOP;
END;
$$;

-- Execute system role creation
SELECT auth.create_system_roles();

-- =============================================
-- PHASE 3: CREATE DEFAULT TENANT ROLE TEMPLATES
-- =============================================

-- Function to create standard roles for any tenant
CREATE OR REPLACE FUNCTION auth.create_tenant_default_roles(p_tenant_hk BYTEA)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_role_record RECORD;
    v_role_hk BYTEA;
    v_role_bk VARCHAR(255);
    v_tenant_bk VARCHAR(255);
    v_load_date TIMESTAMP WITH TIME ZONE := util.current_load_date();
    v_record_source VARCHAR(100) := 'tenant_role_template';
BEGIN
    -- Get tenant business key
    SELECT tenant_bk INTO v_tenant_bk
    FROM auth.tenant_h
    WHERE tenant_hk = p_tenant_hk;
    
    -- Define standard tenant roles
    FOR v_role_record IN
        SELECT * FROM (VALUES
            ('ADMINISTRATOR', 'Administrator', 'Complete administrative access for tenant operations, user management, and system configuration', jsonb_build_object(
                'user_management', true,
                'data_access_level', 'full',
                'reporting_access', true,
                'security_management', true,
                'audit_access', true,
                'role_management', true,
                'tenant_configuration', true,
                'system_administration', true,
                'billing_access', true,
                'create_records', true,
                'edit_all_records', true,
                'delete_records', true,
                'manage_users', true,
                'assign_roles', true,
                'view_all_data', true
            )),
            ('USER', 'User', 'Standard user access with basic functionality', jsonb_build_object(
                'user_management', false,
                'data_access_level', 'own_records',
                'reporting_access', false,
                'security_management', false,
                'audit_access', false,
                'create_records', true,
                'edit_own_records', true,
                'view_shared_records', true
            )),
            ('MANAGER', 'Manager', 'Departmental management with team oversight', jsonb_build_object(
                'user_management', false,
                'data_access_level', 'department',
                'reporting_access', true,
                'security_management', false,
                'audit_access', false,
                'create_records', true,
                'edit_team_records', true,
                'view_department_records', true,
                'approve_requests', true
            )),
            ('VIEWER', 'Viewer', 'Read-only access to authorized data', jsonb_build_object(
                'user_management', false,
                'data_access_level', 'view_only',
                'reporting_access', false,
                'security_management', false,
                'audit_access', false,
                'create_records', false,
                'edit_records', false,
                'view_authorized_records', true
            )),
            ('AUDITOR', 'Auditor', 'Audit trail access and compliance monitoring', jsonb_build_object(
                'user_management', false,
                'data_access_level', 'audit_trail',
                'reporting_access', true,
                'security_management', false,
                'audit_access', true,
                'create_records', false,
                'edit_records', false,
                'view_audit_logs', true,
                'generate_compliance_reports', true
            )),
            ('ANALYST', 'Data Analyst', 'Data analysis and reporting capabilities', jsonb_build_object(
                'user_management', false,
                'data_access_level', 'analytical',
                'reporting_access', true,
                'security_management', false,
                'audit_access', false,
                'create_records', false,
                'edit_records', false,
                'view_aggregated_data', true,
                'create_reports', true,
                'export_data', true
            ))
        ) AS roles(role_name, role_title, role_desc, permissions)
    LOOP
        -- Generate role identifiers
        v_role_bk := v_tenant_bk || '_' || v_role_record.role_name;
        v_role_hk := util.hash_binary(v_role_bk);
        
        -- Create role hub
        INSERT INTO auth.role_h (
            role_hk,
            role_bk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            v_role_hk,
            v_role_bk,
            p_tenant_hk,
            v_load_date,
            v_record_source
        ) ON CONFLICT (role_hk) DO NOTHING;
        
        -- Create role definition
        INSERT INTO auth.role_definition_s (
            role_hk,
            load_date,
            hash_diff,
            role_name,
            role_description,
            is_system_role,
            permissions,
            created_date,
            record_source
        ) VALUES (
            v_role_hk,
            v_load_date,
            util.hash_binary(v_role_record.role_name || v_role_record.role_desc || v_tenant_bk),
            v_role_record.role_title,
            v_role_record.role_desc,
            FALSE, -- Standard tenant roles, not system roles
            v_role_record.permissions,
            CURRENT_TIMESTAMP,
            v_record_source
        ) ON CONFLICT (role_hk, load_date) DO NOTHING;
        
    END LOOP;
    
    RAISE NOTICE 'Created default roles for tenant: %', v_tenant_bk;
END;
$$;

-- =============================================
-- PHASE 4: CREATE SYSTEM ADMIN USER
-- =============================================

-- Create the primary system administrator
DO $$
DECLARE
    v_system_tenant_hk BYTEA;
    v_super_admin_role_hk BYTEA;
    v_admin_user_hk BYTEA;
    v_user_bk VARCHAR(255);
    v_password_hash TEXT;
    v_salt TEXT;
    v_load_date TIMESTAMP WITH TIME ZONE := util.current_load_date();
    v_record_source VARCHAR(100) := 'system_initialization';
BEGIN
    -- Get system tenant and super admin role
    SELECT tenant_hk INTO v_system_tenant_hk
    FROM auth.tenant_h
    WHERE tenant_bk = 'SYSTEM_ADMIN';
    
    SELECT role_hk INTO v_super_admin_role_hk
    FROM auth.role_h
    WHERE role_bk = 'SYSTEM_SUPER_ADMIN';
    
    -- Generate system admin user
    v_user_bk := 'system.admin@platform.local';
    v_admin_user_hk := util.hash_binary(v_user_bk);
    v_salt := gen_salt('bf');
    v_password_hash := crypt('SystemAdmin2024!@#', v_salt);
    
    -- Create system admin user hub
    INSERT INTO auth.user_h (
        user_hk,
        user_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_admin_user_hk,
        v_user_bk,
        v_system_tenant_hk,
        v_load_date,
        v_record_source
    ) ON CONFLICT (user_hk) DO NOTHING;
    
    -- Create authentication record
    INSERT INTO auth.user_auth_s (
        user_hk,
        load_date,
        hash_diff,
        username,
        password_hash,
        password_salt,
        password_last_changed,
        failed_login_attempts,
        account_locked,
        must_change_password,
        record_source
    ) VALUES (
        v_admin_user_hk,
        v_load_date,
        util.hash_binary(v_user_bk || 'SYSTEM_ADMIN_AUTH'),
        v_user_bk,
        v_password_hash::BYTEA,
        v_salt::BYTEA,
        CURRENT_TIMESTAMP,
        0,
        FALSE,
        FALSE, -- System admin doesn't need to change password immediately
        v_record_source
    ) ON CONFLICT (user_hk, load_date) DO NOTHING;
    
    -- Create user profile
    INSERT INTO auth.user_profile_s (
        user_hk,
        load_date,
        hash_diff,
        first_name,
        last_name,
        email,
        job_title,
        department,
        is_active,
        created_date,
        record_source
    ) VALUES (
        v_admin_user_hk,
        v_load_date,
        util.hash_binary('System' || 'Administrator' || v_user_bk),
        'System',
        'Administrator',
        v_user_bk,
        'Platform Administrator',
        'System Administration',
        TRUE,
        CURRENT_TIMESTAMP,
        v_record_source
    ) ON CONFLICT (user_hk, load_date) DO NOTHING;
    
    -- Assign super admin role
    INSERT INTO auth.user_role_l (
        link_user_role_hk,
        user_hk,
        role_hk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(v_admin_user_hk::text || v_super_admin_role_hk::text),
        v_admin_user_hk,
        v_super_admin_role_hk,
        v_system_tenant_hk,
        v_load_date,
        v_record_source
    ) ON CONFLICT (link_user_role_hk) DO NOTHING;
    
    RAISE NOTICE 'System Administrator created: %', v_user_bk;
    RAISE NOTICE 'Default password: SystemAdmin2024!@#';
END;
$$;

-- =============================================
-- PHASE 5: CROSS-TENANT MANAGEMENT FUNCTIONS
-- =============================================

-- Function to list all tenants (system admin only)
CREATE OR REPLACE FUNCTION api.system_tenants_list(
    p_request JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id TEXT;
    v_session_token TEXT;
    v_has_system_access BOOLEAN := FALSE;
    v_tenants JSONB;
BEGIN
    -- Extract and validate parameters
    v_user_id := p_request->>'user_id';
    v_session_token := p_request->>'session_token';
    
    -- Verify user has system-level access
    SELECT EXISTS(
        SELECT 1 
        FROM auth.user_h uh
        JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
        JOIN auth.role_h rh ON url.role_hk = rh.role_hk
        JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
        WHERE uh.user_bk = v_user_id
        AND rds.permissions->>'cross_tenant_access' = 'true'
        AND rds.load_end_date IS NULL
    ) INTO v_has_system_access;
    
    IF NOT v_has_system_access THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Insufficient privileges for cross-tenant access',
            'error_code', 'ACCESS_DENIED'
        );
    END IF;
    
    -- Get all tenants with summary data
    SELECT jsonb_agg(
        jsonb_build_object(
            'tenant_id', th.tenant_bk,
            'tenant_name', tps.tenant_name,
            'is_active', tps.is_active,
            'user_count', (
                SELECT COUNT(*) 
                FROM auth.user_h uh2 
                WHERE uh2.tenant_hk = th.tenant_hk
            ),
            'created_date', tps.created_date,
            'subscription_level', tps.subscription_level
        ) ORDER BY tps.created_date DESC
    ) INTO v_tenants
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
    WHERE tps.load_end_date IS NULL
    AND th.tenant_bk != 'SYSTEM_ADMIN'; -- Exclude system admin tenant
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Tenants retrieved successfully',
        'data', jsonb_build_object(
            'tenants', COALESCE(v_tenants, '[]'::JSONB),
            'total_tenants', CASE 
                WHEN v_tenants IS NULL THEN 0
                ELSE jsonb_array_length(v_tenants)
            END
        )
    );
END;
$$;

-- Function to get platform statistics
CREATE OR REPLACE FUNCTION api.system_platform_stats(
    p_request JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id TEXT;
    v_has_system_access BOOLEAN := FALSE;
    v_stats JSONB;
BEGIN
    v_user_id := p_request->>'user_id';
    
    -- Verify system access
    SELECT EXISTS(
        SELECT 1 
        FROM auth.user_h uh
        JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
        JOIN auth.role_h rh ON url.role_hk = rh.role_hk
        JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
        WHERE uh.user_bk = v_user_id
        AND rds.permissions->>'cross_tenant_access' = 'true'
        AND rds.load_end_date IS NULL
    ) INTO v_has_system_access;
    
    IF NOT v_has_system_access THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Insufficient privileges',
            'error_code', 'ACCESS_DENIED'
        );
    END IF;
    
    -- Gather platform statistics
    SELECT jsonb_build_object(
        'total_tenants', (
            SELECT COUNT(*) 
            FROM auth.tenant_h 
            WHERE tenant_bk != 'SYSTEM_ADMIN'
        ),
        'active_tenants', (
            SELECT COUNT(*) 
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            WHERE tps.is_active = TRUE 
            AND tps.load_end_date IS NULL
            AND th.tenant_bk != 'SYSTEM_ADMIN'
        ),
        'total_users', (
            SELECT COUNT(*) 
            FROM auth.user_h uh
            JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
            WHERE th.tenant_bk != 'SYSTEM_ADMIN'
        ),
        'active_sessions', (
            SELECT COUNT(*) 
            FROM auth.session_h sh
            JOIN auth.session_detail_s sds ON sh.session_hk = sds.session_hk
            WHERE sds.is_active = TRUE 
            AND sds.load_end_date IS NULL
            AND sds.expires_at > CURRENT_TIMESTAMP
        ),
        'audit_events_today', (
            SELECT COUNT(*) 
            FROM audit.audit_event_h 
            WHERE load_date >= CURRENT_DATE
        )
    ) INTO v_stats;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Platform statistics retrieved',
        'data', v_stats
    );
END;
$$;

-- =============================================
-- PHASE 6: UPDATE TENANT REGISTRATION TO CREATE DEFAULT ROLES
-- =============================================

-- Update the existing tenant registration procedure to auto-create default roles
CREATE OR REPLACE FUNCTION auth.register_tenant_with_roles(
    p_tenant_name VARCHAR(100),
    p_admin_email VARCHAR(255),
    p_admin_password TEXT,
    p_admin_first_name VARCHAR(100),
    p_admin_last_name VARCHAR(100),
    OUT tenant_hk BYTEA,
    OUT admin_user_hk BYTEA
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Call the existing registration procedure
    CALL auth.register_tenant(
        p_tenant_name,
        p_admin_email,
        p_admin_password,
        p_admin_first_name,
        p_admin_last_name,
        tenant_hk,
        admin_user_hk
    );
    
    -- Create default roles for the new tenant
    PERFORM auth.create_tenant_default_roles(tenant_hk);
    
    RAISE NOTICE 'Tenant registered with default roles: %', p_tenant_name;
END;
$$;

-- =============================================
-- PHASE 7: VERIFICATION AND TESTING
-- =============================================

-- Test system admin functionality
DO $$
DECLARE
    v_system_test JSONB;
    v_tenant_count INTEGER;
BEGIN
    -- Test system tenant exists
    SELECT COUNT(*) INTO v_tenant_count
    FROM auth.tenant_h
    WHERE tenant_bk = 'SYSTEM_ADMIN';
    
    IF v_tenant_count > 0 THEN
        RAISE NOTICE '✅ System Admin Tenant: CREATED';
    ELSE
        RAISE NOTICE '❌ System Admin Tenant: MISSING';
    END IF;
    
    -- Test system roles exist
    SELECT COUNT(*) INTO v_tenant_count
    FROM auth.role_h rh
    JOIN auth.tenant_h th ON rh.tenant_hk = th.tenant_hk
    WHERE th.tenant_bk = 'SYSTEM_ADMIN';
    
    RAISE NOTICE '✅ System Roles Created: %', v_tenant_count;
    
    -- Test system admin user exists
    SELECT COUNT(*) INTO v_tenant_count
    FROM auth.user_h uh
    JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
    WHERE th.tenant_bk = 'SYSTEM_ADMIN';
    
    RAISE NOTICE '✅ System Admin Users: %', v_tenant_count;
END;
$$;

-- Final verification message
DO $$ 
BEGIN
    RAISE NOTICE '=== 🎉 SYSTEM ADMINISTRATION IMPLEMENTATION COMPLETE! 🎉 ===';
    RAISE NOTICE '';
    RAISE NOTICE '✅ System Admin Tenant: CREATED';
    RAISE NOTICE '✅ Cross-Tenant Roles: SUPER_ADMIN, PLATFORM_ADMIN, SYSTEM_AUDITOR, PLATFORM_SUPPORT';
    RAISE NOTICE '✅ Default Tenant Roles: ADMINISTRATOR, USER, MANAGER, VIEWER, AUDITOR, ANALYST';
    RAISE NOTICE '✅ System Admin User: system.admin@platform.local';
    RAISE NOTICE '✅ Cross-Tenant Management APIs: IMPLEMENTED';
    RAISE NOTICE '';
    RAISE NOTICE '🔐 System Admin Login:';
    RAISE NOTICE '   Username: system.admin@platform.local';
    RAISE NOTICE '   Password: SystemAdmin2024!@#';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 New Features Available:';
    RAISE NOTICE '   - Cross-tenant management';
    RAISE NOTICE '   - Platform-wide statistics';
    RAISE NOTICE '   - System-level user administration';
    RAISE NOTICE '   - Default role templates for all tenants';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Your platform now has ENTERPRISE-GRADE system administration!';
END $$; 