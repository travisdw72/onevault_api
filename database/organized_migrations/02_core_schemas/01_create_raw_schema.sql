-- ============================================================================
-- RAW SCHEMA CREATION - Universal Learning Loop
-- Data Vault 2.0 Compatible Raw Data Layer
-- Supports: One Vault Demo Barn & One Vault Production
-- ============================================================================

-- Create raw schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS raw;

-- Add schema comment
COMMENT ON SCHEMA raw IS 
'Raw data ingestion layer for universal learning loop. Stores data exactly as received from any source without transformation. Supports multi-tenant isolation and cross-industry data capture.';

-- ============================================================================
-- EXTERNAL DATA TABLES (APIs, System Integrations, Data Feeds)
-- ============================================================================

-- External Data Hub
CREATE TABLE IF NOT EXISTS raw.external_data_h (
    external_data_hk BYTEA PRIMARY KEY,
    external_data_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    CONSTRAINT uk_external_data_h_bk_tenant UNIQUE (external_data_bk, tenant_hk)
);

-- External Data Satellite
CREATE TABLE IF NOT EXISTS raw.external_data_s (
    external_data_hk BYTEA NOT NULL REFERENCES raw.external_data_h(external_data_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    source_system VARCHAR(100) NOT NULL,
    source_endpoint VARCHAR(500),
    source_method VARCHAR(20) DEFAULT 'GET',
    batch_id VARCHAR(255),
    data_format VARCHAR(50) DEFAULT 'JSON',
    raw_payload JSONB NOT NULL,
    payload_size_bytes INTEGER,
    collection_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    processing_status VARCHAR(20) DEFAULT 'PENDING',
    error_details TEXT,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (external_data_hk, load_date),
    CONSTRAINT chk_external_data_processing_status 
        CHECK (processing_status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'QUARANTINED'))
);

-- ============================================================================
-- USER INPUT TABLES (Forms, Interactions, Direct User Data)
-- ============================================================================

-- User Input Hub
CREATE TABLE IF NOT EXISTS raw.user_input_h (
    user_input_hk BYTEA PRIMARY KEY,
    user_input_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    CONSTRAINT uk_user_input_h_bk_tenant UNIQUE (user_input_bk, tenant_hk)
);

-- User Input Satellite
CREATE TABLE IF NOT EXISTS raw.user_input_s (
    user_input_hk BYTEA NOT NULL REFERENCES raw.user_input_h(user_input_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    user_hk BYTEA REFERENCES auth.user_h(user_hk),
    session_hk BYTEA REFERENCES auth.session_h(session_hk),
    input_type VARCHAR(100) NOT NULL,
    form_identifier VARCHAR(255),
    field_name VARCHAR(255),
    interaction_type VARCHAR(50),
    raw_input_data JSONB NOT NULL,
    input_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    client_info JSONB,
    validation_status VARCHAR(20) DEFAULT 'UNVALIDATED',
    sanitization_required BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (user_input_hk, load_date),
    CONSTRAINT chk_user_input_validation_status 
        CHECK (validation_status IN ('UNVALIDATED', 'VALID', 'INVALID', 'NEEDS_REVIEW')),
    CONSTRAINT chk_user_input_interaction_type 
        CHECK (interaction_type IN ('FORM_SUBMIT', 'FIELD_CHANGE', 'CLICK', 'NAVIGATION', 'SEARCH', 'UPLOAD'))
);

-- ============================================================================
-- FILE DATA TABLES (Uploads, Documents, Media)
-- ============================================================================

-- File Data Hub
CREATE TABLE IF NOT EXISTS raw.file_data_h (
    file_data_hk BYTEA PRIMARY KEY,
    file_data_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    CONSTRAINT uk_file_data_h_bk_tenant UNIQUE (file_data_bk, tenant_hk)
);

-- File Data Satellite
CREATE TABLE IF NOT EXISTS raw.file_data_s (
    file_data_hk BYTEA NOT NULL REFERENCES raw.file_data_h(file_data_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    user_hk BYTEA REFERENCES auth.user_h(user_hk),
    original_filename VARCHAR(500) NOT NULL,
    file_extension VARCHAR(50),
    mime_type VARCHAR(200),
    file_size_bytes BIGINT NOT NULL,
    file_hash_sha256 VARCHAR(64),
    storage_location TEXT,
    file_content BYTEA,
    upload_source VARCHAR(100),
    upload_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    processing_status VARCHAR(20) DEFAULT 'PENDING',
    virus_scan_status VARCHAR(20) DEFAULT 'PENDING',
    metadata_extracted JSONB,
    error_details TEXT,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (file_data_hk, load_date),
    CONSTRAINT chk_file_processing_status 
        CHECK (processing_status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'QUARANTINED')),
    CONSTRAINT chk_virus_scan_status 
        CHECK (virus_scan_status IN ('PENDING', 'CLEAN', 'INFECTED', 'FAILED', 'SKIPPED'))
);

-- ============================================================================
-- SENSOR DATA TABLES (IoT, Equipment, Real-time Monitoring)
-- ============================================================================

-- Sensor Data Hub
CREATE TABLE IF NOT EXISTS raw.sensor_data_h (
    sensor_data_hk BYTEA PRIMARY KEY,
    sensor_data_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    CONSTRAINT uk_sensor_data_h_bk_tenant UNIQUE (sensor_data_bk, tenant_hk)
);

-- Sensor Data Satellite
CREATE TABLE IF NOT EXISTS raw.sensor_data_s (
    sensor_data_hk BYTEA NOT NULL REFERENCES raw.sensor_data_h(sensor_data_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    sensor_identifier VARCHAR(255) NOT NULL,
    sensor_type VARCHAR(100) NOT NULL,
    device_manufacturer VARCHAR(100),
    device_model VARCHAR(100),
    location_identifier VARCHAR(255),
    reading_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    sensor_readings JSONB NOT NULL,
    reading_frequency_seconds INTEGER,
    data_quality_score DECIMAL(5,2),
    calibration_status VARCHAR(20) DEFAULT 'UNKNOWN',
    battery_level DECIMAL(5,2),
    signal_strength DECIMAL(5,2),
    processing_status VARCHAR(20) DEFAULT 'PENDING',
    anomaly_detected BOOLEAN DEFAULT false,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (sensor_data_hk, load_date),
    CONSTRAINT chk_sensor_processing_status 
        CHECK (processing_status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'QUARANTINED')),
    CONSTRAINT chk_sensor_calibration_status 
        CHECK (calibration_status IN ('CALIBRATED', 'NEEDS_CALIBRATION', 'FAILED', 'UNKNOWN'))
);

-- ============================================================================
-- TABLE COMMENTS FOR DOCUMENTATION
-- ============================================================================

-- External Data Comments
COMMENT ON TABLE raw.external_data_h IS 
'Hub table for external data sources. Stores unique identifiers for data batches from APIs, system integrations, and external feeds across all industries.';

COMMENT ON TABLE raw.external_data_s IS 
'Satellite table storing raw external data exactly as received. Supports JSON payloads from any external system including horse registries, medical devices, manufacturing systems, etc.';

-- User Input Comments
COMMENT ON TABLE raw.user_input_h IS 
'Hub table for user input sessions. Tracks unique user interaction batches with complete tenant isolation.';

COMMENT ON TABLE raw.user_input_s IS 
'Satellite table storing raw user input data including form submissions, clicks, and direct entries. Supports universal user behavior analysis across industries.';

-- File Data Comments
COMMENT ON TABLE raw.file_data_h IS 
'Hub table for file uploads and document management. Handles any file type across all supported industries.';

COMMENT ON TABLE raw.file_data_s IS 
'Satellite table storing file metadata and content. Supports photos, documents, reports, and any file format with virus scanning and processing status tracking.';

-- Sensor Data Comments
COMMENT ON TABLE raw.sensor_data_h IS 
'Hub table for sensor and IoT data collection. Supports equipment monitoring across all industries including training equipment, medical devices, manufacturing sensors.';

COMMENT ON TABLE raw.sensor_data_s IS 
'Satellite table storing raw sensor readings and telemetry data. Supports real-time monitoring with data quality assessment and anomaly detection capabilities.';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA raw TO postgres;

-- Grant permissions on tables to application roles
-- (These would be expanded based on your specific role structure)
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA raw TO postgres;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA raw TO postgres;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Raw schema and tables created successfully!';
    RAISE NOTICE 'Tables created:';
    RAISE NOTICE '  • raw.external_data_h/s - External API and system integration data';
    RAISE NOTICE '  • raw.user_input_h/s - User form submissions and interactions';  
    RAISE NOTICE '  • raw.file_data_h/s - File uploads and document storage';
    RAISE NOTICE '  • raw.sensor_data_h/s - IoT and equipment sensor data';
    RAISE NOTICE 'Ready for universal data ingestion across all industries!';
END $$; 