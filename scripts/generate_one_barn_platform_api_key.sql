-- ========================================================================
-- GENERATE ONE BARN AI PLATFORM API KEY
-- ========================================================================
-- Creates ONE tenant-level API key for the One Barn AI horse health platform
-- Users will login with their credentials through the platform

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_admin_user_hk BYTEA;
    v_token_result RECORD;
BEGIN
    RAISE NOTICE '🐎🤖 === GENERATING ONE BARN AI PLATFORM API KEY ===';
    RAISE NOTICE 'Single tenant-level API key for horse health AI platform';
    RAISE NOTICE '';
    
    -- Get One Barn AI tenant
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL THEN
        RAISE NOTICE '❌ ERROR: one_barn_ai tenant not found!';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Found One Barn AI tenant: %', encode(v_tenant_hk, 'hex');
    
    -- Get admin user to associate the platform API key with
    SELECT uh.user_hk INTO v_admin_user_hk
    FROM auth.user_h uh
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    WHERE uh.tenant_hk = v_tenant_hk
    AND up.email = 'admin@onebarnai.com'
    AND up.load_end_date IS NULL;
    
    IF v_admin_user_hk IS NULL THEN
        RAISE NOTICE '❌ ERROR: admin@onebarnai.com user not found!';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Found admin user: %', encode(v_admin_user_hk, 'hex');
    RAISE NOTICE '';
    
    -- Generate ONE platform API key
    RAISE NOTICE '🔑 Generating One Barn AI Platform API Key...';
    
    SELECT * INTO v_token_result
    FROM auth.generate_api_token(
        p_user_hk := v_admin_user_hk,
        p_token_type := 'API_KEY',
        p_scope := ARRAY[
            'platform:access',
            'horses:read', 'horses:write', 'horses:admin',
            'analytics:read', 'analytics:write', 
            'users:read', 'users:write',
            'reports:read', 'reports:write',
            'health:read', 'health:write',
            'ai:read', 'ai:write'
        ],
        p_expires_in := INTERVAL '1 year'
    );
    
    RAISE NOTICE '';
    RAISE NOTICE '🎉 === ONE BARN AI PLATFORM API KEY CREATED ===';
    RAISE NOTICE '';
    RAISE NOTICE '🔑 API KEY: %', v_token_result.token_value;
    RAISE NOTICE '📅 EXPIRES: %', v_token_result.expires_at;
    RAISE NOTICE '🏢 TENANT: one_barn_ai';
    RAISE NOTICE '🎯 PURPOSE: Horse Health AI Platform Access';
    RAISE NOTICE '';
    RAISE NOTICE '📋 PLATFORM CAPABILITIES:';
    RAISE NOTICE '   ✅ Full horse health data access';
    RAISE NOTICE '   ✅ AI analytics and predictions';
    RAISE NOTICE '   ✅ User authentication & session management';
    RAISE NOTICE '   ✅ Comprehensive reporting';
    RAISE NOTICE '   ✅ Health monitoring and alerts';
    RAISE NOTICE '';
    RAISE NOTICE '🔐 USAGE INSTRUCTIONS:';
    RAISE NOTICE '';
    RAISE NOTICE '1. Platform Authentication:';
    RAISE NOTICE '   Include in API requests: "Authorization: Bearer %"', v_token_result.token_value;
    RAISE NOTICE '';
    RAISE NOTICE '2. User Authentication Flow:';
    RAISE NOTICE '   • Users login: POST /auth/login with email/password';
    RAISE NOTICE '   • Platform validates credentials using API key';
    RAISE NOTICE '   • Users get session tokens for subsequent requests';
    RAISE NOTICE '   • All actions tracked by user_hk in Data Vault 2.0';
    RAISE NOTICE '';
    RAISE NOTICE '3. Available Users (for testing):';
    RAISE NOTICE '   • admin@onebarnai.com (AdminPass123!)';
    RAISE NOTICE '   • travis.woodward@onebarnai.com (SecurePass123!)';
    RAISE NOTICE '   • michelle.nash@onebarnai.com (SupportManager456!)';
    RAISE NOTICE '   • sarah.robertson@onebarnai.com (VPBusinessDev789!)';
    RAISE NOTICE '   • demo@onebarnai.com (Demo123!)';
    RAISE NOTICE '';
    RAISE NOTICE '🐎🤖 ONE BARN AI PLATFORM: READY FOR JULY 7, 2025 DEMO!';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Architecture: Platform API Key + Individual User Logins';
    RAISE NOTICE '📊 Audit Trail: Complete user tracking via Data Vault 2.0';
    RAISE NOTICE '🔒 Security: Tenant isolation + user-level permissions';
    
END $$; 