-- =====================================================================================
-- Step 11: Security Hardening Infrastructure
-- Multi-Tenant Data Vault 2.0 SaaS Platform - Production Ready
-- =====================================================================================
-- Purpose: Advanced security monitoring, threat detection, and security policy management
-- Author: One Vault Development Team
-- Created: 2024
-- =====================================================================================

-- Security hardening schema
CREATE SCHEMA IF NOT EXISTS security_hardening;

-- =====================================================================================
-- SECURITY POLICY MANAGEMENT
-- =====================================================================================

-- Security policy hub
CREATE TABLE security_hardening.security_policy_h (
    security_policy_hk BYTEA PRIMARY KEY,
    security_policy_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'SECURITY_HARDENING_SYSTEM'
);

-- Security policy details satellite
CREATE TABLE security_hardening.security_policy_s (
    security_policy_hk BYTEA NOT NULL REFERENCES security_hardening.security_policy_h(security_policy_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    policy_name VARCHAR(200) NOT NULL,
    policy_category VARCHAR(50) NOT NULL,        -- ACCESS_CONTROL, ENCRYPTION, AUTHENTICATION, AUTHORIZATION
    policy_type VARCHAR(50) NOT NULL,            -- PREVENTIVE, DETECTIVE, CORRECTIVE, COMPENSATING
    policy_description TEXT,
    policy_rules JSONB NOT NULL,                 -- Detailed policy rules and conditions
    enforcement_level VARCHAR(20) DEFAULT 'STRICT', -- STRICT, MODERATE, ADVISORY
    compliance_frameworks TEXT[],                -- HIPAA, GDPR, SOX, PCI_DSS, SOC2
    violation_action VARCHAR(50) DEFAULT 'BLOCK', -- BLOCK, ALERT, LOG, QUARANTINE
    is_active BOOLEAN DEFAULT true,
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    approved_by VARCHAR(100),
    approval_date TIMESTAMP WITH TIME ZONE,
    review_frequency INTERVAL DEFAULT '90 days',
    next_review_date DATE,
    record_source VARCHAR(100) NOT NULL DEFAULT 'SECURITY_HARDENING_SYSTEM',
    PRIMARY KEY (security_policy_hk, load_date)
);

-- =====================================================================================
-- THREAT DETECTION SYSTEM
-- =====================================================================================

-- Threat detection hub
CREATE TABLE security_hardening.threat_detection_h (
    threat_detection_hk BYTEA PRIMARY KEY,
    threat_detection_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'THREAT_DETECTION_SYSTEM'
);

-- Threat detection details satellite
CREATE TABLE security_hardening.threat_detection_s (
    threat_detection_hk BYTEA NOT NULL REFERENCES security_hardening.threat_detection_h(threat_detection_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    detection_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    threat_type VARCHAR(100) NOT NULL,           -- BRUTE_FORCE, SQL_INJECTION, XSS, PRIVILEGE_ESCALATION
    threat_severity VARCHAR(20) NOT NULL,        -- LOW, MEDIUM, HIGH, CRITICAL
    threat_source VARCHAR(100),                  -- IP address or source identifier
    threat_target VARCHAR(100),                  -- Target resource or user
    detection_method VARCHAR(100),               -- RULE_BASED, ML_ANOMALY, SIGNATURE, BEHAVIORAL
    threat_indicators JSONB,                     -- IOCs and threat intelligence
    confidence_score DECIMAL(5,2),               -- 0-100% confidence in detection
    false_positive_probability DECIMAL(5,2),    -- Estimated false positive rate
    mitigation_actions TEXT[],                   -- Actions taken or recommended
    investigation_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, INVESTIGATING, RESOLVED, FALSE_POSITIVE
    assigned_to VARCHAR(100),
    resolution_notes TEXT,
    resolved_date TIMESTAMP WITH TIME ZONE,
    record_source VARCHAR(100) NOT NULL DEFAULT 'THREAT_DETECTION_SYSTEM',
    PRIMARY KEY (threat_detection_hk, load_date)
);

-- =====================================================================================
-- SECURITY VULNERABILITY MANAGEMENT
-- =====================================================================================

-- Security vulnerability hub
CREATE TABLE security_hardening.security_vulnerability_h (
    vulnerability_hk BYTEA PRIMARY KEY,
    vulnerability_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide vulnerabilities
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'VULNERABILITY_SCANNER'
);

-- Security vulnerability details satellite
CREATE TABLE security_hardening.security_vulnerability_s (
    vulnerability_hk BYTEA NOT NULL REFERENCES security_hardening.security_vulnerability_h(vulnerability_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    vulnerability_id VARCHAR(100) NOT NULL,      -- CVE ID or internal ID
    vulnerability_name VARCHAR(200) NOT NULL,
    vulnerability_description TEXT,
    cvss_score DECIMAL(3,1),                     -- CVSS 3.1 score (0.0-10.0)
    cvss_vector VARCHAR(100),                    -- CVSS vector string
    severity_level VARCHAR(20) NOT NULL,         -- LOW, MEDIUM, HIGH, CRITICAL
    affected_component VARCHAR(200),             -- Database, application, OS, etc.
    affected_version VARCHAR(100),
    discovery_date TIMESTAMP WITH TIME ZONE NOT NULL,
    disclosure_date TIMESTAMP WITH TIME ZONE,
    patch_available BOOLEAN DEFAULT false,
    patch_version VARCHAR(100),
    patch_release_date TIMESTAMP WITH TIME ZONE,
    remediation_status VARCHAR(20) DEFAULT 'OPEN', -- OPEN, IN_PROGRESS, PATCHED, MITIGATED, ACCEPTED
    remediation_priority VARCHAR(20),            -- LOW, MEDIUM, HIGH, URGENT
    remediation_deadline DATE,
    remediation_notes TEXT,
    business_impact_assessment TEXT,
    compensating_controls TEXT[],
    assigned_to VARCHAR(100),
    record_source VARCHAR(100) NOT NULL DEFAULT 'VULNERABILITY_SCANNER',
    PRIMARY KEY (vulnerability_hk, load_date)
);

-- =====================================================================================
-- SECURITY INCIDENT RESPONSE
-- =====================================================================================

-- Security incident hub
CREATE TABLE security_hardening.security_incident_h (
    security_incident_hk BYTEA PRIMARY KEY,
    security_incident_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'INCIDENT_RESPONSE_SYSTEM'
);

-- Security incident details satellite
CREATE TABLE security_hardening.security_incident_s (
    security_incident_hk BYTEA NOT NULL REFERENCES security_hardening.security_incident_h(security_incident_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    incident_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    incident_type VARCHAR(100) NOT NULL,         -- DATA_BREACH, UNAUTHORIZED_ACCESS, MALWARE, DDOS
    incident_severity VARCHAR(20) NOT NULL,      -- LOW, MEDIUM, HIGH, CRITICAL
    incident_status VARCHAR(20) DEFAULT 'OPEN', -- OPEN, INVESTIGATING, CONTAINED, RESOLVED, CLOSED
    incident_description TEXT NOT NULL,
    affected_systems TEXT[],                     -- List of affected systems/components
    affected_users INTEGER DEFAULT 0,           -- Number of users affected
    affected_records INTEGER DEFAULT 0,         -- Number of records affected
    data_types_affected TEXT[],                  -- PII, PHI, Financial, etc.
    detection_method VARCHAR(100),               -- How incident was detected
    detection_timestamp TIMESTAMP WITH TIME ZONE,
    containment_timestamp TIMESTAMP WITH TIME ZONE,
    eradication_timestamp TIMESTAMP WITH TIME ZONE,
    recovery_timestamp TIMESTAMP WITH TIME ZONE,
    incident_commander VARCHAR(100),
    response_team TEXT[],                        -- List of response team members
    external_notifications_required BOOLEAN DEFAULT false,
    regulatory_notifications TEXT[],             -- Which regulators notified
    customer_notification_required BOOLEAN DEFAULT false,
    customer_notification_sent TIMESTAMP WITH TIME ZONE,
    forensic_analysis_required BOOLEAN DEFAULT false,
    forensic_findings TEXT,
    lessons_learned TEXT,
    preventive_measures TEXT[],
    estimated_cost DECIMAL(15,2),
    business_impact_hours DECIMAL(8,2),
    record_source VARCHAR(100) NOT NULL DEFAULT 'INCIDENT_RESPONSE_SYSTEM',
    PRIMARY KEY (security_incident_hk, load_date)
);

-- =====================================================================================
-- SECURITY COMPLIANCE TRACKING
-- =====================================================================================

-- Compliance framework hub
CREATE TABLE security_hardening.compliance_framework_h (
    compliance_framework_hk BYTEA PRIMARY KEY,
    compliance_framework_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide frameworks
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'COMPLIANCE_SYSTEM'
);

-- Compliance framework details satellite
CREATE TABLE security_hardening.compliance_framework_s (
    compliance_framework_hk BYTEA NOT NULL REFERENCES security_hardening.compliance_framework_h(compliance_framework_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    framework_name VARCHAR(100) NOT NULL,        -- HIPAA, GDPR, SOX, PCI_DSS, SOC2, ISO27001
    framework_version VARCHAR(50),
    framework_description TEXT,
    applicable_controls JSONB NOT NULL,          -- List of applicable controls
    assessment_frequency INTERVAL DEFAULT '1 year',
    last_assessment_date DATE,
    next_assessment_due DATE,
    current_compliance_score DECIMAL(5,2),      -- 0-100% compliance score
    compliance_status VARCHAR(20) DEFAULT 'IN_PROGRESS', -- COMPLIANT, NON_COMPLIANT, IN_PROGRESS
    gaps_identified TEXT[],                      -- List of compliance gaps
    remediation_plan TEXT,
    remediation_deadline DATE,
    assessor_name VARCHAR(100),
    assessment_report_location TEXT,
    certification_status VARCHAR(20),            -- CERTIFIED, PENDING, EXPIRED, NOT_APPLICABLE
    certification_expiry_date DATE,
    annual_review_required BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL DEFAULT 'COMPLIANCE_SYSTEM',
    PRIMARY KEY (compliance_framework_hk, load_date)
);

-- =====================================================================================
-- SECURITY AUDIT TRAIL
-- =====================================================================================

-- Security audit hub
CREATE TABLE security_hardening.security_audit_h (
    security_audit_hk BYTEA PRIMARY KEY,
    security_audit_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'SECURITY_AUDIT_SYSTEM'
);

-- Security audit details satellite
CREATE TABLE security_hardening.security_audit_s (
    security_audit_hk BYTEA NOT NULL REFERENCES security_hardening.security_audit_h(security_audit_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    audit_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    audit_event_type VARCHAR(100) NOT NULL,      -- LOGIN, LOGOUT, DATA_ACCESS, PERMISSION_CHANGE
    user_identifier VARCHAR(255),               -- User who performed the action
    source_ip INET,                             -- Source IP address
    user_agent TEXT,                            -- Browser/client information
    session_id VARCHAR(255),                    -- Session identifier
    resource_accessed VARCHAR(255),             -- What resource was accessed
    action_performed VARCHAR(100),              -- CREATE, READ, UPDATE, DELETE, EXECUTE
    action_result VARCHAR(20),                  -- SUCCESS, FAILURE, BLOCKED
    risk_score DECIMAL(5,2),                    -- Calculated risk score for the action
    anomaly_indicators JSONB,                   -- Anomaly detection results
    geolocation JSONB,                          -- Geographic location data
    device_fingerprint VARCHAR(255),            -- Device identification
    authentication_method VARCHAR(50),          -- PASSWORD, MFA, SSO, API_KEY
    authorization_context JSONB,                -- Authorization details
    data_classification VARCHAR(50),            -- Classification of accessed data
    retention_period INTERVAL DEFAULT '7 years', -- How long to retain this audit record
    record_source VARCHAR(100) NOT NULL DEFAULT 'SECURITY_AUDIT_SYSTEM',
    PRIMARY KEY (security_audit_hk, load_date)
);

-- =====================================================================================
-- PERFORMANCE INDEXES
-- =====================================================================================

-- Security policy indexes
CREATE INDEX idx_security_policy_h_tenant_hk ON security_hardening.security_policy_h(tenant_hk);
CREATE INDEX idx_security_policy_s_active ON security_hardening.security_policy_s(is_active) WHERE is_active = true;
CREATE INDEX idx_security_policy_s_category ON security_hardening.security_policy_s(policy_category);
CREATE INDEX idx_security_policy_s_review_date ON security_hardening.security_policy_s(next_review_date);

-- Threat detection indexes
CREATE INDEX idx_threat_detection_h_tenant_hk ON security_hardening.threat_detection_h(tenant_hk);
CREATE INDEX idx_threat_detection_s_timestamp ON security_hardening.threat_detection_s(detection_timestamp);
CREATE INDEX idx_threat_detection_s_severity ON security_hardening.threat_detection_s(threat_severity);
CREATE INDEX idx_threat_detection_s_type ON security_hardening.threat_detection_s(threat_type);
CREATE INDEX idx_threat_detection_s_status ON security_hardening.threat_detection_s(investigation_status);
CREATE INDEX idx_threat_detection_s_source ON security_hardening.threat_detection_s(threat_source);

-- Vulnerability indexes
CREATE INDEX idx_vulnerability_h_tenant_hk ON security_hardening.security_vulnerability_h(tenant_hk);
CREATE INDEX idx_vulnerability_s_severity ON security_hardening.security_vulnerability_s(severity_level);
CREATE INDEX idx_vulnerability_s_status ON security_hardening.security_vulnerability_s(remediation_status);
CREATE INDEX idx_vulnerability_s_cvss ON security_hardening.security_vulnerability_s(cvss_score);
CREATE INDEX idx_vulnerability_s_deadline ON security_hardening.security_vulnerability_s(remediation_deadline);

-- Security incident indexes
CREATE INDEX idx_security_incident_h_tenant_hk ON security_hardening.security_incident_h(tenant_hk);
CREATE INDEX idx_security_incident_s_timestamp ON security_hardening.security_incident_s(incident_timestamp);
CREATE INDEX idx_security_incident_s_severity ON security_hardening.security_incident_s(incident_severity);
CREATE INDEX idx_security_incident_s_status ON security_hardening.security_incident_s(incident_status);
CREATE INDEX idx_security_incident_s_type ON security_hardening.security_incident_s(incident_type);

-- Compliance framework indexes
CREATE INDEX idx_compliance_framework_h_tenant_hk ON security_hardening.compliance_framework_h(tenant_hk);
CREATE INDEX idx_compliance_framework_s_name ON security_hardening.compliance_framework_s(framework_name);
CREATE INDEX idx_compliance_framework_s_status ON security_hardening.compliance_framework_s(compliance_status);
CREATE INDEX idx_compliance_framework_s_assessment_due ON security_hardening.compliance_framework_s(next_assessment_due);

-- Security audit indexes
CREATE INDEX idx_security_audit_h_tenant_hk ON security_hardening.security_audit_h(tenant_hk);
CREATE INDEX idx_security_audit_s_timestamp ON security_hardening.security_audit_s(audit_timestamp);
CREATE INDEX idx_security_audit_s_user ON security_hardening.security_audit_s(user_identifier);
CREATE INDEX idx_security_audit_s_event_type ON security_hardening.security_audit_s(audit_event_type);
CREATE INDEX idx_security_audit_s_source_ip ON security_hardening.security_audit_s(source_ip);
CREATE INDEX idx_security_audit_s_risk_score ON security_hardening.security_audit_s(risk_score);

-- =====================================================================================
-- SECURITY HARDENING FUNCTIONS
-- =====================================================================================

-- Function to create security policy
CREATE OR REPLACE FUNCTION security_hardening.create_security_policy(
    p_tenant_hk BYTEA,
    p_policy_name VARCHAR(200),
    p_policy_category VARCHAR(50),
    p_policy_type VARCHAR(50),
    p_policy_rules JSONB,
    p_enforcement_level VARCHAR(20) DEFAULT 'STRICT'
) RETURNS BYTEA AS $$
DECLARE
    v_policy_hk BYTEA;
    v_policy_bk VARCHAR(255);
BEGIN
    v_policy_bk := p_policy_category || '_' || p_policy_name || '_' || encode(p_tenant_hk, 'hex');
    v_policy_hk := util.hash_binary(v_policy_bk);
    
    -- Insert hub record
    INSERT INTO security_hardening.security_policy_h VALUES (
        v_policy_hk, v_policy_bk, p_tenant_hk,
        util.current_load_date(), 'SECURITY_POLICY_MANAGER'
    ) ON CONFLICT DO NOTHING;
    
    -- Insert satellite record
    INSERT INTO security_hardening.security_policy_s VALUES (
        v_policy_hk, util.current_load_date(), NULL,
        util.hash_binary(p_policy_name || p_policy_rules::text),
        p_policy_name, p_policy_category, p_policy_type,
        'Security policy for ' || p_policy_category,
        p_policy_rules, p_enforcement_level,
        ARRAY['HIPAA', 'GDPR'], 'BLOCK', true,
        SESSION_USER, NULL, NULL, '90 days',
        CURRENT_DATE + INTERVAL '90 days',
        'SECURITY_POLICY_MANAGER'
    );
    
    RETURN v_policy_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to log threat detection
CREATE OR REPLACE FUNCTION security_hardening.log_threat_detection(
    p_tenant_hk BYTEA,
    p_threat_type VARCHAR(100),
    p_threat_severity VARCHAR(20),
    p_threat_source VARCHAR(100),
    p_threat_indicators JSONB DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_threat_hk BYTEA;
    v_threat_bk VARCHAR(255);
    v_confidence_score DECIMAL(5,2);
BEGIN
    v_threat_bk := p_threat_type || '_' || p_threat_source || '_' || 
                   to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS_US');
    v_threat_hk := util.hash_binary(v_threat_bk);
    
    -- Calculate confidence score based on threat type and indicators
    v_confidence_score := CASE p_threat_type
        WHEN 'BRUTE_FORCE' THEN 85.0
        WHEN 'SQL_INJECTION' THEN 90.0
        WHEN 'XSS' THEN 80.0
        ELSE 70.0
    END;
    
    -- Insert hub record
    INSERT INTO security_hardening.threat_detection_h VALUES (
        v_threat_hk, v_threat_bk, p_tenant_hk,
        util.current_load_date(), 'THREAT_DETECTION_ENGINE'
    );
    
    -- Insert satellite record
    INSERT INTO security_hardening.threat_detection_s VALUES (
        v_threat_hk, util.current_load_date(), NULL,
        util.hash_binary(v_threat_bk || p_threat_severity),
        CURRENT_TIMESTAMP, p_threat_type, p_threat_severity,
        p_threat_source, NULL, 'RULE_BASED',
        COALESCE(p_threat_indicators, '{}'::jsonb),
        v_confidence_score, 15.0,
        ARRAY['ALERT_SECURITY_TEAM', 'BLOCK_SOURCE_IP'],
        'PENDING', NULL, NULL, NULL,
        'THREAT_DETECTION_ENGINE'
    );
    
    -- Trigger alert if severity is HIGH or CRITICAL
    IF p_threat_severity IN ('HIGH', 'CRITICAL') THEN
        PERFORM pg_notify('security_threat_detected', jsonb_build_object(
            'threat_hk', encode(v_threat_hk, 'hex'),
            'threat_type', p_threat_type,
            'severity', p_threat_severity,
            'source', p_threat_source,
            'tenant_hk', encode(p_tenant_hk, 'hex')
        )::text);
    END IF;
    
    RETURN v_threat_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to log security audit event
CREATE OR REPLACE FUNCTION security_hardening.log_security_audit(
    p_tenant_hk BYTEA,
    p_audit_event_type VARCHAR(100),
    p_user_identifier VARCHAR(255),
    p_resource_accessed VARCHAR(255),
    p_action_performed VARCHAR(100),
    p_action_result VARCHAR(20) DEFAULT 'SUCCESS',
    p_source_ip INET DEFAULT NULL,
    p_session_id VARCHAR(255) DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_audit_hk BYTEA;
    v_audit_bk VARCHAR(255);
    v_risk_score DECIMAL(5,2);
BEGIN
    v_audit_bk := p_audit_event_type || '_' || p_user_identifier || '_' || 
                  to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS_US');
    v_audit_hk := util.hash_binary(v_audit_bk);
    
    -- Calculate risk score based on event type and result
    v_risk_score := CASE 
        WHEN p_action_result = 'FAILURE' THEN 75.0
        WHEN p_audit_event_type = 'PERMISSION_CHANGE' THEN 60.0
        WHEN p_audit_event_type = 'DATA_ACCESS' THEN 40.0
        ELSE 20.0
    END;
    
    -- Insert hub record
    INSERT INTO security_hardening.security_audit_h VALUES (
        v_audit_hk, v_audit_bk, p_tenant_hk,
        util.current_load_date(), 'SECURITY_AUDIT_LOGGER'
    );
    
    -- Insert satellite record
    INSERT INTO security_hardening.security_audit_s VALUES (
        v_audit_hk, util.current_load_date(), NULL,
        util.hash_binary(v_audit_bk || p_action_result),
        CURRENT_TIMESTAMP, p_audit_event_type, p_user_identifier,
        p_source_ip, NULL, p_session_id,
        p_resource_accessed, p_action_performed, p_action_result,
        v_risk_score, '{}'::jsonb, '{}'::jsonb, NULL,
        'PASSWORD', '{}'::jsonb, 'INTERNAL',
        '7 years', 'SECURITY_AUDIT_LOGGER'
    );
    
    RETURN v_audit_hk;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- SECURITY DASHBOARD VIEWS
-- =====================================================================================

-- Security overview dashboard
CREATE VIEW security_hardening.security_dashboard AS
SELECT 
    'Active Security Policies' as metric_name,
    COUNT(*) as current_value,
    'count' as unit,
    'SECURITY' as category
FROM security_hardening.security_policy_s 
WHERE is_active = true AND load_end_date IS NULL

UNION ALL

SELECT 
    'Open Threats (Last 24h)',
    COUNT(*),
    'count',
    'THREATS'
FROM security_hardening.threat_detection_s 
WHERE detection_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
AND investigation_status IN ('PENDING', 'INVESTIGATING')
AND load_end_date IS NULL

UNION ALL

SELECT 
    'Critical Vulnerabilities',
    COUNT(*),
    'count',
    'VULNERABILITIES'
FROM security_hardening.security_vulnerability_s 
WHERE severity_level = 'CRITICAL'
AND remediation_status IN ('OPEN', 'IN_PROGRESS')
AND load_end_date IS NULL

UNION ALL

SELECT 
    'Open Security Incidents',
    COUNT(*),
    'count',
    'INCIDENTS'
FROM security_hardening.security_incident_s 
WHERE incident_status IN ('OPEN', 'INVESTIGATING', 'CONTAINED')
AND load_end_date IS NULL

UNION ALL

SELECT 
    'Compliance Score (%)',
    ROUND(AVG(current_compliance_score), 1),
    'percentage',
    'COMPLIANCE'
FROM security_hardening.compliance_framework_s 
WHERE compliance_status = 'COMPLIANT'
AND load_end_date IS NULL;

-- Comments for documentation
COMMENT ON SCHEMA security_hardening IS 'Advanced security hardening infrastructure for threat detection, vulnerability management, incident response, and compliance automation';

COMMENT ON TABLE security_hardening.security_policy_h IS 'Hub table for security policies with tenant isolation and Data Vault 2.0 structure';
COMMENT ON TABLE security_hardening.threat_detection_h IS 'Hub table for threat detection events with comprehensive threat intelligence tracking';
COMMENT ON TABLE security_hardening.security_vulnerability_h IS 'Hub table for security vulnerabilities with CVSS scoring and remediation tracking';
COMMENT ON TABLE security_hardening.security_incident_h IS 'Hub table for security incidents with full incident response lifecycle management';
COMMENT ON TABLE security_hardening.compliance_framework_h IS 'Hub table for compliance frameworks with automated assessment and reporting';
COMMENT ON TABLE security_hardening.security_audit_h IS 'Hub table for security audit events with comprehensive audit trail and risk scoring';

COMMENT ON VIEW security_hardening.security_dashboard IS 'Real-time security dashboard showing key security metrics, threats, vulnerabilities, incidents, and compliance status'; 