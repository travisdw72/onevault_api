-- ==========================================
-- ZERO TRUST AI AGENTS - STEP 4
-- Create Agent Reasoning & Communication Tracking
-- Track all AI reasoning requests and agent interactions
-- ==========================================

BEGIN;

-- ==========================================
-- AGENT REASONING & INFERENCE TRACKING
-- ==========================================

-- Agent Reasoning Request Hub
CREATE TABLE ai_agents.reasoning_request_h (
    reasoning_hk BYTEA PRIMARY KEY,               -- SHA-256(session_hk + request_timestamp + input_hash)
    reasoning_bk VARCHAR(255) NOT NULL,          -- Request business key
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Agent Reasoning Details Satellite
CREATE TABLE ai_agents.reasoning_details_s (
    reasoning_hk BYTEA NOT NULL REFERENCES ai_agents.reasoning_request_h(reasoning_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Request Context
    session_hk BYTEA NOT NULL REFERENCES ai_agents.agent_session_h(session_hk),
    agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    domain_hk BYTEA NOT NULL REFERENCES ai_agents.knowledge_domain_h(domain_hk),
    
    -- Input Data (Encrypted)
    request_type VARCHAR(100) NOT NULL,           -- 'diagnosis', 'prediction', 'analysis'
    input_data_encrypted BYTEA NOT NULL,          -- Encrypted input data
    input_data_hash BYTEA NOT NULL,               -- Hash for integrity verification
    
    -- Reasoning Process
    reasoning_steps JSONB NOT NULL,               -- Step-by-step reasoning process
    model_version VARCHAR(50) NOT NULL,
    processing_time_ms INTEGER NOT NULL,
    memory_usage_mb DECIMAL(10,2),
    
    -- Output Results (Encrypted)
    output_data_encrypted BYTEA NOT NULL,         -- Encrypted output
    output_data_hash BYTEA NOT NULL,              -- Hash for integrity
    confidence_score DECIMAL(5,4) NOT NULL,
    reasoning_quality VARCHAR(50) NOT NULL,       -- 'excellent', 'good', 'fair', 'poor'
    
    -- Learning Integration
    used_for_learning BOOLEAN DEFAULT false,
    learning_feedback_score DECIMAL(5,4),
    improved_model BOOLEAN DEFAULT false,
    
    -- Security & Compliance
    security_classification VARCHAR(50) NOT NULL, -- 'public', 'internal', 'confidential', 'restricted'
    audit_trail JSONB NOT NULL,                   -- Complete audit trail
    compliance_validated BOOLEAN DEFAULT false,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (reasoning_hk, load_date)
);

-- ==========================================
-- AGENT INTERACTION & COMMUNICATION
-- ==========================================

-- Agent-to-Agent Communication Hub (Zero Trust Only)
CREATE TABLE ai_agents.agent_communication_h (
    communication_hk BYTEA PRIMARY KEY,           -- SHA-256(from_agent + to_agent + timestamp)
    communication_bk VARCHAR(255) NOT NULL,      -- Communication business key
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Agent Communication Details Satellite
CREATE TABLE ai_agents.agent_communication_s (
    communication_hk BYTEA NOT NULL REFERENCES ai_agents.agent_communication_h(communication_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Communication Parties
    from_agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    to_agent_hk BYTEA REFERENCES ai_agents.agent_h(agent_hk), -- NULL for gateway communication
    gateway_processed BOOLEAN NOT NULL DEFAULT true,         -- ALL communication via gateway
    
    -- Message Details (NO KNOWLEDGE SHARING)
    message_type VARCHAR(100) NOT NULL,           -- 'coordination', 'result_sharing', 'status_update'
    message_content_encrypted BYTEA NOT NULL,     -- Encrypted message (NO raw domain knowledge)
    message_hash BYTEA NOT NULL,                  -- Integrity verification
    
    -- Zero Trust Verification
    sender_verified BOOLEAN NOT NULL DEFAULT false,
    recipient_verified BOOLEAN NOT NULL DEFAULT false,
    gateway_verified BOOLEAN NOT NULL DEFAULT false,
    message_encrypted BOOLEAN NOT NULL DEFAULT true,
    
    -- Communication Restrictions
    knowledge_shared BOOLEAN NOT NULL DEFAULT false, -- MUST remain false
    cross_domain_data BOOLEAN NOT NULL DEFAULT false, -- STRICTLY forbidden
    sanitized_output_only BOOLEAN NOT NULL DEFAULT true, -- Only processed results
    
    -- Audit & Compliance
    communication_purpose TEXT NOT NULL,
    approved_by VARCHAR(100),
    approval_timestamp TIMESTAMP WITH TIME ZONE,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (communication_hk, load_date)
);

-- ==========================================
-- LEARNING AND MODEL IMPROVEMENT TRACKING
-- ==========================================

-- AI Learning Event Hub
CREATE TABLE ai_agents.learning_event_h (
    learning_hk BYTEA PRIMARY KEY,                -- SHA-256(agent_hk + learning_timestamp + data_hash)
    learning_bk VARCHAR(255) NOT NULL,           -- Learning event business key
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- AI Learning Details Satellite
CREATE TABLE ai_agents.learning_details_s (
    learning_hk BYTEA NOT NULL REFERENCES ai_agents.learning_event_h(learning_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Learning Context
    agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    domain_hk BYTEA NOT NULL REFERENCES ai_agents.knowledge_domain_h(domain_hk),
    reasoning_hk BYTEA REFERENCES ai_agents.reasoning_request_h(reasoning_hk),
    
    -- Learning Data (Domain Isolated)
    learning_type VARCHAR(100) NOT NULL,          -- 'supervised', 'reinforcement', 'feedback'
    training_data_encrypted BYTEA NOT NULL,       -- Encrypted training data
    training_data_hash BYTEA NOT NULL,            -- Integrity verification
    
    -- Model Updates
    model_before_version VARCHAR(50) NOT NULL,
    model_after_version VARCHAR(50),
    performance_improvement DECIMAL(5,4),         -- Percentage improvement
    learning_success BOOLEAN DEFAULT false,
    
    -- Domain Validation (CRITICAL)
    domain_validated BOOLEAN NOT NULL DEFAULT false,
    cross_domain_check BOOLEAN NOT NULL DEFAULT true, -- Always verify no cross-contamination
    forbidden_data_detected BOOLEAN DEFAULT false,
    
    -- Learning Metrics
    training_accuracy DECIMAL(5,4),
    validation_accuracy DECIMAL(5,4),
    test_accuracy DECIMAL(5,4),
    convergence_time_ms INTEGER,
    
    -- Compliance & Audit
    learning_approved_by VARCHAR(100),
    approval_timestamp TIMESTAMP WITH TIME ZONE,
    audit_trail JSONB NOT NULL,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (learning_hk, load_date)
);

-- ==========================================
-- THREAT DETECTION AND SECURITY MONITORING
-- ==========================================

-- Agent Security Event Hub
CREATE TABLE ai_agents.security_event_h (
    security_event_hk BYTEA PRIMARY KEY,          -- SHA-256(agent_hk + event_timestamp + event_type)
    security_event_bk VARCHAR(255) NOT NULL,     -- Security event business key
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Agent Security Event Details Satellite
CREATE TABLE ai_agents.security_event_s (
    security_event_hk BYTEA NOT NULL REFERENCES ai_agents.security_event_h(security_event_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Event Context
    agent_hk BYTEA REFERENCES ai_agents.agent_h(agent_hk),
    session_hk BYTEA REFERENCES ai_agents.agent_session_h(session_hk),
    
    -- Security Event Details
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    event_type VARCHAR(100) NOT NULL,             -- 'unauthorized_access', 'anomalous_behavior', 'policy_violation'
    event_severity VARCHAR(50) NOT NULL,          -- 'low', 'medium', 'high', 'critical'
    event_description TEXT NOT NULL,
    
    -- Threat Indicators
    threat_indicators JSONB,
    behavioral_anomalies JSONB,
    risk_score DECIMAL(5,4),
    
    -- Response Actions
    automated_response TEXT[],
    manual_intervention_required BOOLEAN DEFAULT false,
    incident_escalated BOOLEAN DEFAULT false,
    
    -- Investigation Details
    investigated_by VARCHAR(100),
    investigation_status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'investigating', 'resolved', 'false_positive'
    resolution_notes TEXT,
    resolution_timestamp TIMESTAMP WITH TIME ZONE,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (security_event_hk, load_date)
);

-- Create indexes for performance
CREATE INDEX idx_reasoning_request_h_tenant_hk ON ai_agents.reasoning_request_h(tenant_hk);
CREATE INDEX idx_reasoning_details_s_agent_hk ON ai_agents.reasoning_details_s(agent_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_reasoning_details_s_session_hk ON ai_agents.reasoning_details_s(session_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_reasoning_details_s_request_type ON ai_agents.reasoning_details_s(request_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_agent_communication_h_tenant_hk ON ai_agents.agent_communication_h(tenant_hk);
CREATE INDEX idx_agent_communication_s_from_agent ON ai_agents.agent_communication_s(from_agent_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_agent_communication_s_message_type ON ai_agents.agent_communication_s(message_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_learning_event_h_tenant_hk ON ai_agents.learning_event_h(tenant_hk);
CREATE INDEX idx_learning_details_s_agent_hk ON ai_agents.learning_details_s(agent_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_learning_details_s_learning_type ON ai_agents.learning_details_s(learning_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_security_event_h_tenant_hk ON ai_agents.security_event_h(tenant_hk);
CREATE INDEX idx_security_event_s_agent_hk ON ai_agents.security_event_s(agent_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_security_event_s_event_type ON ai_agents.security_event_s(event_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_security_event_s_severity ON ai_agents.security_event_s(event_severity) WHERE load_end_date IS NULL;

-- Comments
COMMENT ON TABLE ai_agents.reasoning_request_h IS 'Hub table for AI reasoning requests with comprehensive tracking';
COMMENT ON TABLE ai_agents.reasoning_details_s IS 'Detailed tracking of AI reasoning processes including input/output and performance metrics';
COMMENT ON TABLE ai_agents.agent_communication_h IS 'Hub table for agent-to-agent communication (zero trust only)';
COMMENT ON TABLE ai_agents.agent_communication_s IS 'Communication details with strict knowledge isolation enforcement';
COMMENT ON TABLE ai_agents.learning_event_h IS 'Hub table for AI learning events and model improvements';
COMMENT ON TABLE ai_agents.learning_details_s IS 'Learning event details with domain validation and performance tracking';
COMMENT ON TABLE ai_agents.security_event_h IS 'Hub table for security events and threat detection';
COMMENT ON TABLE ai_agents.security_event_s IS 'Security event details with threat analysis and response tracking';

COMMIT; 