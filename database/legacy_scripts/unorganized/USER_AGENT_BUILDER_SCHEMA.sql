-- ==========================================
-- USER-CONFIGURABLE AI AGENT BUILDER SYSTEM
-- ==========================================
-- Extends existing Data Vault 2.0 and AI Agents infrastructure
-- Allows users to create custom AI agents like n8n workflows

BEGIN;

-- ==========================================
-- AGENT TEMPLATE LIBRARY
-- ==========================================

-- Agent Template Hub - Predefined agent types users can customize
CREATE TABLE ai_agents.agent_template_h (
    agent_template_hk BYTEA PRIMARY KEY,
    agent_template_bk VARCHAR(255) NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

CREATE TABLE ai_agents.agent_template_s (
    agent_template_hk BYTEA NOT NULL REFERENCES ai_agents.agent_template_h(agent_template_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    template_category VARCHAR(100) NOT NULL,        -- IMAGE_AI, VOICE_AI, TEXT_AI, SENSOR_AI
    description TEXT,
    capabilities JSONB NOT NULL,                    -- What this template can do
    required_inputs JSONB NOT NULL,                 -- Required input parameters  
    configuration_schema JSONB NOT NULL,            -- JSON schema for user customization
    default_configuration JSONB NOT NULL,           -- Default settings
    supported_ai_providers JSONB NOT NULL,          -- Compatible AI APIs (OpenAI, Azure, etc.)
    template_icon VARCHAR(100),                     -- UI icon reference
    complexity_level VARCHAR(20) DEFAULT 'BEGINNER', -- BEGINNER, INTERMEDIATE, ADVANCED
    estimated_cost_per_use DECIMAL(10,4),           -- Cost estimation for users
    use_case_examples JSONB,                        -- Example use cases
    is_active BOOLEAN DEFAULT true,
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (agent_template_hk, load_date)
);

-- ==========================================
-- USER-CONFIGURED AGENTS
-- ==========================================

-- User Agent Hub - User-created agent instances
CREATE TABLE ai_agents.user_agent_h (
    user_agent_hk BYTEA PRIMARY KEY,
    user_agent_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

CREATE TABLE ai_agents.user_agent_s (
    user_agent_hk BYTEA NOT NULL REFERENCES ai_agents.user_agent_h(user_agent_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    agent_name VARCHAR(200) NOT NULL,
    agent_description TEXT,
    agent_template_hk BYTEA NOT NULL REFERENCES ai_agents.agent_template_h(agent_template_hk),
    user_configuration JSONB NOT NULL,              -- User's custom configuration
    deployment_status VARCHAR(20) DEFAULT 'DRAFT',  -- DRAFT, TESTING, DEPLOYED, PAUSED
    privacy_settings JSONB NOT NULL,                -- Data access and retention settings
    alert_configuration JSONB,                      -- Alert settings and contacts
    cost_management JSONB,                          -- Budget limits and monitoring
    performance_metrics JSONB,                      -- Success rate, accuracy, etc.
    usage_statistics JSONB,                         -- Usage patterns and frequency
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    last_modified_by VARCHAR(100) DEFAULT SESSION_USER,
    is_shared BOOLEAN DEFAULT false,                -- Can other tenants use as template
    share_permissions JSONB,                        -- Sharing configuration
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (user_agent_hk, load_date)
);

-- ==========================================
-- AGENT EXECUTION TRACKING
-- ==========================================

CREATE TABLE ai_agents.user_agent_execution_h (
    execution_hk BYTEA PRIMARY KEY,
    execution_bk VARCHAR(255) NOT NULL,
    user_agent_hk BYTEA NOT NULL REFERENCES ai_agents.user_agent_h(user_agent_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

CREATE TABLE ai_agents.user_agent_execution_s (
    execution_hk BYTEA NOT NULL REFERENCES ai_agents.user_agent_execution_h(execution_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    execution_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    trigger_type VARCHAR(100) NOT NULL,            -- MANUAL, SCHEDULED, EVENT_DRIVEN, API_CALL
    input_data JSONB NOT NULL,                     -- Input provided to agent
    execution_status VARCHAR(20) DEFAULT 'RUNNING', -- RUNNING, COMPLETED, FAILED, CANCELLED
    output_data JSONB,                             -- Agent results
    processing_time_ms INTEGER,                    -- Execution duration
    ai_provider_used VARCHAR(100),                 -- Which AI service was used
    tokens_consumed INTEGER,                       -- API tokens used
    cost_incurred DECIMAL(10,4),                   -- Actual execution cost
    confidence_score DECIMAL(5,2),                 -- Agent confidence in results
    user_feedback JSONB,                           -- User rating and feedback
    error_details JSONB,                           -- Error information if failed
    executed_by VARCHAR(100) DEFAULT SESSION_USER,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (execution_hk, load_date)
);

-- ==========================================
-- PREDEFINED TEMPLATES INITIALIZATION
-- ==========================================

CREATE OR REPLACE FUNCTION ai_agents.create_predefined_templates()
RETURNS TEXT AS $$
DECLARE
    v_template_hk BYTEA;
    v_template_bk VARCHAR(255);
BEGIN
    -- HORSE HEALTH IMAGE ANALYZER TEMPLATE
    v_template_bk := 'HORSE_HEALTH_ANALYZER_V1';
    v_template_hk := util.hash_binary(v_template_bk);
    
    INSERT INTO ai_agents.agent_template_h VALUES (
        v_template_hk, v_template_bk, util.current_load_date(), util.get_record_source()
    );
    
    INSERT INTO ai_agents.agent_template_s VALUES (
        v_template_hk, util.current_load_date(), NULL,
        util.hash_binary(v_template_bk || 'HORSE_HEALTH'),
        'Horse Health Image Analyzer',
        'IMAGE_AI',
        'Analyzes horse photos for health indicators, injuries, lameness, and body condition scoring',
        '["injury_detection", "lameness_assessment", "body_condition_scoring", "behavioral_analysis", "coat_condition"]',
        '{
            "image_url": {"type": "string", "required": true, "description": "URL or path to horse image"},
            "horse_id": {"type": "string", "required": true, "description": "Unique horse identifier"},
            "analysis_type": {"type": "array", "items": {"enum": ["health", "lameness", "body_condition", "injuries"]}, "required": true},
            "comparison_baseline": {"type": "string", "required": false, "description": "Historical baseline for comparison"}
        }',
        '{
            "confidence_thresholds": {
                "injury_detection": 0.7,
                "lameness_assessment": 0.6,
                "urgent_findings": 0.9
            },
            "analysis_focus": ["general_health", "movement", "visible_injuries"],
            "output_detail_level": "standard",
            "include_recommendations": true,
            "alert_settings": {
                "enabled": true,
                "injury_threshold": 0.7,
                "urgent_threshold": 0.9
            }
        }',
        '["openai_vision", "azure_computer_vision", "google_vision_api", "custom_veterinary_models"]',
        'horse-health-icon',
        'BEGINNER',
        0.08,
        '{
            "horse_trainers": "Daily health monitoring and injury prevention",
            "veterinarians": "Pre-visit health assessments and documentation", 
            "barn_managers": "Automated health checking for large facilities",
            "horse_owners": "Regular wellness monitoring and early problem detection"
        }',
        true,
        SESSION_USER,
        util.get_record_source()
    );
    
    -- SENIOR WELLNESS VOICE MONITOR TEMPLATE
    v_template_bk := 'SENIOR_WELLNESS_VOICE_V1';
    v_template_hk := util.hash_binary(v_template_bk);
    
    INSERT INTO ai_agents.agent_template_h VALUES (
        v_template_hk, v_template_bk, util.current_load_date(), util.get_record_source()
    );
    
    INSERT INTO ai_agents.agent_template_s VALUES (
        v_template_hk, util.current_load_date(), NULL,
        util.hash_binary(v_template_bk || 'SENIOR_VOICE'),
        'Senior Wellness Voice Monitor',
        'VOICE_AI',
        'HIPAA-compliant voice analysis for senior care monitoring including confusion, distress, and emergency detection',
        '["speech_to_text", "emotion_detection", "confusion_indicators", "distress_signals", "emergency_keyword_detection", "cognitive_assessment"]',
        '{
            "audio_url": {"type": "string", "required": true, "description": "URL or path to audio recording"},
            "resident_id": {"type": "string", "required": true, "description": "Unique resident identifier"},
            "analysis_focus": {"type": "array", "items": {"enum": ["wellness", "confusion", "distress", "emergency", "cognitive"]}, "required": true},
            "duration_minutes": {"type": "number", "required": false, "description": "Audio duration for processing limits"}
        }',
        '{
            "hipaa_compliance": {
                "voice_retention_hours": 24,
                "transcript_retention_days": 30,
                "anonymize_transcriptions": true,
                "encryption_level": "AES256"
            },
            "detection_thresholds": {
                "confusion_indicators": 0.6,
                "distress_signals": 0.8,
                "emergency_keywords": 1.0
            },
            "monitoring_schedule": {
                "active_hours": "06:00-22:00",
                "emergency_monitoring": "24/7"
            },
            "privacy_mode": "maximum"
        }',
        '["azure_speech_services", "openai_whisper", "google_speech_api", "hipaa_compliant_providers"]',
        'senior-care-icon',
        'INTERMEDIATE',
        0.12,
        '{
            "senior_care_facilities": "24/7 wellness monitoring and emergency detection",
            "family_caregivers": "Remote monitoring of elderly family members",
            "assisted_living": "Automated check-ins and mood monitoring",
            "memory_care": "Confusion and cognitive decline tracking"
        }',
        true,
        SESSION_USER,
        util.get_record_source()
    );
    
    -- EQUIPMENT MAINTENANCE PREDICTOR TEMPLATE  
    v_template_bk := 'EQUIPMENT_MAINTENANCE_PREDICTOR_V1';
    v_template_hk := util.hash_binary(v_template_bk);
    
    INSERT INTO ai_agents.agent_template_h VALUES (
        v_template_hk, v_template_bk, util.current_load_date(), util.get_record_source()
    );
    
    INSERT INTO ai_agents.agent_template_s VALUES (
        v_template_hk, util.current_load_date(), NULL,
        util.hash_binary(v_template_bk || 'EQUIPMENT_MAINTENANCE'),
        'Equipment Maintenance Predictor',
        'SENSOR_AI',
        'Analyzes IoT sensor data to predict equipment failures and optimize maintenance schedules',
        '["anomaly_detection", "predictive_maintenance", "failure_prediction", "cost_optimization", "schedule_optimization"]',
        '{
            "sensor_data": {"type": "array", "required": true, "description": "Array of sensor readings with timestamps"},
            "equipment_id": {"type": "string", "required": true, "description": "Unique equipment identifier"},
            "equipment_type": {"type": "string", "enum": ["motor", "pump", "compressor", "conveyor", "hvac", "generic"], "required": true},
            "historical_baseline": {"type": "object", "required": false, "description": "Historical performance baseline"}
        }',
        '{
            "prediction_horizon_days": 30,
            "anomaly_sensitivity": "medium",
            "maintenance_cost_factors": {
                "preventive_cost_multiplier": 0.3,
                "reactive_cost_multiplier": 1.0,
                "downtime_cost_per_hour": 500.0
            },
            "alert_thresholds": {
                "minor_anomaly": 0.6,
                "maintenance_recommended": 0.8,
                "urgent_attention": 0.95
            }
        }',
        '["custom_ml_models", "azure_iot_analytics", "aws_iot_analytics", "statistical_analysis"]',
        'maintenance-predictor-icon',
        'ADVANCED',
        0.05,
        '{
            "manufacturing_facilities": "Predictive maintenance for production equipment",
            "facility_management": "HVAC and building systems optimization", 
            "fleet_management": "Vehicle maintenance prediction and scheduling",
            "industrial_operations": "Minimize downtime and maintenance costs"
        }',
        true,
        SESSION_USER,
        util.get_record_source()
    );
    
    RETURN 'Created 3 predefined agent templates: Horse Health Analyzer, Senior Wellness Monitor, Equipment Maintenance Predictor';
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- USER AGENT MANAGEMENT FUNCTIONS
-- ==========================================

-- Function to create a new user agent from template
CREATE OR REPLACE FUNCTION ai_agents.create_user_agent(
    p_tenant_hk BYTEA,
    p_agent_name VARCHAR(200),
    p_template_hk BYTEA,
    p_user_configuration JSONB,
    p_privacy_settings JSONB DEFAULT '{"data_access": "own_tenant_only", "retention_days": 365}'::jsonb,
    p_alert_configuration JSONB DEFAULT '{}'::jsonb,
    p_cost_budget DECIMAL(10,2) DEFAULT 100.00
) RETURNS JSONB AS $$
DECLARE
    v_user_agent_hk BYTEA;
    v_user_agent_bk VARCHAR(255);
    v_template_config RECORD;
    v_merged_config JSONB;
BEGIN
    -- Validate template exists and get configuration
    SELECT * INTO v_template_config
    FROM ai_agents.agent_template_s 
    WHERE agent_template_hk = p_template_hk 
    AND load_end_date IS NULL;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Agent template not found: %', encode(p_template_hk, 'hex');
    END IF;
    
    -- Generate unique identifiers
    v_user_agent_bk := 'USER_AGENT_' || 
                       regexp_replace(p_agent_name, '[^a-zA-Z0-9]', '_', 'g') || '_' ||
                       substr(encode(p_tenant_hk, 'hex'), 1, 8) || '_' ||
                       to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    v_user_agent_hk := util.hash_binary(v_user_agent_bk);
    
    -- Merge user configuration with template defaults
    v_merged_config := v_template_config.default_configuration || p_user_configuration;
    
    -- Create user agent hub record
    INSERT INTO ai_agents.user_agent_h VALUES (
        v_user_agent_hk, v_user_agent_bk, p_tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    -- Create user agent satellite record
    INSERT INTO ai_agents.user_agent_s VALUES (
        v_user_agent_hk, util.current_load_date(), NULL,
        util.hash_binary(v_user_agent_bk || p_agent_name || CURRENT_TIMESTAMP::text),
        p_agent_name,
        'User-configured ' || v_template_config.template_name,
        p_template_hk,
        v_merged_config,
        'DRAFT',
        p_privacy_settings,
        p_alert_configuration,
        jsonb_build_object('monthly_budget', p_cost_budget, 'usage_alerts_enabled', true),
        jsonb_build_object('executions', 0, 'success_rate', 0, 'avg_confidence', 0),
        jsonb_build_object('total_executions', 0, 'total_cost', 0, 'avg_execution_time_ms', 0),
        SESSION_USER,
        SESSION_USER,
        false,
        '{}'::jsonb,
        util.get_record_source()
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'agent_id', encode(v_user_agent_hk, 'hex'),
        'agent_name', p_agent_name,
        'template_used', v_template_config.template_name,
        'status', 'DRAFT',
        'next_steps', 'Configure and test your agent before deploying'
    );
END;
$$ LANGUAGE plpgsql;

-- Function to execute a user agent
CREATE OR REPLACE FUNCTION ai_agents.execute_user_agent(
    p_user_agent_hk BYTEA,
    p_input_data JSONB,
    p_trigger_type VARCHAR(100) DEFAULT 'MANUAL'
) RETURNS JSONB AS $$
DECLARE
    v_execution_hk BYTEA;
    v_execution_bk VARCHAR(255);
    v_agent_config RECORD;
    v_template_config RECORD;
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_end_time TIMESTAMP WITH TIME ZONE;
    v_processing_time INTEGER;
    v_result JSONB;
    v_cost DECIMAL(10,4);
    v_confidence DECIMAL(5,2);
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    -- Get agent configuration
    SELECT ua.*, uas.* INTO v_agent_config
    FROM ai_agents.user_agent_h ua
    JOIN ai_agents.user_agent_s uas ON ua.user_agent_hk = uas.user_agent_hk
    WHERE ua.user_agent_hk = p_user_agent_hk
    AND uas.load_end_date IS NULL;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User agent not found: %', encode(p_user_agent_hk, 'hex');
    END IF;
    
    -- Get template configuration
    SELECT * INTO v_template_config
    FROM ai_agents.agent_template_s
    WHERE agent_template_hk = v_agent_config.agent_template_hk
    AND load_end_date IS NULL;
    
    -- Check deployment status
    IF v_agent_config.deployment_status NOT IN ('DEPLOYED', 'TESTING') THEN
        RAISE EXCEPTION 'Agent must be in DEPLOYED or TESTING status to execute. Current status: %', 
                        v_agent_config.deployment_status;
    END IF;
    
    -- Generate execution identifiers
    v_execution_bk := 'EXEC_' || substr(encode(p_user_agent_hk, 'hex'), 1, 8) || '_' ||
                      to_char(v_start_time, 'YYYYMMDD_HH24MISS_US');
    v_execution_hk := util.hash_binary(v_execution_bk);
    
    -- Create execution hub record
    INSERT INTO ai_agents.user_agent_execution_h VALUES (
        v_execution_hk, v_execution_bk, p_user_agent_hk, v_agent_config.tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    -- Simulate AI execution based on template category
    BEGIN
        CASE v_template_config.template_category
            WHEN 'IMAGE_AI' THEN
                -- Simulate image analysis
                v_result := jsonb_build_object(
                    'analysis_type', 'image_analysis',
                    'detected_objects', '[{"type": "horse", "confidence": 0.95}, {"type": "potential_injury", "confidence": 0.73}]',
                    'health_assessment', jsonb_build_object(
                        'overall_condition', 'good',
                        'concerns', '["Minor swelling detected on left front leg"]',
                        'recommendations', '["Monitor swelling", "Consider veterinary consultation"]'
                    ),
                    'confidence_score', 0.87
                );
                v_cost := 0.08;
                v_confidence := 0.87;
                
            WHEN 'VOICE_AI' THEN
                -- Simulate voice analysis
                v_result := jsonb_build_object(
                    'analysis_type', 'voice_analysis',
                    'transcription', 'I am feeling well today, thank you for asking.',
                    'emotional_state', 'calm_and_positive',
                    'confusion_indicators', 0.1,
                    'distress_level', 0.05,
                    'emergency_keywords_detected', false,
                    'wellness_score', 0.92
                );
                v_cost := 0.12;
                v_confidence := 0.92;
                
            WHEN 'SENSOR_AI' THEN
                -- Simulate sensor data analysis
                v_result := jsonb_build_object(
                    'analysis_type', 'sensor_analysis',
                    'anomalies_detected', 1,
                    'maintenance_prediction', jsonb_build_object(
                        'recommended_date', (CURRENT_DATE + INTERVAL '15 days')::text,
                        'urgency_level', 'medium',
                        'estimated_cost_savings', 1250.00
                    ),
                    'current_health_score', 0.78
                );
                v_cost := 0.05;
                v_confidence := 0.78;
                
            ELSE
                -- Generic analysis
                v_result := jsonb_build_object(
                    'analysis_type', 'generic_analysis',
                    'status', 'completed',
                    'message', 'Analysis completed using generic template'
                );
                v_cost := 0.03;
                v_confidence := 0.75;
        END CASE;
        
        v_end_time := CURRENT_TIMESTAMP;
        v_processing_time := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
        
        -- Create successful execution record
        INSERT INTO ai_agents.user_agent_execution_s VALUES (
            v_execution_hk, util.current_load_date(), NULL,
            util.hash_binary(v_execution_bk || 'COMPLETED' || v_result::text),
            v_start_time,
            p_trigger_type,
            p_input_data,
            'COMPLETED',
            v_result,
            v_processing_time,
            COALESCE((v_agent_config.user_configuration->>'preferred_ai_provider')::text, 'openai'),
            CASE WHEN v_template_config.template_category = 'IMAGE_AI' THEN 150
                 WHEN v_template_config.template_category = 'VOICE_AI' THEN 300
                 ELSE 50 END,
            v_cost,
            v_confidence,
            NULL, -- user_feedback to be added later
            NULL, -- no errors
            SESSION_USER,
            util.get_record_source()
        );
        
    EXCEPTION WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_processing_time := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
        
        -- Log failed execution
        INSERT INTO ai_agents.user_agent_execution_s VALUES (
            v_execution_hk, util.current_load_date(), NULL,
            util.hash_binary(v_execution_bk || 'FAILED'),
            v_start_time,
            p_trigger_type,
            p_input_data,
            'FAILED',
            NULL,
            v_processing_time,
            'unknown',
            0,
            0,
            0,
            NULL,
            jsonb_build_object('error_message', SQLERRM, 'error_code', SQLSTATE),
            SESSION_USER,
            util.get_record_source()
        );
        
        RAISE;
    END;
    
    RETURN jsonb_build_object(
        'success', true,
        'execution_id', encode(v_execution_hk, 'hex'),
        'status', 'COMPLETED',
        'processing_time_ms', v_processing_time,
        'cost_incurred', v_cost,
        'confidence_score', v_confidence,
        'result', v_result
    );
END;
$$ LANGUAGE plpgsql;

-- Function to deploy/activate a user agent
CREATE OR REPLACE FUNCTION ai_agents.deploy_user_agent(
    p_user_agent_hk BYTEA,
    p_deployment_notes TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_agent_config RECORD;
BEGIN
    -- Get current agent configuration
    SELECT uas.* INTO v_agent_config
    FROM ai_agents.user_agent_s uas
    WHERE uas.user_agent_hk = p_user_agent_hk
    AND uas.load_end_date IS NULL;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User agent not found';
    END IF;
    
    -- Update deployment status
    UPDATE ai_agents.user_agent_s 
    SET load_end_date = util.current_load_date()
    WHERE user_agent_hk = p_user_agent_hk AND load_end_date IS NULL;
    
    INSERT INTO ai_agents.user_agent_s VALUES (
        p_user_agent_hk, util.current_load_date(), NULL,
        util.hash_binary(v_agent_config.user_agent_hk::text || 'DEPLOYED' || CURRENT_TIMESTAMP::text),
        v_agent_config.agent_name,
        v_agent_config.agent_description,
        v_agent_config.agent_template_hk,
        v_agent_config.user_configuration,
        'DEPLOYED',
        v_agent_config.privacy_settings,
        v_agent_config.alert_configuration,
        v_agent_config.cost_management,
        v_agent_config.performance_metrics,
        v_agent_config.usage_statistics,
        v_agent_config.created_by,
        SESSION_USER,
        v_agent_config.is_shared,
        v_agent_config.share_permissions,
        util.get_record_source()
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'agent_name', v_agent_config.agent_name,
        'status', 'DEPLOYED',
        'deployed_at', CURRENT_TIMESTAMP,
        'deployed_by', SESSION_USER,
        'message', 'Agent is now active and ready to process requests'
    );
END;
$$ LANGUAGE plpgsql;

-- Initialize predefined templates
SELECT ai_agents.create_predefined_templates();

-- Create performance indexes
CREATE INDEX idx_user_agent_h_tenant_hk ON ai_agents.user_agent_h(tenant_hk);
CREATE INDEX idx_user_agent_s_template_hk ON ai_agents.user_agent_s(agent_template_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_user_agent_s_deployment_status ON ai_agents.user_agent_s(deployment_status) WHERE load_end_date IS NULL;
CREATE INDEX idx_user_agent_execution_h_agent_hk ON ai_agents.user_agent_execution_h(user_agent_hk);
CREATE INDEX idx_user_agent_execution_s_timestamp ON ai_agents.user_agent_execution_s(execution_timestamp);
CREATE INDEX idx_user_agent_execution_s_status ON ai_agents.user_agent_execution_s(execution_status) WHERE load_end_date IS NULL;

COMMIT;

-- ==========================================
-- USAGE EXAMPLES
-- ==========================================

/*
-- Example 1: Horse Trainer Creates Health Monitor Agent
SELECT ai_agents.create_user_agent(
    :horse_trainer_tenant_hk,
    'Thunder Daily Health Check',
    (SELECT agent_template_hk FROM ai_agents.agent_template_s 
     WHERE template_name = 'Horse Health Image Analyzer' AND load_end_date IS NULL),
    '{
        "confidence_thresholds": {
            "injury_detection": 0.8,
            "lameness_assessment": 0.7,
            "urgent_findings": 0.95
        },
        "analysis_focus": ["injuries", "lameness", "general_health"],
        "preferred_ai_provider": "openai_vision",
        "output_detail_level": "high",
        "include_recommendations": true,
        "comparison_mode": "historical_baseline"
    }'::jsonb,
    '{
        "data_access": "own_horses_only",
        "retention_days": 365,
        "share_anonymized_insights": false,
        "hipaa_compliance": false
    }'::jsonb,
    '{
        "injury_detected": {
            "threshold": 0.8,
            "notify": ["trainer@barn.com", "vet@clinic.com"],
            "urgency": "high"
        },
        "urgent_findings": {
            "threshold": 0.95,
            "notify": ["owner@email.com", "vet@clinic.com"],
            "urgency": "critical"
        }
    }'::jsonb,
    50.00
);

-- Example 2: Senior Center Creates Voice Wellness Monitor
SELECT ai_agents.create_user_agent(
    :senior_center_tenant_hk,
    'Resident Wellness Voice Monitor',
    (SELECT agent_template_hk FROM ai_agents.agent_template_s 
     WHERE template_name = 'Senior Wellness Voice Monitor' AND load_end_date IS NULL),
    '{
        "hipaa_compliance": {
            "voice_retention_hours": 24,
            "transcript_retention_days": 30,
            "anonymize_transcriptions": true,
            "encryption_level": "AES256"
        },
        "detection_thresholds": {
            "confusion_indicators": 0.7,
            "distress_signals": 0.8,
            "emergency_keywords": 1.0
        },
        "monitoring_schedule": {
            "active_hours": "06:00-22:00",
            "emergency_monitoring": "24/7"
        },
        "preferred_ai_provider": "azure_speech_services"
    }'::jsonb,
    '{
        "data_access": "assigned_residents_only",
        "retention_days": 30,
        "hipaa_compliance": true,
        "voice_data_retention_hours": 24,
        "anonymize_transcriptions": true
    }'::jsonb,
    '{
        "confusion_detected": {
            "threshold": 0.7,
            "notify": ["nurse_station@center.com"],
            "urgency": "medium"
        },
        "distress_signals": {
            "threshold": 0.8,
            "notify": ["emergency@center.com", "family_contact"],
            "urgency": "high"
        },
        "emergency_keywords": {
            "threshold": 1.0,
            "notify": ["911_dispatcher", "emergency@center.com"],
            "urgency": "critical"
        }
    }'::jsonb,
    100.00
);

-- Example 3: Deploy and Test Horse Health Agent
-- First deploy the agent
SELECT ai_agents.deploy_user_agent(
    :horse_health_agent_hk,
    'Initial deployment for Thunder health monitoring'
);

-- Then execute analysis
SELECT ai_agents.execute_user_agent(
    :horse_health_agent_hk,
    '{
        "image_url": "https://secure.onebarn.com/images/thunder_20240615_morning.jpg",
        "horse_id": "THUNDER_001",
        "analysis_type": ["health", "lameness", "injuries"],
        "comparison_baseline": "historical_average",
        "context": "daily_morning_check"
    }'::jsonb,
    'MANUAL'
);
*/ 