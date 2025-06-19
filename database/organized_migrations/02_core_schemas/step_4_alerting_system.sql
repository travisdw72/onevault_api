-- =====================================================================================
-- Script: step_4_alerting_system.sql
-- Description: Monitoring & Alerting Infrastructure Implementation - Phase 2 Part 2
-- Version: 1.0
-- Date: 2024-12-19
-- Author: One Vault Development Team
-- 
-- Purpose: Implement comprehensive alerting system with automated incident response,
--          notification management, escalation procedures, and real-time alerting
--          for production monitoring and operational excellence
-- =====================================================================================

-- =====================================================================================
-- ALERTING SCHEMA EXTENSION
-- =====================================================================================

-- Ensure monitoring schema exists
CREATE SCHEMA IF NOT EXISTS monitoring;

-- =====================================================================================
-- ALERT DEFINITION AND MANAGEMENT TABLES
-- =====================================================================================

-- Alert Definition Hub
CREATE TABLE monitoring.alert_definition_h (
    alert_definition_hk BYTEA PRIMARY KEY,
    alert_definition_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide alerts
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'ALERTING_SYSTEM'
);

-- Alert Definition Satellite
CREATE TABLE monitoring.alert_definition_s (
    alert_definition_hk BYTEA NOT NULL REFERENCES monitoring.alert_definition_h(alert_definition_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    alert_name VARCHAR(200) NOT NULL,
    alert_description TEXT,
    alert_category VARCHAR(50) NOT NULL,    -- PERFORMANCE, SECURITY, CAPACITY, COMPLIANCE, BACKUP
    alert_severity VARCHAR(20) NOT NULL,    -- LOW, MEDIUM, HIGH, CRITICAL
    metric_source VARCHAR(100),             -- Which table/view to monitor
    condition_logic TEXT NOT NULL,          -- SQL condition for triggering alert
    threshold_value DECIMAL(15,4),
    threshold_operator VARCHAR(10),         -- >, <, =, !=, >=, <=
    evaluation_frequency_minutes INTEGER DEFAULT 5,
    is_enabled BOOLEAN DEFAULT true,
    auto_resolve BOOLEAN DEFAULT false,     -- Auto-resolve when condition clears
    escalation_enabled BOOLEAN DEFAULT false,
    escalation_delay_minutes INTEGER DEFAULT 30,
    suppression_window_minutes INTEGER DEFAULT 60, -- Prevent duplicate alerts
    notification_channels TEXT[],           -- EMAIL, SLACK, SMS, WEBHOOK
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    last_modified_by VARCHAR(100) DEFAULT SESSION_USER,
    record_source VARCHAR(100) NOT NULL DEFAULT 'ALERTING_SYSTEM',
    PRIMARY KEY (alert_definition_hk, load_date)
);

-- Alert Instance Hub (for fired alerts)
CREATE TABLE monitoring.alert_instance_h (
    alert_instance_hk BYTEA PRIMARY KEY,
    alert_instance_bk VARCHAR(255) NOT NULL UNIQUE,
    alert_definition_hk BYTEA NOT NULL REFERENCES monitoring.alert_definition_h(alert_definition_hk),
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'ALERT_ENGINE'
);

-- Alert Instance Satellite
CREATE TABLE monitoring.alert_instance_s (
    alert_instance_hk BYTEA NOT NULL REFERENCES monitoring.alert_instance_h(alert_instance_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    alert_status VARCHAR(20) NOT NULL,      -- OPEN, ACKNOWLEDGED, RESOLVED, SUPPRESSED, ESCALATED
    triggered_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    acknowledged_timestamp TIMESTAMP WITH TIME ZONE,
    resolved_timestamp TIMESTAMP WITH TIME ZONE,
    trigger_value DECIMAL(15,4),
    trigger_details JSONB,
    impact_assessment TEXT,
    urgency_level VARCHAR(20),              -- LOW, MEDIUM, HIGH, CRITICAL
    affected_systems TEXT[],
    estimated_affected_users INTEGER,
    business_impact_description TEXT,
    acknowledged_by VARCHAR(100),
    resolved_by VARCHAR(100),
    resolution_notes TEXT,
    false_positive BOOLEAN DEFAULT false,
    suppression_reason TEXT,
    escalation_level INTEGER DEFAULT 0,     -- 0=initial, 1=first escalation, etc.
    last_notification_sent TIMESTAMP WITH TIME ZONE,
    notification_count INTEGER DEFAULT 0,
    record_source VARCHAR(100) NOT NULL DEFAULT 'ALERT_ENGINE',
    PRIMARY KEY (alert_instance_hk, load_date)
);

-- Notification Configuration Hub
CREATE TABLE monitoring.notification_config_h (
    notification_config_hk BYTEA PRIMARY KEY,
    notification_config_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'NOTIFICATION_MANAGER'
);

-- Notification Configuration Satellite
CREATE TABLE monitoring.notification_config_s (
    notification_config_hk BYTEA NOT NULL REFERENCES monitoring.notification_config_h(notification_config_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    channel_name VARCHAR(100) NOT NULL,     -- EMAIL, SLACK, SMS, WEBHOOK, PAGERDUTY
    channel_type VARCHAR(50) NOT NULL,
    configuration JSONB NOT NULL,           -- Channel-specific config (URLs, tokens, etc.)
    recipient_groups TEXT[],                -- ONCALL, ADMINS, SECURITY_TEAM, etc.
    severity_filter TEXT[],                 -- Which severities to notify for
    category_filter TEXT[],                 -- Which categories to notify for
    time_restrictions JSONB,                -- Business hours, timezone restrictions
    is_enabled BOOLEAN DEFAULT true,
    rate_limit_per_hour INTEGER DEFAULT 100,
    delivery_confirmation_required BOOLEAN DEFAULT false,
    retry_attempts INTEGER DEFAULT 3,
    retry_delay_seconds INTEGER DEFAULT 300,
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    record_source VARCHAR(100) NOT NULL DEFAULT 'NOTIFICATION_MANAGER',
    PRIMARY KEY (notification_config_hk, load_date)
);

-- Notification Log Hub
CREATE TABLE monitoring.notification_log_h (
    notification_log_hk BYTEA PRIMARY KEY,
    notification_log_bk VARCHAR(255) NOT NULL UNIQUE,
    alert_instance_hk BYTEA NOT NULL REFERENCES monitoring.alert_instance_h(alert_instance_hk),
    notification_config_hk BYTEA NOT NULL REFERENCES monitoring.notification_config_h(notification_config_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'NOTIFICATION_DELIVERY'
);

-- Notification Log Satellite
CREATE TABLE monitoring.notification_log_s (
    notification_log_hk BYTEA NOT NULL REFERENCES monitoring.notification_log_h(notification_log_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    sent_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    delivery_status VARCHAR(20) NOT NULL,   -- PENDING, SENT, DELIVERED, FAILED, BOUNCED
    channel_used VARCHAR(100),
    recipient_address TEXT,
    message_content TEXT,
    delivery_confirmation_received BOOLEAN DEFAULT false,
    delivery_confirmation_timestamp TIMESTAMP WITH TIME ZONE,
    failure_reason TEXT,
    retry_count INTEGER DEFAULT 0,
    delivery_duration_ms INTEGER,
    external_message_id VARCHAR(255),       -- Provider-specific message ID
    record_source VARCHAR(100) NOT NULL DEFAULT 'NOTIFICATION_DELIVERY',
    PRIMARY KEY (notification_log_hk, load_date)
);

-- =====================================================================================
-- INCIDENT RESPONSE TABLES
-- =====================================================================================

-- Incident Hub
CREATE TABLE monitoring.incident_h (
    incident_hk BYTEA PRIMARY KEY,
    incident_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'INCIDENT_MANAGER'
);

-- Incident Satellite
CREATE TABLE monitoring.incident_s (
    incident_hk BYTEA NOT NULL REFERENCES monitoring.incident_h(incident_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    incident_title VARCHAR(500) NOT NULL,
    incident_description TEXT,
    incident_status VARCHAR(20) NOT NULL,   -- OPEN, INVESTIGATING, RESOLVED, CLOSED, CANCELLED
    incident_severity VARCHAR(20) NOT NULL, -- LOW, MEDIUM, HIGH, CRITICAL
    incident_priority VARCHAR(20) NOT NULL, -- P1, P2, P3, P4, P5
    created_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    first_response_timestamp TIMESTAMP WITH TIME ZONE,
    resolved_timestamp TIMESTAMP WITH TIME ZONE,
    closed_timestamp TIMESTAMP WITH TIME ZONE,
    assigned_to VARCHAR(100),
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    affected_services TEXT[],
    customer_impact_level VARCHAR(20),      -- NONE, LOW, MEDIUM, HIGH, CRITICAL
    estimated_affected_customers INTEGER,
    root_cause_analysis TEXT,
    resolution_summary TEXT,
    lessons_learned TEXT,
    follow_up_actions TEXT[],
    sla_breach BOOLEAN DEFAULT false,
    response_time_minutes INTEGER,
    resolution_time_minutes INTEGER,
    record_source VARCHAR(100) NOT NULL DEFAULT 'INCIDENT_MANAGER',
    PRIMARY KEY (incident_hk, load_date)
);

-- Alert-to-Incident Link
CREATE TABLE monitoring.alert_incident_l (
    link_alert_incident_hk BYTEA PRIMARY KEY,
    alert_instance_hk BYTEA NOT NULL REFERENCES monitoring.alert_instance_h(alert_instance_hk),
    incident_hk BYTEA NOT NULL REFERENCES monitoring.incident_h(incident_hk),
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'INCIDENT_CORRELATOR'
);

-- =====================================================================================
-- PERFORMANCE INDEXES FOR ALERTING TABLES
-- =====================================================================================

-- Alert Definition Indexes
CREATE INDEX idx_alert_definition_s_enabled ON monitoring.alert_definition_s(is_enabled, alert_category) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_alert_definition_s_frequency ON monitoring.alert_definition_s(evaluation_frequency_minutes, is_enabled) 
WHERE load_end_date IS NULL;

-- Alert Instance Indexes
CREATE INDEX idx_alert_instance_s_status ON monitoring.alert_instance_s(alert_status, triggered_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_alert_instance_s_triggered ON monitoring.alert_instance_s(triggered_timestamp DESC) 
WHERE load_end_date IS NULL AND alert_status = 'OPEN';

CREATE INDEX idx_alert_instance_s_escalation ON monitoring.alert_instance_s(escalation_level, triggered_timestamp) 
WHERE load_end_date IS NULL AND alert_status = 'OPEN';

-- Notification Log Indexes
CREATE INDEX idx_notification_log_s_delivery ON monitoring.notification_log_s(delivery_status, sent_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_notification_log_s_retry ON monitoring.notification_log_s(retry_count, delivery_status) 
WHERE load_end_date IS NULL AND delivery_status = 'FAILED';

-- Incident Indexes
CREATE INDEX idx_incident_s_status ON monitoring.incident_s(incident_status, created_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_incident_s_severity ON monitoring.incident_s(incident_severity, incident_priority) 
WHERE load_end_date IS NULL AND incident_status != 'CLOSED';

-- =====================================================================================
-- ALERT PROCESSING FUNCTIONS
-- =====================================================================================

-- Function to evaluate alert conditions and fire alerts
CREATE OR REPLACE FUNCTION monitoring.evaluate_alert_conditions(
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS TABLE (
    alert_name VARCHAR(200),
    alert_fired BOOLEAN,
    trigger_value DECIMAL(15,4),
    alert_severity VARCHAR(20)
) AS $$
DECLARE
    v_alert_def RECORD;
    v_alert_instance_hk BYTEA;
    v_alert_instance_bk VARCHAR(255);
    v_condition_result BOOLEAN;
    v_trigger_value DECIMAL(15,4);
    v_existing_open_alert BYTEA;
    v_last_alert_time TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Loop through all enabled alert definitions
    FOR v_alert_def IN 
        SELECT adh.*, ads.*
        FROM monitoring.alert_definition_h adh
        JOIN monitoring.alert_definition_s ads ON adh.alert_definition_hk = ads.alert_definition_hk
        WHERE ads.is_enabled = true
        AND ads.load_end_date IS NULL
        AND (p_tenant_hk IS NULL OR adh.tenant_hk = p_tenant_hk OR adh.tenant_hk IS NULL)
    LOOP
        -- Check for suppression window
        SELECT MAX(ais.triggered_timestamp) INTO v_last_alert_time
        FROM monitoring.alert_instance_h aih
        JOIN monitoring.alert_instance_s ais ON aih.alert_instance_hk = ais.alert_instance_hk
        WHERE aih.alert_definition_hk = v_alert_def.alert_definition_hk
        AND ais.load_end_date IS NULL
        AND ais.triggered_timestamp >= CURRENT_TIMESTAMP - (v_alert_def.suppression_window_minutes || ' minutes')::INTERVAL;
        
        -- Skip if within suppression window
        IF v_last_alert_time IS NOT NULL THEN
            CONTINUE;
        END IF;
        
        -- Evaluate alert condition (simplified - would need dynamic SQL execution)
        -- For demonstration, we'll check some common conditions
        BEGIN
            IF v_alert_def.metric_source = 'system_health' THEN
                -- Check system health metrics
                SELECT COUNT(*) > 0, COALESCE(MAX(shms.metric_value), 0) 
                INTO v_condition_result, v_trigger_value
                FROM monitoring.system_health_metric_h shmh
                JOIN monitoring.system_health_metric_s shms ON shmh.health_metric_hk = shms.health_metric_hk
                WHERE shms.load_end_date IS NULL
                AND shms.status = 'CRITICAL'
                AND shms.measurement_timestamp >= CURRENT_TIMESTAMP - INTERVAL '10 minutes'
                AND (p_tenant_hk IS NULL OR shmh.tenant_hk = p_tenant_hk);
                
            ELSIF v_alert_def.metric_source = 'backup_failures' THEN
                -- Check backup failures
                SELECT COUNT(*) > 0, COUNT(*)::DECIMAL 
                INTO v_condition_result, v_trigger_value
                FROM backup_mgmt.backup_execution_s bes
                WHERE bes.backup_status = 'FAILED'
                AND bes.backup_start_time >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
                AND bes.load_end_date IS NULL;
                
            ELSIF v_alert_def.metric_source = 'security_events' THEN
                -- Check security events
                SELECT COUNT(*) >= v_alert_def.threshold_value, COUNT(*)::DECIMAL
                INTO v_condition_result, v_trigger_value
                FROM monitoring.security_event_s ses
                WHERE ses.event_severity IN ('HIGH', 'CRITICAL')
                AND ses.event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
                AND ses.load_end_date IS NULL;
                
            ELSE
                -- Default: no condition met
                v_condition_result := false;
                v_trigger_value := 0;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            -- Log error and continue
            v_condition_result := false;
            v_trigger_value := 0;
        END;
        
        -- If condition is met, create alert instance
        IF v_condition_result THEN
            -- Check if there's already an open alert for this definition
            SELECT ais.alert_instance_hk INTO v_existing_open_alert
            FROM monitoring.alert_instance_h aih
            JOIN monitoring.alert_instance_s ais ON aih.alert_instance_hk = ais.alert_instance_hk
            WHERE aih.alert_definition_hk = v_alert_def.alert_definition_hk
            AND ais.alert_status = 'OPEN'
            AND ais.load_end_date IS NULL
            LIMIT 1;
            
            -- Only create new alert if no open alert exists
            IF v_existing_open_alert IS NULL THEN
                v_alert_instance_bk := v_alert_def.alert_name || '_' || 
                                      to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS_US');
                v_alert_instance_hk := util.hash_binary(v_alert_instance_bk);
                
                -- Insert alert instance hub
                INSERT INTO monitoring.alert_instance_h VALUES (
                    v_alert_instance_hk,
                    v_alert_instance_bk,
                    v_alert_def.alert_definition_hk,
                    p_tenant_hk,
                    util.current_load_date(),
                    'ALERT_ENGINE'
                );
                
                -- Insert alert instance satellite
                INSERT INTO monitoring.alert_instance_s VALUES (
                    v_alert_instance_hk,
                    util.current_load_date(),
                    NULL,
                    util.hash_binary(v_alert_instance_bk || 'OPEN'),
                    'OPEN',
                    CURRENT_TIMESTAMP,
                    NULL, -- acknowledged_timestamp
                    NULL, -- resolved_timestamp
                    v_trigger_value,
                    jsonb_build_object(
                        'alert_definition', v_alert_def.alert_name,
                        'condition_logic', v_alert_def.condition_logic,
                        'threshold_value', v_alert_def.threshold_value,
                        'evaluation_timestamp', CURRENT_TIMESTAMP
                    ),
                    'Automated alert triggered by monitoring system',
                    v_alert_def.alert_severity,
                    ARRAY['DATABASE', 'MONITORING'],
                    NULL, -- estimated_affected_users
                    'System monitoring detected condition requiring attention',
                    NULL, -- acknowledged_by
                    NULL, -- resolved_by
                    NULL, -- resolution_notes
                    false, -- false_positive
                    NULL, -- suppression_reason
                    0, -- escalation_level
                    NULL, -- last_notification_sent
                    0, -- notification_count
                    'ALERT_ENGINE'
                );
                
                -- Trigger notifications
                PERFORM monitoring.send_alert_notifications(v_alert_instance_hk);
            END IF;
        END IF;
        
        -- Return alert evaluation result
        RETURN QUERY SELECT 
            v_alert_def.alert_name,
            v_condition_result,
            v_trigger_value,
            v_alert_def.alert_severity;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to send alert notifications
CREATE OR REPLACE FUNCTION monitoring.send_alert_notifications(
    p_alert_instance_hk BYTEA
) RETURNS INTEGER AS $$
DECLARE
    v_alert_instance RECORD;
    v_alert_definition RECORD;
    v_notification_config RECORD;
    v_notification_log_hk BYTEA;
    v_notification_log_bk VARCHAR(255);
    v_notifications_sent INTEGER := 0;
BEGIN
    -- Get alert instance details
    SELECT aih.*, ais.*
    INTO v_alert_instance
    FROM monitoring.alert_instance_h aih
    JOIN monitoring.alert_instance_s ais ON aih.alert_instance_hk = ais.alert_instance_hk
    WHERE aih.alert_instance_hk = p_alert_instance_hk
    AND ais.load_end_date IS NULL;
    
    IF NOT FOUND THEN
        RETURN 0;
    END IF;
    
    -- Get alert definition
    SELECT adh.*, ads.*
    INTO v_alert_definition
    FROM monitoring.alert_definition_h adh
    JOIN monitoring.alert_definition_s ads ON adh.alert_definition_hk = ads.alert_definition_hk
    WHERE adh.alert_definition_hk = v_alert_instance.alert_definition_hk
    AND ads.load_end_date IS NULL;
    
    -- Loop through notification channels for this alert
    FOR v_notification_config IN 
        SELECT nch.*, ncs.*
        FROM monitoring.notification_config_h nch
        JOIN monitoring.notification_config_s ncs ON nch.notification_config_hk = ncs.notification_config_hk
        WHERE ncs.is_enabled = true
        AND ncs.load_end_date IS NULL
        AND (v_alert_definition.alert_severity = ANY(ncs.severity_filter) OR ncs.severity_filter IS NULL)
        AND (v_alert_definition.alert_category = ANY(ncs.category_filter) OR ncs.category_filter IS NULL)
        AND (v_alert_instance.tenant_hk IS NULL OR nch.tenant_hk = v_alert_instance.tenant_hk OR nch.tenant_hk IS NULL)
    LOOP
        -- Generate notification log entry
        v_notification_log_bk := 'NOTIF_' || encode(p_alert_instance_hk, 'hex') || '_' || 
                                v_notification_config.channel_name || '_' ||
                                to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS_US');
        v_notification_log_hk := util.hash_binary(v_notification_log_bk);
        
        -- Insert notification log hub
        INSERT INTO monitoring.notification_log_h VALUES (
            v_notification_log_hk,
            v_notification_log_bk,
            p_alert_instance_hk,
            v_notification_config.notification_config_hk,
            util.current_load_date(),
            'NOTIFICATION_DELIVERY'
        );
        
        -- Insert notification log satellite
        INSERT INTO monitoring.notification_log_s VALUES (
            v_notification_log_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(v_notification_log_bk || 'PENDING'),
            CURRENT_TIMESTAMP,
            'PENDING',
            v_notification_config.channel_name,
            NULL, -- recipient_address - would be populated from config
            'ALERT: ' || v_alert_definition.alert_name || ' - ' || v_alert_definition.alert_description,
            false, -- delivery_confirmation_received
            NULL, -- delivery_confirmation_timestamp
            NULL, -- failure_reason
            0, -- retry_count
            NULL, -- delivery_duration_ms
            NULL, -- external_message_id
            'NOTIFICATION_DELIVERY'
        );
        
        v_notifications_sent := v_notifications_sent + 1;
    END LOOP;
    
    -- Update alert instance with notification timestamp
    UPDATE monitoring.alert_instance_s 
    SET last_notification_sent = CURRENT_TIMESTAMP,
        notification_count = notification_count + v_notifications_sent
    WHERE alert_instance_hk = p_alert_instance_hk 
    AND load_end_date IS NULL;
    
    RETURN v_notifications_sent;
END;
$$ LANGUAGE plpgsql;

-- Function to acknowledge alerts
CREATE OR REPLACE FUNCTION monitoring.acknowledge_alert(
    p_alert_instance_hk BYTEA,
    p_acknowledged_by VARCHAR(100),
    p_acknowledgment_notes TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_current_status VARCHAR(20);
BEGIN
    -- Check current alert status
    SELECT alert_status INTO v_current_status
    FROM monitoring.alert_instance_s
    WHERE alert_instance_hk = p_alert_instance_hk
    AND load_end_date IS NULL;
    
    IF v_current_status != 'OPEN' THEN
        RETURN false; -- Can only acknowledge open alerts
    END IF;
    
    -- Close current satellite record
    UPDATE monitoring.alert_instance_s 
    SET load_end_date = util.current_load_date()
    WHERE alert_instance_hk = p_alert_instance_hk 
    AND load_end_date IS NULL;
    
    -- Insert new satellite record with acknowledged status
    INSERT INTO monitoring.alert_instance_s (
        alert_instance_hk, load_date, load_end_date, hash_diff,
        alert_status, triggered_timestamp, acknowledged_timestamp, resolved_timestamp,
        trigger_value, trigger_details, impact_assessment, urgency_level,
        affected_systems, estimated_affected_users, business_impact_description,
        acknowledged_by, resolved_by, resolution_notes, false_positive,
        suppression_reason, escalation_level, last_notification_sent,
        notification_count, record_source
    )
    SELECT 
        alert_instance_hk, util.current_load_date(), NULL,
        util.hash_binary(alert_instance_bk || 'ACKNOWLEDGED'),
        'ACKNOWLEDGED', triggered_timestamp, CURRENT_TIMESTAMP, resolved_timestamp,
        trigger_value, trigger_details, impact_assessment, urgency_level,
        affected_systems, estimated_affected_users, business_impact_description,
        p_acknowledged_by, resolved_by, 
        COALESCE(resolution_notes || ' | ', '') || 'Acknowledged: ' || COALESCE(p_acknowledgment_notes, 'No notes provided'),
        false_positive, suppression_reason, escalation_level, last_notification_sent,
        notification_count, 'ALERT_ACKNOWLEDGER'
    FROM monitoring.alert_instance_s ais
    JOIN monitoring.alert_instance_h aih ON ais.alert_instance_hk = aih.alert_instance_hk
    WHERE ais.alert_instance_hk = p_alert_instance_hk
    AND ais.load_end_date = util.current_load_date();
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function to resolve alerts
CREATE OR REPLACE FUNCTION monitoring.resolve_alert(
    p_alert_instance_hk BYTEA,
    p_resolved_by VARCHAR(100),
    p_resolution_notes TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_current_status VARCHAR(20);
BEGIN
    -- Check current alert status
    SELECT alert_status INTO v_current_status
    FROM monitoring.alert_instance_s
    WHERE alert_instance_hk = p_alert_instance_hk
    AND load_end_date IS NULL;
    
    IF v_current_status IN ('RESOLVED', 'SUPPRESSED') THEN
        RETURN false; -- Already resolved or suppressed
    END IF;
    
    -- Close current satellite record
    UPDATE monitoring.alert_instance_s 
    SET load_end_date = util.current_load_date()
    WHERE alert_instance_hk = p_alert_instance_hk 
    AND load_end_date IS NULL;
    
    -- Insert new satellite record with resolved status
    INSERT INTO monitoring.alert_instance_s (
        alert_instance_hk, load_date, load_end_date, hash_diff,
        alert_status, triggered_timestamp, acknowledged_timestamp, resolved_timestamp,
        trigger_value, trigger_details, impact_assessment, urgency_level,
        affected_systems, estimated_affected_users, business_impact_description,
        acknowledged_by, resolved_by, resolution_notes, false_positive,
        suppression_reason, escalation_level, last_notification_sent,
        notification_count, record_source
    )
    SELECT 
        alert_instance_hk, util.current_load_date(), NULL,
        util.hash_binary(alert_instance_bk || 'RESOLVED'),
        'RESOLVED', triggered_timestamp, acknowledged_timestamp, CURRENT_TIMESTAMP,
        trigger_value, trigger_details, impact_assessment, urgency_level,
        affected_systems, estimated_affected_users, business_impact_description,
        acknowledged_by, p_resolved_by, p_resolution_notes, false_positive,
        suppression_reason, escalation_level, last_notification_sent,
        notification_count, 'ALERT_RESOLVER'
    FROM monitoring.alert_instance_s ais
    JOIN monitoring.alert_instance_h aih ON ais.alert_instance_hk = aih.alert_instance_hk
    WHERE ais.alert_instance_hk = p_alert_instance_hk
    AND ais.load_end_date = util.current_load_date();
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- INCIDENT MANAGEMENT FUNCTIONS
-- =====================================================================================

-- Function to create incident from alerts
CREATE OR REPLACE FUNCTION monitoring.create_incident_from_alerts(
    p_alert_instance_hks BYTEA[],
    p_incident_title VARCHAR(500),
    p_incident_description TEXT,
    p_assigned_to VARCHAR(100) DEFAULT NULL,
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_incident_hk BYTEA;
    v_incident_bk VARCHAR(255);
    v_incident_severity VARCHAR(20);
    v_alert_hk BYTEA;
    v_link_hk BYTEA;
BEGIN
    -- Determine incident severity from alerts
    SELECT CASE 
        WHEN COUNT(*) FILTER (WHERE ais.urgency_level = 'CRITICAL') > 0 THEN 'CRITICAL'
        WHEN COUNT(*) FILTER (WHERE ais.urgency_level = 'HIGH') > 0 THEN 'HIGH'
        WHEN COUNT(*) FILTER (WHERE ais.urgency_level = 'MEDIUM') > 0 THEN 'MEDIUM'
        ELSE 'LOW'
    END INTO v_incident_severity
    FROM monitoring.alert_instance_s ais
    WHERE ais.alert_instance_hk = ANY(p_alert_instance_hks)
    AND ais.load_end_date IS NULL;
    
    -- Generate incident business key
    v_incident_bk := 'INC_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS') || '_' ||
                     encode(util.hash_binary(p_incident_title), 'hex');
    v_incident_hk := util.hash_binary(v_incident_bk);
    
    -- Insert incident hub
    INSERT INTO monitoring.incident_h VALUES (
        v_incident_hk, v_incident_bk, p_tenant_hk,
        util.current_load_date(), 'INCIDENT_MANAGER'
    );
    
    -- Insert incident satellite
    INSERT INTO monitoring.incident_s VALUES (
        v_incident_hk, util.current_load_date(), NULL,
        util.hash_binary(v_incident_bk || 'OPEN'),
        p_incident_title, p_incident_description, 'OPEN', v_incident_severity,
        CASE v_incident_severity 
            WHEN 'CRITICAL' THEN 'P1'
            WHEN 'HIGH' THEN 'P2'
            WHEN 'MEDIUM' THEN 'P3'
            ELSE 'P4'
        END,
        CURRENT_TIMESTAMP, NULL, NULL, NULL, p_assigned_to, SESSION_USER,
        ARRAY['DATABASE', 'MONITORING'], 'MEDIUM', NULL,
        NULL, NULL, NULL, ARRAY[]::TEXT[], false, NULL, NULL,
        'INCIDENT_MANAGER'
    );
    
    -- Link alerts to incident
    FOREACH v_alert_hk IN ARRAY p_alert_instance_hks
    LOOP
        v_link_hk := util.hash_binary(encode(v_alert_hk, 'hex') || encode(v_incident_hk, 'hex'));
        
        INSERT INTO monitoring.alert_incident_l VALUES (
            v_link_hk, v_alert_hk, v_incident_hk, p_tenant_hk,
            util.current_load_date(), 'INCIDENT_CORRELATOR'
        );
    END LOOP;
    
    RETURN v_incident_hk;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- ALERTING DASHBOARD VIEWS
-- =====================================================================================

-- Active alerts dashboard
CREATE OR REPLACE VIEW monitoring.active_alerts_dashboard AS
SELECT 
    aih.alert_instance_bk,
    ads.alert_name,
    ads.alert_category,
    ais.alert_status,
    ais.urgency_level,
    ais.triggered_timestamp,
    ais.acknowledged_timestamp,
    ais.acknowledged_by,
    ais.trigger_value,
    ads.threshold_value,
    ais.affected_systems,
    ais.business_impact_description,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - ais.triggered_timestamp))/60 as age_minutes,
    CASE 
        WHEN ais.alert_status = 'OPEN' AND CURRENT_TIMESTAMP - ais.triggered_timestamp > INTERVAL '1 hour' THEN 'OVERDUE'
        WHEN ais.alert_status = 'ACKNOWLEDGED' AND CURRENT_TIMESTAMP - ais.acknowledged_timestamp > INTERVAL '4 hours' THEN 'STALE'
        ELSE 'NORMAL'
    END as alert_health
FROM monitoring.alert_instance_h aih
JOIN monitoring.alert_instance_s ais ON aih.alert_instance_hk = ais.alert_instance_hk
JOIN monitoring.alert_definition_h adh ON aih.alert_definition_hk = adh.alert_definition_hk
JOIN monitoring.alert_definition_s ads ON adh.alert_definition_hk = ads.alert_definition_hk
WHERE ais.load_end_date IS NULL
AND ads.load_end_date IS NULL
AND ais.alert_status IN ('OPEN', 'ACKNOWLEDGED', 'ESCALATED')
ORDER BY 
    CASE ais.urgency_level 
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3
        ELSE 4
    END,
    ais.triggered_timestamp DESC;

-- Incident summary dashboard
CREATE OR REPLACE VIEW monitoring.incident_summary_dashboard AS
SELECT 
    ih.incident_bk,
    is_.incident_title,
    is_.incident_status,
    is_.incident_severity,
    is_.incident_priority,
    is_.created_timestamp,
    is_.assigned_to,
    is_.customer_impact_level,
    is_.estimated_affected_customers,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - is_.created_timestamp))/60 as age_minutes,
    COUNT(ail.alert_instance_hk) as linked_alerts_count,
    CASE 
        WHEN is_.incident_status = 'OPEN' AND CURRENT_TIMESTAMP - is_.created_timestamp > INTERVAL '30 minutes' THEN 'OVERDUE_RESPONSE'
        WHEN is_.incident_status = 'INVESTIGATING' AND CURRENT_TIMESTAMP - is_.created_timestamp > INTERVAL '4 hours' THEN 'OVERDUE_RESOLUTION'
        ELSE 'ON_TRACK'
    END as sla_status
FROM monitoring.incident_h ih
JOIN monitoring.incident_s is_ ON ih.incident_hk = is_.incident_hk
LEFT JOIN monitoring.alert_incident_l ail ON ih.incident_hk = ail.incident_hk
WHERE is_.load_end_date IS NULL
AND is_.incident_status != 'CLOSED'
GROUP BY ih.incident_hk, ih.incident_bk, is_.incident_title, is_.incident_status,
         is_.incident_severity, is_.incident_priority, is_.created_timestamp,
         is_.assigned_to, is_.customer_impact_level, is_.estimated_affected_customers
ORDER BY 
    CASE is_.incident_priority
        WHEN 'P1' THEN 1
        WHEN 'P2' THEN 2
        WHEN 'P3' THEN 3
        WHEN 'P4' THEN 4
        ELSE 5
    END,
    is_.created_timestamp DESC;

-- Grant permissions for alerting functions
GRANT EXECUTE ON FUNCTION monitoring.evaluate_alert_conditions TO postgres;
GRANT EXECUTE ON FUNCTION monitoring.send_alert_notifications TO postgres;
GRANT EXECUTE ON FUNCTION monitoring.acknowledge_alert TO postgres;
GRANT EXECUTE ON FUNCTION monitoring.resolve_alert TO postgres;
GRANT EXECUTE ON FUNCTION monitoring.create_incident_from_alerts TO postgres;

-- Grant SELECT permissions on alerting views
GRANT SELECT ON monitoring.active_alerts_dashboard TO postgres;
GRANT SELECT ON monitoring.incident_summary_dashboard TO postgres;

-- =====================================================================================
-- SCRIPT COMPLETION AND VALIDATION
-- =====================================================================================

-- Insert default alert definitions for common scenarios
INSERT INTO monitoring.alert_definition_h (alert_definition_hk, alert_definition_bk, tenant_hk, load_date, record_source)
VALUES 
    (util.hash_binary('SYSTEM_DATABASE_SIZE_WARNING'), 'SYSTEM_DATABASE_SIZE_WARNING', NULL, util.current_load_date(), 'SETUP_SCRIPT'),
    (util.hash_binary('SYSTEM_HIGH_CONNECTION_COUNT'), 'SYSTEM_HIGH_CONNECTION_COUNT', NULL, util.current_load_date(), 'SETUP_SCRIPT'),
    (util.hash_binary('BACKUP_FAILURE_ALERT'), 'BACKUP_FAILURE_ALERT', NULL, util.current_load_date(), 'SETUP_SCRIPT'),
    (util.hash_binary('SECURITY_HIGH_SEVERITY_EVENTS'), 'SECURITY_HIGH_SEVERITY_EVENTS', NULL, util.current_load_date(), 'SETUP_SCRIPT');

INSERT INTO monitoring.alert_definition_s (
    alert_definition_hk, load_date, hash_diff, alert_name, alert_description,
    alert_category, alert_severity, metric_source, condition_logic,
    threshold_value, threshold_operator, evaluation_frequency_minutes,
    is_enabled, notification_channels, record_source
)
VALUES 
    (
        util.hash_binary('SYSTEM_DATABASE_SIZE_WARNING'), util.current_load_date(),
        util.hash_binary('DATABASE_SIZE_WARNING_DEF'),
        'Database Size Warning', 'Database size approaching capacity limits',
        'CAPACITY', 'MEDIUM', 'system_health',
        'database_size_gb > threshold_value', 50.0, '>', 60,
        true, ARRAY['EMAIL', 'SLACK'], 'SETUP_SCRIPT'
    ),
    (
        util.hash_binary('SYSTEM_HIGH_CONNECTION_COUNT'), util.current_load_date(),
        util.hash_binary('HIGH_CONNECTIONS_DEF'),
        'High Connection Count', 'Database connection count approaching limits',
        'PERFORMANCE', 'HIGH', 'system_health',
        'active_connections > threshold_value', 150.0, '>', 5,
        true, ARRAY['EMAIL', 'SLACK'], 'SETUP_SCRIPT'
    ),
    (
        util.hash_binary('BACKUP_FAILURE_ALERT'), util.current_load_date(),
        util.hash_binary('BACKUP_FAILURE_DEF'),
        'Backup Failure Alert', 'One or more backup operations have failed',
        'BACKUP', 'CRITICAL', 'backup_failures',
        'failed_backup_count > threshold_value', 0.0, '>', 15,
        true, ARRAY['EMAIL', 'SLACK', 'SMS'], 'SETUP_SCRIPT'
    ),
    (
        util.hash_binary('SECURITY_HIGH_SEVERITY_EVENTS'), util.current_load_date(),
        util.hash_binary('SECURITY_EVENTS_DEF'),
        'High Severity Security Events', 'Multiple high-severity security events detected',
        'SECURITY', 'CRITICAL', 'security_events',
        'high_severity_event_count >= threshold_value', 5.0, '>=', 5,
        true, ARRAY['EMAIL', 'SLACK', 'SMS'], 'SETUP_SCRIPT'
    );

-- Log successful completion
DO $$
BEGIN
    RAISE NOTICE 'Step 4: Alerting System deployment completed successfully at %', CURRENT_TIMESTAMP;
    RAISE NOTICE 'Created alerting infrastructure with % alert tables and % alert functions', 
        (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'monitoring' AND table_name LIKE '%alert%'),
        (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'monitoring' AND routine_name LIKE '%alert%');
    RAISE NOTICE 'Inserted % default alert definitions', 
        (SELECT COUNT(*) FROM monitoring.alert_definition_s WHERE record_source = 'SETUP_SCRIPT');
END
$$; 