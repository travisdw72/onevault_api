-- ==========================================
-- ZERO TRUST AI AGENTS - STEP 9
-- Create Threat Intelligence System
-- SIEM Integration and Automated Incident Response
-- ==========================================

BEGIN;

-- ==========================================
-- THREAT FEED MANAGEMENT
-- ==========================================

-- Threat Feed Hub
CREATE TABLE ai_agents.threat_feed_h (
    threat_feed_hk BYTEA PRIMARY KEY,            -- SHA-256(feed_name + provider)
    threat_feed_bk VARCHAR(255) NOT NULL UNIQUE, -- Threat feed business key
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for global feeds
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Threat Feed Configuration Satellite
CREATE TABLE ai_agents.threat_feed_s (
    threat_feed_hk BYTEA NOT NULL REFERENCES ai_agents.threat_feed_h(threat_feed_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Feed Information
    feed_name VARCHAR(200) NOT NULL,
    feed_provider VARCHAR(100) NOT NULL,         -- 'misp', 'crowdstrike', 'virustotal', 'custom'
    feed_type VARCHAR(50) NOT NULL,              -- 'ioc', 'malware', 'vulnerability', 'behavioral'
    feed_url TEXT,
    feed_format VARCHAR(50) NOT NULL,            -- 'stix', 'json', 'xml', 'csv'
    
    -- Update Configuration
    update_frequency INTERVAL NOT NULL DEFAULT '1 hour',
    last_update TIMESTAMP WITH TIME ZONE,
    next_update TIMESTAMP WITH TIME ZONE,
    auto_update_enabled BOOLEAN NOT NULL DEFAULT true,
    
    -- Feed Quality
    feed_reliability VARCHAR(50) NOT NULL DEFAULT 'medium', -- 'high', 'medium', 'low'
    confidence_threshold DECIMAL(5,4) NOT NULL DEFAULT 0.75,
    false_positive_rate DECIMAL(5,4) DEFAULT 0.05,
    
    -- Integration Configuration
    api_key_required BOOLEAN DEFAULT false,
    authentication_method VARCHAR(50),           -- 'api_key', 'oauth', 'certificate', 'none'
    rate_limit_per_hour INTEGER DEFAULT 1000,
    
    -- Processing Configuration
    preprocessing_enabled BOOLEAN DEFAULT true,
    enrichment_enabled BOOLEAN DEFAULT true,
    correlation_enabled BOOLEAN DEFAULT true,
    
    -- Status
    feed_status VARCHAR(50) NOT NULL DEFAULT 'active', -- 'active', 'inactive', 'error', 'maintenance'
    last_error TEXT,
    error_count INTEGER DEFAULT 0,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (threat_feed_hk, load_date)
);

-- ==========================================
-- THREAT INDICATORS
-- ==========================================

-- Threat Indicator Hub
CREATE TABLE ai_agents.threat_indicator_h (
    indicator_hk BYTEA PRIMARY KEY,              -- SHA-256(indicator_value + indicator_type)
    indicator_bk VARCHAR(255) NOT NULL,         -- Indicator business key
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for global indicators
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Threat Indicator Details Satellite
CREATE TABLE ai_agents.threat_indicator_s (
    indicator_hk BYTEA NOT NULL REFERENCES ai_agents.threat_indicator_h(indicator_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Indicator Details
    indicator_type VARCHAR(50) NOT NULL,         -- 'ip', 'domain', 'hash', 'url', 'email', 'certificate'
    indicator_value TEXT NOT NULL,
    indicator_hash BYTEA NOT NULL,               -- Hash of indicator value for privacy
    
    -- Threat Classification
    threat_category VARCHAR(100) NOT NULL,       -- 'malware', 'c2', 'phishing', 'scanning', 'exploit'
    threat_severity VARCHAR(20) NOT NULL,        -- 'low', 'medium', 'high', 'critical'
    threat_confidence DECIMAL(5,4) NOT NULL,     -- Confidence in threat assessment
    
    -- Source Information
    source_feed_hk BYTEA REFERENCES ai_agents.threat_feed_h(threat_feed_hk),
    original_source VARCHAR(200),
    first_seen TIMESTAMP WITH TIME ZONE NOT NULL,
    last_seen TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Contextual Information
    malware_family VARCHAR(100),
    attack_techniques TEXT[],                    -- MITRE ATT&CK techniques
    targeted_sectors TEXT[],
    geographic_regions TEXT[],
    
    -- Intelligence Context
    campaign_name VARCHAR(200),
    threat_actor_group VARCHAR(200),
    attribution_confidence DECIMAL(5,4),
    
    -- Lifecycle Management
    indicator_status VARCHAR(50) NOT NULL DEFAULT 'active', -- 'active', 'expired', 'false_positive', 'watchlist'
    expiry_date TIMESTAMP WITH TIME ZONE,
    auto_expire BOOLEAN DEFAULT true,
    
    -- Enrichment Data
    reputation_score DECIMAL(5,4),
    whois_data JSONB,
    dns_data JSONB,
    geolocation_data JSONB,
    additional_context JSONB,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (indicator_hk, load_date)
);

-- ==========================================
-- THREAT DETECTION ENGINE
-- ==========================================

-- Threat Detection Hub
CREATE TABLE ai_agents.threat_detection_h (
    detection_hk BYTEA PRIMARY KEY,              -- SHA-256(agent_hk + detection_timestamp + indicator_hk)
    detection_bk VARCHAR(255) NOT NULL,         -- Detection business key
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Threat Detection Details Satellite
CREATE TABLE ai_agents.threat_detection_s (
    detection_hk BYTEA NOT NULL REFERENCES ai_agents.threat_detection_h(detection_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Detection Context
    detecting_agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    session_hk BYTEA REFERENCES ai_agents.agent_session_h(session_hk),
    indicator_hk BYTEA REFERENCES ai_agents.threat_indicator_h(indicator_hk),
    
    -- Detection Details
    detection_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    detection_method VARCHAR(100) NOT NULL,      -- 'signature', 'behavioral', 'ml_anomaly', 'correlation'
    detection_rule VARCHAR(200),
    detection_confidence DECIMAL(5,4) NOT NULL,
    
    -- Threat Assessment
    threat_level VARCHAR(20) NOT NULL,           -- 'informational', 'low', 'medium', 'high', 'critical'
    risk_score DECIMAL(5,4) NOT NULL,
    potential_impact TEXT,
    attack_stage VARCHAR(50),                    -- 'reconnaissance', 'initial_access', 'execution', etc.
    
    -- Event Data
    source_ip INET,
    destination_ip INET,
    source_port INTEGER,
    destination_port INTEGER,
    protocol VARCHAR(20),
    user_agent TEXT,
    request_data JSONB,
    
    -- Detection Analysis
    indicators_matched TEXT[],
    behavioral_patterns JSONB,
    anomaly_score DECIMAL(5,4),
    ml_model_confidence DECIMAL(5,4),
    
    -- Response Status
    response_required BOOLEAN NOT NULL DEFAULT true,
    automated_response_triggered BOOLEAN DEFAULT false,
    response_actions TEXT[],
    manual_investigation_required BOOLEAN DEFAULT false,
    
    -- Investigation Status
    investigation_status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'investigating', 'confirmed', 'false_positive', 'resolved'
    assigned_analyst VARCHAR(100),
    investigation_notes TEXT,
    resolution_timestamp TIMESTAMP WITH TIME ZONE,
    
    -- SIEM Integration
    siem_event_id VARCHAR(255),
    siem_correlation_id VARCHAR(255),
    exported_to_siem BOOLEAN DEFAULT false,
    siem_export_timestamp TIMESTAMP WITH TIME ZONE,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (detection_hk, load_date)
);

-- ==========================================
-- INCIDENT MANAGEMENT
-- ==========================================

-- Security Incident Hub
CREATE TABLE ai_agents.security_incident_h (
    incident_hk BYTEA PRIMARY KEY,               -- SHA-256(incident_number + tenant_hk)
    incident_bk VARCHAR(255) NOT NULL,          -- Incident business key
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Security Incident Details Satellite
CREATE TABLE ai_agents.security_incident_s (
    incident_hk BYTEA NOT NULL REFERENCES ai_agents.security_incident_h(incident_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Incident Classification
    incident_number VARCHAR(100) NOT NULL UNIQUE,
    incident_title VARCHAR(500) NOT NULL,
    incident_description TEXT NOT NULL,
    incident_category VARCHAR(100) NOT NULL,     -- 'malware', 'data_breach', 'unauthorized_access', 'ddos'
    incident_severity VARCHAR(20) NOT NULL,      -- 'low', 'medium', 'high', 'critical'
    
    -- Timeline
    incident_detected TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    incident_reported TIMESTAMP WITH TIME ZONE,
    incident_acknowledged TIMESTAMP WITH TIME ZONE,
    incident_contained TIMESTAMP WITH TIME ZONE,
    incident_resolved TIMESTAMP WITH TIME ZONE,
    
    -- Status and Assignment
    incident_status VARCHAR(50) NOT NULL DEFAULT 'new', -- 'new', 'assigned', 'investigating', 'contained', 'resolved', 'closed'
    assigned_team VARCHAR(100),
    primary_analyst VARCHAR(100),
    escalation_level INTEGER DEFAULT 1,
    
    -- Impact Assessment
    business_impact VARCHAR(50),                 -- 'none', 'minimal', 'moderate', 'significant', 'severe'
    affected_systems TEXT[],
    affected_users INTEGER,
    estimated_financial_impact DECIMAL(15,2),
    data_compromised BOOLEAN DEFAULT false,
    
    -- Root Cause Analysis
    attack_vector VARCHAR(200),
    root_cause TEXT,
    contributing_factors TEXT[],
    lessons_learned TEXT,
    
    -- Response Actions
    containment_actions TEXT[],
    eradication_actions TEXT[],
    recovery_actions TEXT[],
    preventive_measures TEXT[],
    
    -- Communication
    stakeholders_notified TEXT[],
    external_notification_required BOOLEAN DEFAULT false,
    regulatory_notification_required BOOLEAN DEFAULT false,
    public_disclosure_required BOOLEAN DEFAULT false,
    
    -- Evidence and Artifacts
    evidence_collected JSONB,
    forensic_analysis_required BOOLEAN DEFAULT false,
    chain_of_custody JSONB,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (incident_hk, load_date)
);

-- ==========================================
-- AUTOMATED RESPONSE SYSTEM
-- ==========================================

-- Automated Response Hub
CREATE TABLE ai_agents.automated_response_h (
    response_hk BYTEA PRIMARY KEY,               -- SHA-256(detection_hk + response_timestamp)
    response_bk VARCHAR(255) NOT NULL,          -- Response business key
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Automated Response Details Satellite
CREATE TABLE ai_agents.automated_response_s (
    response_hk BYTEA NOT NULL REFERENCES ai_agents.automated_response_h(response_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Response Context
    detection_hk BYTEA NOT NULL REFERENCES ai_agents.threat_detection_h(detection_hk),
    incident_hk BYTEA REFERENCES ai_agents.security_incident_h(incident_hk),
    responding_agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    
    -- Response Configuration
    response_type VARCHAR(100) NOT NULL,         -- 'block_ip', 'quarantine_agent', 'revoke_session', 'escalate'
    response_severity VARCHAR(20) NOT NULL,      -- 'low', 'medium', 'high', 'critical'
    auto_approve_threshold DECIMAL(5,4) NOT NULL DEFAULT 0.90,
    
    -- Execution Details
    response_triggered TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    response_executed TIMESTAMP WITH TIME ZONE,
    response_completed TIMESTAMP WITH TIME ZONE,
    execution_duration INTERVAL GENERATED ALWAYS AS (response_completed - response_executed) STORED,
    
    -- Response Actions
    actions_planned TEXT[] NOT NULL,
    actions_executed TEXT[],
    actions_failed TEXT[],
    rollback_actions TEXT[],
    
    -- Status and Results
    response_status VARCHAR(50) NOT NULL DEFAULT 'planned', -- 'planned', 'executing', 'completed', 'failed', 'rolled_back'
    success_rate DECIMAL(5,4),
    effectiveness_score DECIMAL(5,4),
    unintended_consequences TEXT[],
    
    -- Approval and Override
    auto_approved BOOLEAN DEFAULT false,
    manual_approval_required BOOLEAN DEFAULT false,
    approved_by VARCHAR(100),
    approval_timestamp TIMESTAMP WITH TIME ZONE,
    override_reason TEXT,
    
    -- Impact Assessment
    systems_affected TEXT[],
    users_impacted INTEGER,
    downtime_duration INTERVAL,
    business_impact_assessment TEXT,
    
    -- Monitoring and Validation
    monitoring_enabled BOOLEAN DEFAULT true,
    validation_checks TEXT[],
    rollback_triggered BOOLEAN DEFAULT false,
    rollback_reason TEXT,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (response_hk, load_date)
);

-- ==========================================
-- THREAT INTELLIGENCE FUNCTIONS
-- ==========================================

-- Function to process threat feed update
CREATE OR REPLACE FUNCTION ai_agents.process_threat_feed_update(
    p_feed_hk BYTEA,
    p_indicators JSONB
) RETURNS JSONB
SECURITY DEFINER
SET search_path = ai_agents, auth, audit
LANGUAGE plpgsql AS $$
DECLARE
    v_indicator RECORD;
    v_indicator_hk BYTEA;
    v_tenant_hk BYTEA;
    v_processed_count INTEGER := 0;
    v_new_count INTEGER := 0;
    v_updated_count INTEGER := 0;
BEGIN
    -- Get feed tenant context
    SELECT tfs.tenant_hk INTO v_tenant_hk
    FROM ai_agents.threat_feed_s tfs
    WHERE tfs.threat_feed_hk = p_feed_hk
    AND tfs.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Threat feed not found');
    END IF;
    
    -- Process each indicator in the feed
    FOR v_indicator IN SELECT * FROM jsonb_array_elements(p_indicators) AS t(indicator)
    LOOP
        -- Generate indicator hash key
        v_indicator_hk := util.hash_binary(
            (v_indicator.indicator->>'type') || (v_indicator.indicator->>'value')
        );
        
        -- Check if indicator already exists
        IF EXISTS (
            SELECT 1 FROM ai_agents.threat_indicator_h 
            WHERE indicator_hk = v_indicator_hk
        ) THEN
            -- Update existing indicator
            UPDATE ai_agents.threat_indicator_s SET load_end_date = util.current_load_date()
            WHERE indicator_hk = v_indicator_hk AND load_end_date IS NULL;
            
            INSERT INTO ai_agents.threat_indicator_s VALUES (
                v_indicator_hk,
                util.current_load_date(),
                NULL,
                util.hash_binary(encode(v_indicator_hk, 'hex') || 'UPDATED'),
                (v_indicator.indicator->>'type'),
                (v_indicator.indicator->>'value'),
                util.hash_binary(v_indicator.indicator->>'value'), -- hashed value for privacy
                COALESCE((v_indicator.indicator->>'category'), 'unknown'),
                COALESCE((v_indicator.indicator->>'severity'), 'medium'),
                COALESCE((v_indicator.indicator->>'confidence')::DECIMAL(5,4), 0.5),
                p_feed_hk,
                COALESCE((v_indicator.indicator->>'source'), 'threat_feed'),
                COALESCE((v_indicator.indicator->>'first_seen')::TIMESTAMP WITH TIME ZONE, CURRENT_TIMESTAMP),
                CURRENT_TIMESTAMP, -- last_seen
                COALESCE((v_indicator.indicator->>'malware_family'), ''),
                COALESCE(ARRAY(SELECT jsonb_array_elements_text(v_indicator.indicator->'attack_techniques')), ARRAY[]::TEXT[]),
                COALESCE(ARRAY(SELECT jsonb_array_elements_text(v_indicator.indicator->'targeted_sectors')), ARRAY[]::TEXT[]),
                COALESCE(ARRAY(SELECT jsonb_array_elements_text(v_indicator.indicator->'geographic_regions')), ARRAY[]::TEXT[]),
                COALESCE((v_indicator.indicator->>'campaign_name'), ''),
                COALESCE((v_indicator.indicator->>'threat_actor'), ''),
                COALESCE((v_indicator.indicator->>'attribution_confidence')::DECIMAL(5,4), 0.3),
                'active',
                COALESCE((v_indicator.indicator->>'expiry_date')::TIMESTAMP WITH TIME ZONE, CURRENT_TIMESTAMP + INTERVAL '30 days'),
                true, -- auto_expire
                COALESCE((v_indicator.indicator->>'reputation_score')::DECIMAL(5,4), 0.5),
                COALESCE(v_indicator.indicator->'whois_data', '{}'::JSONB),
                COALESCE(v_indicator.indicator->'dns_data', '{}'::JSONB),
                COALESCE(v_indicator.indicator->'geolocation_data', '{}'::JSONB),
                COALESCE(v_indicator.indicator->'additional_context', '{}'::JSONB),
                'threat_intelligence_system'
            );
            
            v_updated_count := v_updated_count + 1;
        ELSE
            -- Insert new indicator
            INSERT INTO ai_agents.threat_indicator_h VALUES (
                v_indicator_hk,
                'IND_' || UPPER(v_indicator.indicator->>'type') || '_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS'),
                v_tenant_hk,
                util.current_load_date(),
                'threat_intelligence_system'
            );
            
            INSERT INTO ai_agents.threat_indicator_s VALUES (
                v_indicator_hk,
                util.current_load_date(),
                NULL,
                util.hash_binary(encode(v_indicator_hk, 'hex') || 'NEW'),
                (v_indicator.indicator->>'type'),
                (v_indicator.indicator->>'value'),
                util.hash_binary(v_indicator.indicator->>'value'),
                COALESCE((v_indicator.indicator->>'category'), 'unknown'),
                COALESCE((v_indicator.indicator->>'severity'), 'medium'),
                COALESCE((v_indicator.indicator->>'confidence')::DECIMAL(5,4), 0.5),
                p_feed_hk,
                COALESCE((v_indicator.indicator->>'source'), 'threat_feed'),
                COALESCE((v_indicator.indicator->>'first_seen')::TIMESTAMP WITH TIME ZONE, CURRENT_TIMESTAMP),
                CURRENT_TIMESTAMP,
                COALESCE((v_indicator.indicator->>'malware_family'), ''),
                COALESCE(ARRAY(SELECT jsonb_array_elements_text(v_indicator.indicator->'attack_techniques')), ARRAY[]::TEXT[]),
                COALESCE(ARRAY(SELECT jsonb_array_elements_text(v_indicator.indicator->'targeted_sectors')), ARRAY[]::TEXT[]),
                COALESCE(ARRAY(SELECT jsonb_array_elements_text(v_indicator.indicator->'geographic_regions')), ARRAY[]::TEXT[]),
                COALESCE((v_indicator.indicator->>'campaign_name'), ''),
                COALESCE((v_indicator.indicator->>'threat_actor'), ''),
                COALESCE((v_indicator.indicator->>'attribution_confidence')::DECIMAL(5,4), 0.3),
                'active',
                COALESCE((v_indicator.indicator->>'expiry_date')::TIMESTAMP WITH TIME ZONE, CURRENT_TIMESTAMP + INTERVAL '30 days'),
                true,
                COALESCE((v_indicator.indicator->>'reputation_score')::DECIMAL(5,4), 0.5),
                COALESCE(v_indicator.indicator->'whois_data', '{}'::JSONB),
                COALESCE(v_indicator.indicator->'dns_data', '{}'::JSONB),
                COALESCE(v_indicator.indicator->'geolocation_data', '{}'::JSONB),
                COALESCE(v_indicator.indicator->'additional_context', '{}'::JSONB),
                'threat_intelligence_system'
            );
            
            v_new_count := v_new_count + 1;
        END IF;
        
        v_processed_count := v_processed_count + 1;
    END LOOP;
    
    -- Update feed last update timestamp
    UPDATE ai_agents.threat_feed_s SET load_end_date = util.current_load_date()
    WHERE threat_feed_hk = p_feed_hk AND load_end_date IS NULL;
    
    INSERT INTO ai_agents.threat_feed_s (
        threat_feed_hk, load_date, load_end_date, hash_diff,
        feed_name, feed_provider, feed_type, feed_url, feed_format,
        update_frequency, last_update, next_update, auto_update_enabled,
        feed_reliability, confidence_threshold, false_positive_rate,
        api_key_required, authentication_method, rate_limit_per_hour,
        preprocessing_enabled, enrichment_enabled, correlation_enabled,
        feed_status, last_error, error_count, record_source
    )
    SELECT 
        threat_feed_hk, util.current_load_date(), NULL,
        util.hash_binary(encode(threat_feed_hk, 'hex') || 'UPDATED'),
        feed_name, feed_provider, feed_type, feed_url, feed_format,
        update_frequency, CURRENT_TIMESTAMP, 
        CURRENT_TIMESTAMP + update_frequency, auto_update_enabled,
        feed_reliability, confidence_threshold, false_positive_rate,
        api_key_required, authentication_method, rate_limit_per_hour,
        preprocessing_enabled, enrichment_enabled, correlation_enabled,
        'active', NULL, 0, 'threat_intelligence_system'
    FROM ai_agents.threat_feed_s
    WHERE threat_feed_hk = p_feed_hk AND load_end_date = util.current_load_date();
    
    RETURN jsonb_build_object(
        'success', true,
        'feed_id', encode(p_feed_hk, 'hex'),
        'processed_count', v_processed_count,
        'new_indicators', v_new_count,
        'updated_indicators', v_updated_count,
        'timestamp', CURRENT_TIMESTAMP
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to process threat feed: ' || SQLERRM,
        'timestamp', CURRENT_TIMESTAMP
    );
END;
$$;

-- Function to trigger automated threat response
CREATE OR REPLACE FUNCTION ai_agents.trigger_automated_response(
    p_detection_hk BYTEA,
    p_response_type VARCHAR(100),
    p_confidence_threshold DECIMAL(5,4) DEFAULT 0.90
) RETURNS JSONB
SECURITY DEFINER
SET search_path = ai_agents, auth, audit
LANGUAGE plpgsql AS $$
DECLARE
    v_response_hk BYTEA;
    v_tenant_hk BYTEA;
    v_detection_confidence DECIMAL(5,4);
    v_threat_level VARCHAR(20);
    v_auto_approved BOOLEAN := false;
BEGIN
    -- Get detection context
    SELECT tds.tenant_hk, tds.detection_confidence, tds.threat_level
    INTO v_tenant_hk, v_detection_confidence, v_threat_level
    FROM ai_agents.threat_detection_s tds
    WHERE tds.detection_hk = p_detection_hk
    AND tds.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Threat detection not found');
    END IF;
    
    -- Determine if auto-approval is appropriate
    v_auto_approved := (v_detection_confidence >= p_confidence_threshold);
    
    -- Generate response ID
    v_response_hk := util.hash_binary(
        encode(p_detection_hk, 'hex') || p_response_type || CURRENT_TIMESTAMP::text
    );
    
    -- Insert automated response hub
    INSERT INTO ai_agents.automated_response_h VALUES (
        v_response_hk,
        'RESP_' || p_response_type || '_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS'),
        v_tenant_hk,
        util.current_load_date(),
        'threat_response_system'
    );
    
    -- Insert response details
    INSERT INTO ai_agents.automated_response_s VALUES (
        v_response_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(encode(v_response_hk, 'hex') || 'PLANNED'),
        p_detection_hk,
        NULL, -- incident_hk (could be linked if incident exists)
        (SELECT soc_agent_hk FROM ai_agents.soc_agent_h LIMIT 1), -- Use first available SOC agent
        p_response_type,
        v_threat_level,
        p_confidence_threshold,
        CURRENT_TIMESTAMP,
        CASE WHEN v_auto_approved THEN CURRENT_TIMESTAMP ELSE NULL END,
        CASE WHEN v_auto_approved THEN CURRENT_TIMESTAMP + INTERVAL '5 minutes' ELSE NULL END,
        ARRAY[
            CASE p_response_type
                WHEN 'block_ip' THEN 'Add IP to firewall block list'
                WHEN 'quarantine_agent' THEN 'Isolate agent from network'
                WHEN 'revoke_session' THEN 'Terminate active sessions'
                ELSE 'Execute security response'
            END
        ], -- actions_planned
        CASE WHEN v_auto_approved THEN ARRAY['Response auto-approved and initiated'] ELSE ARRAY[]::TEXT[] END,
        ARRAY[]::TEXT[], -- actions_failed
        ARRAY[
            CASE p_response_type
                WHEN 'block_ip' THEN 'Remove IP from block list'
                WHEN 'quarantine_agent' THEN 'Restore agent network access'
                WHEN 'revoke_session' THEN 'Allow new session creation'
                ELSE 'Reverse security response'
            END
        ], -- rollback_actions
        CASE WHEN v_auto_approved THEN 'executing' ELSE 'planned' END,
        CASE WHEN v_auto_approved THEN 1.0 ELSE NULL END, -- success_rate
        NULL, -- effectiveness_score (to be calculated later)
        ARRAY[]::TEXT[], -- unintended_consequences
        v_auto_approved,
        NOT v_auto_approved, -- manual_approval_required
        CASE WHEN v_auto_approved THEN 'system_auto_approval' ELSE NULL END,
        CASE WHEN v_auto_approved THEN CURRENT_TIMESTAMP ELSE NULL END,
        NULL, -- override_reason
        ARRAY[
            CASE p_response_type
                WHEN 'block_ip' THEN 'firewall_system'
                WHEN 'quarantine_agent' THEN 'network_isolation_system'
                WHEN 'revoke_session' THEN 'session_management_system'
                ELSE 'security_system'
            END
        ], -- systems_affected
        0, -- users_impacted (to be calculated)
        NULL, -- downtime_duration
        'Automated threat response to protect system security', -- business_impact_assessment
        true, -- monitoring_enabled
        ARRAY['Verify response effectiveness', 'Monitor for false positives'], -- validation_checks
        false, -- rollback_triggered
        NULL, -- rollback_reason
        'threat_response_system'
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'response_id', encode(v_response_hk, 'hex'),
        'response_type', p_response_type,
        'auto_approved', v_auto_approved,
        'detection_confidence', v_detection_confidence,
        'threat_level', v_threat_level,
        'status', CASE WHEN v_auto_approved THEN 'executing' ELSE 'awaiting_approval' END,
        'timestamp', CURRENT_TIMESTAMP
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to trigger automated response: ' || SQLERRM,
        'timestamp', CURRENT_TIMESTAMP
    );
END;
$$;

-- Create indexes for performance
CREATE INDEX idx_threat_feed_h_tenant_hk ON ai_agents.threat_feed_h(tenant_hk);
CREATE INDEX idx_threat_feed_s_provider ON ai_agents.threat_feed_s(feed_provider) WHERE load_end_date IS NULL;
CREATE INDEX idx_threat_feed_s_status ON ai_agents.threat_feed_s(feed_status) WHERE load_end_date IS NULL;
CREATE INDEX idx_threat_indicator_h_tenant_hk ON ai_agents.threat_indicator_h(tenant_hk);
CREATE INDEX idx_threat_indicator_s_type ON ai_agents.threat_indicator_s(indicator_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_threat_indicator_s_category ON ai_agents.threat_indicator_s(threat_category) WHERE load_end_date IS NULL;
CREATE INDEX idx_threat_indicator_s_severity ON ai_agents.threat_indicator_s(threat_severity) WHERE load_end_date IS NULL;
CREATE INDEX idx_threat_indicator_s_status ON ai_agents.threat_indicator_s(indicator_status) WHERE load_end_date IS NULL;
CREATE INDEX idx_threat_detection_h_tenant_hk ON ai_agents.threat_detection_h(tenant_hk);
CREATE INDEX idx_threat_detection_s_agent ON ai_agents.threat_detection_s(detecting_agent_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_threat_detection_s_level ON ai_agents.threat_detection_s(threat_level) WHERE load_end_date IS NULL;
CREATE INDEX idx_threat_detection_s_status ON ai_agents.threat_detection_s(investigation_status) WHERE load_end_date IS NULL;
CREATE INDEX idx_security_incident_h_tenant_hk ON ai_agents.security_incident_h(tenant_hk);
CREATE INDEX idx_security_incident_s_number ON ai_agents.security_incident_s(incident_number) WHERE load_end_date IS NULL;
CREATE INDEX idx_security_incident_s_severity ON ai_agents.security_incident_s(incident_severity) WHERE load_end_date IS NULL;
CREATE INDEX idx_security_incident_s_status ON ai_agents.security_incident_s(incident_status) WHERE load_end_date IS NULL;
CREATE INDEX idx_automated_response_h_tenant_hk ON ai_agents.automated_response_h(tenant_hk);
CREATE INDEX idx_automated_response_s_detection ON ai_agents.automated_response_s(detection_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_automated_response_s_type ON ai_agents.automated_response_s(response_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_automated_response_s_status ON ai_agents.automated_response_s(response_status) WHERE load_end_date IS NULL;

-- Comments
COMMENT ON TABLE ai_agents.threat_feed_h IS 'Hub table for external threat intelligence feed sources';
COMMENT ON TABLE ai_agents.threat_feed_s IS 'Threat feed configuration including update schedules and quality metrics';
COMMENT ON TABLE ai_agents.threat_indicator_h IS 'Hub table for threat indicators from various intelligence sources';
COMMENT ON TABLE ai_agents.threat_indicator_s IS 'Threat indicator details including IOCs, malware signatures, and attribution data';
COMMENT ON TABLE ai_agents.threat_detection_h IS 'Hub table for threat detections triggered by agent activities';
COMMENT ON TABLE ai_agents.threat_detection_s IS 'Threat detection details including analysis results and investigation status';
COMMENT ON TABLE ai_agents.security_incident_h IS 'Hub table for security incidents requiring investigation and response';
COMMENT ON TABLE ai_agents.security_incident_s IS 'Security incident details including timeline, impact assessment, and response actions';
COMMENT ON TABLE ai_agents.automated_response_h IS 'Hub table for automated threat response actions';
COMMENT ON TABLE ai_agents.automated_response_s IS 'Automated response details including execution status and effectiveness metrics';

COMMENT ON FUNCTION ai_agents.process_threat_feed_update IS 'Processes threat intelligence feed updates with indicator management and enrichment';
COMMENT ON FUNCTION ai_agents.trigger_automated_response IS 'Triggers automated security responses based on threat detections with approval workflows';

COMMIT; 