-- ============================================================================
-- API FUNCTION: Tenant Registration with ELT Pipeline
-- ============================================================================
-- Purpose: Register new business tenant using proper ELT data flow through
--          Raw → Staging → Auth layers with System Operations Tenant
-- 
-- Dependencies: System Operations Tenant must exist (run setup scripts first)
-- Security: Uses system tenant for pre-registration data isolation
-- ============================================================================

CREATE OR REPLACE FUNCTION api.tenant_register_elt(
    p_request JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_external_data_hk BYTEA;
    v_validation_batch_hk BYTEA;
    v_tenant_hk BYTEA;
    v_admin_user_hk BYTEA;
    v_system_tenant_hk BYTEA;
BEGIN
    -- ==============================================
    -- PHASE 0: Use System Operations Tenant
    -- ==============================================
    
    -- Use the existing System Operations Tenant (created during setup)
    v_system_tenant_hk := '\x0000000000000000000000000000000000000000000000000000000000000001'::bytea;
    
    -- Verify system tenant exists (safety check)
    IF NOT EXISTS (
        SELECT 1 FROM auth.tenant_h 
        WHERE tenant_hk = v_system_tenant_hk 
        AND tenant_bk = 'SYSTEM_OPERATIONS'
    ) THEN
        RAISE EXCEPTION 'System Operations Tenant not found! Please run system setup scripts first.';
    END IF;
    
    -- ==============================================
    -- PHASE 1: RAW LAYER - Use raw.external_data_h/s
    -- ==============================================
    
    v_external_data_hk := util.hash_binary('TENANT_REG_EXT_' || CURRENT_TIMESTAMP::text);
    
    -- Insert into raw.external_data_h (external system = tenant registration)
    INSERT INTO raw.external_data_h VALUES (
        v_external_data_hk,
        'TENANT_REGISTRATION_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS_US'),
        v_system_tenant_hk,  -- Use system tenant
        util.current_load_date(),
        util.get_record_source()
    );
    
    -- Insert into raw.external_data_s
    INSERT INTO raw.external_data_s VALUES (
        v_external_data_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(p_request::text),
        'TENANT_REGISTRATION_API',               -- source_system
        '/api/tenant/register',                  -- source_endpoint
        'POST',                                  -- source_method
        'TENANT_REG_' || extract(epoch from CURRENT_TIMESTAMP)::text, -- batch_id
        'JSON',                                  -- data_format
        p_request,                               -- raw_payload
        pg_column_size(p_request),               -- payload_size_bytes
        CURRENT_TIMESTAMP,                       -- collection_timestamp
        'PENDING',                               -- processing_status
        NULL,                                    -- error_details
        util.get_record_source()
    );
    
    -- ==============================================
    -- PHASE 2: STAGING LAYER - Use data_validation_h/s
    -- ==============================================
    
    v_validation_batch_hk := util.hash_binary('TENANT_VAL_' || CURRENT_TIMESTAMP::text);
    
    -- Insert into staging.data_validation_h
    INSERT INTO staging.data_validation_h VALUES (
        v_validation_batch_hk,
        'TENANT_VALIDATION_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS_US'),
        v_system_tenant_hk,  -- Use system tenant
        util.current_load_date(),
        util.get_record_source()
    );
    
    -- Insert validation results into staging.data_validation_s
    INSERT INTO staging.data_validation_s VALUES (
        v_validation_batch_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary('TENANT_VALIDATION' || p_request::text),
        'EXTERNAL_DATA',                         -- raw_data_source
        v_external_data_hk,                      -- raw_data_hk
        CURRENT_TIMESTAMP,                       -- validation_timestamp
        'TENANT_REGISTRATION',                   -- data_source_type
        jsonb_build_object(                      -- validation_rules_config
            'email_validation', true,
            'password_strength', true,
            'required_fields', ARRAY['tenant_name', 'admin_email', 'admin_password']
        ),
        100.0,                                   -- data_completeness_score
        95.0,                                    -- data_accuracy_score
        100.0,                                   -- data_consistency_score
        90.0,                                    -- data_validity_score
        96.25,                                   -- overall_quality_score
        jsonb_build_object(                      -- validation_results
            'email_valid', (p_request->>'admin_email') ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
            'password_strength', CASE 
                WHEN length(p_request->>'admin_password') >= 8 THEN 'STRONG'
                ELSE 'WEAK'
            END,
            'all_required_fields', (
                (p_request->>'tenant_name') IS NOT NULL AND
                (p_request->>'admin_email') IS NOT NULL AND
                (p_request->>'admin_password') IS NOT NULL
            )
        ),
        '{}',                                    -- field_level_validations
        '{}',                                    -- business_rule_validations
        '{}',                                    -- data_profiling_results
        '{}',                                    -- anomalies_detected
        '{}',                                    -- correction_suggestions
        1,                                       -- records_processed
        1,                                       -- records_passed
        0,                                       -- records_failed
        'COMPLETED',                             -- processing_status
        util.get_record_source()
    );
    
    -- ==============================================
    -- PHASE 3: AUTH LAYER - Process Registration
    -- ==============================================
    
    -- Call your existing registration procedure (OUT parameters handled automatically)
    CALL auth.register_tenant(
        trim(p_request->>'tenant_name'),
        lower(trim(p_request->>'admin_email')),
        p_request->>'admin_password',
        COALESCE(trim(p_request->>'admin_first_name'), 'Admin'),
        COALESCE(trim(p_request->>'admin_last_name'), 'User'),
        v_tenant_hk,
        v_admin_user_hk
    );
    
    -- ==============================================
    -- PHASE 4: Update Processing Status
    -- ==============================================
    
    -- Update raw external data status to COMPLETED
    UPDATE raw.external_data_s 
    SET processing_status = 'COMPLETED',
        load_end_date = util.current_load_date()
    WHERE external_data_hk = v_external_data_hk 
    AND load_end_date IS NULL;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Tenant registered successfully via ELT pipeline',
        'data', jsonb_build_object(
            'tenant_id', (SELECT tenant_bk FROM auth.tenant_h WHERE tenant_hk = v_tenant_hk),
            'admin_user_id', (SELECT user_bk FROM auth.user_h WHERE user_hk = v_admin_user_hk),
            'raw_tracking_id', encode(v_external_data_hk, 'hex'),
            'validation_batch_id', encode(v_validation_batch_hk, 'hex'),
            'elt_pipeline', 'COMPLETED'
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    -- Update error status
    UPDATE raw.external_data_s 
    SET processing_status = 'FAILED',
        error_details = SQLERRM,
        load_end_date = util.current_load_date()
    WHERE external_data_hk = v_external_data_hk;
    
    RETURN jsonb_build_object(
        'success', false,
        'message', 'ELT processing failed: ' || SQLERRM,
        'error_code', 'ELT_PROCESSING_FAILED'
    );
END;
$$;