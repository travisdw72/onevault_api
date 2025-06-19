-- =============================================
-- 🔍 USER AND ROLE INVESTIGATION
-- Analyze how users are created and what roles exist
-- =============================================

DO $$
DECLARE
    v_target_username TEXT := 'travisdwoodward72@gmail.com';
    v_user_hk BYTEA;
    v_tenant_hk BYTEA;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔍════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔍                 USER AND ROLE INVESTIGATION                     ';
    RAISE NOTICE '🔍════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    
    -- Get user context
    SELECT uh.user_hk, uh.tenant_hk INTO v_user_hk, v_tenant_hk
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = v_target_username
    AND uas.load_end_date IS NULL
    LIMIT 1;
    
    -- =============================================
    -- 1. EXISTING ROLES ANALYSIS
    -- =============================================
    RAISE NOTICE '🏷️  EXISTING ROLES IN SYSTEM:';
    RAISE NOTICE '';
    
    DECLARE
        role_record RECORD;
        role_count INTEGER := 0;
    BEGIN
        FOR role_record IN
            SELECT 
                encode(r.role_hk, 'hex') as role_id,
                r.role_bk,
                encode(r.tenant_hk, 'hex') as tenant_id,
                rd.role_name,
                rd.role_description,
                rd.is_system_role,
                rd.permissions,
                rd.load_date
            FROM auth.role_h r
            JOIN auth.role_definition_s rd ON r.role_hk = rd.role_hk
            WHERE rd.load_end_date IS NULL
            ORDER BY rd.is_system_role DESC, rd.role_name
        LOOP
            role_count := role_count + 1;
            RAISE NOTICE '   📋 Role %: %', role_count, role_record.role_name;
            RAISE NOTICE '      ID: %', role_record.role_id;
            RAISE NOTICE '      Business Key: %', role_record.role_bk;
            RAISE NOTICE '      System Role: %', role_record.is_system_role;
            RAISE NOTICE '      Description: %', COALESCE(role_record.role_description, 'No description');
            RAISE NOTICE '      Permissions: %', role_record.permissions::text;
            RAISE NOTICE '      Created: %', role_record.load_date;
            RAISE NOTICE '';
        END LOOP;
        
        IF role_count = 0 THEN
            RAISE NOTICE '   ⚠️  NO ROLES FOUND! This explains why role integration failed.';
            RAISE NOTICE '   💡 Need to create default roles for the system.';
        ELSE
            RAISE NOTICE '   📊 Total Roles Found: %', role_count;
        END IF;
    END;
    RAISE NOTICE '';
    
    -- =============================================
    -- 2. USER ROLE ASSIGNMENTS
    -- =============================================
    RAISE NOTICE '👤 USER ROLE ASSIGNMENTS FOR: %', v_target_username;
    RAISE NOTICE '';
    
    DECLARE
        assignment_record RECORD;
        assignment_count INTEGER := 0;
    BEGIN
        FOR assignment_record IN
            SELECT 
                encode(url.user_hk, 'hex') as user_id,
                encode(url.role_hk, 'hex') as role_id,
                rd.role_name,
                rd.permissions,
                url.load_date as assigned_date
            FROM auth.user_role_l url
            JOIN auth.role_h r ON url.role_hk = r.role_hk
            JOIN auth.role_definition_s rd ON r.role_hk = rd.role_hk
            WHERE url.user_hk = v_user_hk
            AND rd.load_end_date IS NULL
            ORDER BY url.load_date DESC
        LOOP
            assignment_count := assignment_count + 1;
            RAISE NOTICE '   🔗 Assignment %: %', assignment_count, assignment_record.role_name;
            RAISE NOTICE '      Role ID: %', assignment_record.role_id;
            RAISE NOTICE '      Assigned: %', assignment_record.assigned_date;
            RAISE NOTICE '      Permissions: %', assignment_record.permissions::text;
            RAISE NOTICE '';
        END LOOP;
        
        IF assignment_count = 0 THEN
            RAISE NOTICE '   ⚠️  NO ROLE ASSIGNMENTS FOUND!';
            RAISE NOTICE '   💡 User exists but has no roles assigned.';
        ELSE
            RAISE NOTICE '   📊 Total Assignments: %', assignment_count;
        END IF;
    END;
    RAISE NOTICE '';
    
    -- =============================================
    -- 3. SEARCH FOR USER CREATION FUNCTIONS
    -- =============================================
    RAISE NOTICE '🔍 SEARCHING FOR USER CREATION FUNCTIONS:';
    RAISE NOTICE '';
    
    DECLARE
        func_record RECORD;
        func_count INTEGER := 0;
    BEGIN
        FOR func_record IN
            SELECT 
                n.nspname as schema_name,
                p.proname as function_name,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as return_type
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE (
                p.proname ILIKE '%register%' OR
                p.proname ILIKE '%create_user%' OR
                p.proname ILIKE '%create_tenant%' OR
                p.proname ILIKE '%add_user%' OR
                p.proname ILIKE '%signup%'
            )
            AND n.nspname IN ('api', 'auth', 'util')
            ORDER BY n.nspname, p.proname
        LOOP
            func_count := func_count + 1;
            RAISE NOTICE '   🔧 Function %: %.%', func_count, func_record.schema_name, func_record.function_name;
            RAISE NOTICE '      Arguments: %', func_record.arguments;
            RAISE NOTICE '      Returns: %', func_record.return_type;
            RAISE NOTICE '';
        END LOOP;
        
        IF func_count = 0 THEN
            RAISE NOTICE '   ⚠️  NO USER CREATION FUNCTIONS FOUND!';
        ELSE
            RAISE NOTICE '   📊 Found % user creation functions', func_count;
        END IF;
    END;
    RAISE NOTICE '';
    
    -- =============================================
    -- 4. TENANT INFORMATION
    -- =============================================
    RAISE NOTICE '🏢 TENANT INFORMATION:';
    RAISE NOTICE '';
    
    DECLARE
        tenant_record RECORD;
    BEGIN
        SELECT 
            encode(t.tenant_hk, 'hex') as tenant_id,
            t.tenant_bk,
            tp.tenant_name,
            tp.tenant_description,
            tp.subscription_level,
            tp.max_users,
            tp.created_date
        INTO tenant_record
        FROM auth.tenant_h t
        JOIN auth.tenant_profile_s tp ON t.tenant_hk = tp.tenant_hk
        WHERE t.tenant_hk = v_tenant_hk
        AND tp.load_end_date IS NULL
        ORDER BY tp.load_date DESC
        LIMIT 1;
        
        IF tenant_record IS NOT NULL THEN
            RAISE NOTICE '   🏢 Tenant: %', tenant_record.tenant_name;
            RAISE NOTICE '      ID: %', tenant_record.tenant_id;
            RAISE NOTICE '      Business Key: %', tenant_record.tenant_bk;
            RAISE NOTICE '      Subscription: %', tenant_record.subscription_level;
            RAISE NOTICE '      Max Users: %', tenant_record.max_users;
            RAISE NOTICE '      Created: %', tenant_record.created_date;
        ELSE
            RAISE NOTICE '   ⚠️  TENANT INFORMATION NOT FOUND!';
        END IF;
    END;
    RAISE NOTICE '';
    
    -- =============================================
    -- 5. RECOMMENDATIONS
    -- =============================================
    RAISE NOTICE '💡 RECOMMENDATIONS:';
    RAISE NOTICE '';
    
    -- Check if we need to create default roles
    IF NOT EXISTS (SELECT 1 FROM auth.role_h LIMIT 1) THEN
        RAISE NOTICE '   🎯 CREATE DEFAULT ROLES:';
        RAISE NOTICE '      • Administrator (full access)';
        RAISE NOTICE '      • Standard User (basic access)';
        RAISE NOTICE '      • Viewer (read-only access)';
        RAISE NOTICE '';
    END IF;
    
    -- Check if user needs role assignment
    IF NOT EXISTS (
        SELECT 1 FROM auth.user_role_l 
        WHERE user_hk = v_user_hk
    ) THEN
        RAISE NOTICE '   🎯 ASSIGN USER ROLES:';
        RAISE NOTICE '      • User "%" needs role assignment', v_target_username;
        RAISE NOTICE '      • Suggest: Administrator role for initial setup';
        RAISE NOTICE '';
    END IF;
    
    RAISE NOTICE '🔍════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔍              INVESTIGATION COMPLETE                            ';
    RAISE NOTICE '🔍════════════════════════════════════════════════════════════════';
    
END $$; 