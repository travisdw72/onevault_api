-- ==========================================
-- USER-CONFIGURABLE AI AGENT BUILDER SYSTEM - SAFE VERSION WITH JSON FIX
-- ==========================================
-- Safely extends existing Data Vault 2.0 and AI Agents infrastructure
-- Handles existing tables and functions gracefully with proper JSON escaping

BEGIN;

-- Check if required utility functions exist
DO $$ 
BEGIN
    -- Verify util.hash_binary exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_schema = 'util' 
        AND routine_name = 'hash_binary'
    ) THEN
        RAISE EXCEPTION 'Required function util.hash_binary() does not exist. Please run foundation scripts first.';
    END IF;
    
    -- Verify util.current_load_date exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_schema = 'util' 
        AND routine_name = 'current_load_date'
    ) THEN
        RAISE EXCEPTION 'Required function util.current_load_date() does not exist. Please run foundation scripts first.';
    END IF;
    
    -- Verify util.get_record_source exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_schema = 'util' 
        AND routine_name = 'get_record_source'
    ) THEN
        RAISE EXCEPTION 'Required function util.get_record_source() does not exist. Please run foundation scripts first.';
    END IF;
    
    RAISE NOTICE 'All required utility functions verified ✅';
END $$;

-- ==========================================
-- AGENT TEMPLATES (SAFE CREATION)
-- ==========================================

CREATE TABLE IF NOT EXISTS ai_agents.agent_template_h (
    agent_template_hk BYTEA PRIMARY KEY,
    agent_template_bk VARCHAR(255) NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS ai_agents.agent_template_s (
    agent_template_hk BYTEA NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    template_category VARCHAR(100) NOT NULL,        -- IMAGE_AI, TEXT_AI, MULTIMODAL_AI, WORKFLOW_AI
    description TEXT,
    capabilities JSONB NOT NULL,                    -- Array of capability strings
    input_schema JSONB NOT NULL,                    -- Expected input format
    configuration_schema JSONB,                     -- Configurable parameters
    supported_providers JSONB,                      -- AI providers that can run this
    icon_name VARCHAR(100),                         -- UI icon identifier
    complexity_level VARCHAR(20) DEFAULT 'INTERMEDIATE', -- BEGINNER, INTERMEDIATE, ADVANCED
    estimated_cost_per_run DECIMAL(8,4),            -- Estimated cost in USD
    use_cases JSONB,                                -- Dictionary of use case descriptions
    is_active BOOLEAN DEFAULT true,
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (agent_template_hk, load_date)
);

-- Add foreign key constraint for agent_template_s
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'ai_agents' 
        AND table_name = 'agent_template_s'
        AND constraint_name = 'agent_template_s_agent_template_hk_fkey'
    ) THEN
        ALTER TABLE ai_agents.agent_template_s 
        ADD CONSTRAINT agent_template_s_agent_template_hk_fkey 
        FOREIGN KEY (agent_template_hk) REFERENCES ai_agents.agent_template_h(agent_template_hk);
        RAISE NOTICE 'Added foreign key constraint to agent_template_s ✅';
    END IF;
END $$;

-- ==========================================
-- USER AGENT INSTANCES (SAFE CREATION)
-- ==========================================

CREATE TABLE IF NOT EXISTS ai_agents.user_agent_h (
    user_agent_hk BYTEA PRIMARY KEY,
    user_agent_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Add tenant foreign key constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'ai_agents' 
        AND table_name = 'user_agent_h'
        AND constraint_name = 'user_agent_h_tenant_hk_fkey'
    ) THEN
        -- Check if auth.tenant_h exists before adding constraint
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'auth' 
            AND table_name = 'tenant_h'
        ) THEN
            ALTER TABLE ai_agents.user_agent_h 
            ADD CONSTRAINT user_agent_h_tenant_hk_fkey 
            FOREIGN KEY (tenant_hk) REFERENCES auth.tenant_h(tenant_hk);
            RAISE NOTICE 'Added tenant foreign key constraint to user_agent_h ✅';
        ELSE
            RAISE NOTICE 'Warning: auth.tenant_h table not found, skipping foreign key constraint';
        END IF;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS ai_agents.user_agent_s (
    user_agent_hk BYTEA NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    agent_template_hk BYTEA NOT NULL,               -- Reference to template used
    agent_name VARCHAR(200) NOT NULL,
    agent_description TEXT,
    custom_configuration JSONB,                     -- User's custom settings
    deployment_status VARCHAR(20) DEFAULT 'DRAFT',  -- DRAFT, ACTIVE, PAUSED, ARCHIVED
    deployment_date TIMESTAMP WITH TIME ZONE,
    last_execution_date TIMESTAMP WITH TIME ZONE,
    total_executions INTEGER DEFAULT 0,
    total_cost_incurred DECIMAL(10,4) DEFAULT 0.0,
    performance_metrics JSONB,                      -- Success rate, avg time, etc.
    user_notes TEXT,
    notification_settings JSONB,                    -- When/how to notify user
    access_permissions JSONB,                       -- Who can use this agent
    last_modified_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    last_modified_by VARCHAR(100) DEFAULT SESSION_USER,
    is_shared BOOLEAN DEFAULT false,                -- Can other tenants use as template
    share_permissions JSONB,                        -- Sharing configuration
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (user_agent_hk, load_date)
);

-- Add foreign key constraints for user_agent_s
DO $$
BEGIN
    -- Add FK to user_agent_h if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'ai_agents' 
        AND table_name = 'user_agent_s'
        AND constraint_name = 'user_agent_s_user_agent_hk_fkey'
    ) THEN
        ALTER TABLE ai_agents.user_agent_s 
        ADD CONSTRAINT user_agent_s_user_agent_hk_fkey 
        FOREIGN KEY (user_agent_hk) REFERENCES ai_agents.user_agent_h(user_agent_hk);
        RAISE NOTICE 'Added user_agent foreign key constraint to user_agent_s ✅';
    END IF;
    
    -- Add FK to agent_template_h if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'ai_agents' 
        AND table_name = 'user_agent_s'
        AND constraint_name = 'user_agent_s_agent_template_hk_fkey'
    ) THEN
        ALTER TABLE ai_agents.user_agent_s 
        ADD CONSTRAINT user_agent_s_agent_template_hk_fkey 
        FOREIGN KEY (agent_template_hk) REFERENCES ai_agents.agent_template_h(agent_template_hk);
        RAISE NOTICE 'Added template foreign key constraint to user_agent_s ✅';
    END IF;
END $$;

-- ==========================================
-- AGENT EXECUTION TRACKING (SAFE CREATION)
-- ==========================================

CREATE TABLE IF NOT EXISTS ai_agents.user_agent_execution_h (
    execution_hk BYTEA PRIMARY KEY,
    execution_bk VARCHAR(255) NOT NULL,
    user_agent_hk BYTEA NOT NULL,
    tenant_hk BYTEA NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS ai_agents.user_agent_execution_s (
    execution_hk BYTEA NOT NULL,
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
-- FUNCTIONS WITH PROPER JSON HANDLING
-- ==========================================

-- Create predefined templates function (with FIXED JSON escaping)
CREATE OR REPLACE FUNCTION ai_agents.create_predefined_templates()
RETURNS TEXT AS $$
DECLARE
    v_template_hk BYTEA;
    v_template_bk VARCHAR(255);
    v_templates_created INTEGER := 0;
BEGIN
    -- HORSE HEALTH IMAGE ANALYZER TEMPLATE (FIXED JSON)
    v_template_bk := 'HORSE_HEALTH_ANALYZER_V1';
    v_template_hk := util.hash_binary(v_template_bk);
    
    -- Check if template already exists
    IF NOT EXISTS (
        SELECT 1 FROM ai_agents.agent_template_h 
        WHERE agent_template_hk = v_template_hk
    ) THEN
        INSERT INTO ai_agents.agent_template_h VALUES (
            v_template_hk, v_template_bk, util.current_load_date(), util.get_record_source()
        );
        
        INSERT INTO ai_agents.agent_template_s VALUES (
            v_template_hk, util.current_load_date(), NULL,
            util.hash_binary(v_template_bk || 'HORSE_HEALTH'),
            'Horse Health Image Analyzer',
            'IMAGE_AI',
            'Analyzes equine photos for health indicators, injuries, lameness, and body condition scoring',
            '["injury_detection", "lameness_assessment", "body_condition_scoring", "behavioral_analysis", "coat_condition"]',
            '{"image_url": {"type": "string", "required": true, "description": "URL or path to equine image"}, "equine_id": {"type": "string", "required": true, "description": "Unique equine identifier"}, "analysis_type": {"type": "array", "items": {"enum": ["health", "lameness", "body_condition", "injuries"]}, "required": true}, "comparison_baseline": {"type": "string", "required": false, "description": "Historical baseline for comparison"}}',
            '{"confidence_thresholds": {"injury_detection": 0.7, "lameness_assessment": 0.6, "urgent_findings": 0.9}, "analysis_focus": ["general_health", "movement", "visible_injuries"], "output_detail_level": "standard", "include_recommendations": true, "alert_settings": {"enabled": true, "injury_threshold": 0.7, "urgent_threshold": 0.9}}',
            '["openai_vision", "azure_computer_vision", "google_vision_api", "custom_veterinary_models"]',
            'equine-health-icon',
            'BEGINNER',
            0.08,
            '{"equine_trainers": "Daily health monitoring and injury prevention", "veterinarians": "Pre-visit health assessments and documentation", "barn_managers": "Automated health checking for large facilities", "equine_owners": "Regular wellness monitoring and early problem detection"}',
            true,
            SESSION_USER,
            util.get_record_source()
        );
        v_templates_created := v_templates_created + 1;
    END IF;
    
    RETURN 'Successfully processed predefined templates. Created: ' || v_templates_created || ' new templates.';
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- SAFE INDEX CREATION
-- ==========================================

-- Create indexes only if they don't exist
DO $$
BEGIN
    -- Index on user_agent_h.tenant_hk
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'ai_agents' 
        AND tablename = 'user_agent_h' 
        AND indexname = 'idx_user_agent_h_tenant_hk'
    ) THEN
        CREATE INDEX idx_user_agent_h_tenant_hk ON ai_agents.user_agent_h(tenant_hk);
        RAISE NOTICE 'Created index on user_agent_h.tenant_hk ✅';
    END IF;
    
    -- Index on user_agent_s.template_hk
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'ai_agents' 
        AND tablename = 'user_agent_s' 
        AND indexname = 'idx_user_agent_s_template_hk'
    ) THEN
        CREATE INDEX idx_user_agent_s_template_hk ON ai_agents.user_agent_s(agent_template_hk) WHERE load_end_date IS NULL;
        RAISE NOTICE 'Created index on user_agent_s.agent_template_hk ✅';
    END IF;
    
    -- Index on user_agent_s.deployment_status
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'ai_agents' 
        AND tablename = 'user_agent_s' 
        AND indexname = 'idx_user_agent_s_deployment_status'
    ) THEN
        CREATE INDEX idx_user_agent_s_deployment_status ON ai_agents.user_agent_s(deployment_status) WHERE load_end_date IS NULL;
        RAISE NOTICE 'Created index on user_agent_s.deployment_status ✅';
    END IF;
    
    RAISE NOTICE 'All indexes processed successfully ✅';
END $$;

-- Initialize predefined templates (safe)
SELECT ai_agents.create_predefined_templates();

-- Final success message
DO $$
BEGIN
    RAISE NOTICE '🎉 USER AGENT BUILDER SCHEMA safely deployed with FIXED JSON! 🎉';
    RAISE NOTICE 'Tables created/verified: agent_template_h, agent_template_s, user_agent_h, user_agent_s, user_agent_execution_h, user_agent_execution_s';
    RAISE NOTICE 'Functions created: create_predefined_templates() with proper JSON escaping';
    RAISE NOTICE 'Ready for user agent creation and management!';
END $$;

COMMIT; 