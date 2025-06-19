-- =====================================================================
-- AI Monitoring System - Data Vault 2.0 with Zero Trust Architecture
-- One Vault Template Database Extension
-- Generic Monitoring System (Industry Agnostic)
-- =====================================================================

-- Note: This script extends the existing One Vault template database
-- It works with the existing auth, business, and audit schemas
-- All entities are generic and can be used for any industry

-- =====================================================================
-- DEPLOYMENT LOGGING
-- =====================================================================
DO $$
DECLARE
    deployment_id INTEGER;
BEGIN
    SELECT util.log_deployment_start(
        'AI_MONITORING_SYSTEM_V1',
        'Generic AI monitoring system with Zero Trust security for multi-entity business optimization',
        'ROLLBACK: Remove ai_monitoring schema and related objects'
    ) INTO deployment_id;
    
    RAISE NOTICE 'Starting deployment ID: %', deployment_id;
END $$;

-- =====================================================================
-- SCHEMA CREATION
-- =====================================================================
CREATE SCHEMA IF NOT EXISTS ai_monitoring AUTHORIZATION postgres;
COMMENT ON SCHEMA ai_monitoring IS 'AI monitoring system for generic entity observation and analysis';

-- Grant permissions
GRANT USAGE ON SCHEMA ai_monitoring TO app_user, authenticated_users;
GRANT ALL ON SCHEMA ai_monitoring TO dv_admin, admin_access;

-- =====================================================================
-- ENHANCED HUB TABLES (Zero Trust)
-- =====================================================================

-- Generic monitored entity hub (replaces horse_hub)
CREATE TABLE ai_monitoring.monitored_entity_h (
    entity_hk BYTEA PRIMARY KEY,
    entity_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Zero Trust Security Enhancements
    data_classification VARCHAR(20) NOT NULL DEFAULT 'CONFIDENTIAL',
    access_control_hash VARCHAR(64) NOT NULL,
    encryption_key_id UUID NOT NULL DEFAULT gen_random_uuid(),
    created_by_user_hk BYTEA,
    created_from_ip INET,
    security_labels JSONB NOT NULL DEFAULT '{}',
    
    CONSTRAINT chk_entity_data_classification 
        CHECK (data_classification IN ('PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'))
);

-- AI analysis hub with trust scoring
CREATE TABLE ai_monitoring.ai_analysis_h (
    analysis_hk BYTEA PRIMARY KEY,
    analysis_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Zero Trust AI-specific fields
    ai_model_trust_score DECIMAL(3,2) NOT NULL DEFAULT 0.00,
    processing_node_id VARCHAR(100) NOT NULL,
    security_context JSONB NOT NULL DEFAULT '{}',
    
    CONSTRAINT chk_ai_trust_score CHECK (ai_model_trust_score BETWEEN 0.00 AND 1.00)
);

-- Enhanced alert hub
CREATE TABLE ai_monitoring.alert_h (
    alert_hk BYTEA PRIMARY KEY,
    alert_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Zero Trust alert security
    alert_trust_level VARCHAR(20) NOT NULL DEFAULT 'UNVERIFIED',
    originating_system_id VARCHAR(100) NOT NULL,
    security_incident_flag BOOLEAN DEFAULT FALSE,
    
    CONSTRAINT chk_alert_trust_level 
        CHECK (alert_trust_level IN ('VERIFIED', 'TRUSTED', 'UNVERIFIED', 'SUSPICIOUS'))
);

-- =====================================================================
-- LINK TABLES (Zero Trust Enhanced)
-- =====================================================================

-- Entity to analysis relationship
CREATE TABLE ai_monitoring.entity_analysis_l (
    link_entity_analysis_hk BYTEA PRIMARY KEY,
    entity_hk BYTEA NOT NULL REFERENCES ai_monitoring.monitored_entity_h(entity_hk),
    analysis_hk BYTEA NOT NULL REFERENCES ai_monitoring.ai_analysis_h(analysis_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Zero Trust relationship scoring
    relationship_trust_score DECIMAL(3,2) NOT NULL DEFAULT 0.00,
    data_lineage_hash VARCHAR(64) NOT NULL,
    security_context JSONB NOT NULL DEFAULT '{}'
);

-- Analysis to alert correlation
CREATE TABLE ai_monitoring.analysis_alert_l (
    link_analysis_alert_hk BYTEA PRIMARY KEY,
    analysis_hk BYTEA NOT NULL REFERENCES ai_monitoring.ai_analysis_h(analysis_hk),
    alert_hk BYTEA NOT NULL REFERENCES ai_monitoring.alert_h(alert_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Correlation confidence
    correlation_confidence DECIMAL(3,2) NOT NULL DEFAULT 0.00,
    security_correlation_id UUID DEFAULT gen_random_uuid()
);

-- =====================================================================
-- SATELLITE TABLES (Zero Trust with Encryption)
-- =====================================================================

-- Monitored entity details (generic, not horse-specific)
CREATE TABLE ai_monitoring.monitored_entity_details_s (
    entity_hk BYTEA NOT NULL REFERENCES ai_monitoring.monitored_entity_h(entity_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Generic entity attributes (encrypted sensitive fields)
    entity_name_encrypted BYTEA, -- Encrypted with tenant-specific key
    entity_type VARCHAR(100), -- Non-sensitive: equipment, facility, asset, etc.
    entity_category VARCHAR(100), -- Non-sensitive: manufacturing, logistics, etc.
    location_encrypted BYTEA, -- Encrypted location data
    description_encrypted BYTEA, -- Encrypted description
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    
    -- Metadata
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    
    -- Zero Trust data protection
    data_classification VARCHAR(20) NOT NULL DEFAULT 'CONFIDENTIAL',
    field_access_matrix JSONB NOT NULL DEFAULT '{}',
    encryption_metadata JSONB NOT NULL DEFAULT '{}',
    data_integrity_hash VARCHAR(64) NOT NULL,
    last_accessed_by_hk BYTEA,
    last_accessed_date TIMESTAMP WITH TIME ZONE,
    access_count INTEGER DEFAULT 0,
    
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (entity_hk, load_date),
    CONSTRAINT chk_entity_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'MAINTENANCE', 'RETIRED'))
);

-- AI analysis results satellite
CREATE TABLE ai_monitoring.ai_analysis_results_s (
    analysis_hk BYTEA NOT NULL REFERENCES ai_monitoring.ai_analysis_h(analysis_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- AI analysis data
    ai_provider VARCHAR(50) NOT NULL,
    analysis_type VARCHAR(100) NOT NULL,
    confidence_score DECIMAL(5,4) NOT NULL,
    analysis_data_encrypted BYTEA NOT NULL, -- Encrypted AI results
    processing_time_ms INTEGER,
    model_version VARCHAR(50),
    input_data_hash VARCHAR(64),
    
    -- Zero Trust AI validation
    model_trust_certification VARCHAR(100) NOT NULL,
    data_provenance_hash VARCHAR(64) NOT NULL,
    analysis_integrity_score DECIMAL(3,2) NOT NULL,
    security_scan_results JSONB DEFAULT '{}',
    bias_detection_results JSONB DEFAULT '{}',
    
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (analysis_hk, load_date),
    
    CONSTRAINT chk_confidence_score CHECK (confidence_score BETWEEN 0.0000 AND 1.0000),
    CONSTRAINT chk_integrity_score CHECK (analysis_integrity_score BETWEEN 0.00 AND 1.00)
);

-- Alert details satellite
CREATE TABLE ai_monitoring.alert_details_s (
    alert_hk BYTEA NOT NULL REFERENCES ai_monitoring.alert_h(alert_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Alert information
    severity VARCHAR(20) NOT NULL,
    alert_type VARCHAR(100) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message_encrypted BYTEA NOT NULL, -- Encrypted alert message
    metadata_encrypted BYTEA, -- Encrypted additional data
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    
    -- Response tracking
    acknowledged_by_hk BYTEA,
    acknowledged_date TIMESTAMP WITH TIME ZONE,
    resolved_by_hk BYTEA,
    resolved_date TIMESTAMP WITH TIME ZONE,
    resolution_notes_encrypted BYTEA,
    
    -- Zero Trust alert validation
    alert_authenticity_score DECIMAL(3,2) NOT NULL DEFAULT 0.00,
    false_positive_probability DECIMAL(3,2) DEFAULT 0.00,
    security_impact_assessment JSONB DEFAULT '{}',
    response_required_by TIMESTAMP WITH TIME ZONE,
    escalation_chain JSONB DEFAULT '{}',
    
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (alert_hk, load_date),
    
    CONSTRAINT chk_alert_severity CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT chk_alert_status CHECK (status IN ('OPEN', 'ACKNOWLEDGED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
    CONSTRAINT chk_authenticity_score CHECK (alert_authenticity_score BETWEEN 0.00 AND 1.00)
);

-- =====================================================================
-- ZERO TRUST SECURITY TABLES
-- =====================================================================

-- Zero Trust access policies
CREATE TABLE ai_monitoring.zt_access_policies_h (
    policy_hk BYTEA PRIMARY KEY,
    policy_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE ai_monitoring.zt_access_policies_s (
    policy_hk BYTEA NOT NULL REFERENCES ai_monitoring.zt_access_policies_h(policy_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    policy_name VARCHAR(200) NOT NULL,
    resource_pattern VARCHAR(255) NOT NULL,
    action_allowed VARCHAR(50) NOT NULL,
    conditions JSONB NOT NULL DEFAULT '{}',
    risk_threshold INTEGER NOT NULL DEFAULT 50,
    policy_active BOOLEAN DEFAULT TRUE,
    expires_date TIMESTAMP WITH TIME ZONE,
    
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (policy_hk, load_date),
    CONSTRAINT chk_risk_threshold CHECK (risk_threshold BETWEEN 0 AND 100)
);

-- Zero Trust security events
CREATE TABLE ai_monitoring.zt_security_events_h (
    security_event_hk BYTEA PRIMARY KEY,
    security_event_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE ai_monitoring.zt_security_events_s (
    security_event_hk BYTEA NOT NULL REFERENCES ai_monitoring.zt_security_events_h(security_event_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    event_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    event_description TEXT NOT NULL,
    source_ip INET,
    user_hk BYTEA,
    session_hk BYTEA,
    resource_accessed VARCHAR(255),
    action_attempted VARCHAR(50),
    risk_score INTEGER NOT NULL DEFAULT 0,
    anomaly_indicators JSONB DEFAULT '{}',
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    response_action VARCHAR(100),
    investigation_status VARCHAR(20) DEFAULT 'OPEN',
    
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (security_event_hk, load_date),
    
    CONSTRAINT chk_security_severity CHECK (severity IN ('INFO', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT chk_investigation_status CHECK (investigation_status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'FALSE_POSITIVE')),
    CONSTRAINT chk_security_risk_score CHECK (risk_score BETWEEN 0 AND 100)
);

-- =====================================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================================

-- Primary performance indexes
CREATE INDEX idx_monitored_entity_tenant_hk ON ai_monitoring.monitored_entity_h(tenant_hk);
CREATE INDEX idx_monitored_entity_classification ON ai_monitoring.monitored_entity_h(tenant_hk, data_classification);
CREATE INDEX idx_ai_analysis_tenant_hk ON ai_monitoring.ai_analysis_h(tenant_hk);
CREATE INDEX idx_ai_analysis_trust_score ON ai_monitoring.ai_analysis_h(ai_model_trust_score DESC);
CREATE INDEX idx_alert_tenant_hk ON ai_monitoring.alert_h(tenant_hk);
CREATE INDEX idx_alert_security_incident ON ai_monitoring.alert_h(tenant_hk, security_incident_flag);

-- Satellite performance indexes
CREATE INDEX idx_entity_details_tenant_status ON ai_monitoring.monitored_entity_details_s(tenant_hk, status) WHERE load_end_date IS NULL;
CREATE INDEX idx_entity_details_type ON ai_monitoring.monitored_entity_details_s(entity_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_analysis_results_confidence ON ai_monitoring.ai_analysis_results_s(confidence_score DESC) WHERE load_end_date IS NULL;
CREATE INDEX idx_alert_details_severity_status ON ai_monitoring.alert_details_s(tenant_hk, severity, status) WHERE load_end_date IS NULL;
CREATE INDEX idx_alert_details_response_required ON ai_monitoring.alert_details_s(response_required_by) WHERE status = 'OPEN';

-- Zero Trust security indexes
CREATE INDEX idx_zt_policies_tenant_active ON ai_monitoring.zt_access_policies_s(tenant_hk, policy_active) WHERE load_end_date IS NULL;
CREATE INDEX idx_zt_security_events_tenant_severity ON ai_monitoring.zt_security_events_s(tenant_hk, severity, event_timestamp DESC);
CREATE INDEX idx_zt_security_events_risk_score ON ai_monitoring.zt_security_events_s(risk_score DESC, event_timestamp DESC);

-- =====================================================================
-- TENANT ISOLATION STRATEGY
-- =====================================================================

-- Note: Tenant isolation is handled at the application layer through the existing
-- robust authentication system (auth.validate_token_comprehensive, etc.)
-- All API functions validate tenant_hk before data access
-- This follows the existing pattern used throughout the One Vault system

-- Tables are designed with tenant_hk columns for proper isolation
-- All queries in the API functions filter by tenant_hk from validated tokens
-- This approach is consistent with the existing auth, business, and audit schemas

-- =====================================================================
-- PERMISSIONS
-- =====================================================================

-- Grant permissions to appropriate roles
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA ai_monitoring TO app_user;
GRANT SELECT ON ALL TABLES IN SCHEMA ai_monitoring TO app_business_user;
GRANT ALL ON ALL TABLES IN SCHEMA ai_monitoring TO dv_admin;

-- Grant sequence permissions
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ai_monitoring TO app_user;

-- =====================================================================
-- AUDIT TRIGGERS
-- =====================================================================

-- Create audit triggers for all tables
SELECT util.create_audit_triggers_safe('ai_monitoring');

-- =====================================================================
-- COMMENTS FOR DOCUMENTATION
-- =====================================================================

COMMENT ON TABLE ai_monitoring.monitored_entity_h IS 'Hub table for generic monitored entities (equipment, facilities, assets, etc.) with Zero Trust security';
COMMENT ON TABLE ai_monitoring.ai_analysis_h IS 'Hub table for AI analysis sessions with trust scoring and security validation';
COMMENT ON TABLE ai_monitoring.alert_h IS 'Hub table for system alerts with security incident tracking';

COMMENT ON TABLE ai_monitoring.monitored_entity_details_s IS 'Satellite containing encrypted entity details with field-level access control';
COMMENT ON TABLE ai_monitoring.ai_analysis_results_s IS 'Satellite containing encrypted AI analysis results with integrity validation';
COMMENT ON TABLE ai_monitoring.alert_details_s IS 'Satellite containing encrypted alert information with response tracking';

COMMENT ON COLUMN ai_monitoring.monitored_entity_details_s.entity_name_encrypted IS 'Encrypted entity name using tenant-specific encryption key';
COMMENT ON COLUMN ai_monitoring.monitored_entity_details_s.data_classification IS 'Data classification level for Zero Trust access control';
COMMENT ON COLUMN ai_monitoring.ai_analysis_results_s.analysis_data_encrypted IS 'Encrypted AI analysis results with integrity protection';
COMMENT ON COLUMN ai_monitoring.alert_details_s.message_encrypted IS 'Encrypted alert message content for security';

-- =====================================================================
-- COMPLETION LOG
-- =====================================================================

DO $$
DECLARE
    v_deployment_id INTEGER;
BEGIN
    -- Get the current deployment ID and mark as complete
    SELECT deployment_id INTO v_deployment_id 
    FROM util.deployment_log 
    WHERE deployment_name = 'AI_MONITORING_SYSTEM_V1' 
    ORDER BY deployment_start DESC 
    LIMIT 1;
    
    PERFORM util.log_deployment_complete(
        v_deployment_id,
        TRUE,
        'AI Monitoring System successfully deployed with Zero Trust security'
    );
    
    RAISE NOTICE 'AI Monitoring System deployment completed successfully!';
END $$;

-- =====================================================================
-- VERIFICATION QUERIES
-- =====================================================================

-- Verify table creation
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables 
WHERE schemaname = 'ai_monitoring'
ORDER BY tablename;

-- Verify RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles
FROM pg_policies 
WHERE schemaname = 'ai_monitoring'
ORDER BY tablename, policyname;

-- Final verification notice
DO $$
BEGIN
    RAISE NOTICE 'AI Monitoring System deployment verification complete!';
END $$; 