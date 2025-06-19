-- ============================================================================
-- RAW & STAGING HELPER FUNCTIONS - Universal Learning Loop
-- Data Processing Utilities for Raw/Staging Operations
-- Supports: One Vault Demo Barn & One Vault Production
-- ============================================================================

-- ============================================================================
-- RAW DATA INGESTION FUNCTIONS
-- ============================================================================

-- Insert External Data with automatic hash generation
CREATE OR REPLACE FUNCTION raw.insert_external_data(
    p_tenant_hk BYTEA,
    p_source_system VARCHAR(100),
    p_source_endpoint VARCHAR(500),
    p_raw_payload JSONB,
    p_batch_id VARCHAR(255) DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_external_data_hk BYTEA;
    v_external_data_bk VARCHAR(255);
    v_hash_diff BYTEA;
    v_collection_timestamp TIMESTAMP WITH TIME ZONE;
BEGIN
    v_collection_timestamp := CURRENT_TIMESTAMP;
    
    -- Generate business key
    v_external_data_bk := p_source_system || '_' || 
                         COALESCE(p_batch_id, to_char(v_collection_timestamp, 'YYYYMMDD_HH24MISS_US'));
    
    -- Generate hash key
    v_external_data_hk := util.hash_binary(v_external_data_bk || encode(p_tenant_hk, 'hex'));
    
    -- Generate hash diff
    v_hash_diff := util.hash_binary(
        p_source_system || 
        COALESCE(p_source_endpoint, '') ||
        p_raw_payload::text ||
        v_collection_timestamp::text
    );
    
    -- Insert hub record
    INSERT INTO raw.external_data_h VALUES (
        v_external_data_hk,
        v_external_data_bk,
        p_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    ) ON CONFLICT (external_data_bk, tenant_hk) DO NOTHING;
    
    -- Insert satellite record
    INSERT INTO raw.external_data_s VALUES (
        v_external_data_hk,
        util.current_load_date(),
        NULL,
        v_hash_diff,
        p_source_system,
        p_source_endpoint,
        'GET',
        p_batch_id,
        'JSON',
        p_raw_payload,
        pg_column_size(p_raw_payload),
        v_collection_timestamp,
        'PENDING',
        NULL,
        util.get_record_source()
    );
    
    RETURN v_external_data_hk;
END;
$$ LANGUAGE plpgsql;

-- Insert User Input Data
CREATE OR REPLACE FUNCTION raw.insert_user_input(
    p_tenant_hk BYTEA,
    p_user_hk BYTEA,
    p_session_hk BYTEA,
    p_input_type VARCHAR(100),
    p_form_identifier VARCHAR(255),
    p_raw_input_data JSONB,
    p_interaction_type VARCHAR(50) DEFAULT 'FORM_SUBMIT'
) RETURNS BYTEA AS $$
DECLARE
    v_user_input_hk BYTEA;
    v_user_input_bk VARCHAR(255);
    v_hash_diff BYTEA;
    v_input_timestamp TIMESTAMP WITH TIME ZONE;
BEGIN
    v_input_timestamp := CURRENT_TIMESTAMP;
    
    -- Generate business key
    v_user_input_bk := encode(p_user_hk, 'hex') || '_' || 
                      p_input_type || '_' ||
                      to_char(v_input_timestamp, 'YYYYMMDD_HH24MISS_US');
    
    -- Generate hash key
    v_user_input_hk := util.hash_binary(v_user_input_bk || encode(p_tenant_hk, 'hex'));
    
    -- Generate hash diff
    v_hash_diff := util.hash_binary(
        p_input_type ||
        COALESCE(p_form_identifier, '') ||
        p_raw_input_data::text ||
        v_input_timestamp::text
    );
    
    -- Insert hub record
    INSERT INTO raw.user_input_h VALUES (
        v_user_input_hk,
        v_user_input_bk,
        p_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    ) ON CONFLICT (user_input_bk, tenant_hk) DO NOTHING;
    
    -- Insert satellite record
    INSERT INTO raw.user_input_s VALUES (
        v_user_input_hk,
        util.current_load_date(),
        NULL,
        v_hash_diff,
        p_user_hk,
        p_session_hk,
        p_input_type,
        p_form_identifier,
        NULL, -- field_name
        p_interaction_type,
        p_raw_input_data,
        v_input_timestamp,
        NULL, -- client_info
        'UNVALIDATED',
        true,
        util.get_record_source()
    );
    
    RETURN v_user_input_hk;
END;
$$ LANGUAGE plpgsql;

-- Insert File Data
CREATE OR REPLACE FUNCTION raw.insert_file_data(
    p_tenant_hk BYTEA,
    p_user_hk BYTEA,
    p_original_filename VARCHAR(500),
    p_file_content BYTEA,
    p_mime_type VARCHAR(200),
    p_upload_source VARCHAR(100) DEFAULT 'WEB_UPLOAD'
) RETURNS BYTEA AS $$
DECLARE
    v_file_data_hk BYTEA;
    v_file_data_bk VARCHAR(255);
    v_hash_diff BYTEA;
    v_upload_timestamp TIMESTAMP WITH TIME ZONE;
    v_file_hash VARCHAR(64);
BEGIN
    v_upload_timestamp := CURRENT_TIMESTAMP;
    v_file_hash := encode(digest(p_file_content, 'sha256'), 'hex');
    
    -- Generate business key
    v_file_data_bk := encode(p_user_hk, 'hex') || '_' || 
                     v_file_hash || '_' ||
                     to_char(v_upload_timestamp, 'YYYYMMDD_HH24MISS');
    
    -- Generate hash key
    v_file_data_hk := util.hash_binary(v_file_data_bk || encode(p_tenant_hk, 'hex'));
    
    -- Generate hash diff
    v_hash_diff := util.hash_binary(
        p_original_filename ||
        v_file_hash ||
        p_mime_type ||
        v_upload_timestamp::text
    );
    
    -- Insert hub record
    INSERT INTO raw.file_data_h VALUES (
        v_file_data_hk,
        v_file_data_bk,
        p_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    ) ON CONFLICT (file_data_bk, tenant_hk) DO NOTHING;
    
    -- Insert satellite record
    INSERT INTO raw.file_data_s VALUES (
        v_file_data_hk,
        util.current_load_date(),
        NULL,
        v_hash_diff,
        p_user_hk,
        p_original_filename,
        split_part(p_original_filename, '.', -1),
        p_mime_type,
        pg_column_size(p_file_content),
        v_file_hash,
        NULL, -- storage_location
        p_file_content,
        p_upload_source,
        v_upload_timestamp,
        'PENDING',
        'PENDING',
        NULL, -- metadata_extracted
        NULL,
        util.get_record_source()
    );
    
    RETURN v_file_data_hk;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STAGING PROCESSING FUNCTIONS
-- ============================================================================

-- Start User Input Validation Process
CREATE OR REPLACE FUNCTION staging.start_user_input_validation(
    p_tenant_hk BYTEA,
    p_raw_user_input_hk BYTEA,
    p_validation_type VARCHAR(100) DEFAULT 'STANDARD'
) RETURNS BYTEA AS $$
DECLARE
    v_validation_batch_hk BYTEA;
    v_validation_batch_bk VARCHAR(255);
    v_hash_diff BYTEA;
    v_validation_timestamp TIMESTAMP WITH TIME ZONE;
BEGIN
    v_validation_timestamp := CURRENT_TIMESTAMP;
    
    -- Generate business key
    v_validation_batch_bk := 'USER_VAL_' || 
                            encode(p_raw_user_input_hk, 'hex') || '_' ||
                            to_char(v_validation_timestamp, 'YYYYMMDD_HH24MISS');
    
    -- Generate hash key
    v_validation_batch_hk := util.hash_binary(v_validation_batch_bk || encode(p_tenant_hk, 'hex'));
    
    -- Generate hash diff
    v_hash_diff := util.hash_binary(
        encode(p_raw_user_input_hk, 'hex') ||
        p_validation_type ||
        v_validation_timestamp::text
    );
    
    -- Insert hub record
    INSERT INTO staging.user_input_validation_h VALUES (
        v_validation_batch_hk,
        v_validation_batch_bk,
        p_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    );
    
    -- Insert satellite record
    INSERT INTO staging.user_input_validation_s VALUES (
        v_validation_batch_hk,
        util.current_load_date(),
        NULL,
        v_hash_diff,
        p_raw_user_input_hk,
        v_validation_timestamp,
        p_validation_type,
        NULL, -- input_category
        ARRAY[]::TEXT[], -- validation_rules_applied
        '{}'::JSONB, -- validation_results
        '{}'::JSONB, -- sanitization_performed
        '{}'::JSONB, -- security_scan_results
        NULL, -- data_quality_score
        'PENDING',
        0, -- error_count
        0, -- warning_count
        NULL, -- processing_duration_ms
        'SANITIZATION', -- next_processing_step
        util.get_record_source()
    );
    
    RETURN v_validation_batch_hk;
END;
$$ LANGUAGE plpgsql;

-- Start Data Validation Process
CREATE OR REPLACE FUNCTION staging.start_data_validation(
    p_tenant_hk BYTEA,
    p_raw_data_source VARCHAR(100),
    p_raw_data_hk BYTEA,
    p_data_source_type VARCHAR(100)
) RETURNS BYTEA AS $$
DECLARE
    v_data_validation_hk BYTEA;
    v_data_validation_bk VARCHAR(255);
    v_hash_diff BYTEA;
    v_validation_timestamp TIMESTAMP WITH TIME ZONE;
BEGIN
    v_validation_timestamp := CURRENT_TIMESTAMP;
    
    -- Generate business key
    v_data_validation_bk := 'DATA_VAL_' || 
                           p_raw_data_source || '_' ||
                           encode(p_raw_data_hk, 'hex') || '_' ||
                           to_char(v_validation_timestamp, 'YYYYMMDD_HH24MISS');
    
    -- Generate hash key
    v_data_validation_hk := util.hash_binary(v_data_validation_bk || encode(p_tenant_hk, 'hex'));
    
    -- Generate hash diff
    v_hash_diff := util.hash_binary(
        p_raw_data_source ||
        encode(p_raw_data_hk, 'hex') ||
        p_data_source_type ||
        v_validation_timestamp::text
    );
    
    -- Insert hub record
    INSERT INTO staging.data_validation_h VALUES (
        v_data_validation_hk,
        v_data_validation_bk,
        p_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    );
    
    -- Insert satellite record
    INSERT INTO staging.data_validation_s VALUES (
        v_data_validation_hk,
        util.current_load_date(),
        NULL,
        v_hash_diff,
        p_raw_data_source,
        p_raw_data_hk,
        v_validation_timestamp,
        p_data_source_type,
        '{}'::JSONB, -- validation_rules_config
        NULL, -- data_completeness_score
        NULL, -- data_accuracy_score
        NULL, -- data_consistency_score
        NULL, -- data_validity_score
        NULL, -- overall_quality_score
        '{}'::JSONB, -- validation_results
        '{}'::JSONB, -- field_level_validations
        '{}'::JSONB, -- business_rule_validations
        '{}'::JSONB, -- data_profiling_results
        '{}'::JSONB, -- anomalies_detected
        '{}'::JSONB, -- correction_suggestions
        0, -- records_processed
        0, -- records_passed
        0, -- records_failed
        'PENDING',
        util.get_record_source()
    );
    
    RETURN v_data_validation_hk;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DATA QUALITY ASSESSMENT FUNCTIONS
-- ============================================================================

-- Calculate Data Quality Score
CREATE OR REPLACE FUNCTION staging.calculate_data_quality_score(
    p_completeness_score DECIMAL(5,2),
    p_accuracy_score DECIMAL(5,2),
    p_consistency_score DECIMAL(5,2),
    p_validity_score DECIMAL(5,2),
    p_completeness_weight DECIMAL(3,2) DEFAULT 0.25,
    p_accuracy_weight DECIMAL(3,2) DEFAULT 0.35,
    p_consistency_weight DECIMAL(3,2) DEFAULT 0.20,
    p_validity_weight DECIMAL(3,2) DEFAULT 0.20
) RETURNS DECIMAL(5,2) AS $$
DECLARE
    v_overall_score DECIMAL(5,2);
BEGIN
    -- Weighted average of quality dimensions
    v_overall_score := (
        COALESCE(p_completeness_score, 0) * p_completeness_weight +
        COALESCE(p_accuracy_score, 0) * p_accuracy_weight +
        COALESCE(p_consistency_score, 0) * p_consistency_weight +
        COALESCE(p_validity_score, 0) * p_validity_weight
    );
    
    -- Ensure score is between 0 and 100
    RETURN GREATEST(0, LEAST(100, v_overall_score));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Analyze JSON Data Structure
CREATE OR REPLACE FUNCTION staging.analyze_json_structure(
    p_json_data JSONB
) RETURNS JSONB AS $$
DECLARE
    v_analysis JSONB;
    v_field_count INTEGER;
    v_null_fields INTEGER;
    v_empty_fields INTEGER;
    v_field_types JSONB;
BEGIN
    -- Count total fields
    SELECT count(*) INTO v_field_count 
    FROM jsonb_each(p_json_data);
    
    -- Count null fields
    SELECT count(*) INTO v_null_fields
    FROM jsonb_each(p_json_data)
    WHERE value = 'null'::jsonb;
    
    -- Count empty string fields
    SELECT count(*) INTO v_empty_fields
    FROM jsonb_each(p_json_data)
    WHERE value = '""'::jsonb;
    
    -- Analyze field types
    SELECT jsonb_object_agg(key, jsonb_typeof(value)) INTO v_field_types
    FROM jsonb_each(p_json_data);
    
    -- Build analysis result
    v_analysis := jsonb_build_object(
        'total_fields', v_field_count,
        'null_fields', v_null_fields,
        'empty_fields', v_empty_fields,
        'completeness_percentage', 
            CASE WHEN v_field_count > 0 
                 THEN ROUND((v_field_count - v_null_fields - v_empty_fields)::DECIMAL / v_field_count * 100, 2)
                 ELSE 0 
            END,
        'field_types', v_field_types,
        'data_size_bytes', pg_column_size(p_json_data)
    );
    
    RETURN v_analysis;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- UNIVERSAL LEARNING SUPPORT FUNCTIONS
-- ============================================================================

-- Extract Learning Patterns from Raw Data
CREATE OR REPLACE FUNCTION staging.extract_learning_patterns(
    p_tenant_hk BYTEA,
    p_domain_context VARCHAR(100),
    p_data_sample JSONB,
    p_pattern_type VARCHAR(100) DEFAULT 'GENERAL'
) RETURNS JSONB AS $$
DECLARE
    v_patterns JSONB;
    v_field_frequency JSONB;
    v_value_distributions JSONB;
BEGIN
    -- Initialize patterns object
    v_patterns := jsonb_build_object(
        'domain_context', p_domain_context,
        'pattern_type', p_pattern_type,
        'extraction_timestamp', CURRENT_TIMESTAMP,
        'tenant_specific', true
    );
    
    -- Field frequency analysis
    SELECT jsonb_object_agg(
        key, 
        jsonb_build_object(
            'present', true,
            'type', jsonb_typeof(value),
            'sample_value', CASE 
                WHEN jsonb_typeof(value) = 'string' THEN left(value::text, 50)
                ELSE value
            END
        )
    ) INTO v_field_frequency
    FROM jsonb_each(p_data_sample);
    
    -- Basic value distributions
    v_value_distributions := jsonb_build_object(
        'string_fields', (
            SELECT count(*) 
            FROM jsonb_each(p_data_sample) 
            WHERE jsonb_typeof(value) = 'string'
        ),
        'numeric_fields', (
            SELECT count(*) 
            FROM jsonb_each(p_data_sample) 
            WHERE jsonb_typeof(value) = 'number'
        ),
        'boolean_fields', (
            SELECT count(*) 
            FROM jsonb_each(p_data_sample) 
            WHERE jsonb_typeof(value) = 'boolean'
        )
    );
    
    -- Build final patterns
    v_patterns := v_patterns || jsonb_build_object(
        'field_analysis', v_field_frequency,
        'value_distributions', v_value_distributions
    );
    
    RETURN v_patterns;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Get Processing Statistics
CREATE OR REPLACE FUNCTION staging.get_processing_statistics(
    p_tenant_hk BYTEA,
    p_processing_date DATE DEFAULT CURRENT_DATE
) RETURNS TABLE (
    schema_name VARCHAR(100),
    table_name VARCHAR(100),
    total_records BIGINT,
    pending_records BIGINT,
    completed_records BIGINT,
    failed_records BIGINT,
    processing_rate DECIMAL(5,2)
) AS $$
BEGIN
    -- Raw schema statistics
    RETURN QUERY
    SELECT 
        'raw'::VARCHAR(100),
        'external_data'::VARCHAR(100),
        count(*),
        count(*) FILTER (WHERE eds.processing_status = 'PENDING'),
        count(*) FILTER (WHERE eds.processing_status = 'COMPLETED'),
        count(*) FILTER (WHERE eds.processing_status = 'FAILED'),
        CASE WHEN count(*) > 0 
             THEN ROUND(count(*) FILTER (WHERE eds.processing_status = 'COMPLETED')::DECIMAL / count(*) * 100, 2)
             ELSE 0 
        END
    FROM raw.external_data_h edh
    JOIN raw.external_data_s eds ON edh.external_data_hk = eds.external_data_hk
    WHERE edh.tenant_hk = p_tenant_hk
    AND eds.load_end_date IS NULL
    AND edh.load_date::DATE = p_processing_date
    
    UNION ALL
    
    -- Staging schema statistics
    SELECT 
        'staging'::VARCHAR(100),
        'user_input_validation'::VARCHAR(100),
        count(*),
        count(*) FILTER (WHERE uivs.validation_status = 'PENDING'),
        count(*) FILTER (WHERE uivs.validation_status = 'VALID'),
        count(*) FILTER (WHERE uivs.validation_status = 'INVALID'),
        CASE WHEN count(*) > 0 
             THEN ROUND(count(*) FILTER (WHERE uivs.validation_status = 'VALID')::DECIMAL / count(*) * 100, 2)
             ELSE 0 
        END
    FROM staging.user_input_validation_h uivh
    JOIN staging.user_input_validation_s uivs ON uivh.validation_batch_hk = uivs.validation_batch_hk
    WHERE uivh.tenant_hk = p_tenant_hk
    AND uivs.load_end_date IS NULL
    AND uivh.load_date::DATE = p_processing_date;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- GRANTS AND PERMISSIONS
-- ============================================================================

-- Grant execute permissions on functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA raw TO postgres;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA staging TO postgres;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Raw and Staging helper functions created successfully!';
    RAISE NOTICE 'Functions created:';
    RAISE NOTICE '  • raw.insert_external_data() - Insert external API data';
    RAISE NOTICE '  • raw.insert_user_input() - Insert user form/interaction data';
    RAISE NOTICE '  • raw.insert_file_data() - Insert file upload data';
    RAISE NOTICE '  • staging.start_user_input_validation() - Begin user input validation';
    RAISE NOTICE '  • staging.start_data_validation() - Begin external data validation';
    RAISE NOTICE '  • staging.calculate_data_quality_score() - Calculate quality metrics';
    RAISE NOTICE '  • staging.analyze_json_structure() - Analyze JSON data patterns';
    RAISE NOTICE '  • staging.extract_learning_patterns() - Extract AI learning patterns';
    RAISE NOTICE '  • staging.get_processing_statistics() - Get processing metrics';
    RAISE NOTICE 'Ready for universal data processing operations!';
END $$; 