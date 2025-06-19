-- ============================================================================
-- STAGING SCHEMA CREATION - Universal Learning Loop
-- Data Vault 2.0 Compatible Staging/Processing Layer
-- Supports: One Vault Demo Barn & One Vault Production
-- ============================================================================

-- Create staging schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS staging;

-- Add schema comment
COMMENT ON SCHEMA staging IS 
'Staging and processing layer for universal learning loop. Validates, transforms, and prepares raw data for business layer loading. Supports cross-industry data processing patterns.';

-- ============================================================================
-- USER INPUT VALIDATION TABLES (Real-time User Data Processing)
-- ============================================================================

-- User Input Validation Hub
CREATE TABLE IF NOT EXISTS staging.user_input_validation_h (
    validation_batch_hk BYTEA PRIMARY KEY,
    validation_batch_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    CONSTRAINT uk_user_validation_h_bk_tenant UNIQUE (validation_batch_bk, tenant_hk)
);

-- User Input Validation Satellite
CREATE TABLE IF NOT EXISTS staging.user_input_validation_s (
    validation_batch_hk BYTEA NOT NULL REFERENCES staging.user_input_validation_h(validation_batch_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    raw_user_input_hk BYTEA NOT NULL REFERENCES raw.user_input_h(user_input_hk),
    validation_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    validation_type VARCHAR(100) NOT NULL,
    input_category VARCHAR(100),
    validation_rules_applied TEXT[],
    validation_results JSONB NOT NULL,
    sanitization_performed JSONB,
    security_scan_results JSONB,
    data_quality_score DECIMAL(5,2),
    validation_status VARCHAR(20) DEFAULT 'PENDING',
    error_count INTEGER DEFAULT 0,
    warning_count INTEGER DEFAULT 0,
    processing_duration_ms INTEGER,
    next_processing_step VARCHAR(100),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (validation_batch_hk, load_date),
    CONSTRAINT chk_validation_status 
        CHECK (validation_status IN ('PENDING', 'VALID', 'INVALID', 'NEEDS_REVIEW', 'QUARANTINED'))
);

-- ============================================================================
-- USER BEHAVIOR ANALYSIS TABLES (Interaction Patterns & Analytics)
-- ============================================================================

-- User Behavior Analysis Hub
CREATE TABLE IF NOT EXISTS staging.user_behavior_analysis_h (
    behavior_analysis_hk BYTEA PRIMARY KEY,
    behavior_analysis_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    CONSTRAINT uk_behavior_analysis_h_bk_tenant UNIQUE (behavior_analysis_bk, tenant_hk)
);

-- User Behavior Analysis Satellite
CREATE TABLE IF NOT EXISTS staging.user_behavior_analysis_s (
    behavior_analysis_hk BYTEA NOT NULL REFERENCES staging.user_behavior_analysis_h(behavior_analysis_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    user_hk BYTEA REFERENCES auth.user_h(user_hk),
    session_hk BYTEA REFERENCES auth.session_h(session_hk),
    analysis_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    behavior_type VARCHAR(100) NOT NULL,
    interaction_patterns JSONB NOT NULL,
    usage_metrics JSONB,
    navigation_flow JSONB,
    form_completion_stats JSONB,
    error_patterns JSONB,
    performance_metrics JSONB,
    device_characteristics JSONB,
    behavior_score DECIMAL(5,2),
    anomaly_flags TEXT[],
    insights_generated JSONB,
    recommendations JSONB,
    processing_status VARCHAR(20) DEFAULT 'PENDING',
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (behavior_analysis_hk, load_date),
    CONSTRAINT chk_behavior_processing_status 
        CHECK (processing_status IN ('PENDING', 'ANALYZED', 'INSIGHTS_GENERATED', 'COMPLETED', 'FAILED'))
);

-- ============================================================================
-- DATA VALIDATION TABLES (External Data Quality Processing)
-- ============================================================================

-- Data Validation Hub
CREATE TABLE IF NOT EXISTS staging.data_validation_h (
    data_validation_hk BYTEA PRIMARY KEY,
    data_validation_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    CONSTRAINT uk_data_validation_h_bk_tenant UNIQUE (data_validation_bk, tenant_hk)
);

-- Data Validation Satellite
CREATE TABLE IF NOT EXISTS staging.data_validation_s (
    data_validation_hk BYTEA NOT NULL REFERENCES staging.data_validation_h(data_validation_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    raw_data_source VARCHAR(100) NOT NULL,
    raw_data_hk BYTEA NOT NULL,
    validation_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    data_source_type VARCHAR(100) NOT NULL,
    validation_rules_config JSONB NOT NULL,
    data_completeness_score DECIMAL(5,2),
    data_accuracy_score DECIMAL(5,2),
    data_consistency_score DECIMAL(5,2),
    data_validity_score DECIMAL(5,2),
    overall_quality_score DECIMAL(5,2),
    validation_results JSONB NOT NULL,
    field_level_validations JSONB,
    business_rule_validations JSONB,
    data_profiling_results JSONB,
    anomalies_detected JSONB,
    correction_suggestions JSONB,
    records_processed INTEGER,
    records_passed INTEGER,
    records_failed INTEGER,
    processing_status VARCHAR(20) DEFAULT 'PENDING',
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (data_validation_hk, load_date),
    CONSTRAINT chk_data_validation_status 
        CHECK (processing_status IN ('PENDING', 'VALIDATING', 'COMPLETED', 'FAILED', 'NEEDS_REVIEW'))
);

-- ============================================================================
-- BUSINESS RULE PROCESSING TABLES (Domain Logic Application)
-- ============================================================================

-- Business Rule Processing Hub
CREATE TABLE IF NOT EXISTS staging.business_rule_h (
    business_rule_batch_hk BYTEA PRIMARY KEY,
    business_rule_batch_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    CONSTRAINT uk_business_rule_h_bk_tenant UNIQUE (business_rule_batch_bk, tenant_hk)
);

-- Business Rule Processing Satellite
CREATE TABLE IF NOT EXISTS staging.business_rule_s (
    business_rule_batch_hk BYTEA NOT NULL REFERENCES staging.business_rule_h(business_rule_batch_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    domain_context VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    business_rules_applied JSONB NOT NULL,
    transformation_logic JSONB,
    derived_attributes JSONB,
    calculated_fields JSONB,
    enrichment_data JSONB,
    classification_results JSONB,
    validation_results JSONB,
    rule_execution_results JSONB NOT NULL,
    processing_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    rules_passed INTEGER DEFAULT 0,
    rules_failed INTEGER DEFAULT 0,
    rules_warnings INTEGER DEFAULT 0,
    performance_metrics JSONB,
    processing_status VARCHAR(20) DEFAULT 'PENDING',
    next_stage_ready BOOLEAN DEFAULT false,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (business_rule_batch_hk, load_date),
    CONSTRAINT chk_business_rule_status 
        CHECK (processing_status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'PARTIAL_SUCCESS'))
);

-- ============================================================================
-- ENTITY RESOLUTION TABLES (Duplicate Detection & Matching)
-- ============================================================================

-- Entity Resolution Hub
CREATE TABLE IF NOT EXISTS staging.entity_resolution_h (
    entity_resolution_hk BYTEA PRIMARY KEY,
    entity_resolution_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    CONSTRAINT uk_entity_resolution_h_bk_tenant UNIQUE (entity_resolution_bk, tenant_hk)
);

-- Entity Resolution Satellite
CREATE TABLE IF NOT EXISTS staging.entity_resolution_s (
    entity_resolution_hk BYTEA NOT NULL REFERENCES staging.entity_resolution_h(entity_resolution_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    matching_algorithm VARCHAR(100) NOT NULL,
    matching_criteria JSONB NOT NULL,
    candidate_entities JSONB,
    match_results JSONB NOT NULL,
    confidence_scores JSONB,
    master_entity_recommendation JSONB,
    duplicate_entities_found JSONB,
    resolution_actions JSONB,
    human_review_required BOOLEAN DEFAULT false,
    auto_merge_eligible BOOLEAN DEFAULT false,
    processing_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    entities_processed INTEGER,
    duplicates_found INTEGER,
    matches_resolved INTEGER,
    processing_status VARCHAR(20) DEFAULT 'PENDING',
    steward_review_status VARCHAR(20) DEFAULT 'NOT_REQUIRED',
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (entity_resolution_hk, load_date),
    CONSTRAINT chk_entity_resolution_status 
        CHECK (processing_status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'NEEDS_REVIEW')),
    CONSTRAINT chk_steward_review_status 
        CHECK (steward_review_status IN ('NOT_REQUIRED', 'PENDING', 'APPROVED', 'REJECTED', 'NEEDS_MORE_INFO'))
);

-- ============================================================================
-- DATA STANDARDIZATION TABLES (Cleaning & Formatting)
-- ============================================================================

-- Data Standardization Hub
CREATE TABLE IF NOT EXISTS staging.standardization_h (
    standardization_batch_hk BYTEA PRIMARY KEY,
    standardization_batch_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    CONSTRAINT uk_standardization_h_bk_tenant UNIQUE (standardization_batch_bk, tenant_hk)
);

-- Data Standardization Satellite
CREATE TABLE IF NOT EXISTS staging.standardization_s (
    standardization_batch_hk BYTEA NOT NULL REFERENCES staging.standardization_h(standardization_batch_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    standardization_type VARCHAR(100) NOT NULL,
    standardization_rules JSONB NOT NULL,
    original_data JSONB NOT NULL,
    standardized_data JSONB NOT NULL,
    transformations_applied JSONB,
    data_format_conversions JSONB,
    data_cleansing_actions JSONB,
    validation_post_standardization JSONB,
    quality_improvement_metrics JSONB,
    processing_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    records_standardized INTEGER,
    standardization_success_rate DECIMAL(5,2),
    data_quality_before DECIMAL(5,2),
    data_quality_after DECIMAL(5,2),
    improvement_score DECIMAL(5,2),
    processing_status VARCHAR(20) DEFAULT 'PENDING',
    ready_for_business_layer BOOLEAN DEFAULT false,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (standardization_batch_hk, load_date),
    CONSTRAINT chk_standardization_status 
        CHECK (processing_status IN ('PENDING', 'STANDARDIZING', 'COMPLETED', 'FAILED', 'PARTIAL_SUCCESS'))
);

-- ============================================================================
-- TABLE COMMENTS FOR DOCUMENTATION
-- ============================================================================

-- User Input Validation Comments
COMMENT ON TABLE staging.user_input_validation_h IS 
'Hub table for user input validation processing batches. Tracks validation sessions for real-time user data processing.';

COMMENT ON TABLE staging.user_input_validation_s IS 
'Satellite table storing user input validation results including security scanning, sanitization, and quality assessment.';

-- User Behavior Analysis Comments
COMMENT ON TABLE staging.user_behavior_analysis_h IS 
'Hub table for user behavior analysis processing. Tracks user interaction pattern analysis sessions.';

COMMENT ON TABLE staging.user_behavior_analysis_s IS 
'Satellite table storing user behavior analysis results including interaction patterns, usage metrics, and behavioral insights across industries.';

-- Data Validation Comments
COMMENT ON TABLE staging.data_validation_h IS 
'Hub table for external data validation processing. Tracks data quality assessment batches for all external data sources.';

COMMENT ON TABLE staging.data_validation_s IS 
'Satellite table storing comprehensive data validation results including quality scores, profiling results, and anomaly detection.';

-- Business Rule Processing Comments
COMMENT ON TABLE staging.business_rule_h IS 
'Hub table for business rule processing batches. Tracks domain-specific business logic application sessions.';

COMMENT ON TABLE staging.business_rule_s IS 
'Satellite table storing business rule execution results including transformations, enrichments, and derived attributes.';

-- Entity Resolution Comments
COMMENT ON TABLE staging.entity_resolution_h IS 
'Hub table for entity resolution processing. Tracks duplicate detection and entity matching sessions.';

COMMENT ON TABLE staging.entity_resolution_s IS 
'Satellite table storing entity resolution results including match confidence scores, duplicate detection, and master entity recommendations.';

-- Data Standardization Comments
COMMENT ON TABLE staging.standardization_h IS 
'Hub table for data standardization processing batches. Tracks data cleaning and formatting sessions.';

COMMENT ON TABLE staging.standardization_s IS 
'Satellite table storing data standardization results including transformations, quality improvements, and formatted output data.';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA staging TO postgres;

-- Grant permissions on tables to application roles
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA staging TO postgres;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA staging TO postgres;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Staging schema and tables created successfully!';
    RAISE NOTICE 'Tables created:';
    RAISE NOTICE '  • staging.user_input_validation_h/s - Real-time user input processing';
    RAISE NOTICE '  • staging.user_behavior_analysis_h/s - User interaction pattern analysis';
    RAISE NOTICE '  • staging.data_validation_h/s - External data quality assessment';
    RAISE NOTICE '  • staging.business_rule_h/s - Domain-specific business logic processing';
    RAISE NOTICE '  • staging.entity_resolution_h/s - Duplicate detection and entity matching';
    RAISE NOTICE '  • staging.standardization_h/s - Data cleaning and formatting';
    RAISE NOTICE 'Ready for universal data processing across all industries!';
END $$; 