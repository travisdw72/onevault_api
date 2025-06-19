-- =============================================
-- FIXED: API Role Management Functions
-- Multi-Entity Business Optimization Platform
-- Resolves GROUP BY / ORDER BY aggregate function issue
-- =============================================

-- Fix the tenant_roles_list function - ORDER BY must be inside the aggregate function
CREATE OR REPLACE FUNCTION api.tenant_roles_list(
    p_request JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tenant_id TEXT;
    v_roles JSONB;
BEGIN
    v_tenant_id := p_request->>'tenant_id';
    
    IF v_tenant_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Tenant ID is required',
            'error_code', 'MISSING_TENANT_ID'
        );
    END IF;
    
    -- FIXED: Move ORDER BY inside the jsonb_agg() function
    SELECT jsonb_agg(
        jsonb_build_object(
            'role_name', rds.role_name,
            'role_bk', rh.role_bk,
            'description', rds.role_description,
            'is_system_role', rds.is_system_role,
            'permissions', rds.permissions,
            'created_date', rds.created_date
        ) ORDER BY rds.is_system_role DESC, rds.role_name
    ) INTO v_roles
    FROM auth.role_h rh
    JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
    JOIN auth.tenant_h th ON rh.tenant_hk = th.tenant_hk
    WHERE th.tenant_bk = v_tenant_id
    AND rds.load_end_date IS NULL;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Roles retrieved successfully',
        'data', jsonb_build_object(
            'tenant_id', v_tenant_id,
            'roles', COALESCE(v_roles, '[]'::JSONB),
            'total_roles', CASE 
                WHEN v_roles IS NULL THEN 0
                ELSE jsonb_array_length(v_roles)
            END
        )
    );
END;
$$;

-- Test the fixed function
SELECT api.tenant_roles_list(jsonb_build_object(
    'tenant_id', (SELECT tenant_bk FROM auth.tenant_h LIMIT 1)
));

-- Verification message
DO $$ 
BEGIN
    RAISE NOTICE '=== ROLE MANAGEMENT FIX APPLIED ===';
    RAISE NOTICE 'Fixed: ORDER BY clause moved inside jsonb_agg() function';
    RAISE NOTICE 'Function api.tenant_roles_list() should now work correctly';
    RAISE NOTICE 'Ready for business module development';
END $$;
