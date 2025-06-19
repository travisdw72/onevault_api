-- ==========================================
-- ZERO TRUST AI AGENTS - STEP 1
-- Create AI Agents Schema and Core Identity Tables
-- Builds on existing Data Vault 2.0 Platform
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

-- Create initial indexes for performance
CREATE INDEX idx_agent_h_tenant_hk ON ai_agents.agent_h(tenant_hk);
CREATE INDEX idx_agent_h_agent_bk ON ai_agents.agent_h(agent_bk);
CREATE INDEX idx_agent_identity_s_agent_type ON ai_agents.agent_identity_s(agent_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_agent_identity_s_knowledge_domain ON ai_agents.agent_identity_s(knowledge_domain) WHERE load_end_date IS NULL;
CREATE INDEX idx_agent_certificate_s_fingerprint ON ai_agents.agent_certificate_s(certificate_fingerprint) WHERE load_end_date IS NULL;

-- Comments
COMMENT ON SCHEMA ai_agents IS 'Zero Trust AI Agent system with domain-specific knowledge isolation and comprehensive security';
COMMENT ON TABLE ai_agents.agent_h IS 'Hub table for AI agent identities following Data Vault 2.0 patterns';
COMMENT ON TABLE ai_agents.agent_identity_s IS 'Agent identity and configuration satellite with strict domain isolation';
COMMENT ON TABLE ai_agents.agent_certificate_s IS 'Agent certificate management for mTLS authentication';

COMMIT; 