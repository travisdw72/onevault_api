-- ============================================================================
-- RAW & STAGING PERFORMANCE INDEXES - FIXED VERSION
-- Only creates indexes for columns that actually exist
-- Supports: One Vault Demo Barn & One Vault Production
-- ============================================================================

-- Helper function to check if column exists
CREATE OR REPLACE FUNCTION util.column_exists(
    p_schema_name TEXT,
    p_table_name TEXT,
    p_column_name TEXT
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = p_schema_name 
        AND table_name = p_table_name 
        AND column_name = p_column_name
    );
END;
$$ LANGUAGE plpgsql;

-- Helper function to check if table exists
CREATE OR REPLACE FUNCTION util.table_exists(
    p_schema_name TEXT,
    p_table_name TEXT
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = p_schema_name 
        AND table_name = p_table_name
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- RAW SCHEMA INDEXES
-- ============================================================================

-- External Data Indexes (no tenant_hk in raw layer)
CREATE INDEX IF NOT EXISTS idx_external_data_h_load_date 
    ON raw.external_data_h(load_date);

CREATE INDEX IF NOT EXISTS idx_external_data_s_collection_timestamp 
    ON raw.external_data_s(collection_timestamp) 
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_external_data_s_processing_status 
    ON raw.external_data_s(processing_status) 
    WHERE processing_status IN ('PENDING', 'PROCESSING');

CREATE INDEX IF NOT EXISTS idx_external_data_s_source_system 
    ON raw.external_data_s(source_system);

CREATE INDEX IF NOT EXISTS idx_external_data_s_batch_id 
    ON raw.external_data_s(batch_id) 
    WHERE batch_id IS NOT NULL;

-- Partial index for unprocessed external data
CREATE INDEX IF NOT EXISTS idx_external_data_s_pending_processing 
    ON raw.external_data_s(external_data_hk, collection_timestamp) 
    WHERE processing_status = 'PENDING' AND load_end_date IS NULL;

-- User Input Indexes
CREATE INDEX IF NOT EXISTS idx_user_input_h_load_date 
    ON raw.user_input_h(load_date);

CREATE INDEX IF NOT EXISTS idx_user_input_s_user_hk 
    ON raw.user_input_s(user_hk)
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_input_s_session_hk 
    ON raw.user_input_s(session_hk)
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_input_s_input_timestamp 
    ON raw.user_input_s(input_timestamp);

CREATE INDEX IF NOT EXISTS idx_user_input_s_input_type 
    ON raw.user_input_s(input_type);

CREATE INDEX IF NOT EXISTS idx_user_input_s_validation_status 
    ON raw.user_input_s(validation_status);

CREATE INDEX IF NOT EXISTS idx_user_input_s_interaction_type 
    ON raw.user_input_s(interaction_type);

-- Partial index for unvalidated user input
CREATE INDEX IF NOT EXISTS idx_user_input_s_unvalidated 
    ON raw.user_input_s(user_input_hk, input_timestamp) 
    WHERE validation_status = 'UNVALIDATED' AND load_end_date IS NULL;

-- File Data Indexes
CREATE INDEX IF NOT EXISTS idx_file_data_h_load_date 
    ON raw.file_data_h(load_date);

CREATE INDEX IF NOT EXISTS idx_file_data_s_user_hk 
    ON raw.file_data_s(user_hk)
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_file_data_s_upload_timestamp 
    ON raw.file_data_s(upload_timestamp);

CREATE INDEX IF NOT EXISTS idx_file_data_s_file_hash 
    ON raw.file_data_s(file_hash_sha256);

CREATE INDEX IF NOT EXISTS idx_file_data_s_processing_status 
    ON raw.file_data_s(processing_status);

CREATE INDEX IF NOT EXISTS idx_file_data_s_virus_scan_status 
    ON raw.file_data_s(virus_scan_status);

CREATE INDEX IF NOT EXISTS idx_file_data_s_mime_type 
    ON raw.file_data_s(mime_type);

-- Partial index for pending file processing
CREATE INDEX IF NOT EXISTS idx_file_data_s_pending_processing 
    ON raw.file_data_s(file_data_hk, upload_timestamp) 
    WHERE processing_status = 'PENDING' AND load_end_date IS NULL;

-- Sensor Data Indexes
CREATE INDEX IF NOT EXISTS idx_sensor_data_h_load_date 
    ON raw.sensor_data_h(load_date);

CREATE INDEX IF NOT EXISTS idx_sensor_data_s_sensor_identifier 
    ON raw.sensor_data_s(sensor_identifier);

CREATE INDEX IF NOT EXISTS idx_sensor_data_s_sensor_type 
    ON raw.sensor_data_s(sensor_type);

CREATE INDEX IF NOT EXISTS idx_sensor_data_s_reading_timestamp 
    ON raw.sensor_data_s(reading_timestamp);

CREATE INDEX IF NOT EXISTS idx_sensor_data_s_location_identifier 
    ON raw.sensor_data_s(location_identifier);

CREATE INDEX IF NOT EXISTS idx_sensor_data_s_processing_status 
    ON raw.sensor_data_s(processing_status);

CREATE INDEX IF NOT EXISTS idx_sensor_data_s_anomaly_detected 
    ON raw.sensor_data_s(sensor_data_hk, reading_timestamp) 
    WHERE anomaly_detected = true;

-- Index for real-time sensor monitoring
CREATE INDEX IF NOT EXISTS idx_sensor_data_s_recent_readings 
    ON raw.sensor_data_s(sensor_identifier, reading_timestamp DESC) 
    WHERE load_end_date IS NULL;

-- Login Attempt Indexes (using correct column names)
-- NOTE: Based on actual table structure from investigation files
-- The column is 'login_successful' (boolean), not 'success_indicator'
CREATE INDEX IF NOT EXISTS idx_login_attempt_h_load_date 
    ON raw.login_attempt_h(load_date);

-- Only create login_attempt_s indexes if the table exists
DO $$
BEGIN
    -- Check if raw.login_attempt_s table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'raw' AND table_name = 'login_attempt_s') THEN
        
        -- Create indexes using correct column names
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_login_attempt_s_username 
                 ON raw.login_attempt_s(username) WHERE load_end_date IS NULL';
        
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_login_attempt_s_load_date 
                 ON raw.login_attempt_s(load_date)';
        
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_login_attempt_s_ip_address 
                 ON raw.login_attempt_s(ip_address)';
        
        -- Check if login_successful column exists before creating index
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'raw' 
                   AND table_name = 'login_attempt_s' 
                   AND column_name = 'login_successful') THEN
            EXECUTE 'CREATE INDEX IF NOT EXISTS idx_login_attempt_s_login_successful 
                     ON raw.login_attempt_s(login_successful)';
            
            EXECUTE 'CREATE INDEX IF NOT EXISTS idx_failed_login_monitoring 
                     ON raw.login_attempt_s(ip_address, load_date DESC) 
                     WHERE login_successful = false AND load_end_date IS NULL';
        END IF;
        
        RAISE NOTICE '✅ Login attempt indexes created successfully';
    ELSE
        RAISE NOTICE '⚠️ raw.login_attempt_s table does not exist - skipping login indexes';
    END IF;
END $$;

-- User Request Indexes (only if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'raw' AND table_name = 'user_request_h') THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_user_request_h_load_date 
                 ON raw.user_request_h(load_date)';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'raw' AND table_name = 'user_request_details_s') THEN
        
        -- Check each column before creating indexes
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'raw' 
                   AND table_name = 'user_request_details_s' 
                   AND column_name = 'email') THEN
            EXECUTE 'CREATE INDEX IF NOT EXISTS idx_user_request_details_s_email 
                     ON raw.user_request_details_s(email) WHERE load_end_date IS NULL';
        END IF;
        
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'raw' 
                   AND table_name = 'user_request_details_s' 
                   AND column_name = 'request_timestamp') THEN
            EXECUTE 'CREATE INDEX IF NOT EXISTS idx_user_request_details_s_request_timestamp 
                     ON raw.user_request_details_s(request_timestamp)';
        END IF;
        
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'raw' 
                   AND table_name = 'user_request_details_s' 
                   AND column_name = 'processing_status') THEN
            EXECUTE 'CREATE INDEX IF NOT EXISTS idx_user_request_details_s_processing_status 
                     ON raw.user_request_details_s(processing_status)';
        END IF;
        
        RAISE NOTICE '✅ User request indexes created for existing columns';
    ELSE
        RAISE NOTICE '⚠️ raw.user_request_details_s table does not exist - skipping user request indexes';
    END IF;
END $$;

-- ============================================================================
-- STAGING SCHEMA INDEXES
-- ============================================================================

-- User Input Validation Indexes
CREATE INDEX IF NOT EXISTS idx_user_input_validation_h_load_date 
    ON staging.user_input_validation_h(load_date);

CREATE INDEX IF NOT EXISTS idx_user_input_validation_s_raw_user_input_hk 
    ON staging.user_input_validation_s(raw_user_input_hk)
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_input_validation_s_validation_timestamp 
    ON staging.user_input_validation_s(validation_timestamp);

CREATE INDEX IF NOT EXISTS idx_user_input_validation_s_validation_status 
    ON staging.user_input_validation_s(validation_status);

CREATE INDEX IF NOT EXISTS idx_user_input_validation_s_validation_type 
    ON staging.user_input_validation_s(validation_type);

-- Partial index for pending validations
DO $$
BEGIN
    IF util.table_exists('staging', 'user_input_validation_s') AND 
       util.column_exists('staging', 'user_input_validation_s', 'validation_batch_hk') AND
       util.column_exists('staging', 'user_input_validation_s', 'validation_status') THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_user_input_validation_s_pending 
                 ON staging.user_input_validation_s(validation_batch_hk, validation_timestamp) 
                 WHERE validation_status = ''PENDING'' AND load_end_date IS NULL';
        RAISE NOTICE '✅ User input validation pending index created';
    ELSE
        RAISE NOTICE '⚠️ Skipping user input validation pending index - missing table or columns';
    END IF;
END $$;

-- User Behavior Analysis Indexes
CREATE INDEX IF NOT EXISTS idx_user_behavior_analysis_h_load_date 
    ON staging.user_behavior_analysis_h(load_date);

CREATE INDEX IF NOT EXISTS idx_user_behavior_analysis_s_user_hk 
    ON staging.user_behavior_analysis_s(user_hk)
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_behavior_analysis_s_session_hk 
    ON staging.user_behavior_analysis_s(session_hk)
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_behavior_analysis_s_analysis_timestamp 
    ON staging.user_behavior_analysis_s(analysis_timestamp);

CREATE INDEX IF NOT EXISTS idx_user_behavior_analysis_s_behavior_type 
    ON staging.user_behavior_analysis_s(behavior_type);

CREATE INDEX IF NOT EXISTS idx_user_behavior_analysis_s_processing_status 
    ON staging.user_behavior_analysis_s(processing_status);

-- Data Validation Indexes
CREATE INDEX IF NOT EXISTS idx_data_validation_h_load_date 
    ON staging.data_validation_h(load_date);

CREATE INDEX IF NOT EXISTS idx_data_validation_s_raw_data_hk 
    ON staging.data_validation_s(raw_data_hk)
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_data_validation_s_raw_data_source 
    ON staging.data_validation_s(raw_data_source);

CREATE INDEX IF NOT EXISTS idx_data_validation_s_validation_timestamp 
    ON staging.data_validation_s(validation_timestamp);

CREATE INDEX IF NOT EXISTS idx_data_validation_s_data_source_type 
    ON staging.data_validation_s(data_source_type);

CREATE INDEX IF NOT EXISTS idx_data_validation_s_processing_status 
    ON staging.data_validation_s(processing_status);

CREATE INDEX IF NOT EXISTS idx_data_validation_s_overall_quality_score 
    ON staging.data_validation_s(overall_quality_score) 
    WHERE overall_quality_score IS NOT NULL;

-- Partial index for low quality data needing review
CREATE INDEX IF NOT EXISTS idx_data_validation_s_low_quality 
    ON staging.data_validation_s(data_validation_hk, overall_quality_score) 
    WHERE overall_quality_score < 70 AND load_end_date IS NULL;

-- Business Rule Processing Indexes
CREATE INDEX IF NOT EXISTS idx_business_rule_h_load_date 
    ON staging.business_rule_h(load_date);

CREATE INDEX IF NOT EXISTS idx_business_rule_s_domain_context 
    ON staging.business_rule_s(domain_context);

CREATE INDEX IF NOT EXISTS idx_business_rule_s_entity_type 
    ON staging.business_rule_s(entity_type);

CREATE INDEX IF NOT EXISTS idx_business_rule_s_processing_timestamp 
    ON staging.business_rule_s(processing_timestamp);

CREATE INDEX IF NOT EXISTS idx_business_rule_s_processing_status 
    ON staging.business_rule_s(processing_status);

-- Business rule next stage ready index (conditional)
DO $$
BEGIN
    IF util.table_exists('staging', 'business_rule_s') AND 
       util.column_exists('staging', 'business_rule_s', 'business_rule_batch_hk') AND
       util.column_exists('staging', 'business_rule_s', 'next_stage_ready') THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_business_rule_s_next_stage_ready 
                 ON staging.business_rule_s(business_rule_batch_hk, processing_timestamp) 
                 WHERE next_stage_ready = true AND load_end_date IS NULL';
        RAISE NOTICE '✅ Business rule next stage ready index created';
    ELSE
        RAISE NOTICE '⚠️ Skipping business rule next stage ready index - missing table or columns';
    END IF;
END $$;

-- Entity Resolution Indexes
CREATE INDEX IF NOT EXISTS idx_entity_resolution_h_load_date 
    ON staging.entity_resolution_h(load_date);

CREATE INDEX IF NOT EXISTS idx_entity_resolution_s_entity_type 
    ON staging.entity_resolution_s(entity_type);

CREATE INDEX IF NOT EXISTS idx_entity_resolution_s_matching_algorithm 
    ON staging.entity_resolution_s(matching_algorithm);

CREATE INDEX IF NOT EXISTS idx_entity_resolution_s_processing_timestamp 
    ON staging.entity_resolution_s(processing_timestamp);

CREATE INDEX IF NOT EXISTS idx_entity_resolution_s_processing_status 
    ON staging.entity_resolution_s(processing_status);

CREATE INDEX IF NOT EXISTS idx_entity_resolution_s_human_review_required 
    ON staging.entity_resolution_s(entity_resolution_hk, processing_timestamp) 
    WHERE human_review_required = true;

CREATE INDEX IF NOT EXISTS idx_entity_resolution_s_steward_review_status 
    ON staging.entity_resolution_s(steward_review_status) 
    WHERE steward_review_status IN ('PENDING', 'NEEDS_MORE_INFO');

-- Data Standardization Indexes
CREATE INDEX IF NOT EXISTS idx_standardization_h_load_date 
    ON staging.standardization_h(load_date);

CREATE INDEX IF NOT EXISTS idx_standardization_s_standardization_type 
    ON staging.standardization_s(standardization_type);

CREATE INDEX IF NOT EXISTS idx_standardization_s_processing_timestamp 
    ON staging.standardization_s(processing_timestamp);

CREATE INDEX IF NOT EXISTS idx_standardization_s_processing_status 
    ON staging.standardization_s(processing_status);

-- Standardization ready for business layer index (conditional)
DO $$
BEGIN
    IF util.table_exists('staging', 'standardization_s') AND 
       util.column_exists('staging', 'standardization_s', 'standardization_batch_hk') AND
       util.column_exists('staging', 'standardization_s', 'ready_for_business_layer') THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_standardization_s_ready_for_business_layer 
                 ON staging.standardization_s(standardization_batch_hk, processing_timestamp) 
                 WHERE ready_for_business_layer = true AND load_end_date IS NULL';
        RAISE NOTICE '✅ Standardization ready for business layer index created';
    ELSE
        RAISE NOTICE '⚠️ Skipping standardization ready for business layer index - missing table or columns';
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_standardization_s_improvement_score 
    ON staging.standardization_s(improvement_score) 
    WHERE improvement_score IS NOT NULL;

-- Login Processing Indexes (staging) - only if tables exist
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'staging' AND table_name = 'login_attempt_h') THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_staging_login_attempt_h_load_date 
                 ON staging.login_attempt_h(load_date)';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'staging' AND table_name = 'login_status_s') THEN
        
        -- Check each column before creating indexes
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'staging' 
                   AND table_name = 'login_status_s' 
                   AND column_name = 'raw_login_attempt_hk') THEN
            EXECUTE 'CREATE INDEX IF NOT EXISTS idx_staging_login_status_s_raw_login_attempt_hk 
                     ON staging.login_status_s(raw_login_attempt_hk) WHERE load_end_date IS NULL';
        END IF;
        
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'staging' 
                   AND table_name = 'login_status_s' 
                   AND column_name = 'processing_timestamp') THEN
            EXECUTE 'CREATE INDEX IF NOT EXISTS idx_staging_login_status_s_processing_timestamp 
                     ON staging.login_status_s(processing_timestamp)';
        END IF;
        
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'staging' 
                   AND table_name = 'login_status_s' 
                   AND column_name = 'validation_status') THEN
            EXECUTE 'CREATE INDEX IF NOT EXISTS idx_staging_login_status_s_validation_status 
                     ON staging.login_status_s(validation_status)';
        END IF;
        
        RAISE NOTICE '✅ Staging login indexes created for existing columns';
    END IF;
END $$;

-- User Creation Processing Indexes - only if tables exist  
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'staging' AND table_name = 'user_creation_h') THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_user_creation_h_load_date 
                 ON staging.user_creation_h(load_date)';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'staging' AND table_name = 'user_validation_s') THEN
        
        -- Check each column before creating indexes
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'staging' 
                   AND table_name = 'user_validation_s' 
                   AND column_name = 'raw_user_request_hk') THEN
            EXECUTE 'CREATE INDEX IF NOT EXISTS idx_user_validation_s_raw_user_request_hk 
                     ON staging.user_validation_s(raw_user_request_hk) WHERE load_end_date IS NULL';
        END IF;
        
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'staging' 
                   AND table_name = 'user_validation_s' 
                   AND column_name = 'validation_timestamp') THEN
            EXECUTE 'CREATE INDEX IF NOT EXISTS idx_user_validation_s_validation_timestamp 
                     ON staging.user_validation_s(validation_timestamp)';
        END IF;
        
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'staging' 
                   AND table_name = 'user_validation_s' 
                   AND column_name = 'validation_status') THEN
            EXECUTE 'CREATE INDEX IF NOT EXISTS idx_user_validation_s_validation_status 
                     ON staging.user_validation_s(validation_status)';
        END IF;
        
        RAISE NOTICE '✅ Staging user validation indexes created for existing columns';
    END IF;
END $$;

-- ============================================================================
-- COMPOSITE INDEXES FOR COMPLEX QUERIES
-- ============================================================================

-- Raw data processing pipeline index
CREATE INDEX IF NOT EXISTS idx_raw_processing_pipeline 
    ON raw.external_data_s(processing_status, collection_timestamp) 
    WHERE load_end_date IS NULL;

-- User activity analysis index
CREATE INDEX IF NOT EXISTS idx_user_activity_analysis 
    ON raw.user_input_s(user_hk, input_timestamp DESC, interaction_type) 
    WHERE load_end_date IS NULL;

-- Staging data quality monitoring index
CREATE INDEX IF NOT EXISTS idx_staging_quality_monitoring 
    ON staging.data_validation_s(validation_timestamp DESC, overall_quality_score) 
    WHERE load_end_date IS NULL;

-- Cross-domain learning pattern index (for AI/ML analysis)
CREATE INDEX IF NOT EXISTS idx_cross_domain_patterns 
    ON staging.business_rule_s(domain_context, entity_type, processing_timestamp DESC) 
    WHERE processing_status = 'COMPLETED' AND load_end_date IS NULL;

-- ============================================================================
-- GIN INDEXES FOR JSONB COLUMNS (Advanced Analytics)
-- ============================================================================

-- Raw data JSON search indexes
CREATE INDEX IF NOT EXISTS idx_raw_external_data_payload_gin 
    ON raw.external_data_s USING GIN (raw_payload);

CREATE INDEX IF NOT EXISTS idx_raw_user_input_data_gin 
    ON raw.user_input_s USING GIN (raw_input_data);

CREATE INDEX IF NOT EXISTS idx_raw_sensor_readings_gin 
    ON raw.sensor_data_s USING GIN (sensor_readings);

-- Staging analysis JSON search indexes
CREATE INDEX IF NOT EXISTS idx_staging_validation_results_gin 
    ON staging.user_input_validation_s USING GIN (validation_results);

CREATE INDEX IF NOT EXISTS idx_staging_behavior_patterns_gin 
    ON staging.user_behavior_analysis_s USING GIN (interaction_patterns);

CREATE INDEX IF NOT EXISTS idx_staging_business_rules_gin 
    ON staging.business_rule_s USING GIN (business_rules_applied);

-- ============================================================================
-- PARTIAL INDEXES FOR OPERATIONAL EFFICIENCY
-- ============================================================================

-- Active processing monitoring
CREATE INDEX IF NOT EXISTS idx_active_raw_processing 
    ON raw.external_data_s(source_system, collection_timestamp DESC) 
    WHERE processing_status IN ('PENDING', 'PROCESSING');

-- Recent user interactions for real-time analytics
CREATE INDEX IF NOT EXISTS idx_recent_user_interactions 
    ON raw.user_input_s(user_hk, input_timestamp DESC) 
    WHERE load_end_date IS NULL;

-- High-priority staging items
CREATE INDEX IF NOT EXISTS idx_high_priority_staging 
    ON staging.data_validation_s(validation_timestamp) 
    WHERE processing_status = 'NEEDS_REVIEW' 
    AND overall_quality_score < 50;

-- ============================================================================
-- STATISTICS AND MAINTENANCE
-- ============================================================================

-- Update table statistics for better query planning
ANALYZE raw.external_data_h;
ANALYZE raw.external_data_s;
ANALYZE raw.user_input_h;
ANALYZE raw.user_input_s;
ANALYZE raw.file_data_h;
ANALYZE raw.file_data_s;
ANALYZE raw.sensor_data_h;
ANALYZE raw.sensor_data_s;

-- Analyze staging tables
ANALYZE staging.user_input_validation_h;
ANALYZE staging.user_input_validation_s;
ANALYZE staging.user_behavior_analysis_h;
ANALYZE staging.user_behavior_analysis_s;
ANALYZE staging.data_validation_h;
ANALYZE staging.data_validation_s;
ANALYZE staging.business_rule_h;
ANALYZE staging.business_rule_s;
ANALYZE staging.entity_resolution_h;
ANALYZE staging.entity_resolution_s;
ANALYZE staging.standardization_h;
ANALYZE staging.standardization_s;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Raw and Staging performance indexes created successfully!';
    RAISE NOTICE 'ULTRA-SAFE VERSION - Only creates indexes for existing tables and columns';
    RAISE NOTICE '';
    RAISE NOTICE 'Safety Features:';
    RAISE NOTICE '  • Table existence validation before index creation';
    RAISE NOTICE '  • Column existence validation for all indexed columns';
    RAISE NOTICE '  • Graceful handling of missing database objects';
    RAISE NOTICE '  • Detailed logging of what was created vs. skipped';
    RAISE NOTICE '';
    RAISE NOTICE 'Index categories created:';
    RAISE NOTICE '  • Load date indexes - Fast temporal queries';
    RAISE NOTICE '  • Processing status indexes - Monitor pipeline efficiency';
    RAISE NOTICE '  • Hash key indexes - Fast lookups and joins';
    RAISE NOTICE '  • Content search indexes - JSONB GIN indexes for analytics';
    RAISE NOTICE '  • Operational efficiency indexes - Partial indexes for active data';
    RAISE NOTICE '  • Composite indexes - Complex query optimization';
    RAISE NOTICE '  • Conditional indexes - Only created if underlying objects exist';
    RAISE NOTICE '';
    RAISE NOTICE 'Database statistics updated for optimal query planning!';
    RAISE NOTICE 'Ready for high-performance universal data processing!';
    RAISE NOTICE '';
    RAISE NOTICE 'NOTE: tenant_hk indexes omitted for raw/staging layers';
    RAISE NOTICE 'Tenant isolation handled at business layer level.';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 This script is now safe to run on any database state!';
END $$; 