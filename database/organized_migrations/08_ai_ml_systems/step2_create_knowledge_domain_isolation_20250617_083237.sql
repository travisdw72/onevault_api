-- ==========================================
-- ZERO TRUST AI AGENTS - STEP 2
-- Create Domain-Specific Knowledge Isolation
-- Prevents cross-domain contamination
-- ==========================================

BEGIN;

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

-- Create indexes for performance
CREATE INDEX idx_knowledge_domain_h_tenant_hk ON ai_agents.knowledge_domain_h(tenant_hk);
CREATE INDEX idx_knowledge_domain_h_domain_bk ON ai_agents.knowledge_domain_h(domain_bk);
CREATE INDEX idx_knowledge_domain_s_domain_name ON ai_agents.knowledge_domain_s(domain_name) WHERE load_end_date IS NULL;
CREATE INDEX idx_agent_domain_l_agent_hk ON ai_agents.agent_domain_l(agent_hk);
CREATE INDEX idx_agent_domain_l_domain_hk ON ai_agents.agent_domain_l(domain_hk);
CREATE INDEX idx_agent_domain_access_s_permissions ON ai_agents.agent_domain_access_s(read_permission, write_permission, learn_permission) WHERE load_end_date IS NULL;

-- Comments
COMMENT ON TABLE ai_agents.knowledge_domain_h IS 'Hub table for AI knowledge domains - medical, equine, manufacturing, etc.';
COMMENT ON TABLE ai_agents.knowledge_domain_s IS 'Domain-specific knowledge isolation configuration - prevents cross-domain contamination';
COMMENT ON TABLE ai_agents.agent_domain_l IS 'Link table assigning agents to specific knowledge domains (one domain per agent)';
COMMENT ON TABLE ai_agents.agent_domain_access_s IS 'Restrictive access permissions for agents within their assigned domain';

COMMIT; 