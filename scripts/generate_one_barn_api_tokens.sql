-- ========================================================================
-- GENERATE ONE BARN AI API TOKENS FOR DEMO
-- ========================================================================
-- Creates API tokens for key One Barn AI users for July 7, 2025 presentation

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_token_result RECORD;
    v_user_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🐎🤖 === GENERATING ONE BARN AI API TOKENS ===';
    RAISE NOTICE 'For July 7, 2025 Horse Health AI Platform Demo';
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
    RAISE NOTICE '';
    
    -- ================================
    -- TRAVIS WOODWARD (CEO) - FULL ACCESS TOKEN
    -- ================================
    
    RAISE NOTICE '👤 Generating API token for Travis Woodward (CEO)...';
    
    SELECT uh.user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    WHERE uh.tenant_hk = v_tenant_hk
    AND up.email = 'travis.woodward@onebarnai.com'
    AND up.load_end_date IS NULL;
    
    IF v_user_hk IS NOT NULL THEN
        SELECT * INTO v_token_result
        FROM auth.generate_api_token(
            p_user_hk := v_user_hk,
            p_token_type := 'ADMIN_API',
            p_scope := ARRAY['horses:read', 'horses:write', 'analytics:read', 'analytics:write', 'users:admin', 'system:admin'],
            p_expires_in := INTERVAL '30 days'
        );
        
        RAISE NOTICE '✅ Travis Woodward (CEO) API Token:';
        RAISE NOTICE '   Token: %', v_token_result.token_value;
        RAISE NOTICE '   Expires: %', v_token_result.expires_at;
        RAISE NOTICE '   Scope: Full Administrator Access';
        RAISE NOTICE '';
        v_user_count := v_user_count + 1;
    END IF;
    
    -- ================================
    -- MICHELLE NASH (SUPPORT MANAGER) - SUPPORT ACCESS
    -- ================================
    
    RAISE NOTICE '👤 Generating API token for Michelle Nash (Support Manager)...';
    
    SELECT uh.user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    WHERE uh.tenant_hk = v_tenant_hk
    AND up.email = 'michelle.nash@onebarnai.com'
    AND up.load_end_date IS NULL;
    
    IF v_user_hk IS NOT NULL THEN
        SELECT * INTO v_token_result
        FROM auth.generate_api_token(
            p_user_hk := v_user_hk,
            p_token_type := 'MANAGER_API',
            p_scope := ARRAY['horses:read', 'horses:write', 'analytics:read', 'users:read', 'support:admin'],
            p_expires_in := INTERVAL '30 days'
        );
        
        RAISE NOTICE '✅ Michelle Nash (Support Manager) API Token:';
        RAISE NOTICE '   Token: %', v_token_result.token_value;
        RAISE NOTICE '   Expires: %', v_token_result.expires_at;
        RAISE NOTICE '   Scope: Manager + Support Access';
        RAISE NOTICE '';
        v_user_count := v_user_count + 1;
    END IF;
    
    -- ================================
    -- SARAH ROBERTSON (VP BUSINESS DEV) - BUSINESS ACCESS
    -- ================================
    
    RAISE NOTICE '👤 Generating API token for Sarah Robertson (VP Business Dev)...';
    
    SELECT uh.user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    WHERE uh.tenant_hk = v_tenant_hk
    AND up.email = 'sarah.robertson@onebarnai.com'
    AND up.load_end_date IS NULL;
    
    IF v_user_hk IS NOT NULL THEN
        SELECT * INTO v_token_result
        FROM auth.generate_api_token(
            p_user_hk := v_user_hk,
            p_token_type := 'BUSINESS_API',
            p_scope := ARRAY['horses:read', 'analytics:read', 'reports:read', 'reports:write', 'business:admin'],
            p_expires_in := INTERVAL '30 days'
        );
        
        RAISE NOTICE '✅ Sarah Robertson (VP Business Dev) API Token:';
        RAISE NOTICE '   Token: %', v_token_result.token_value;
        RAISE NOTICE '   Expires: %', v_token_result.expires_at;
        RAISE NOTICE '   Scope: Business Analytics & Reporting';
        RAISE NOTICE '';
        v_user_count := v_user_count + 1;
    END IF;
    
    -- ================================
    -- DEMO USER - LIMITED DEMO ACCESS
    -- ================================
    
    RAISE NOTICE '👤 Generating API token for Demo User (Presentations)...';
    
    SELECT uh.user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    WHERE uh.tenant_hk = v_tenant_hk
    AND up.email = 'demo@onebarnai.com'
    AND up.load_end_date IS NULL;
    
    IF v_user_hk IS NOT NULL THEN
        SELECT * INTO v_token_result
        FROM auth.generate_api_token(
            p_user_hk := v_user_hk,
            p_token_type := 'DEMO_API',
            p_scope := ARRAY['horses:read', 'analytics:read', 'demo:access'],
            p_expires_in := INTERVAL '7 days'
        );
        
        RAISE NOTICE '✅ Demo User API Token:';
        RAISE NOTICE '   Token: %', v_token_result.token_value;
        RAISE NOTICE '   Expires: %', v_token_result.expires_at;
        RAISE NOTICE '   Scope: Read-Only Demo Access';
        RAISE NOTICE '';
        v_user_count := v_user_count + 1;
    END IF;
    
    -- ================================
    -- SYSTEM ADMIN - EMERGENCY ACCESS
    -- ================================
    
    RAISE NOTICE '👤 Generating API token for System Administrator (Emergency)...';
    
    SELECT uh.user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    WHERE uh.tenant_hk = v_tenant_hk
    AND up.email = 'admin@onebarnai.com'
    AND up.load_end_date IS NULL;
    
    IF v_user_hk IS NOT NULL THEN
        SELECT * INTO v_token_result
        FROM auth.generate_api_token(
            p_user_hk := v_user_hk,
            p_token_type := 'SYSTEM_API',
            p_scope := ARRAY['system:admin', 'users:admin', 'horses:admin', 'analytics:admin', 'audit:read'],
            p_expires_in := INTERVAL '90 days'
        );
        
        RAISE NOTICE '✅ System Administrator API Token:';
        RAISE NOTICE '   Token: %', v_token_result.token_value;
        RAISE NOTICE '   Expires: %', v_token_result.expires_at;
        RAISE NOTICE '   Scope: Full System Administration';
        RAISE NOTICE '';
        v_user_count := v_user_count + 1;
    END IF;
    
    -- ================================
    -- SUMMARY
    -- ================================
    
    RAISE NOTICE '🎉 === API TOKEN GENERATION COMPLETE ===';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Generated % API tokens for One Barn AI team', v_user_count;
    RAISE NOTICE '✅ All tokens ready for July 7, 2025 presentation';
    RAISE NOTICE '✅ Tokens include appropriate scope-based permissions';
    RAISE NOTICE '';
    RAISE NOTICE '🔐 TOKEN USAGE GUIDELINES:';
    RAISE NOTICE '';
    RAISE NOTICE '• Include token in Authorization header: "Bearer <token>"';
    RAISE NOTICE '• Tokens are tenant-isolated to one_barn_ai';
    RAISE NOTICE '• Each token has scope-based permissions';
    RAISE NOTICE '• All API activity is fully audited';
    RAISE NOTICE '• Demo token expires in 7 days (others in 30-90 days)';
    RAISE NOTICE '';
    RAISE NOTICE '🐎🤖 ONE BARN AI: API TOKENS READY FOR EQUINE HEALTHCARE REVOLUTION!';
    
END $$; 