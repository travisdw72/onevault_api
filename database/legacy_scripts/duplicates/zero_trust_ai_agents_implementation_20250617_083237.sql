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

-- Comments
COMMENT ON SCHEMA ai_agents IS 'Zero Trust AI Agent system with domain-specific knowledge isolation and comprehensive security';
COMMENT ON TABLE ai_agents.agent_h IS 'Hub table for AI agent identities following Data Vault 2.0 patterns';

COMMIT; 