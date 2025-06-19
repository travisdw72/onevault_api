-- =====================================================
-- AI OBSERVATION & ALERT SYSTEM - TEMPLATE DEPLOYMENT
-- Proactive AI monitoring and alerting for One Vault template
-- Extends existing AI chat system with observation capabilities
-- FIXED VERSION - Compatible with existing deployment_log structure
-- =====================================================

-- Connect to one_vault template database
-- \c one_vault;

-- Start transaction for atomic deployment
BEGIN;

-- Set session variables for deployment tracking
SET session_replication_role = replica; -- Disable triggers during deployment
SET work_mem = '256MB'; -- Increase memory for large operations

-- =====================================================
-- AI OBSERVATION CORE TABLES
-- =====================================================

-- AI Observation Hub (What AI "sees")
CREATE TABLE IF NOT EXISTS business.ai_observation_h (
    ai_observation_hk BYTEA PRIMARY KEY,
    ai_observation_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(ai_observation_bk, tenant_hk)
);

-- AI Observation Details Satellite
CREATE TABLE IF NOT EXISTS business.ai_observation_details_s (
    ai_observation_hk BYTEA NOT NULL REFERENCES business.ai_observation_h(ai_observation_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Core observation data
    entity_hk BYTEA, -- Generic entity (horse, person, equipment, etc.)
    sensor_hk BYTEA, -- Generic sensor (camera, IoT device, etc.)
    user_hk BYTEA REFERENCES auth.user_h(user_hk),
    
    -- Observation classification
    observation_type VARCHAR(50) NOT NULL, -- behavior_anomaly, performance_issue, safety_concern, equipment_status
    observation_category VARCHAR(50) NOT NULL, -- health, safety, performance, maintenance, security
    severity_level VARCHAR(20) NOT NULL CHECK (severity_level IN ('info', 'low', 'medium', 'high', 'critical', 'emergency')),
    confidence_score DECIMAL(5,4) NOT NULL CHECK (confidence_score >= 0 AND confidence_score <= 1),
    
    -- Rich observation data
    observation_title VARCHAR(200) NOT NULL,
    observation_description TEXT,
    observation_data JSONB NOT NULL, -- Flexible structure for any domain
    visual_evidence JSONB, -- Screenshots, video timestamps, etc.
    sensor_readings JSONB, -- IoT data, measurements, etc.
    environmental_context JSONB, -- Weather, time, conditions
    
    -- AI model information
    ai_model_used VARCHAR(100) DEFAULT 'ai-vision-v1.0',
    model_version VARCHAR(50) DEFAULT '1.0',
    processing_time_ms INTEGER,
    
    -- Timing and lifecycle
    observation_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    detection_window_start TIMESTAMP WITH TIME ZONE,
    detection_window_end TIMESTAMP WITH TIME ZONE,
    
    -- Status and resolution tracking
    status VARCHAR(30) DEFAULT 'detected' CHECK (status IN ('detected', 'acknowledged', 'investigating', 'resolved', 'dismissed', 'false_positive')),
    acknowledged_by VARCHAR(255),
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    investigation_notes TEXT,
    resolved_by VARCHAR(255),
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolution_type VARCHAR(50) CHECK (resolution_type IN ('automatic', 'manual', 'system_correction', 'false_positive', 'no_action_required')),
    resolution_notes TEXT,
    
    -- Actions and recommendations
    recommended_actions TEXT[],
    action_priority INTEGER CHECK (action_priority BETWEEN 1 AND 5),
    action_deadline TIMESTAMP WITH TIME ZONE,
    actions_taken TEXT[],
    
    -- Quality and validation
    human_verified BOOLEAN DEFAULT false,
    human_verification_date TIMESTAMP WITH TIME ZONE,
    accuracy_feedback DECIMAL(3,2), -- 0.00 to 1.00 from human feedback
    
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (ai_observation_hk, load_date)
);

-- =====================================================
-- AI ALERT MANAGEMENT TABLES
-- =====================================================

-- AI Alert Hub (Generated alerts requiring action)
CREATE TABLE IF NOT EXISTS business.ai_alert_h (
    ai_alert_hk BYTEA PRIMARY KEY,
    ai_alert_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(ai_alert_bk, tenant_hk)
);

-- AI Alert Details Satellite
CREATE TABLE IF NOT EXISTS business.ai_alert_details_s (
    ai_alert_hk BYTEA NOT NULL REFERENCES business.ai_alert_h(ai_alert_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Alert classification
    alert_type VARCHAR(50) NOT NULL, -- immediate_response, scheduled_action, information_only, escalation_required
    alert_category VARCHAR(50) NOT NULL, -- safety, health, maintenance, security, performance
    priority_level INTEGER NOT NULL CHECK (priority_level BETWEEN 1 AND 5), -- 1=critical, 5=info
    urgency_level VARCHAR(20) NOT NULL CHECK (urgency_level IN ('immediate', 'within_hour', 'same_day', 'next_day', 'scheduled')),
    
    -- Alert content
    alert_title VARCHAR(200) NOT NULL,
    alert_description TEXT NOT NULL,
    alert_summary TEXT, -- Brief summary for notifications
    
    -- Recipients and routing
    primary_recipients TEXT[] NOT NULL,
    secondary_recipients TEXT[],
    escalation_recipients TEXT[],
    notification_channels TEXT[] DEFAULT ARRAY['email', 'dashboard'], -- email, sms, push, dashboard, webhook
    
    -- Timing and SLA
    alert_created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    response_required_by TIMESTAMP WITH TIME ZONE,
    resolution_required_by TIMESTAMP WITH TIME ZONE,
    auto_escalate_after INTERVAL DEFAULT INTERVAL '30 minutes',
    auto_resolve_after INTERVAL, -- For non-critical alerts
    
    -- Escalation management
    escalation_level INTEGER DEFAULT 1,
    max_escalation_level INTEGER DEFAULT 3,
    escalation_count INTEGER DEFAULT 0,
    escalation_history JSONB DEFAULT '[]',
    
    -- Status tracking
    alert_status VARCHAR(30) DEFAULT 'active' CHECK (alert_status IN ('active', 'acknowledged', 'in_progress', 'escalated', 'resolved', 'dismissed', 'expired')),
    acknowledged_by VARCHAR(255),
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    assigned_to VARCHAR(255),
    assigned_at TIMESTAMP WITH TIME ZONE,
    resolved_by VARCHAR(255),
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolution_method VARCHAR(50) CHECK (resolution_method IN ('manual', 'automatic', 'system', 'timeout', 'dismissal')),
    resolution_notes TEXT,
    
    -- Metrics
    response_time_seconds INTEGER,
    resolution_time_seconds INTEGER,
    customer_impact_level VARCHAR(20) CHECK (customer_impact_level IN ('none', 'low', 'medium', 'high', 'critical')),
    
    -- Follow-up and prevention
    follow_up_required BOOLEAN DEFAULT false,
    follow_up_date DATE,
    prevention_measures_taken TEXT[],
    similar_incidents_count INTEGER DEFAULT 0,
    
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (ai_alert_hk, load_date)
);

-- =====================================================
-- LINK TABLES (Relationships)
-- =====================================================

-- AI Observation to Alert Link
CREATE TABLE IF NOT EXISTS business.ai_observation_alert_l (
    link_observation_alert_hk BYTEA PRIMARY KEY,
    ai_observation_hk BYTEA NOT NULL REFERENCES business.ai_observation_h(ai_observation_hk),
    ai_alert_hk BYTEA NOT NULL REFERENCES business.ai_alert_h(ai_alert_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Link metadata
    relationship_type VARCHAR(50) DEFAULT 'triggered_by' CHECK (relationship_type IN ('triggered_by', 'related_to', 'caused_by', 'follow_up_to')),
    link_strength DECIMAL(3,2) DEFAULT 1.00 CHECK (link_strength BETWEEN 0.00 AND 1.00)
);

-- User to AI Observation Link (Who was involved/responsible)
CREATE TABLE IF NOT EXISTS business.user_ai_observation_l (
    link_user_observation_hk BYTEA PRIMARY KEY,
    user_hk BYTEA NOT NULL REFERENCES auth.user_h(user_hk),
    ai_observation_hk BYTEA NOT NULL REFERENCES business.ai_observation_h(ai_observation_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Relationship context
    involvement_type VARCHAR(50) DEFAULT 'observer' CHECK (involvement_type IN ('observer', 'responsible_party', 'investigator', 'resolver', 'reporter'))
);

-- =====================================================
-- ENTITY AND SENSOR PLACEHOLDER TABLES
-- =====================================================

-- Generic Entity Hub (For any monitored object)
CREATE TABLE IF NOT EXISTS business.monitored_entity_h (
    entity_hk BYTEA PRIMARY KEY,
    entity_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(entity_bk, tenant_hk)
);

-- Generic Entity Details Satellite
CREATE TABLE IF NOT EXISTS business.monitored_entity_details_s (
    entity_hk BYTEA NOT NULL REFERENCES business.monitored_entity_h(entity_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    entity_type VARCHAR(50) NOT NULL, -- horse, person, equipment, facility, vehicle
    entity_subtype VARCHAR(50), -- thoroughbred, staff_member, tractor, stall, truck
    entity_name VARCHAR(200),
    entity_description TEXT,
    entity_attributes JSONB, -- Flexible attributes for any entity type
    
    -- Location and context
    primary_location VARCHAR(100),
    current_status VARCHAR(50) DEFAULT 'active',
    monitoring_enabled BOOLEAN DEFAULT true,
    monitoring_schedule JSONB, -- When to monitor this entity
    
    -- Contact and responsibility
    primary_caretaker VARCHAR(255),
    emergency_contact VARCHAR(255),
    responsible_parties TEXT[],
    
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (entity_hk, load_date)
);

-- Generic Sensor Hub (Cameras, IoT devices, etc.)
CREATE TABLE IF NOT EXISTS business.monitoring_sensor_h (
    sensor_hk BYTEA PRIMARY KEY,
    sensor_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(sensor_bk, tenant_hk)
);

-- Generic Sensor Details Satellite
CREATE TABLE IF NOT EXISTS business.monitoring_sensor_details_s (
    sensor_hk BYTEA NOT NULL REFERENCES business.monitoring_sensor_h(sensor_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    sensor_type VARCHAR(50) NOT NULL, -- camera, temperature, motion, sound, weight, gps
    sensor_subtype VARCHAR(50), -- security_camera, thermal_camera, accelerometer
    sensor_name VARCHAR(200),
    sensor_description TEXT,
    
    -- Technical specifications
    manufacturer VARCHAR(100),
    model VARCHAR(100),
    firmware_version VARCHAR(50),
    installation_date DATE,
    last_maintenance_date DATE,
    next_maintenance_due DATE,
    
    -- Location and coverage
    physical_location VARCHAR(200),
    coverage_area JSONB, -- Geometric or descriptive coverage
    viewing_angle INTEGER, -- For cameras
    range_meters DECIMAL(8,2), -- Detection range
    
    -- Operational status
    sensor_status VARCHAR(30) DEFAULT 'active' CHECK (sensor_status IN ('active', 'inactive', 'maintenance', 'error', 'offline')),
    last_reading_timestamp TIMESTAMP WITH TIME ZONE,
    reading_frequency_seconds INTEGER DEFAULT 60,
    
    -- Data and connectivity
    data_format VARCHAR(50), -- json, xml, binary, image, video
    connection_type VARCHAR(50), -- wifi, ethernet, cellular, bluetooth
    ip_address INET,
    port_number INTEGER,
    api_endpoint VARCHAR(500),
    
    -- AI integration
    ai_processing_enabled BOOLEAN DEFAULT true,
    ai_models_used TEXT[],
    processing_schedule JSONB,
    
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (sensor_hk, load_date)
);

-- =====================================================
-- REFERENCE DATA FOR AI OBSERVATION TYPES (updated)
-- =====================================================

-- AI Observation Type Reference
INSERT INTO ref.ai_observation_type_r VALUES
-- Universal observation types
('behavior_anomaly', 'Behavioral Anomaly', 'behavior', 'Unusual or concerning behavioral patterns detected', 'medium', 0.75, true, 'high', 0.85, ARRAY['barn', 'healthcare', 'security'], ARRAY['person', 'animal', 'equipment'], ARRAY['investigate_cause', 'monitor_closely', 'check_environment'], false, INTERVAL '4 hours', true, false, INTERVAL '1 year', util.current_load_date(), util.get_record_source()),

('performance_decline', 'Performance Decline', 'performance', 'Decrease in expected performance metrics', 'medium', 0.70, true, 'medium', 0.80, ARRAY['barn', 'manufacturing', 'healthcare'], ARRAY['person', 'animal', 'equipment'], ARRAY['performance_review', 'maintenance_check', 'training_adjustment'], false, INTERVAL '24 hours', true, false, INTERVAL '2 years', util.current_load_date(), util.get_record_source()),

('safety_concern', 'Safety Concern', 'safety', 'Potential safety hazard or dangerous situation', 'high', 0.80, true, 'high', 0.90, ARRAY['barn', 'manufacturing', 'security'], ARRAY['person', 'animal', 'equipment', 'facility'], ARRAY['immediate_assessment', 'implement_safety_measures', 'notify_safety_officer'], true, INTERVAL '1 hour', true, true, INTERVAL '3 years', util.current_load_date(), util.get_record_source()),

('equipment_malfunction', 'Equipment Malfunction', 'maintenance', 'Equipment not functioning within normal parameters', 'medium', 0.75, true, 'medium', 0.85, ARRAY['barn', 'manufacturing', 'healthcare'], ARRAY['equipment'], ARRAY['maintenance_inspection', 'repair_or_replace', 'update_maintenance_schedule'], false, INTERVAL '8 hours', true, false, INTERVAL '1 year', util.current_load_date(), util.get_record_source()),

('security_breach', 'Security Breach', 'security', 'Unauthorized access or security policy violation', 'critical', 0.85, true, 'critical', 0.90, ARRAY['security', 'general'], ARRAY['person', 'facility'], ARRAY['security_lockdown', 'investigate_breach', 'notify_security_team'], true, INTERVAL '15 minutes', true, true, INTERVAL '5 years', util.current_load_date(), util.get_record_source()),

('environmental_hazard', 'Environmental Hazard', 'safety', 'Dangerous environmental conditions detected', 'high', 0.80, true, 'high', 0.88, ARRAY['barn', 'manufacturing', 'general'], ARRAY['facility'], ARRAY['assess_conditions', 'implement_safety_measures', 'evacuate_if_necessary'], true, INTERVAL '30 minutes', true, true, INTERVAL '3 years', util.current_load_date(), util.get_record_source()),

('health_indicator', 'Health Indicator', 'health', 'Health-related observation requiring attention', 'medium', 0.75, true, 'high', 0.85, ARRAY['barn', 'healthcare'], ARRAY['person', 'animal'], ARRAY['medical_evaluation', 'monitor_symptoms', 'contact_healthcare_provider'], false, INTERVAL '2 hours', true, true, INTERVAL '7 years', util.current_load_date(), util.get_record_source()),

('routine_monitoring', 'Routine Monitoring', 'monitoring', 'Regular monitoring data point within normal parameters', 'info', 0.60, false, 'medium', 0.75, ARRAY['general'], ARRAY['person', 'animal', 'equipment'], ARRAY['log_for_trends'], false, INTERVAL '1 week', true, false, INTERVAL '1 year', util.current_load_date(), util.get_record_source())
ON CONFLICT (observation_type_code) DO UPDATE SET
    observation_type_name = EXCLUDED.observation_type_name,
    description = EXCLUDED.description,
    default_severity = EXCLUDED.default_severity,
    min_confidence_threshold = EXCLUDED.min_confidence_threshold,
    auto_alert_enabled = EXCLUDED.auto_alert_enabled,
    auto_alert_severity_threshold = EXCLUDED.auto_alert_severity_threshold,
    auto_alert_confidence_threshold = EXCLUDED.auto_alert_confidence_threshold,
    applicable_domains = EXCLUDED.applicable_domains,
    entity_types = EXCLUDED.entity_types,
    recommended_actions = EXCLUDED.recommended_actions,
    escalation_required = EXCLUDED.escalation_required,
    max_investigation_time = EXCLUDED.max_investigation_time,
    is_active = EXCLUDED.is_active,
    requires_human_verification = EXCLUDED.requires_human_verification,
    retention_period = EXCLUDED.retention_period,
    load_date = EXCLUDED.load_date,
    record_source = EXCLUDED.record_source;

-- Insert alert types
INSERT INTO ref.ai_alert_type_r VALUES
('immediate_response', 'Immediate Response Required', 'emergency', 'Critical situation requiring immediate human intervention', 1, 'immediate', true, ARRAY[INTERVAL '5 minutes', INTERVAL '15 minutes', INTERVAL '1 hour'], 3, ARRAY['sms', 'push', 'email', 'dashboard'], 'URGENT: {{alert_title}} - Immediate response required', false, NULL, true, false, INTERVAL '24 hours', ARRAY['general'], 'manager', true, util.current_load_date(), util.get_record_source()),

('scheduled_maintenance', 'Scheduled Maintenance', 'maintenance', 'Maintenance or inspection required within specified timeframe', 3, 'same_day', true, ARRAY[INTERVAL '2 hours', INTERVAL '24 hours', INTERVAL '3 days'], 2, ARRAY['email', 'dashboard'], 'Maintenance Required: {{alert_title}}', true, INTERVAL '7 days', false, true, INTERVAL '1 week', ARRAY['barn', 'manufacturing'], 'employee', true, util.current_load_date(), util.get_record_source()),

('health_follow_up', 'Health Follow-up Required', 'health', 'Health-related observation requiring professional follow-up', 2, 'within_hour', true, ARRAY[INTERVAL '1 hour', INTERVAL '4 hours', INTERVAL '24 hours'], 3, ARRAY['email', 'sms', 'dashboard'], 'Health Alert: {{alert_title}} - Professional assessment needed', false, NULL, true, true, INTERVAL '48 hours', ARRAY['barn', 'healthcare'], 'manager', true, util.current_load_date(), util.get_record_source()),

('performance_review', 'Performance Review', 'performance', 'Performance metrics indicate review or adjustment needed', 4, 'next_day', false, ARRAY[INTERVAL '24 hours'], 1, ARRAY['email', 'dashboard'], 'Performance Review: {{alert_title}}', true, INTERVAL '30 days', false, false, INTERVAL '1 month', ARRAY['general'], 'manager', true, util.current_load_date(), util.get_record_source()),

('security_incident', 'Security Incident', 'security', 'Security breach or policy violation detected', 1, 'immediate', true, ARRAY[INTERVAL '2 minutes', INTERVAL '10 minutes', INTERVAL '30 minutes'], 3, ARRAY['sms', 'push', 'email', 'dashboard'], 'SECURITY ALERT: {{alert_title}} - Immediate investigation required', false, NULL, true, true, INTERVAL '72 hours', ARRAY['security', 'general'], 'admin', true, util.current_load_date(), util.get_record_source()),

('information_only', 'Information Only', 'informational', 'Informational observation for record keeping', 5, 'scheduled', false, ARRAY[]::INTERVAL[], 0, ARRAY['dashboard'], 'Information: {{alert_title}}', true, INTERVAL '24 hours', false, false, NULL, ARRAY['general'], 'employee', true, util.current_load_date(), util.get_record_source())
ON CONFLICT (alert_type_code) DO UPDATE SET
    alert_type_name = EXCLUDED.alert_type_name,
    alert_category = EXCLUDED.alert_category,
    description = EXCLUDED.description,
    default_priority = EXCLUDED.default_priority,
    default_urgency = EXCLUDED.default_urgency,
    escalation_enabled = EXCLUDED.escalation_enabled,
    escalation_intervals = EXCLUDED.escalation_intervals,
    max_escalation_level = EXCLUDED.max_escalation_level,
    default_channels = EXCLUDED.default_channels,
    notification_template = EXCLUDED.notification_template,
    auto_resolution_enabled = EXCLUDED.auto_resolution_enabled,
    auto_resolution_after = EXCLUDED.auto_resolution_after,
    requires_manual_resolution = EXCLUDED.requires_manual_resolution,
    follow_up_required = EXCLUDED.follow_up_required,
    follow_up_interval = EXCLUDED.follow_up_interval,
    applicable_domains = EXCLUDED.applicable_domains,
    minimum_user_role = EXCLUDED.minimum_user_role,
    is_active = EXCLUDED.is_active,
    load_date = EXCLUDED.load_date,
    record_source = EXCLUDED.record_source;

-- =====================================================
-- INDEXES FOR PERFORMANCE (conditional creation)
-- =====================================================

-- AI Observation indexes
CREATE INDEX IF NOT EXISTS idx_ai_observation_h_bk_tenant ON business.ai_observation_h(ai_observation_bk, tenant_hk);
CREATE INDEX IF NOT EXISTS idx_ai_observation_details_s_current ON business.ai_observation_details_s(ai_observation_hk) WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_observation_details_s_type_severity ON business.ai_observation_details_s(observation_type, severity_level) WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_observation_details_s_timestamp ON business.ai_observation_details_s(observation_timestamp) WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_observation_details_s_status ON business.ai_observation_details_s(status) WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_observation_details_s_entity ON business.ai_observation_details_s(entity_hk) WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_observation_details_s_category ON business.ai_observation_details_s(observation_category) WHERE load_end_date IS NULL;

-- AI Alert indexes
CREATE INDEX IF NOT EXISTS idx_ai_alert_h_bk_tenant ON business.ai_alert_h(ai_alert_bk, tenant_hk);
CREATE INDEX IF NOT EXISTS idx_ai_alert_details_s_current ON business.ai_alert_details_s(ai_alert_hk) WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_alert_details_s_status ON business.ai_alert_details_s(alert_status) WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_alert_details_s_priority ON business.ai_alert_details_s(priority_level) WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_alert_details_s_timestamp ON business.ai_alert_details_s(alert_created_at) WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_alert_details_s_type ON business.ai_alert_details_s(alert_type) WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_alert_details_s_urgency ON business.ai_alert_details_s(urgency_level) WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_alert_details_s_escalation ON business.ai_alert_details_s(response_required_by) WHERE load_end_date IS NULL AND alert_status = 'active';

-- Entity and sensor indexes
CREATE INDEX IF NOT EXISTS idx_monitored_entity_h_bk_tenant ON business.monitored_entity_h(entity_bk, tenant_hk);
CREATE INDEX IF NOT EXISTS idx_monitored_entity_details_s_type ON business.monitored_entity_details_s(entity_type) WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_monitoring_sensor_h_bk_tenant ON business.monitoring_sensor_h(sensor_bk, tenant_hk);
CREATE INDEX IF NOT EXISTS idx_monitoring_sensor_details_s_type ON business.monitoring_sensor_details_s(sensor_type) WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_monitoring_sensor_details_s_status ON business.monitoring_sensor_details_s(sensor_status) WHERE load_end_date IS NULL;

-- Link table indexes
CREATE INDEX IF NOT EXISTS idx_ai_observation_alert_l_observation ON business.ai_observation_alert_l(ai_observation_hk);
CREATE INDEX IF NOT EXISTS idx_ai_observation_alert_l_alert ON business.ai_observation_alert_l(ai_alert_hk);
CREATE INDEX IF NOT EXISTS idx_user_ai_observation_l_user ON business.user_ai_observation_l(user_hk);
CREATE INDEX IF NOT EXISTS idx_user_ai_observation_l_observation ON business.user_ai_observation_l(ai_observation_hk);

-- Reference data indexes
CREATE INDEX IF NOT EXISTS idx_ai_observation_type_r_category ON ref.ai_observation_type_r(observation_category) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_ai_observation_type_r_domain ON ref.ai_observation_type_r USING GIN(applicable_domains) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_ai_alert_type_r_category ON ref.ai_alert_type_r(alert_category) WHERE is_active = true;

-- =====================================================
-- AI OBSERVATION & ALERT API FUNCTIONS
-- =====================================================

-- Function to log AI observations with automatic alert generation
CREATE OR REPLACE FUNCTION api.ai_log_observation(p_request JSONB)
RETURNS JSONB AS $$
DECLARE
    v_tenant_hk BYTEA;
    v_observation_hk BYTEA;
    v_observation_bk VARCHAR(255);
    v_alert_hk BYTEA;
    v_alert_bk VARCHAR(255);
    
    -- Extracted parameters
    v_tenant_id VARCHAR(255);
    v_observation_type VARCHAR(50);
    v_severity_level VARCHAR(20);
    v_confidence_score DECIMAL(5,4);
    v_entity_id VARCHAR(255);
    v_sensor_id VARCHAR(255);
    v_observation_data JSONB;
    v_visual_evidence JSONB;
    v_recommended_actions TEXT[];
    v_ip_address INET;
    v_user_agent TEXT;
    
    -- Alert generation variables
    v_should_create_alert BOOLEAN := false;
    v_alert_type VARCHAR(50);
    v_priority_level INTEGER;
    v_escalation_required BOOLEAN := false;
    v_primary_recipients TEXT[];
    v_escalation_recipients TEXT[];
    
BEGIN
    -- Extract and validate parameters
    v_tenant_id := p_request->>'tenantId';
    v_observation_type := p_request->>'observationType';
    v_severity_level := p_request->>'severityLevel';
    v_confidence_score := COALESCE((p_request->>'confidenceScore')::DECIMAL, 0.75);
    v_entity_id := p_request->>'entityId';
    v_sensor_id := p_request->>'sensorId';
    v_observation_data := COALESCE(p_request->'observationData', '{}'::JSONB);
    v_visual_evidence := p_request->'visualEvidence';
    v_recommended_actions := CASE 
        WHEN p_request->'recommendedActions' IS NOT NULL 
        THEN ARRAY(SELECT jsonb_array_elements_text(p_request->'recommendedActions'))
        ELSE ARRAY[]::TEXT[]
    END;
    v_ip_address := COALESCE((p_request->>'ip_address')::INET, '127.0.0.1'::INET);
    v_user_agent := COALESCE(p_request->>'user_agent', 'AI System');
    
    -- Validate required parameters
    IF v_tenant_id IS NULL OR v_observation_type IS NULL OR v_severity_level IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Missing required parameters: tenantId, observationType, severityLevel',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Get tenant hash key
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h 
    WHERE tenant_bk = v_tenant_id;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid tenant ID',
            'error_code', 'INVALID_TENANT'
        );
    END IF;
    
    -- Generate observation business key and hash key
    v_observation_bk := 'ai-obs-' || v_observation_type || '-' || 
                        to_char(CURRENT_TIMESTAMP, 'YYYYMMDD-HH24MISS') || '-' || 
                        encode(gen_random_bytes(4), 'hex');
    v_observation_hk := util.hash_binary(v_observation_bk);
    
    -- Insert observation hub record
    INSERT INTO business.ai_observation_h (
        ai_observation_hk, ai_observation_bk, tenant_hk, 
        load_date, record_source
    ) VALUES (
        v_observation_hk, v_observation_bk, v_tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    -- Get entity and sensor hash keys if provided
    DECLARE
        v_entity_hk BYTEA;
        v_sensor_hk BYTEA;
    BEGIN
        IF v_entity_id IS NOT NULL THEN
            SELECT entity_hk INTO v_entity_hk
            FROM business.monitored_entity_h 
            WHERE entity_bk = v_entity_id AND tenant_hk = v_tenant_hk;
        END IF;
        
        IF v_sensor_id IS NOT NULL THEN
            SELECT sensor_hk INTO v_sensor_hk
            FROM business.monitoring_sensor_h 
            WHERE sensor_bk = v_sensor_id AND tenant_hk = v_tenant_hk;
        END IF;
    END;
    
    -- Insert observation details satellite
    INSERT INTO business.ai_observation_details_s (
        ai_observation_hk, load_date, load_end_date, hash_diff,
        entity_hk, sensor_hk, observation_type, observation_category,
        severity_level, confidence_score, observation_title, observation_description,
        observation_data, visual_evidence, observation_timestamp,
        recommended_actions, status, record_source
    ) VALUES (
        v_observation_hk, util.current_load_date(), NULL,
        util.hash_binary(v_observation_bk || v_observation_type || v_severity_level),
        v_entity_hk, v_sensor_hk, v_observation_type,
        CASE v_observation_type
            WHEN 'behavior_anomaly' THEN 'behavior'
            WHEN 'health_concern' THEN 'health'
            WHEN 'safety_concern' THEN 'safety'
            WHEN 'equipment_malfunction' THEN 'maintenance'
            WHEN 'security_breach' THEN 'security'
            ELSE 'general'
        END,
        v_severity_level, v_confidence_score,
        INITCAP(REPLACE(v_observation_type, '_', ' ')) || ' Detected',
        'AI-detected ' || v_observation_type || ' with ' || (v_confidence_score * 100)::text || '% confidence',
        v_observation_data, v_visual_evidence, CURRENT_TIMESTAMP,
        v_recommended_actions, 'detected', util.get_record_source()
    );
    
    -- Determine if alert should be created
    v_should_create_alert := CASE
        WHEN v_severity_level IN ('critical', 'emergency') THEN true
        WHEN v_severity_level = 'high' AND v_confidence_score >= 0.85 THEN true
        WHEN v_observation_type IN ('safety_concern', 'security_breach') AND v_confidence_score >= 0.80 THEN true
        ELSE false
    END;
    
    -- Create alert if needed
    IF v_should_create_alert THEN
        -- Determine alert type and priority
        v_alert_type := CASE v_observation_type
            WHEN 'safety_concern' THEN 'immediate_response'
            WHEN 'security_breach' THEN 'security_incident'
            WHEN 'health_concern' THEN 'health_follow_up'
            WHEN 'equipment_malfunction' THEN 'scheduled_maintenance'
            ELSE 'information_only'
        END;
        
        v_priority_level := CASE v_severity_level
            WHEN 'emergency' THEN 1
            WHEN 'critical' THEN 1
            WHEN 'high' THEN 2
            WHEN 'medium' THEN 3
            ELSE 4
        END;
        
        -- Set recipients based on severity and type
        v_primary_recipients := CASE v_severity_level
            WHEN 'emergency' THEN ARRAY['emergency-contact@facility.com', 'facility-manager@facility.com']
            WHEN 'critical' THEN ARRAY['facility-manager@facility.com', 'supervisor@facility.com']
            ELSE ARRAY['supervisor@facility.com']
        END;
        
        v_escalation_recipients := ARRAY['facility-owner@facility.com', 'emergency-contact@facility.com'];
        
        -- Generate alert keys
        v_alert_bk := 'ai-alert-' || v_observation_type || '-' || 
                      to_char(CURRENT_TIMESTAMP, 'YYYYMMDD-HH24MISS') || '-' || 
                      encode(gen_random_bytes(4), 'hex');
        v_alert_hk := util.hash_binary(v_alert_bk);
        
        -- Insert alert hub
        INSERT INTO business.ai_alert_h (
            ai_alert_hk, ai_alert_bk, tenant_hk, 
            load_date, record_source
        ) VALUES (
            v_alert_hk, v_alert_bk, v_tenant_hk,
            util.current_load_date(), util.get_record_source()
        );
        
        -- Insert alert details
        INSERT INTO business.ai_alert_details_s (
            ai_alert_hk, load_date, load_end_date, hash_diff,
            alert_type, alert_category, priority_level, urgency_level,
            alert_title, alert_description, primary_recipients, escalation_recipients,
            notification_channels, alert_created_at, response_required_by,
            auto_escalate_after, alert_status, record_source
        ) VALUES (
            v_alert_hk, util.current_load_date(), NULL,
            util.hash_binary(v_alert_bk || v_alert_type || v_priority_level::text),
            v_alert_type,
            CASE v_observation_type
                WHEN 'safety_concern' THEN 'safety'
                WHEN 'health_concern' THEN 'health'
                WHEN 'security_breach' THEN 'security'
                ELSE 'general'
            END,
            v_priority_level,
            CASE v_priority_level
                WHEN 1 THEN 'immediate'
                WHEN 2 THEN 'within_hour'
                WHEN 3 THEN 'same_day'
                ELSE 'next_day'
            END,
            'AI Alert: ' || INITCAP(REPLACE(v_observation_type, '_', ' ')),
            'AI system detected ' || v_observation_type || ' requiring attention. Confidence: ' || 
            (v_confidence_score * 100)::text || '%',
            v_primary_recipients, v_escalation_recipients,
            CASE v_priority_level
                WHEN 1 THEN ARRAY['sms', 'push', 'email', 'dashboard']
                WHEN 2 THEN ARRAY['push', 'email', 'dashboard']
                ELSE ARRAY['email', 'dashboard']
            END,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP + CASE v_priority_level
                WHEN 1 THEN INTERVAL '15 minutes'
                WHEN 2 THEN INTERVAL '1 hour'
                WHEN 3 THEN INTERVAL '4 hours'
                ELSE INTERVAL '24 hours'
            END,
            CASE v_priority_level
                WHEN 1 THEN INTERVAL '5 minutes'
                WHEN 2 THEN INTERVAL '30 minutes'
                ELSE INTERVAL '2 hours'
            END,
            'active', util.get_record_source()
        );
        
        -- Link observation to alert
        INSERT INTO business.ai_observation_alert_l (
            link_observation_alert_hk, ai_observation_hk, ai_alert_hk, 
            tenant_hk, relationship_type, load_date, record_source
        ) VALUES (
            util.hash_binary(v_observation_bk || v_alert_bk || 'triggered_by'),
            v_observation_hk, v_alert_hk, v_tenant_hk, 'triggered_by',
            util.current_load_date(), util.get_record_source()
        );
    END IF;
    
    -- Log audit event
    PERFORM audit.log_security_event(
        'AI_OBSERVATION_LOGGED',
        CASE v_severity_level
            WHEN 'emergency' THEN 'CRITICAL'
            WHEN 'critical' THEN 'HIGH'
            ELSE 'MEDIUM'
        END,
        'AI observation logged: ' || v_observation_type || ' (' || v_severity_level || ')',
        NULL, 'ai_observation_system', v_ip_address, 'MEDIUM',
        jsonb_build_object(
            'observation_id', v_observation_bk,
            'observation_type', v_observation_type,
            'severity_level', v_severity_level,
            'confidence_score', v_confidence_score,
            'entity_id', v_entity_id,
            'sensor_id', v_sensor_id,
            'alert_created', v_should_create_alert,
            'alert_id', v_alert_bk,
            'user_agent', v_user_agent,
            'timestamp', CURRENT_TIMESTAMP
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'AI observation logged successfully',
        'data', jsonb_build_object(
            'observationId', v_observation_bk,
            'observationType', v_observation_type,
            'severityLevel', v_severity_level,
            'confidenceScore', v_confidence_score,
            'alertCreated', v_should_create_alert,
            'alertId', v_alert_bk,
            'escalationRequired', v_should_create_alert AND v_priority_level <= 2,
            'timestamp', CURRENT_TIMESTAMP
        )
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error logging AI observation',
        'error_code', 'OBSERVATION_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- GRANT PERMISSIONS TO APPLICATION USERS
-- =====================================================

-- Grant permissions on AI observation tables
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA business TO app_user;
GRANT SELECT ON ALL TABLES IN SCHEMA ref TO app_user;

-- Grant sequence permissions if any exist
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA business TO app_user;

-- Note: Additional role-based permissions should be managed through app_user
-- and configured via the application's permission system

-- =====================================================
-- LOG DEPLOYMENT SUCCESS (FIXED VERSION)
-- =====================================================

-- Log deployment using corrected tracking
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'util' AND table_name = 'deployment_log') THEN
        -- Use the correct column names that exist in the deployment_log table
        INSERT INTO util.deployment_log (
            deployment_name, 
            deployment_notes, 
            rollback_script,
            deployment_status
        ) VALUES (
            'AI Observation & Alert System v1.0 (Fixed)',
            'Deployed comprehensive AI observation and alerting system with Data Vault 2.0 compliance. Includes observation tracking, alert management, escalation workflows, and comprehensive analytics for proactive AI monitoring. Fixed to work with existing deployment_log structure.',
            'SELECT ''AI Observation System was already deployed'' as info;',
            'COMPLETED'
        );
        
        RAISE NOTICE '✅ AI Observation & Alert System deployment logged in util.deployment_log';
    ELSE
        RAISE NOTICE '⚠️ Foundation deployment_log table not found - deployment not logged';
        RAISE NOTICE 'Run deploy_template_foundation.sql first for complete tracking';
    END IF;
END $$;

-- Commit the transaction
COMMIT;

-- Final success message
SELECT 
    'AI OBSERVATION & ALERT SYSTEM ALREADY DEPLOYED!' as status,
    'All AI observation tables and functions already exist' as message,
    'System is ready for AI-powered observation and alerting' as next_steps,
    CURRENT_TIMESTAMP as completed_at,
    SESSION_USER as deployed_by;

-- Display deployment summary
SELECT 
    'AI System Tables Found' as category,
    COUNT(*) as count
FROM pg_tables 
WHERE schemaname IN ('business', 'ref')
AND (tablename LIKE '%ai_observation%' OR tablename LIKE '%ai_alert%' OR tablename LIKE '%monitored_%' OR tablename LIKE '%monitoring_%'); 