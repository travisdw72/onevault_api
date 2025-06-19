-- ==========================================
-- ZERO TRUST AI AGENTS - STEP 3
-- Create Zero Trust Session Management
-- All agent interactions require authentication
-- ==========================================

BEGIN;

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
    certificate_used BYTEA,                       -- Reference to certificate fingerprint
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

-- Session Activity Tracking Satellite
CREATE TABLE ai_agents.session_activity_s (
    session_hk BYTEA NOT NULL REFERENCES ai_agents.agent_session_h(session_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Activity Details
    activity_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    activity_type VARCHAR(100) NOT NULL,          -- 'reasoning_request', 'data_access', 'learning_update'
    activity_description TEXT,
    
    -- Resource Usage
    cpu_time_ms INTEGER DEFAULT 0,
    memory_used_mb DECIMAL(10,2) DEFAULT 0,
    data_transferred_kb DECIMAL(10,2) DEFAULT 0,
    
    -- Security Monitoring
    suspicious_behavior BOOLEAN DEFAULT false,
    security_alerts TEXT[],
    threat_indicators JSONB,
    
    -- Performance Metrics
    response_time_ms INTEGER,
    success_rate DECIMAL(5,4),
    error_count INTEGER DEFAULT 0,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (session_hk, load_date)
);

-- Session Authentication Link (tracks all auth events)
CREATE TABLE ai_agents.session_auth_l (
    session_auth_hk BYTEA PRIMARY KEY,            -- SHA-256(session_hk + auth_timestamp)
    session_hk BYTEA NOT NULL REFERENCES ai_agents.agent_session_h(session_hk),
    agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Session Authentication Details Satellite
CREATE TABLE ai_agents.session_auth_s (
    session_auth_hk BYTEA NOT NULL REFERENCES ai_agents.session_auth_l(session_auth_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Authentication Event
    auth_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    auth_type VARCHAR(50) NOT NULL,               -- 'initial', 'renewal', 'challenge', 'termination'
    auth_method VARCHAR(100) NOT NULL,            -- 'certificate', 'mfa', 'behavioral'
    auth_result VARCHAR(50) NOT NULL,             -- 'success', 'failure', 'challenge_required'
    
    -- Certificate Details (if used)
    certificate_fingerprint BYTEA,
    certificate_validation_result VARCHAR(50),
    
    -- Multi-Factor Authentication
    mfa_method VARCHAR(50),                       -- 'totp', 'sms', 'push', 'biometric'
    mfa_result VARCHAR(50),
    
    -- Behavioral Analysis
    behavioral_confidence DECIMAL(5,4),
    risk_factors JSONB,
    anomaly_detected BOOLEAN DEFAULT false,
    
    -- Audit Information
    ip_address INET,
    user_agent TEXT,
    geographic_location VARCHAR(100),
    network_segment VARCHAR(100),
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (session_auth_hk, load_date)
);

-- Create indexes for performance
CREATE INDEX idx_agent_session_h_tenant_hk ON ai_agents.agent_session_h(tenant_hk);
CREATE INDEX idx_agent_session_s_token ON ai_agents.agent_session_s(session_token) WHERE load_end_date IS NULL;
CREATE INDEX idx_agent_session_s_status ON ai_agents.agent_session_s(session_status) WHERE load_end_date IS NULL;
CREATE INDEX idx_agent_session_s_agent_hk ON ai_agents.agent_session_s(agent_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_agent_session_s_expires ON ai_agents.agent_session_s(session_expires) WHERE load_end_date IS NULL;
CREATE INDEX idx_session_activity_s_timestamp ON ai_agents.session_activity_s(activity_timestamp) WHERE load_end_date IS NULL;
CREATE INDEX idx_session_activity_s_type ON ai_agents.session_activity_s(activity_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_session_auth_s_timestamp ON ai_agents.session_auth_s(auth_timestamp) WHERE load_end_date IS NULL;
CREATE INDEX idx_session_auth_s_result ON ai_agents.session_auth_s(auth_result) WHERE load_end_date IS NULL;

-- Comments
COMMENT ON TABLE ai_agents.agent_session_h IS 'Hub table for AI agent sessions with zero trust authentication';
COMMENT ON TABLE ai_agents.agent_session_s IS 'Session state tracking with comprehensive security monitoring';
COMMENT ON TABLE ai_agents.session_activity_s IS 'Detailed activity tracking for all agent actions within sessions';
COMMENT ON TABLE ai_agents.session_auth_l IS 'Link table for session authentication events';
COMMENT ON TABLE ai_agents.session_auth_s IS 'Detailed authentication tracking including mTLS, MFA, and behavioral analysis';

COMMIT; 