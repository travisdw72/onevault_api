-- step7_generate_api_key_template.sql
-- Template for generating platform API keys during tenant setup
-- 
-- Usage Instructions:
-- 1. Copy this file to a new file (e.g., step7_generate_onevault_api_key.sql)
-- 2. Replace all {PLACEHOLDER} values with actual values
-- 3. Run this script after creating all users
--
-- Required Replacements:
-- {PLATFORM_NAME} - Platform identifier (must match step1)
-- {API_KEY_NAME} - Name for the API key (e.g., 'onevault_platform_key')
-- {API_KEY_DESCRIPTION} - Description of the API key purpose
-- {EXPIRATION_INTERVAL} - How long the key should be valid (e.g., '1 year', '6 months')
-- {API_SCOPES} - Comma-separated list of scopes (e.g., 'read', 'write', 'ai_chat', 'site_events')

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_api_key VARCHAR(255);
    v_api_key_hk BYTEA;
    v_success BOOLEAN;
    v_message TEXT;
    v_expiration_date DATE;
BEGIN
    RAISE NOTICE 'Generating API key for platform: {PLATFORM_NAME}';
    
    -- Get tenant HK
    SELECT tenant_hk INTO v_tenant_hk 
    FROM auth.tenant_h 
    WHERE tenant_bk = '{PLATFORM_NAME}';
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'Tenant not found: {PLATFORM_NAME}. Please run step1_create_tenant first.';
    END IF;
    
    -- Calculate expiration date
    v_expiration_date := CURRENT_DATE + INTERVAL '{EXPIRATION_INTERVAL}';
    
    -- Generate API key
    SELECT p_api_key_hk, p_api_key, p_success, p_message
    INTO v_api_key_hk, v_api_key, v_success, v_message
    FROM auth.generate_api_key(
        v_tenant_hk,
        '{API_KEY_NAME}',
        '{API_KEY_DESCRIPTION}',
        v_expiration_date,
        ARRAY[{API_SCOPES}] -- e.g., ARRAY['read', 'write', 'ai_chat', 'site_events']
    );
    
    IF NOT v_success THEN
        RAISE EXCEPTION 'Failed to generate API key: %', v_message;
    END IF;
    
    RAISE NOTICE '✅ API Key generated successfully';
    RAISE NOTICE 'Platform: {PLATFORM_NAME}';
    RAISE NOTICE 'API Key Name: {API_KEY_NAME}';
    RAISE NOTICE 'API Key: %', v_api_key;
    RAISE NOTICE 'API Key HK: %', encode(v_api_key_hk, 'hex');
    RAISE NOTICE 'Expiration: %', v_expiration_date;
    RAISE NOTICE 'Scopes: {API_SCOPES}';
    RAISE NOTICE '';
    RAISE NOTICE '🔐 CRITICAL: Store this API key securely!';
    RAISE NOTICE '📋 Add to your application environment variables:';
    RAISE NOTICE 'ONEVAULT_API_KEY=%', v_api_key;
    RAISE NOTICE 'ONEVAULT_API_BASE_URL=https://api.onevault.com';
    RAISE NOTICE '';
    
END $$;

-- Verify API key creation
SELECT 
    'API Key Verification' as check_type,
    key_name,
    description,
    expiration_date,
    scopes,
    encode(api_key_hk, 'hex') as api_key_hk_hex,
    load_date
FROM auth.api_key_h akh
JOIN auth.api_key_s aks ON akh.api_key_hk = aks.api_key_hk
WHERE akh.tenant_hk = (SELECT tenant_hk FROM auth.tenant_h WHERE tenant_bk = '{PLATFORM_NAME}')
AND aks.key_name = '{API_KEY_NAME}'
AND aks.load_end_date IS NULL; 