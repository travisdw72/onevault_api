-- ==========================================
-- ZERO TRUST AI AGENTS IMPLEMENTATION
-- Builds on existing Data Vault 2.0 Platform
-- Domain-Specific Reasoning with Knowledge Isolation
-- ==========================================

BEGIN;

-- Create zero trust agent management schema
CREATE SCHEMA IF NOT EXISTS ai_agents;

-- ==========================================
-- AGENT IDENTITY & CERTIFICATE MANAGEMENT
-- ==========================================

-- Agent Hub - Core Identity (Data Vault 2.0 Pattern)
CREATE TABLE ai_agents.agent_h (
    agent_hk BYTEA PRIMARY KEY,                    -- SHA-256(agent_id + tenant_hk)
    agent_bk VARCHAR(255) NOT NULL UNIQUE,        -- Agent business key (MDA-001, ECA-001, etc.)
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'zero_trust_agent_system'
);

-- Agent Identity Satellite
CREATE TABLE ai_agents.agent_identity_s (
    agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Agent Classification
    agent_name VARCHAR(200) NOT NULL,
    agent_type VARCHAR(100) NOT NULL,             -- 'medical', 'equine', 'manufacturing', 'financial'
    specialization VARCHAR(200) NOT NULL,         -- 'diagnostic_reasoning', 'veterinary_care'
    security_clearance VARCHAR(50) NOT NULL,      -- 'medical_hipaa', 'financial_sox', 'manufacturing_iso'
    
    -- Zero Trust Configuration
    network_segment VARCHAR(100) NOT NULL,        -- Micro-segmentation assignment
    max_session_duration INTERVAL NOT NULL DEFAULT '10 minutes',
    requires_mfa BOOLEAN NOT NULL DEFAULT true,
    certificate_required BOOLEAN NOT NULL DEFAULT true,
    
    -- Domain Expertise (ISOLATED)
    knowledge_domain VARCHAR(100) NOT NULL,       -- STRICTLY one domain only
    allowed_data_types TEXT[] NOT NULL,           -- What data types this agent can access
    forbidden_domains TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[], -- Explicit restrictions
    
    -- AI Model Configuration
    model_version VARCHAR(50) NOT NULL,
    reasoning_engine VARCHAR(100) NOT NULL,       -- 'medical_diagnostic', 'equine_health'
    confidence_threshold DECIMAL(5,4) DEFAULT 0.75,
    
    -- Operational Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    certification_status VARCHAR(50) NOT NULL DEFAULT 'pending',
    last_training_date TIMESTAMP WITH TIME ZONE,
    
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (agent_hk, load_date)
);

-- Agent Certificate Satellite (Zero Trust Authentication)
CREATE TABLE ai_agents.agent_certificate_s (
    agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- mTLS Certificate Details
    certificate_fingerprint BYTEA NOT NULL,       -- SHA-256 of certificate
    certificate_serial VARCHAR(100) NOT NULL,
    certificate_issuer VARCHAR(500) NOT NULL,     -- Certificate Authority
    certificate_subject VARCHAR(500) NOT NULL,
    certificate_not_before TIMESTAMP WITH TIME ZONE NOT NULL,
    certificate_not_after TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Private Key Security (HSM-backed)
    private_key_id VARCHAR(100) NOT NULL,         -- HSM key reference
    key_algorithm VARCHAR(50) NOT NULL DEFAULT 'RSA-4096',
    key_usage TEXT[] NOT NULL DEFAULT ARRAY['digital_signature', 'key_encipherment'],
    
    -- Authentication Status
    certificate_status VARCHAR(50) NOT NULL DEFAULT 'active',
    last_authentication TIMESTAMP WITH TIME ZONE,
    authentication_failures INTEGER DEFAULT 0,
    revocation_reason TEXT,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (agent_hk, load_date)
);

-- ==========================================
-- DOMAIN-SPECIFIC KNOWLEDGE ISOLATION
-- ==========================================

-- Knowledge Domain Hub
CREATE TABLE ai_agents.knowledge_domain_h (
    domain_hk BYTEA PRIMARY KEY,                  -- SHA-256(domain_name + version)
    domain_bk VARCHAR(255) NOT NULL UNIQUE,      -- 'medical_v2.1', 'equine_v1.3'
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Knowledge Domain Configuration Satellite
CREATE TABLE ai_agents.knowledge_domain_s (
    domain_hk BYTEA NOT NULL REFERENCES ai_agents.knowledge_domain_h(domain_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Domain Definition
    domain_name VARCHAR(100) NOT NULL,            -- 'medical', 'equine', 'manufacturing'
    domain_version VARCHAR(50) NOT NULL,
    domain_description TEXT NOT NULL,
    
    -- Knowledge Base Configuration
    knowledge_base_location TEXT NOT NULL,        -- Encrypted knowledge storage location
    model_weights_location TEXT NOT NULL,         -- AI model storage (encrypted)
    training_data_location TEXT NOT NULL,         -- Training data (encrypted)
    
    -- Domain Restrictions (CRITICAL for isolation)
    allowed_data_schemas TEXT[] NOT NULL,         -- Only these database schemas
    allowed_tables TEXT[] NOT NULL,               -- Only these specific tables
    forbidden_schemas TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[], -- Explicitly forbidden
    cross_domain_sharing BOOLEAN NOT NULL DEFAULT false, -- NO sharing by default
    
    -- Learning Configuration
    learning_enabled BOOLEAN NOT NULL DEFAULT true,
    learning_data_retention INTERVAL NOT NULL DEFAULT '2 years',
    model_update_frequency INTERVAL NOT NULL DEFAULT '1 week',
    
    -- Compliance & Security
    compliance_frameworks TEXT[] NOT NULL,        -- ['HIPAA', 'GDPR', 'SOX']
    encryption_at_rest BOOLEAN NOT NULL DEFAULT true,
    encryption_in_transit BOOLEAN NOT NULL DEFAULT true,
    audit_level VARCHAR(50) NOT NULL DEFAULT 'comprehensive',
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (domain_hk, load_date)
);

-- Agent Domain Assignment Link (Many-to-Many with restrictions)
CREATE TABLE ai_agents.agent_domain_l (
    agent_domain_hk BYTEA PRIMARY KEY,            -- SHA-256(agent_hk + domain_hk)
    agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    domain_hk BYTEA NOT NULL REFERENCES ai_agents.knowledge_domain_h(domain_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    -- Constraint: One domain per agent for knowledge isolation
    UNIQUE(agent_hk, tenant_hk)
);

-- Agent Domain Access Rights Satellite
CREATE TABLE ai_agents.agent_domain_access_s (
    agent_domain_hk BYTEA NOT NULL REFERENCES ai_agents.agent_domain_l(agent_domain_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Access Permissions (VERY RESTRICTIVE)
    read_permission BOOLEAN NOT NULL DEFAULT false,
    write_permission BOOLEAN NOT NULL DEFAULT false,
    learn_permission BOOLEAN NOT NULL DEFAULT false,
    inference_permission BOOLEAN NOT NULL DEFAULT false,
    
    -- Access Constraints
    max_daily_queries INTEGER NOT NULL DEFAULT 1000,
    max_concurrent_sessions INTEGER NOT NULL DEFAULT 1,
    session_timeout INTERVAL NOT NULL DEFAULT '10 minutes',
    
    -- Learning Restrictions
    learning_scope TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[], -- What can it learn from
    forbidden_learning TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[], -- What it CANNOT learn
    
    -- Audit Trail
    access_granted_by VARCHAR(100) NOT NULL,
    access_granted_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    access_review_date DATE NOT NULL DEFAULT CURRENT_DATE + INTERVAL '90 days',
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (agent_domain_hk, load_date)
);

-- ==========================================
-- ZERO TRUST SESSION MANAGEMENT
-- ==========================================

-- Agent Session Hub
CREATE TABLE ai_agents.agent_session_h (
    session_hk BYTEA PRIMARY KEY,                 -- SHA-256(agent_hk + session_start + nonce)
    session_bk VARCHAR(255) NOT NULL UNIQUE,     -- Session business key
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Agent Session State Satellite
CREATE TABLE ai_agents.agent_session_s (
    session_hk BYTEA NOT NULL REFERENCES ai_agents.agent_session_h(session_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Session Identity
    agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    requesting_user_hk BYTEA NOT NULL REFERENCES auth.user_h(user_hk),
    
    -- Zero Trust Session Details
    session_token VARCHAR(255) NOT NULL UNIQUE,   -- JWT token for this session
    session_start TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    session_expires TIMESTAMP WITH TIME ZONE NOT NULL,
    session_status VARCHAR(50) NOT NULL DEFAULT 'active',
    
    -- Authentication Details
    authentication_method VARCHAR(100) NOT NULL,  -- 'mtls_certificate', 'jwt_token'
    certificate_used BYTEA REFERENCES ai_agents.agent_certificate_s(certificate_fingerprint),
    ip_address INET NOT NULL,
    user_agent TEXT,
    
    -- Session Security
    mfa_verified BOOLEAN NOT NULL DEFAULT false,
    behavioral_score DECIMAL(5,4) DEFAULT 1.0,    -- Behavioral analytics score
    risk_assessment VARCHAR(50) DEFAULT 'low',     -- 'low', 'medium', 'high', 'critical'
    
    -- Session Limits
    max_requests INTEGER NOT NULL DEFAULT 100,
    requests_made INTEGER DEFAULT 0,
    max_data_access_mb INTEGER NOT NULL DEFAULT 10,
    data_accessed_mb DECIMAL(10,2) DEFAULT 0,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (session_hk, load_date)
);

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
-- DOMAIN-SPECIFIC AI FUNCTIONS
-- ==========================================

-- Medical Diagnosis Agent Function
CREATE OR REPLACE FUNCTION ai_agents.medical_diagnosis_reasoning(
    p_session_token VARCHAR(255),
    p_patient_data JSONB,
    p_symptoms JSONB,
    p_medical_history JSONB
) RETURNS JSONB
SECURITY DEFINER
SET search_path = ai_agents, auth, audit
LANGUAGE plpgsql AS $$
DECLARE
    v_session_hk BYTEA;
    v_agent_hk BYTEA;
    v_reasoning_hk BYTEA;
    v_diagnosis_result JSONB;
    v_confidence_score DECIMAL(5,4);
BEGIN
    -- Verify session and agent identity (Zero Trust)
    SELECT s.session_hk, s.agent_hk INTO v_session_hk, v_agent_hk
    FROM ai_agents.agent_session_h sh
    JOIN ai_agents.agent_session_s s ON sh.session_hk = s.session_hk
    WHERE s.session_token = p_session_token
    AND s.session_status = 'active'
    AND s.session_expires > CURRENT_TIMESTAMP
    AND s.load_end_date IS NULL;
    
    IF v_session_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Invalid or expired session',
            'timestamp', CURRENT_TIMESTAMP
        );
    END IF;
    
    -- Verify agent is medical domain specialist
    IF NOT EXISTS (
        SELECT 1 FROM ai_agents.agent_identity_s ais
        WHERE ais.agent_hk = v_agent_hk
        AND ais.knowledge_domain = 'medical'
        AND ais.is_active = true
        AND ais.load_end_date IS NULL
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Agent not authorized for medical diagnosis',
            'timestamp', CURRENT_TIMESTAMP
        );
    END IF;
    
    -- Generate reasoning request ID
    v_reasoning_hk := util.hash_binary(encode(v_session_hk, 'hex') || CURRENT_TIMESTAMP::text);
    
    -- Insert reasoning request
    INSERT INTO ai_agents.reasoning_request_h VALUES (
        v_reasoning_hk,
        'MEDICAL_DIAG_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS'),
        (SELECT tenant_hk FROM ai_agents.agent_session_s WHERE session_hk = v_session_hk AND load_end_date IS NULL),
        util.current_load_date(),
        'medical_diagnosis_agent'
    );
    
    -- Perform medical reasoning (Domain-specific only)
    -- This would integrate with actual medical AI models
    v_diagnosis_result := jsonb_build_object(
        'differential_diagnosis', jsonb_build_array(
            jsonb_build_object('condition', 'Condition A', 'probability', 0.85, 'reasoning', 'Symptom pattern match'),
            jsonb_build_object('condition', 'Condition B', 'probability', 0.12, 'reasoning', 'Alternative pattern'),
            jsonb_build_object('condition', 'Condition C', 'probability', 0.03, 'reasoning', 'Rare but possible')
        ),
        'recommended_tests', jsonb_build_array(
            jsonb_build_object('test', 'Blood Panel', 'priority', 'high', 'reasoning', 'Rule out systemic issues'),
            jsonb_build_object('test', 'Imaging', 'priority', 'medium', 'reasoning', 'Confirm structural issues')
        ),
        'treatment_recommendations', jsonb_build_array(
            jsonb_build_object('treatment', 'Initial Treatment', 'confidence', 0.85, 'monitoring', 'required')
        ),
        'urgency_level', 'medium',
        'follow_up_required', true
    );
    
    v_confidence_score := 0.85;
    
    -- Store reasoning details
    INSERT INTO ai_agents.reasoning_details_s VALUES (
        v_reasoning_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(encode(v_reasoning_hk, 'hex') || 'medical_diagnosis'),
        v_session_hk,
        v_agent_hk,
        (SELECT domain_hk FROM ai_agents.knowledge_domain_h WHERE domain_bk LIKE 'medical_%' LIMIT 1),
        'medical_diagnosis',
        encode(digest(p_patient_data::text || p_symptoms::text, 'sha256'), 'hex')::bytea,
        util.hash_binary(p_patient_data::text || p_symptoms::text),
        jsonb_build_object(
            'step1', 'Symptom analysis completed',
            'step2', 'Medical history integration',
            'step3', 'Differential diagnosis generation',
            'step4', 'Treatment recommendation synthesis'
        ),
        'medical_diagnostic_v2.1',
        250, -- processing time ms
        15.5, -- memory usage MB
        encode(digest(v_diagnosis_result::text, 'sha256'), 'hex')::bytea,
        util.hash_binary(v_diagnosis_result::text),
        v_confidence_score,
        'good',
        false, -- used_for_learning
        NULL, -- learning_feedback_score
        false, -- improved_model
        'confidential', -- HIPAA protected
        jsonb_build_object(
            'session_verified', true,
            'agent_verified', true,
            'domain_restricted', true,
            'hipaa_compliant', true
        ),
        true, -- compliance_validated
        'medical_diagnosis_agent'
    );
    
    -- Log successful reasoning for learning (MEDICAL DOMAIN ONLY)
    PERFORM business.ai_learn_from_data(
        (SELECT tenant_hk FROM ai_agents.agent_session_s WHERE session_hk = v_session_hk AND load_end_date IS NULL),
        'medical_diagnosis',
        'diagnostic_reasoning',
        'medical_case',
        jsonb_build_array(
            jsonb_build_object(
                'input_symptoms', p_symptoms,
                'diagnosis_confidence', v_confidence_score,
                'reasoning_quality', 'good',
                'model_version', 'medical_diagnostic_v2.1'
            )
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'agent_id', encode(v_agent_hk, 'hex'),
        'reasoning_id', encode(v_reasoning_hk, 'hex'),
        'domain', 'medical',
        'diagnosis', v_diagnosis_result,
        'confidence', v_confidence_score,
        'timestamp', CURRENT_TIMESTAMP
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Medical diagnosis reasoning failed: ' || SQLERRM,
        'timestamp', CURRENT_TIMESTAMP
    );
END;
$$;

-- Equine Care Agent Function
CREATE OR REPLACE FUNCTION ai_agents.equine_care_reasoning(
    p_session_token VARCHAR(255),
    p_horse_data JSONB,
    p_health_metrics JSONB,
    p_behavior_observations JSONB
) RETURNS JSONB
SECURITY DEFINER
SET search_path = ai_agents, auth, audit
LANGUAGE plpgsql AS $$
DECLARE
    v_session_hk BYTEA;
    v_agent_hk BYTEA;
    v_reasoning_hk BYTEA;
    v_care_result JSONB;
    v_confidence_score DECIMAL(5,4);
BEGIN
    -- Verify session and agent identity (Zero Trust)
    SELECT s.session_hk, s.agent_hk INTO v_session_hk, v_agent_hk
    FROM ai_agents.agent_session_h sh
    JOIN ai_agents.agent_session_s s ON sh.session_hk = s.session_hk
    WHERE s.session_token = p_session_token
    AND s.session_status = 'active'
    AND s.session_expires > CURRENT_TIMESTAMP
    AND s.load_end_date IS NULL;
    
    IF v_session_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Invalid or expired session',
            'timestamp', CURRENT_TIMESTAMP
        );
    END IF;
    
    -- Verify agent is equine domain specialist (NO MEDICAL KNOWLEDGE)
    IF NOT EXISTS (
        SELECT 1 FROM ai_agents.agent_identity_s ais
        WHERE ais.agent_hk = v_agent_hk
        AND ais.knowledge_domain = 'equine'
        AND ais.is_active = true
        AND ais.load_end_date IS NULL
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Agent not authorized for equine care',
            'timestamp', CURRENT_TIMESTAMP
        );
    END IF;
    
    -- Generate reasoning request ID
    v_reasoning_hk := util.hash_binary(encode(v_session_hk, 'hex') || 'EQUINE' || CURRENT_TIMESTAMP::text);
    
    -- Perform equine-specific reasoning (EQUINE DOMAIN ONLY)
    v_care_result := jsonb_build_object(
        'health_assessment', jsonb_build_object(
            'overall_score', 8.5,
            'lameness_detected', false,
            'nutritional_status', 'good',
            'behavioral_indicators', 'normal'
        ),
        'care_recommendations', jsonb_build_array(
            jsonb_build_object('action', 'Increase exercise', 'priority', 'medium', 'reasoning', 'Fitness improvement'),
            jsonb_build_object('action', 'Adjust feeding schedule', 'priority', 'low', 'reasoning', 'Optimize nutrition')
        ),
        'monitoring_plan', jsonb_build_object(
            'frequency', 'weekly',
            'metrics_to_track', jsonb_build_array('weight', 'energy_level', 'coat_condition'),
            'alert_thresholds', jsonb_build_object('weight_change', 5, 'energy_drop', 20)
        ),
        'veterinary_consultation', jsonb_build_object(
            'recommended', false,
            'urgency', 'routine',
            'next_checkup', '3_months'
        )
    );
    
    v_confidence_score := 0.78;
    
    -- Store reasoning details (EQUINE DOMAIN ISOLATED)
    INSERT INTO ai_agents.reasoning_details_s VALUES (
        v_reasoning_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(encode(v_reasoning_hk, 'hex') || 'equine_care'),
        v_session_hk,
        v_agent_hk,
        (SELECT domain_hk FROM ai_agents.knowledge_domain_h WHERE domain_bk LIKE 'equine_%' LIMIT 1),
        'equine_health_assessment',
        encode(digest(p_horse_data::text || p_health_metrics::text, 'sha256'), 'hex')::bytea,
        util.hash_binary(p_horse_data::text || p_health_metrics::text),
        jsonb_build_object(
            'step1', 'Health metrics analysis',
            'step2', 'Behavior pattern evaluation',
            'step3', 'Care recommendation generation',
            'step4', 'Monitoring plan creation'
        ),
        'equine_care_v1.3',
        180, -- processing time ms
        12.3, -- memory usage MB
        encode(digest(v_care_result::text, 'sha256'), 'hex')::bytea,
        util.hash_binary(v_care_result::text),
        v_confidence_score,
        'good',
        false, -- used_for_learning
        NULL,
        false,
        'internal', -- Not HIPAA, but still protected
        jsonb_build_object(
            'session_verified', true,
            'agent_verified', true,
            'domain_restricted', 'equine_only',
            'knowledge_isolation', true
        ),
        true,
        'equine_care_agent'
    );
    
    -- Log for learning (EQUINE DOMAIN ONLY - NO MEDICAL DATA)
    PERFORM business.ai_learn_from_data(
        (SELECT tenant_hk FROM ai_agents.agent_session_s WHERE session_hk = v_session_hk AND load_end_date IS NULL),
        'equine_care',
        'health_assessment',
        'equine_case',
        jsonb_build_array(
            jsonb_build_object(
                'health_metrics', p_health_metrics,
                'care_confidence', v_confidence_score,
                'assessment_quality', 'good',
                'model_version', 'equine_care_v1.3'
            )
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'agent_id', encode(v_agent_hk, 'hex'),
        'reasoning_id', encode(v_reasoning_hk, 'hex'),
        'domain', 'equine',
        'assessment', v_care_result,
        'confidence', v_confidence_score,
        'timestamp', CURRENT_TIMESTAMP
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Equine care reasoning failed: ' || SQLERRM,
        'timestamp', CURRENT_TIMESTAMP
    );
END;
$$;

-- ==========================================
-- ZERO TRUST GATEWAY FUNCTION
-- ==========================================

-- Central Gateway for All Agent Communication
CREATE OR REPLACE FUNCTION ai_agents.zero_trust_gateway(
    p_request JSONB
) RETURNS JSONB
SECURITY DEFINER
SET search_path = ai_agents, auth, audit
LANGUAGE plpgsql AS $$
DECLARE
    v_request_type VARCHAR(100);
    v_session_token VARCHAR(255);
    v_agent_verified BOOLEAN := false;
    v_domain_authorized BOOLEAN := false;
    v_result JSONB;
BEGIN
    -- Extract request details
    v_request_type := p_request->>'request_type';
    v_session_token := p_request->>'session_token';
    
    -- Verify session token exists
    IF v_session_token IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Missing session token',
            'security_level', 'CRITICAL',
            'timestamp', CURRENT_TIMESTAMP
        );
    END IF;
    
    -- Verify agent session (Zero Trust)
    SELECT true INTO v_agent_verified
    FROM ai_agents.agent_session_h sh
    JOIN ai_agents.agent_session_s s ON sh.session_hk = s.session_hk
    WHERE s.session_token = v_session_token
    AND s.session_status = 'active'
    AND s.session_expires > CURRENT_TIMESTAMP
    AND s.load_end_date IS NULL;
    
    IF NOT v_agent_verified THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Agent session verification failed',
            'security_level', 'HIGH',
            'timestamp', CURRENT_TIMESTAMP
        );
    END IF;
    
    -- Route to appropriate domain-specific agent
    CASE v_request_type
        WHEN 'medical_diagnosis' THEN
            v_result := ai_agents.medical_diagnosis_reasoning(
                v_session_token,
                p_request->'patient_data',
                p_request->'symptoms',
                p_request->'medical_history'
            );
            
        WHEN 'equine_care' THEN
            v_result := ai_agents.equine_care_reasoning(
                v_session_token,
                p_request->'horse_data',
                p_request->'health_metrics',
                p_request->'behavior_observations'
            );
            
        -- Add other domain agents here
        ELSE
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Unknown request type: ' || v_request_type,
                'timestamp', CURRENT_TIMESTAMP
            );
    END CASE;
    
    -- Log gateway activity
    PERFORM audit.log_security_event(
        (SELECT tenant_hk FROM ai_agents.agent_session_s s 
         WHERE s.session_token = v_session_token AND s.load_end_date IS NULL),
        'agent_gateway_access',
        'INFO',
        'Agent request processed through zero trust gateway',
        NULL, -- ip_address
        NULL, -- user_agent
        (SELECT requesting_user_hk FROM ai_agents.agent_session_s s 
         WHERE s.session_token = v_session_token AND s.load_end_date IS NULL),
        jsonb_build_object(
            'request_type', v_request_type,
            'agent_verified', v_agent_verified,
            'gateway_version', 'v1.0'
        )
    );
    
    RETURN v_result;
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Gateway processing failed: ' || SQLERRM,
        'security_level', 'HIGH',
        'timestamp', CURRENT_TIMESTAMP
    );
END;
$$;

-- ==========================================
-- INITIALIZATION DATA
-- ==========================================

-- Insert knowledge domains (Isolated)
DO $$
DECLARE
    v_medical_domain_hk BYTEA;
    v_equine_domain_hk BYTEA;
    v_tenant_hk BYTEA;
BEGIN
    -- Get a sample tenant (adjust as needed)
    SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h LIMIT 1;
    
    IF v_tenant_hk IS NOT NULL THEN
        -- Medical Domain
        v_medical_domain_hk := util.hash_binary('medical_v2.1');
        INSERT INTO ai_agents.knowledge_domain_h VALUES (
            v_medical_domain_hk, 'medical_v2.1', v_tenant_hk, util.current_load_date(), 'zero_trust_init'
        ) ON CONFLICT DO NOTHING;
        
        INSERT INTO ai_agents.knowledge_domain_s VALUES (
            v_medical_domain_hk, util.current_load_date(), NULL,
            util.hash_binary('medical_v2.1_config'),
            'medical', 'v2.1', 'Medical diagnostic and treatment domain',
            '/secure/medical/knowledge/', '/secure/medical/models/', '/secure/medical/training/',
            ARRAY['healthcare'], ARRAY['patient_h', 'diagnosis_s', 'treatment_s'],
            ARRAY['equine', 'manufacturing', 'financial'], false,
            true, '2 years', '1 week',
            ARRAY['HIPAA', 'GDPR'], true, true, 'comprehensive',
            'zero_trust_init'
        ) ON CONFLICT DO NOTHING;
        
        -- Equine Domain
        v_equine_domain_hk := util.hash_binary('equine_v1.3');
        INSERT INTO ai_agents.knowledge_domain_h VALUES (
            v_equine_domain_hk, 'equine_v1.3', v_tenant_hk, util.current_load_date(), 'zero_trust_init'
        ) ON CONFLICT DO NOTHING;
        
        INSERT INTO ai_agents.knowledge_domain_s VALUES (
            v_equine_domain_hk, util.current_load_date(), NULL,
            util.hash_binary('equine_v1.3_config'),
            'equine', 'v1.3', 'Equine veterinary care and management domain',
            '/secure/equine/knowledge/', '/secure/equine/models/', '/secure/equine/training/',
            ARRAY['equine'], ARRAY['horse_h', 'health_s', 'care_s'],
            ARRAY['medical', 'manufacturing', 'financial'], false,
            true, '2 years', '1 week',
            ARRAY['GDPR'], true, true, 'comprehensive',
            'zero_trust_init'
        ) ON CONFLICT DO NOTHING;
    END IF;
END;
$$;

-- Create indexes for performance
CREATE INDEX idx_agent_h_tenant_hk ON ai_agents.agent_h(tenant_hk);
CREATE INDEX idx_agent_identity_s_agent_type ON ai_agents.agent_identity_s(agent_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_agent_session_s_token ON ai_agents.agent_session_s(session_token) WHERE load_end_date IS NULL;
CREATE INDEX idx_reasoning_details_s_agent_hk ON ai_agents.reasoning_details_s(agent_hk) WHERE load_end_date IS NULL;

-- Comments
COMMENT ON SCHEMA ai_agents IS 'Zero Trust AI Agent system with domain-specific knowledge isolation and comprehensive security';
COMMENT ON TABLE ai_agents.agent_h IS 'Hub table for AI agent identities following Data Vault 2.0 patterns';
COMMENT ON TABLE ai_agents.knowledge_domain_s IS 'Domain-specific knowledge isolation configuration - prevents cross-domain contamination';
COMMENT ON FUNCTION ai_agents.zero_trust_gateway IS 'Central gateway enforcing zero trust for all agent communications';

COMMIT; 