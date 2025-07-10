-- step1_create_tenant_template.sql
-- Template for creating new tenants in OneVault platform
-- 
-- Usage Instructions:
-- 1. Copy this file to a new file (e.g., step1_create_onevault_tenant.sql)
-- 2. Replace all {PLACEHOLDER} values with actual values
-- 3. Run the script on your target database
--
-- Required Replacements:
-- {PLATFORM_NAME} - Platform identifier (e.g., 'onevault', 'onevault_canvas', 'customer_name')
-- {PLATFORM_DISPLAY_NAME} - Human-readable platform name
-- {ADMIN_EMAIL} - Admin user email address
-- {ADMIN_PASSWORD} - Secure admin password
-- {TENANT_TYPE} - 'internal' for company platforms, 'customer' for customer platforms
-- {CONTACT_PHONE} - Contact phone number
-- {CONTACT_ADDRESS} - Physical address
-- {CONTACT_CITY} - City
-- {CONTACT_STATE} - State/Province
-- {CONTACT_ZIP} - Postal code
-- {CONTACT_COUNTRY} - Country code (e.g., 'US', 'CA')

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_admin_user_hk BYTEA;
    v_admin_role_hk BYTEA;
    v_success BOOLEAN;
    v_message TEXT;
    v_user_data JSONB;
    v_session_token VARCHAR(255);
BEGIN
    RAISE NOTICE 'Creating tenant: {PLATFORM_NAME}';
    
    -- Create tenant
    SELECT p_tenant_hk, p_success, p_message 
    INTO v_tenant_hk, v_success, v_message
    FROM auth.register_tenant(
        '{PLATFORM_NAME}',
        '{TENANT_TYPE}',
        '{PLATFORM_NAME}@onevault.com',
        '{CONTACT_PHONE}',
        '{CONTACT_ADDRESS}',
        '{CONTACT_CITY}',
        '{CONTACT_STATE}',
        '{CONTACT_ZIP}',
        '{CONTACT_COUNTRY}',
        '{ADMIN_EMAIL}',
        '{ADMIN_PASSWORD}'
    );
    
    IF NOT v_success THEN
        RAISE EXCEPTION 'Failed to create tenant: %', v_message;
    END IF;
    
    RAISE NOTICE '✅ Tenant created successfully';
    RAISE NOTICE 'Tenant: {PLATFORM_NAME}';
    RAISE NOTICE 'Tenant HK: %', encode(v_tenant_hk, 'hex');
    RAISE NOTICE 'Admin User: {ADMIN_EMAIL}';
    RAISE NOTICE 'Admin Password: {ADMIN_PASSWORD}';
    RAISE NOTICE '';
    RAISE NOTICE '🔐 IMPORTANT: Store these credentials securely!';
    
END $$;

-- Verify tenant creation
SELECT 
    'Tenant Verification' as check_type,
    tenant_bk,
    encode(tenant_hk, 'hex') as tenant_hk_hex,
    load_date
FROM auth.tenant_h 
WHERE tenant_bk = '{PLATFORM_NAME}'; 