-- ==========================================
-- ZERO TRUST AI AGENTS - STEP 6
-- Create Missing Zero Trust Components
-- Complete the architecture from AI_AGENT_IMPLEMENTATION_GUIDE.md
-- ==========================================

BEGIN;

-- ==========================================
-- ZERO TRUST GATEWAY COMPONENTS
-- ==========================================

-- Zero Trust Gateway Hub
CREATE TABLE ai_agents.zero_trust_gateway_h (
    gateway_hk BYTEA PRIMARY KEY,
    gateway_bk VARCHAR(255) NOT NULL UNIQUE,        -- ZTG-001, ZTG-002
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Gateway Configuration Satellite
CREATE TABLE ai_agents.zero_trust_gateway_s (
    gateway_hk BYTEA NOT NULL REFERENCES ai_agents.zero_trust_gateway_h(gateway_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Gateway Configuration
    gateway_name VARCHAR(200) NOT NULL,
    gateway_version VARCHAR(50) NOT NULL,
    deep_packet_inspection BOOLEAN NOT NULL DEFAULT true,
    behavioral_analytics BOOLEAN NOT NULL DEFAULT true,
    traffic_analysis BOOLEAN NOT NULL DEFAULT true,
    
    -- Security Settings
    min_tls_version VARCHAR(10) NOT NULL DEFAULT '1.3',
    certificate_validation_strict BOOLEAN NOT NULL DEFAULT true,
    session_timeout_seconds INTEGER NOT NULL DEFAULT 600,
    max_concurrent_sessions INTEGER NOT NULL DEFAULT 100,
    
    -- Threat Protection
    ddos_protection BOOLEAN NOT NULL DEFAULT true,
    rate_limiting_enabled BOOLEAN NOT NULL DEFAULT true,
    requests_per_minute INTEGER NOT NULL DEFAULT 1000,
    geoblocking_enabled BOOLEAN NOT NULL DEFAULT false,
    
    is_active BOOLEAN NOT NULL DEFAULT true,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (gateway_hk, load_date)
);

-- ==========================================
-- PKI AUTHORITY AND HSM INTEGRATION
-- ==========================================

-- PKI Authority Hub
CREATE TABLE ai_agents.pki_authority_h (
    pki_authority_hk BYTEA PRIMARY KEY,
    pki_authority_bk VARCHAR(255) NOT NULL UNIQUE,  -- PKI-CA-001
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for root CA
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- PKI Authority Configuration Satellite
CREATE TABLE ai_agents.pki_authority_s (
    pki_authority_hk BYTEA NOT NULL REFERENCES ai_agents.pki_authority_h(pki_authority_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- CA Configuration
    ca_name VARCHAR(200) NOT NULL,
    ca_level VARCHAR(50) NOT NULL,                   -- ROOT, INTERMEDIATE, ISSUING
    ca_certificate_pem TEXT NOT NULL,
    ca_certificate_fingerprint BYTEA NOT NULL,
    
    -- HSM Integration
    hsm_provider VARCHAR(100) NOT NULL,              -- AWS_CloudHSM, Azure_KeyVault, etc.
    hsm_cluster_id VARCHAR(255),
    key_algorithm VARCHAR(50) NOT NULL DEFAULT 'RSA-4096',
    signing_algorithm VARCHAR(50) NOT NULL DEFAULT 'SHA256-RSA',
    
    -- Certificate Lifecycle
    certificate_validity_days INTEGER NOT NULL DEFAULT 365,
    auto_renewal_enabled BOOLEAN NOT NULL DEFAULT true,
    renewal_threshold_days INTEGER NOT NULL DEFAULT 30,
    revocation_checking BOOLEAN NOT NULL DEFAULT true,
    
    -- Compliance
    fips_140_2_level INTEGER NOT NULL DEFAULT 3,
    common_criteria_certified BOOLEAN NOT NULL DEFAULT true,
    audit_logging_enabled BOOLEAN NOT NULL DEFAULT true,
    
    is_active BOOLEAN NOT NULL DEFAULT true,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (pki_authority_hk, load_date)
);

-- ==========================================
-- ADVANCED AGENT TYPES (FROM MERMAID DIAGRAM)
-- ==========================================

-- Data Acquisition Agent Hub
CREATE TABLE ai_agents.data_acquisition_agent_h (
    da_agent_hk BYTEA PRIMARY KEY,
    da_agent_bk VARCHAR(255) NOT NULL UNIQUE,       -- DA-001, DA-002
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Data Validation Agent Hub  
CREATE TABLE ai_agents.data_validation_agent_h (
    dv_agent_hk BYTEA PRIMARY KEY,
    dv_agent_bk VARCHAR(255) NOT NULL UNIQUE,       -- DVA-001, DVA-002
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Logic Reasoning Agent Hub
CREATE TABLE ai_agents.logic_reasoning_agent_h (
    lr_agent_hk BYTEA PRIMARY KEY,
    lr_agent_bk VARCHAR(255) NOT NULL UNIQUE,       -- LRA-001, LRA-002
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Orchestration Agent Hub
CREATE TABLE ai_agents.orchestration_agent_h (
    orch_agent_hk BYTEA PRIMARY KEY,
    orch_agent_bk VARCHAR(255) NOT NULL UNIQUE,     -- OA-001, OA-002
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Pattern Recognition Agent Hub
CREATE TABLE ai_agents.pattern_recognition_agent_h (
    pr_agent_hk BYTEA PRIMARY KEY,
    pr_agent_bk VARCHAR(255) NOT NULL UNIQUE,       -- PRA-001, PRA-002
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Business Intelligence Agent Hub
CREATE TABLE ai_agents.business_intelligence_agent_h (
    bi_agent_hk BYTEA PRIMARY KEY,
    bi_agent_bk VARCHAR(255) NOT NULL UNIQUE,       -- BIA-001, BIA-002
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Decision Making Agent Hub
CREATE TABLE ai_agents.decision_making_agent_h (
    dm_agent_hk BYTEA PRIMARY KEY,
    dm_agent_bk VARCHAR(255) NOT NULL UNIQUE,       -- DMA-001, DMA-002
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- ==========================================
-- THREAT INTELLIGENCE AND SOC AGENTS
-- ==========================================

-- Threat Intelligence Agent Hub
CREATE TABLE ai_agents.threat_intelligence_agent_h (
    ti_agent_hk BYTEA PRIMARY KEY,
    ti_agent_bk VARCHAR(255) NOT NULL UNIQUE,       -- TIA-001
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- SOC Agent Hub
CREATE TABLE ai_agents.soc_agent_h (
    soc_agent_hk BYTEA PRIMARY KEY,
    soc_agent_bk VARCHAR(255) NOT NULL UNIQUE,      -- SOC-001
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Threat Intelligence Satellite
CREATE TABLE ai_agents.threat_intelligence_s (
    ti_agent_hk BYTEA NOT NULL REFERENCES ai_agents.threat_intelligence_agent_h(ti_agent_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Threat Feed Configuration
    threat_feeds_enabled TEXT[] NOT NULL,           -- ['misp', 'crowdstrike', 'virustotal']
    feed_update_frequency INTERVAL NOT NULL DEFAULT '1 hour',
    threat_correlation_enabled BOOLEAN NOT NULL DEFAULT true,
    
    -- ML Threat Detection
    ml_threat_detection BOOLEAN NOT NULL DEFAULT true,
    anomaly_detection_threshold DECIMAL(5,4) NOT NULL DEFAULT 0.85,
    behavioral_analysis_enabled BOOLEAN NOT NULL DEFAULT true,
    
    -- Response Configuration
    automated_blocking BOOLEAN NOT NULL DEFAULT true,
    quarantine_suspicious_agents BOOLEAN NOT NULL DEFAULT true,
    alert_escalation_threshold INTEGER NOT NULL DEFAULT 3,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (ti_agent_hk, load_date)
);

-- ==========================================
-- BEHAVIORAL ANALYTICS SYSTEM
-- ==========================================

-- Behavioral Analytics Hub
CREATE TABLE ai_agents.behavioral_analytics_h (
    behavioral_hk BYTEA PRIMARY KEY,
    behavioral_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Behavioral Analytics Satellite
CREATE TABLE ai_agents.behavioral_analytics_s (
    behavioral_hk BYTEA NOT NULL REFERENCES ai_agents.behavioral_analytics_h(behavioral_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Agent Being Analyzed
    agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    session_hk BYTEA NOT NULL REFERENCES ai_agents.agent_session_h(session_hk),
    
    -- Behavioral Metrics
    request_frequency_score DECIMAL(5,4),           -- Normal vs unusual request patterns
    data_access_pattern_score DECIMAL(5,4),         -- Normal vs unusual data access
    reasoning_complexity_score DECIMAL(5,4),        -- Complexity of reasoning requests
    error_rate_score DECIMAL(5,4),                  -- Error rate analysis
    
    -- Anomaly Detection
    overall_behavioral_score DECIMAL(5,4) NOT NULL,
    anomaly_threshold DECIMAL(5,4) NOT NULL DEFAULT 0.75,
    anomaly_detected BOOLEAN GENERATED ALWAYS AS (overall_behavioral_score < anomaly_threshold) STORED,
    
    -- Risk Assessment
    risk_level VARCHAR(20) NOT NULL,                -- low, medium, high, critical
    risk_factors JSONB,
    recommended_actions TEXT[],
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (behavioral_hk, load_date)
);

-- ==========================================
-- CONSENSUS AND ORCHESTRATION SYSTEM
-- ==========================================

-- Consensus Protocol Hub
CREATE TABLE ai_agents.consensus_protocol_h (
    consensus_hk BYTEA PRIMARY KEY,
    consensus_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Consensus Protocol Satellite
CREATE TABLE ai_agents.consensus_protocol_s (
    consensus_hk BYTEA NOT NULL REFERENCES ai_agents.consensus_protocol_h(consensus_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Consensus Configuration
    consensus_algorithm VARCHAR(100) NOT NULL,      -- 'byzantine_fault_tolerance', 'raft', 'paxos'
    minimum_participants INTEGER NOT NULL DEFAULT 3,
    consensus_threshold DECIMAL(5,4) NOT NULL DEFAULT 0.67,
    timeout_seconds INTEGER NOT NULL DEFAULT 30,
    
    -- Participating Agents
    participating_agents JSONB NOT NULL,            -- Array of agent_hk participating
    orchestration_agent_hk BYTEA REFERENCES ai_agents.orchestration_agent_h(orch_agent_hk),
    
    -- Decision Details
    decision_topic VARCHAR(200) NOT NULL,
    decision_context JSONB,
    consensus_reached BOOLEAN DEFAULT false,
    consensus_timestamp TIMESTAMP WITH TIME ZONE,
    
    -- Audit and Verification
    cryptographic_proof BYTEA,                      -- Digital signature of consensus
    verification_hash BYTEA,                        -- Hash for tamper detection
    audit_trail JSONB NOT NULL,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (consensus_hk, load_date)
);

-- Create indexes for performance
CREATE INDEX idx_zero_trust_gateway_h_tenant_hk ON ai_agents.zero_trust_gateway_h(tenant_hk);
CREATE INDEX idx_pki_authority_s_ca_fingerprint ON ai_agents.pki_authority_s(ca_certificate_fingerprint) WHERE load_end_date IS NULL;
CREATE INDEX idx_threat_intelligence_s_feeds ON ai_agents.threat_intelligence_s(threat_feeds_enabled) WHERE load_end_date IS NULL;
CREATE INDEX idx_behavioral_analytics_s_anomaly ON ai_agents.behavioral_analytics_s(anomaly_detected) WHERE load_end_date IS NULL;
CREATE INDEX idx_behavioral_analytics_s_risk_level ON ai_agents.behavioral_analytics_s(risk_level) WHERE load_end_date IS NULL;
CREATE INDEX idx_consensus_protocol_s_reached ON ai_agents.consensus_protocol_s(consensus_reached) WHERE load_end_date IS NULL;

-- Comments
COMMENT ON TABLE ai_agents.zero_trust_gateway_h IS 'Zero Trust Gateway configuration for deep packet inspection and behavioral analytics';
COMMENT ON TABLE ai_agents.pki_authority_h IS 'PKI Certificate Authority with HSM integration for agent certificates';
COMMENT ON TABLE ai_agents.threat_intelligence_agent_h IS 'Threat Intelligence Agent for real-time threat detection and correlation';
COMMENT ON TABLE ai_agents.behavioral_analytics_h IS 'Behavioral analytics system for agent anomaly detection';
COMMENT ON TABLE ai_agents.consensus_protocol_h IS 'Consensus protocol system for multi-agent decision making';

COMMIT; 