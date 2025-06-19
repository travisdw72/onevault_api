-- ==========================================
-- USER-CONFIGURABLE AI AGENT BUILDER SYSTEM
-- ==========================================
-- Extends existing Data Vault 2.0 and AI Agents infrastructure
-- Allows users to create custom AI agents like n8n workflows

BEGIN;

-- ==========================================
-- AGENT TEMPLATE DEFINITIONS
-- ==========================================

-- Agent Template Hub - Predefined agent types
CREATE TABLE ai_agents.agent_template_h (
    agent_template_hk BYTEA PRIMARY KEY,
    agent_template_bk VARCHAR(255) NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Agent Template Configuration
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
    configuration_schema JSONB NOT NULL,            -- JSON schema for configuration
    default_configuration JSONB NOT NULL,           -- Default settings
    supported_ai_models JSONB NOT NULL,             -- Compatible AI models/APIs
    template_icon VARCHAR(100),                     -- UI icon reference
    complexity_level VARCHAR(20) DEFAULT 'BEGINNER', -- BEGINNER, INTERMEDIATE, ADVANCED
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

-- User Agent Configuration
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
    privacy_settings JSONB NOT NULL,                -- What data this agent can access
    performance_metrics JSONB,                      -- Performance tracking
    usage_statistics JSONB,                         -- Usage patterns
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    last_modified_by VARCHAR(100) DEFAULT SESSION_USER,
    is_shared BOOLEAN DEFAULT false,                -- Can other tenants see this as template
    share_permissions JSONB,                        -- Who can use this as template
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (user_agent_hk, load_date)
);

-- ==========================================
-- AGENT WORKFLOW DEFINITIONS
-- ==========================================

-- Workflow Hub - AI agent workflows (like n8n nodes)
CREATE TABLE ai_agents.agent_workflow_h (
    workflow_hk BYTEA PRIMARY KEY,
    workflow_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Workflow Configuration
CREATE TABLE ai_agents.agent_workflow_s (
    workflow_hk BYTEA NOT NULL REFERENCES ai_agents.agent_workflow_h(workflow_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    workflow_name VARCHAR(200) NOT NULL,
    workflow_description TEXT,
    workflow_definition JSONB NOT NULL,             -- Visual workflow definition (nodes, connections)
    trigger_configuration JSONB NOT NULL,           -- What triggers this workflow
    execution_settings JSONB NOT NULL,              -- How to execute this workflow
    error_handling JSONB NOT NULL,                  -- Error handling configuration
    is_active BOOLEAN DEFAULT true,
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (workflow_hk, load_date)
);

-- Workflow Node Hub - Individual workflow steps
CREATE TABLE ai_agents.workflow_node_h (
    node_hk BYTEA PRIMARY KEY,
    node_bk VARCHAR(255) NOT NULL,
    workflow_hk BYTEA NOT NULL REFERENCES ai_agents.agent_workflow_h(workflow_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Workflow Node Configuration
CREATE TABLE ai_agents.workflow_node_s (
    node_hk BYTEA NOT NULL REFERENCES ai_agents.workflow_node_h(node_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    node_name VARCHAR(200) NOT NULL,
    node_type VARCHAR(100) NOT NULL,                -- AI_ANALYSIS, DATA_FETCH, CONDITION, ACTION
    node_configuration JSONB NOT NULL,              -- Node-specific settings
    position_config JSONB NOT NULL,                 -- UI position (x, y coordinates)
    input_connections JSONB,                        -- Connected input nodes
    output_connections JSONB,                       -- Connected output nodes
    execution_order INTEGER,                        -- Order in workflow
    is_required BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (node_hk, load_date)
);

-- ==========================================
-- AI MODEL INTEGRATIONS
-- ==========================================

-- AI Model Provider Hub
CREATE TABLE ai_agents.ai_provider_h (
    provider_hk BYTEA PRIMARY KEY,
    provider_bk VARCHAR(255) NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- AI Model Provider Configuration
CREATE TABLE ai_agents.ai_provider_s (
    provider_hk BYTEA NOT NULL REFERENCES ai_agents.ai_provider_h(provider_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    provider_name VARCHAR(200) NOT NULL,           -- OpenAI, Azure AI, Google AI, Custom
    provider_type VARCHAR(100) NOT NULL,           -- IMAGE, TEXT, VOICE, MULTIMODAL
    api_endpoint VARCHAR(500),
    authentication_method VARCHAR(100),            -- API_KEY, OAUTH, CERTIFICATE
    rate_limits JSONB,                             -- Rate limiting configuration
    pricing_model JSONB,                           -- Cost structure
    capabilities JSONB NOT NULL,                   -- What this provider can do
    supported_formats JSONB,                       -- Supported input/output formats
    quality_metrics JSONB,                         -- Performance metrics
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (provider_hk, load_date)
);

-- ==========================================
-- AGENT EXECUTION TRACKING
-- ==========================================

-- Agent Execution Hub
CREATE TABLE ai_agents.agent_execution_h (
    execution_hk BYTEA PRIMARY KEY,
    execution_bk VARCHAR(255) NOT NULL,
    user_agent_hk BYTEA NOT NULL REFERENCES ai_agents.user_agent_h(user_agent_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Agent Execution Details
CREATE TABLE ai_agents.agent_execution_s (
    execution_hk BYTEA NOT NULL REFERENCES ai_agents.agent_execution_h(execution_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    execution_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    trigger_type VARCHAR(100) NOT NULL,            -- MANUAL, SCHEDULED, EVENT_DRIVEN
    input_data JSONB NOT NULL,                     -- Input provided to agent
    execution_status VARCHAR(20) DEFAULT 'RUNNING', -- RUNNING, COMPLETED, FAILED, CANCELLED
    output_data JSONB,                             -- Agent output/results
    processing_time_ms INTEGER,                    -- Execution duration
    tokens_used INTEGER,                           -- AI API tokens consumed
    cost_incurred DECIMAL(10,4),                   -- Execution cost
    error_details JSONB,                           -- Error information if failed
    confidence_score DECIMAL(5,2),                 -- Agent confidence in results
    user_feedback JSONB,                           -- User feedback on results
    executed_by VARCHAR(100) DEFAULT SESSION_USER,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (execution_hk, load_date)
);

-- ==========================================
-- USER INTERACTION TRACKING
-- ==========================================

-- User Agent Interaction Hub
CREATE TABLE ai_agents.user_interaction_h (
    interaction_hk BYTEA PRIMARY KEY,
    interaction_bk VARCHAR(255) NOT NULL,
    user_agent_hk BYTEA NOT NULL REFERENCES ai_agents.user_agent_h(user_agent_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- User Agent Interaction Details
CREATE TABLE ai_agents.user_interaction_s (
    interaction_hk BYTEA NOT NULL REFERENCES ai_agents.user_interaction_h(interaction_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    interaction_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    interaction_type VARCHAR(100) NOT NULL,        -- CONFIGURATION, EXECUTION, FEEDBACK, SHARING
    interaction_data JSONB NOT NULL,               -- Interaction details
    session_id VARCHAR(255),                       -- User session identifier
    user_satisfaction_score INTEGER,               -- 1-5 rating
    improvement_suggestions TEXT,                   -- User feedback
    feature_requests JSONB,                        -- Requested enhancements
    usage_pattern JSONB,                           -- How user is using the agent
    user_hk BYTEA REFERENCES auth.user_h(user_hk),
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (interaction_hk, load_date)
);

-- ==========================================
-- TEMPLATE MARKETPLACE
-- ==========================================

-- Shared Template Hub
CREATE TABLE ai_agents.shared_template_h (
    shared_template_hk BYTEA PRIMARY KEY,
    shared_template_bk VARCHAR(255) NOT NULL,
    original_user_agent_hk BYTEA NOT NULL REFERENCES ai_agents.user_agent_h(user_agent_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Shared Template Details
CREATE TABLE ai_agents.shared_template_s (
    shared_template_hk BYTEA NOT NULL REFERENCES ai_agents.shared_template_h(shared_template_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    template_category VARCHAR(100) NOT NULL,
    anonymized_configuration JSONB NOT NULL,       -- Configuration with sensitive data removed
    usage_instructions TEXT,
    compatibility_requirements JSONB,              -- System requirements
    performance_benchmarks JSONB,                  -- Expected performance metrics
    user_rating DECIMAL(3,2),                      -- Average user rating
    download_count INTEGER DEFAULT 0,
    is_verified BOOLEAN DEFAULT false,             -- Verified by platform administrators
    verification_notes TEXT,
    shared_by VARCHAR(100) DEFAULT SESSION_USER,
    approval_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (shared_template_hk, load_date)
);

-- ==========================================
-- PREDEFINED AGENT TEMPLATES
-- ==========================================

-- Function to create predefined agent templates
CREATE OR REPLACE FUNCTION ai_agents.create_predefined_templates()
RETURNS TEXT AS $$
DECLARE
    v_template_hk BYTEA;
    v_template_bk VARCHAR(255);
BEGIN
    -- Image Analysis Agent Template (for horse trainers)
    v_template_bk := 'IMAGE_ANALYSIS_TEMPLATE_V1';
    v_template_hk := util.hash_binary(v_template_bk);
    
    INSERT INTO ai_agents.agent_template_h VALUES (
        v_template_hk, v_template_bk, util.current_load_date(), util.get_record_source()
    );
    
    INSERT INTO ai_agents.agent_template_s VALUES (
        v_template_hk, util.current_load_date(), NULL,
        util.hash_binary(v_template_bk || 'IMAGE_ANALYSIS'),
        'Image Analysis Agent',
        'IMAGE_AI',
        'Analyzes images using computer vision and provides insights',
        '["object_detection", "classification", "anomaly_detection", "measurement", "comparison"]',
        '{
            "image_url": {"type": "string", "required": true, "description": "URL or path to image"},
            "analysis_type": {"type": "string", "enum": ["health", "condition", "quality", "safety"], "required": true},
            "comparison_baseline": {"type": "string", "required": false, "description": "Baseline for comparison"}
        }',
        '{
            "confidence_threshold": 0.7,
            "max_image_size_mb": 10,
            "output_format": "detailed",
            "include_annotations": true
        }',
        '["openai_vision", "azure_computer_vision", "google_vision", "custom_models"]',
        'image-analysis-icon',
        'BEGINNER',
        true,
        SESSION_USER,
        util.get_record_source()
    );
    
    -- Voice Analysis Agent Template (for senior centers)
    v_template_bk := 'VOICE_ANALYSIS_TEMPLATE_V1';
    v_template_hk := util.hash_binary(v_template_bk);
    
    INSERT INTO ai_agents.agent_template_h VALUES (
        v_template_hk, v_template_bk, util.current_load_date(), util.get_record_source()
    );
    
    INSERT INTO ai_agents.agent_template_s VALUES (
        v_template_hk, util.current_load_date(), NULL,
        util.hash_binary(v_template_bk || 'VOICE_ANALYSIS'),
        'Voice Analysis Agent',
        'VOICE_AI',
        'Analyzes voice recordings for speech patterns, emotion, and health indicators',
        '["speech_to_text", "emotion_detection", "health_monitoring", "conversation_analysis", "voice_biometrics"]',
        '{
            "audio_url": {"type": "string", "required": true, "description": "URL or path to audio file"},
            "analysis_focus": {"type": "string", "enum": ["health", "emotion", "comprehension", "safety"], "required": true},
            "speaker_profile": {"type": "object", "required": false, "description": "Known speaker characteristics"}
        }',
        '{
            "audio_quality_threshold": 0.6,
            "max_duration_minutes": 30,
            "language": "auto-detect",
            "include_transcription": true,
            "emotion_sensitivity": "medium"
        }',
        '["openai_whisper", "azure_speech", "google_speech", "custom_voice_models"]',
        'voice-analysis-icon',
        'INTERMEDIATE',
        true,
        SESSION_USER,
        util.get_record_source()
    );
    
    -- Sensor Data Analysis Agent Template
    v_template_bk := 'SENSOR_DATA_TEMPLATE_V1';
    v_template_hk := util.hash_binary(v_template_bk);
    
    INSERT INTO ai_agents.agent_template_h VALUES (
        v_template_hk, v_template_bk, util.current_load_date(), util.get_record_source()
    );
    
    INSERT INTO ai_agents.agent_template_s VALUES (
        v_template_hk, util.current_load_date(), NULL,
        util.hash_binary(v_template_bk || 'SENSOR_DATA'),
        'Sensor Data Analysis Agent',
        'SENSOR_AI',
        'Analyzes IoT sensor data for patterns, anomalies, and predictions',
        '["time_series_analysis", "anomaly_detection", "predictive_maintenance", "environmental_monitoring", "trend_analysis"]',
        '{
            "sensor_data": {"type": "array", "required": true, "description": "Array of sensor readings"},
            "sensor_type": {"type": "string", "enum": ["temperature", "humidity", "motion", "pressure", "custom"], "required": true},
            "analysis_period": {"type": "string", "required": true, "description": "Time period for analysis"}
        }',
        '{
            "anomaly_threshold": 2.0,
            "prediction_horizon_hours": 24,
            "sampling_interval": "1_minute",
            "include_visualizations": true
        }',
        '["custom_ml_models", "time_series_analytics", "statistical_analysis"]',
        'sensor-analysis-icon',
        'ADVANCED',
        true,
        SESSION_USER,
        util.get_record_source()
    );
    
    RETURN 'Created 3 predefined agent templates';
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- AGENT BUILDER FUNCTIONS
-- ==========================================

-- Function to create a new user agent from template
CREATE OR REPLACE FUNCTION ai_agents.create_user_agent(
    p_tenant_hk BYTEA,
    p_agent_name VARCHAR(200),
    p_template_hk BYTEA,
    p_user_configuration JSONB,
    p_privacy_settings JSONB DEFAULT '{"data_access": "own_tenant_only"}'::jsonb
) RETURNS BYTEA AS $$
DECLARE
    v_user_agent_hk BYTEA;
    v_user_agent_bk VARCHAR(255);
    v_template_config RECORD;
BEGIN
    -- Validate template exists
    SELECT * INTO v_template_config
    FROM ai_agents.agent_template_s 
    WHERE agent_template_hk = p_template_hk 
    AND load_end_date IS NULL;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Agent template not found';
    END IF;
    
    -- Generate user agent identifiers
    v_user_agent_bk := 'USER_AGENT_' || p_agent_name || '_' || 
                       encode(p_tenant_hk, 'hex')::text || '_' || 
                       to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    v_user_agent_hk := util.hash_binary(v_user_agent_bk);
    
    -- Validate user configuration against template schema
    -- (This would include JSON schema validation in a real implementation)
    
    -- Create user agent hub record
    INSERT INTO ai_agents.user_agent_h VALUES (
        v_user_agent_hk, v_user_agent_bk, p_tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    -- Create user agent satellite record
    INSERT INTO ai_agents.user_agent_s VALUES (
        v_user_agent_hk, util.current_load_date(), NULL,
        util.hash_binary(v_user_agent_bk || p_agent_name),
        p_agent_name,
        'User-configured ' || v_template_config.template_name,
        p_template_hk,
        p_user_configuration,
        'DRAFT',
        p_privacy_settings,
        '{"executions": 0, "success_rate": 0}'::jsonb,
        '{"total_executions": 0, "total_runtime_ms": 0}'::jsonb,
        SESSION_USER,
        SESSION_USER,
        false,
        '{}'::jsonb,
        util.get_record_source()
    );
    
    RETURN v_user_agent_hk;
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
    v_execution_time INTEGER;
    v_result JSONB;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    -- Get agent configuration
    SELECT ua.*, uas.* INTO v_agent_config
    FROM ai_agents.user_agent_h ua
    JOIN ai_agents.user_agent_s uas ON ua.user_agent_hk = uas.user_agent_hk
    WHERE ua.user_agent_hk = p_user_agent_hk
    AND uas.load_end_date IS NULL;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User agent not found';
    END IF;
    
    -- Get template configuration
    SELECT * INTO v_template_config
    FROM ai_agents.agent_template_s
    WHERE agent_template_hk = v_agent_config.agent_template_hk
    AND load_end_date IS NULL;
    
    -- Generate execution identifiers
    v_execution_bk := 'EXEC_' || encode(p_user_agent_hk, 'hex') || '_' || 
                      to_char(v_start_time, 'YYYYMMDD_HH24MISS_US');
    v_execution_hk := util.hash_binary(v_execution_bk);
    
    -- Create execution hub record
    INSERT INTO ai_agents.agent_execution_h VALUES (
        v_execution_hk, v_execution_bk, p_user_agent_hk, v_agent_config.tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    -- Simulate agent execution (in real implementation, this would call actual AI services)
    BEGIN
        -- This is where the actual AI processing would happen
        -- Based on the template type and user configuration
        
        CASE v_template_config.template_category
            WHEN 'IMAGE_AI' THEN
                v_result := jsonb_build_object(
                    'analysis_type', 'image_analysis',
                    'objects_detected', '[{"type": "example", "confidence": 0.95}]',
                    'summary', 'Image analysis completed successfully'
                );
            WHEN 'VOICE_AI' THEN
                v_result := jsonb_build_object(
                    'analysis_type', 'voice_analysis',
                    'transcription', 'Example transcription text',
                    'emotion_detected', 'calm',
                    'confidence', 0.87
                );
            WHEN 'SENSOR_AI' THEN
                v_result := jsonb_build_object(
                    'analysis_type', 'sensor_analysis',
                    'anomalies_detected', 0,
                    'trend', 'stable',
                    'predictions', '[{"time": "1h", "value": 23.5}]'
                );
            ELSE
                v_result := jsonb_build_object(
                    'analysis_type', 'generic',
                    'status', 'completed',
                    'message', 'Analysis completed using generic template'
                );
        END CASE;
        
        v_end_time := CURRENT_TIMESTAMP;
        v_execution_time := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
        
        -- Create execution satellite record
        INSERT INTO ai_agents.agent_execution_s VALUES (
            v_execution_hk, util.current_load_date(), NULL,
            util.hash_binary(v_execution_bk || 'COMPLETED'),
            v_start_time,
            p_trigger_type,
            p_input_data,
            'COMPLETED',
            v_result,
            v_execution_time,
            100, -- tokens_used (simulated)
            0.05, -- cost_incurred (simulated)
            NULL, -- no errors
            0.90, -- confidence_score
            NULL, -- user_feedback (to be added later)
            SESSION_USER,
            util.get_record_source()
        );
        
    EXCEPTION WHEN OTHERS THEN
        v_end_time := CURRENT_TIMESTAMP;
        v_execution_time := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
        
        -- Log failed execution
        INSERT INTO ai_agents.agent_execution_s VALUES (
            v_execution_hk, util.current_load_date(), NULL,
            util.hash_binary(v_execution_bk || 'FAILED'),
            v_start_time,
            p_trigger_type,
            p_input_data,
            'FAILED',
            NULL,
            v_execution_time,
            0,
            0,
            jsonb_build_object('error_message', SQLERRM, 'error_code', SQLSTATE),
            0,
            NULL,
            SESSION_USER,
            util.get_record_source()
        );
        
        RAISE;
    END;
    
    RETURN jsonb_build_object(
        'execution_id', encode(v_execution_hk, 'hex'),
        'status', 'COMPLETED',
        'execution_time_ms', v_execution_time,
        'result', v_result
    );
END;
$$ LANGUAGE plpgsql;

-- Initialize predefined templates
SELECT ai_agents.create_predefined_templates();

-- Create indexes for performance
CREATE INDEX idx_user_agent_h_tenant_hk ON ai_agents.user_agent_h(tenant_hk);
CREATE INDEX idx_user_agent_s_template_hk ON ai_agents.user_agent_s(agent_template_hk);
CREATE INDEX idx_agent_execution_h_user_agent_hk ON ai_agents.agent_execution_h(user_agent_hk);
CREATE INDEX idx_agent_execution_s_status ON ai_agents.agent_execution_s(execution_status);
CREATE INDEX idx_agent_execution_s_timestamp ON ai_agents.agent_execution_s(execution_timestamp);

COMMIT;

-- ==========================================
-- USAGE EXAMPLES
-- ==========================================

/*
-- Example 1: Horse Trainer Creates Image Analysis Agent
SELECT ai_agents.create_user_agent(
    :horse_trainer_tenant_hk,
    'Horse Health Monitor',
    (SELECT agent_template_hk FROM ai_agents.agent_template_s WHERE template_name = 'Image Analysis Agent' AND load_end_date IS NULL),
    '{
        "confidence_threshold": 0.8,
        "analysis_focus": "health_assessment",
        "output_detail_level": "high",
        "alert_thresholds": {
            "injury_detected": 0.7,
            "lameness_indicators": 0.6
        },
        "comparison_mode": "historical_baseline"
    }'::jsonb,
    '{
        "data_access": "own_horses_only",
        "share_anonymized_insights": false,
        "retention_period_days": 365
    }'::jsonb
);

-- Example 2: Senior Center Creates Voice Analysis Agent  
SELECT ai_agents.create_user_agent(
    :senior_center_tenant_hk,
    'Wellness Check Voice Monitor',
    (SELECT agent_template_hk FROM ai_agents.agent_template_s WHERE template_name = 'Voice Analysis Agent' AND load_end_date IS NULL),
    '{
        "emotion_sensitivity": "high",
        "health_indicators": ["confusion", "distress", "fatigue"],
        "alert_contacts": ["nurse@seniorcenter.com"],
        "privacy_mode": "maximum",
        "analysis_schedule": "daily_checkins"
    }'::jsonb,
    '{
        "data_access": "assigned_residents_only",
        "hipaa_compliance_mode": true,
        "voice_data_retention_hours": 24,
        "anonymize_transcriptions": true
    }'::jsonb
);

-- Example 3: Execute the Horse Health Monitor
SELECT ai_agents.execute_user_agent(
    :horse_health_monitor_agent_hk,
    '{
        "image_url": "https://secure.onebarn.com/images/horse_123_20240615.jpg",
        "analysis_type": "health",
        "horse_id": "HORSE_123",
        "comparison_baseline": "historical_average"
    }'::jsonb,
    'MANUAL'
);
*/ 