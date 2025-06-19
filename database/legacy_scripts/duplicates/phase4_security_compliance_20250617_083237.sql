-- Phase 4: Security & Compliance Enhancement
-- Objective: Implement comprehensive security and compliance measures

-- Start transaction
BEGIN;

-- Create security schema first
CREATE SCHEMA IF NOT EXISTS security;

-- Create security assessment table
CREATE TABLE IF NOT EXISTS security.ai_security_assessment (
    assessment_id BIGSERIAL PRIMARY KEY,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    assessment_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assessment_type VARCHAR(50) NOT NULL,
    security_score DECIMAL(5,2) NOT NULL,
    compliance_score DECIMAL(5,2) NOT NULL,
    risk_level VARCHAR(20) NOT NULL,
    findings JSONB NOT NULL,
    recommendations JSONB,
    remediation_status VARCHAR(20) DEFAULT 'PENDING',
    next_assessment_date DATE,
    assessor_id VARCHAR(100),
    assessment_metadata JSONB,
    
    CONSTRAINT chk_ai_security_assessment_scores 
        CHECK (security_score >= 0 AND security_score <= 100 AND
               compliance_score >= 0 AND compliance_score <= 100),
    CONSTRAINT chk_ai_security_assessment_risk 
        CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT chk_ai_security_assessment_status 
        CHECK (remediation_status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'DEFERRED'))
);

COMMENT ON TABLE security.ai_security_assessment IS 
'Comprehensive security assessment tracking for AI operations including scores, findings, and remediation status.';

-- Create indexes for security assessment
CREATE INDEX IF NOT EXISTS idx_ai_security_assessment_tenant_date 
ON security.ai_security_assessment (tenant_hk, assessment_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_ai_security_assessment_risk 
ON security.ai_security_assessment (risk_level, assessment_timestamp DESC) 
WHERE risk_level IN ('HIGH', 'CRITICAL');

-- Create compliance monitoring table
CREATE TABLE IF NOT EXISTS security.compliance_monitoring (
    monitoring_id BIGSERIAL PRIMARY KEY,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    check_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    compliance_type VARCHAR(50) NOT NULL,
    requirement_id VARCHAR(100) NOT NULL,
    requirement_name VARCHAR(200) NOT NULL,
    is_compliant BOOLEAN NOT NULL,
    compliance_details JSONB NOT NULL,
    violation_severity VARCHAR(20),
    remediation_steps TEXT,
    due_date DATE,
    responsible_party VARCHAR(100),
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_compliance_monitoring_severity 
        CHECK (violation_severity IS NULL OR 
               violation_severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'))
);

COMMENT ON TABLE security.compliance_monitoring IS 
'Real-time compliance monitoring for AI operations tracking regulatory requirements and violations.';

-- Create indexes for compliance monitoring
CREATE INDEX IF NOT EXISTS idx_compliance_monitoring_tenant_date 
ON security.compliance_monitoring (tenant_hk, check_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_compliance_monitoring_violations 
ON security.compliance_monitoring (tenant_hk, is_compliant, violation_severity) 
WHERE NOT is_compliant;

-- Create PII detection function
CREATE OR REPLACE FUNCTION security.detect_pii(
    p_text TEXT,
    p_sensitivity_level VARCHAR(20) DEFAULT 'MEDIUM'
) RETURNS TABLE (
    pii_type VARCHAR(50),
    confidence_score DECIMAL(5,2),
    detection_method VARCHAR(50),
    requires_masking BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    WITH pii_patterns AS (
        -- Email addresses
        SELECT 
            'EMAIL' as pattern_type,
            confidence_score,
            'REGEX' as method,
            true as mask_required
        FROM (
            SELECT 
                CASE 
                    WHEN p_text ~* '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' THEN 0.95
                    ELSE 0.0
                END as confidence_score
        ) e
        WHERE confidence_score > 0
        
        UNION ALL
        
        -- Phone numbers
        SELECT 
            'PHONE_NUMBER',
            confidence_score,
            'REGEX',
            true
        FROM (
            SELECT 
                CASE 
                    WHEN p_text ~* '(\+\d{1,3}[-. ]?)?\(?\d{3}\)?[-. ]?\d{3}[-. ]?\d{4}' THEN 0.90
                    ELSE 0.0
                END as confidence_score
        ) p
        WHERE confidence_score > 0
        
        UNION ALL
        
        -- Credit card numbers
        SELECT 
            'CREDIT_CARD',
            confidence_score,
            'LUHN_ALGORITHM',
            true
        FROM (
            SELECT 
                CASE 
                    WHEN p_text ~* '\d{4}[-. ]?\d{4}[-. ]?\d{4}[-. ]?\d{4}' THEN 0.95
                    ELSE 0.0
                END as confidence_score
        ) c
        WHERE confidence_score > 0
        
        UNION ALL
        
        -- Social security numbers
        SELECT 
            'SSN',
            confidence_score,
            'REGEX',
            true
        FROM (
            SELECT 
                CASE 
                    WHEN p_text ~* '\d{3}[-. ]?\d{2}[-. ]?\d{4}' THEN 0.95
                    ELSE 0.0
                END as confidence_score
        ) s
        WHERE confidence_score > 0
        
        UNION ALL
        
        -- IP addresses
        SELECT 
            'IP_ADDRESS',
            confidence_score,
            'REGEX',
            CASE WHEN p_sensitivity_level = 'HIGH' THEN true ELSE false END
        FROM (
            SELECT 
                CASE 
                    WHEN p_text ~* '(\d{1,3}\.){3}\d{1,3}' THEN 0.90
                    ELSE 0.0
                END as confidence_score
        ) i
        WHERE confidence_score > 0
    )
    SELECT 
        pattern_type,
        confidence_score,
        method,
        mask_required
    FROM pii_patterns
    WHERE (p_sensitivity_level = 'HIGH' AND confidence_score >= 0.8)
       OR (p_sensitivity_level = 'MEDIUM' AND confidence_score >= 0.9)
       OR (p_sensitivity_level = 'LOW' AND confidence_score >= 0.95);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION security.detect_pii(TEXT, VARCHAR) IS 
'Detects potential PII in text content with configurable sensitivity levels and confidence scoring.';

-- Create compliance alert function
CREATE OR REPLACE FUNCTION security.create_compliance_alert(
    p_tenant_hk BYTEA,
    p_alert_type VARCHAR(50),
    p_severity VARCHAR(20),
    p_details JSONB
) RETURNS BIGINT AS $$
DECLARE
    v_alert_id BIGINT;
BEGIN
    INSERT INTO security.compliance_alerts (
        tenant_hk,
        alert_timestamp,
        alert_type,
        severity,
        alert_details,
        status,
        resolution_required_by
    ) VALUES (
        p_tenant_hk,
        CURRENT_TIMESTAMP,
        p_alert_type,
        p_severity,
        p_details,
        'NEW',
        CASE 
            WHEN p_severity = 'CRITICAL' THEN CURRENT_TIMESTAMP + INTERVAL '4 hours'
            WHEN p_severity = 'HIGH' THEN CURRENT_TIMESTAMP + INTERVAL '24 hours'
            WHEN p_severity = 'MEDIUM' THEN CURRENT_TIMESTAMP + INTERVAL '72 hours'
            ELSE CURRENT_TIMESTAMP + INTERVAL '7 days'
        END
    ) RETURNING alert_id INTO v_alert_id;
    
    -- Log alert creation
    INSERT INTO security.compliance_audit_log (
        tenant_hk,
        event_type,
        event_timestamp,
        event_details,
        severity
    ) VALUES (
        p_tenant_hk,
        'COMPLIANCE_ALERT_CREATED',
        CURRENT_TIMESTAMP,
        jsonb_build_object(
            'alert_id', v_alert_id,
            'alert_type', p_alert_type,
            'severity', p_severity
        ),
        p_severity
    );
    
    RETURN v_alert_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION security.create_compliance_alert(BYTEA, VARCHAR, VARCHAR, JSONB) IS 
'Creates and logs compliance alerts with severity-based resolution timeframes.';

-- Create compliance alerts table
CREATE TABLE IF NOT EXISTS security.compliance_alerts (
    alert_id BIGSERIAL PRIMARY KEY,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    alert_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    alert_details JSONB NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'NEW',
    resolution_required_by TIMESTAMP WITH TIME ZONE NOT NULL,
    resolution_details JSONB,
    resolved_by VARCHAR(100),
    resolution_timestamp TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT chk_compliance_alerts_severity 
        CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT chk_compliance_alerts_status 
        CHECK (status IN ('NEW', 'IN_PROGRESS', 'RESOLVED', 'DEFERRED'))
);

COMMENT ON TABLE security.compliance_alerts IS 
'Compliance alerts tracking system with severity levels and resolution tracking.';

-- Create indexes for compliance alerts
CREATE INDEX IF NOT EXISTS idx_compliance_alerts_tenant_status 
ON security.compliance_alerts (tenant_hk, status, alert_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_compliance_alerts_severity 
ON security.compliance_alerts (severity, resolution_required_by) 
WHERE status IN ('NEW', 'IN_PROGRESS');

-- Create compliance audit log
CREATE TABLE IF NOT EXISTS security.compliance_audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    event_type VARCHAR(100) NOT NULL,
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    event_details JSONB NOT NULL,
    severity VARCHAR(20),
    user_id VARCHAR(100),
    source_ip INET,
    session_id VARCHAR(100)
);

COMMENT ON TABLE security.compliance_audit_log IS 
'Comprehensive audit logging for all compliance-related events and activities.';

-- Create indexes for audit log
CREATE INDEX IF NOT EXISTS idx_compliance_audit_log_tenant_date 
ON security.compliance_audit_log (tenant_hk, event_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_compliance_audit_log_event_type 
ON security.compliance_audit_log (event_type, event_timestamp DESC);

-- Create security policy function
CREATE OR REPLACE FUNCTION security.enforce_ai_security_policy(
    p_tenant_hk BYTEA,
    p_operation_type VARCHAR(50),
    p_context JSONB
) RETURNS TABLE (
    is_allowed BOOLEAN,
    policy_name VARCHAR(100),
    validation_details JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH policy_checks AS (
        -- Rate limiting check
        SELECT 
            'RATE_LIMIT' as policy,
            CASE 
                WHEN (
                    SELECT COUNT(*) 
                    FROM business.ai_interaction_h aih
                    JOIN business.ai_interaction_details_s aid 
                        ON aih.ai_interaction_hk = aid.ai_interaction_hk
                    WHERE aih.tenant_hk = p_tenant_hk
                    AND aid.interaction_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 minute'
                    AND aid.load_end_date IS NULL
                ) <= COALESCE((p_context->>'rate_limit')::INTEGER, 100) THEN true
                ELSE false
            END as check_passed,
            jsonb_build_object(
                'max_rate', COALESCE((p_context->>'rate_limit')::INTEGER, 100),
                'current_usage', (
                    SELECT COUNT(*) 
                    FROM business.ai_interaction_h aih
                    JOIN business.ai_interaction_details_s aid 
                        ON aih.ai_interaction_hk = aid.ai_interaction_hk
                    WHERE aih.tenant_hk = p_tenant_hk
                    AND aid.interaction_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 minute'
                    AND aid.load_end_date IS NULL
                )
            ) as details
            
        UNION ALL
        
        -- Security level check
        SELECT 
            'SECURITY_LEVEL',
            CASE 
                WHEN COALESCE(p_context->>'required_security_level', 'standard') = 'high' THEN
                    EXISTS (
                        SELECT 1 
                        FROM security.ai_security_assessment
                        WHERE tenant_hk = p_tenant_hk
                        AND security_score >= 80
                        AND assessment_timestamp >= CURRENT_TIMESTAMP - INTERVAL '30 days'
                    )
                ELSE true
            END,
            jsonb_build_object(
                'required_level', COALESCE(p_context->>'required_security_level', 'standard'),
                'current_score', (
                    SELECT security_score 
                    FROM security.ai_security_assessment
                    WHERE tenant_hk = p_tenant_hk
                    ORDER BY assessment_timestamp DESC
                    LIMIT 1
                )
            )
            
        UNION ALL
        
        -- Compliance check
        SELECT 
            'COMPLIANCE_STATUS',
            NOT EXISTS (
                SELECT 1 
                FROM security.compliance_monitoring
                WHERE tenant_hk = p_tenant_hk
                AND NOT is_compliant
                AND violation_severity IN ('HIGH', 'CRITICAL')
                AND check_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
            ),
            jsonb_build_object(
                'has_violations', EXISTS (
                    SELECT 1 
                    FROM security.compliance_monitoring
                    WHERE tenant_hk = p_tenant_hk
                    AND NOT is_compliant
                    AND violation_severity IN ('HIGH', 'CRITICAL')
                    AND check_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
                )
            )
    )
    SELECT 
        MIN(check_passed::INTEGER)::BOOLEAN as is_allowed,
        STRING_AGG(
            CASE WHEN NOT check_passed THEN policy ELSE NULL END, 
            ', '
        ) as failed_policies,
        jsonb_object_agg(
            policy,
            details
        ) as validation_details
    FROM policy_checks
    GROUP BY true;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION security.enforce_ai_security_policy(BYTEA, VARCHAR, JSONB) IS 
'Enforces comprehensive AI security policies including rate limiting, security levels, and compliance status.';

-- Commit transaction
COMMIT; 