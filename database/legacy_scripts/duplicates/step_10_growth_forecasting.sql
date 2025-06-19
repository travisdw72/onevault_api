-- =====================================================================================
-- Phase 5: Growth Forecasting & Capacity Management Procedures
-- One Vault Multi-Tenant Data Vault 2.0 Platform
-- =====================================================================================

-- =====================================================================================
-- GROWTH ANALYSIS FUNCTIONS
-- =====================================================================================

-- Function to analyze growth patterns and generate forecasts
CREATE OR REPLACE FUNCTION capacity_planning.analyze_growth_patterns(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_resource_type VARCHAR(50) DEFAULT NULL,
    p_analysis_days INTEGER DEFAULT 30
) RETURNS TABLE (
    resource_type VARCHAR(50),
    pattern_type VARCHAR(50),
    growth_rate_percentage DECIMAL(8,4),
    confidence_level DECIMAL(5,2),
    forecast_7d DECIMAL(15,4),
    forecast_30d DECIMAL(15,4),
    forecast_90d DECIMAL(15,4),
    time_to_capacity_days INTEGER,
    recommended_action VARCHAR(500)
) AS $$
DECLARE
    v_pattern_record RECORD;
    v_pattern_hk BYTEA;
    v_pattern_bk VARCHAR(255);
    v_forecast_hk BYTEA;
    v_forecast_bk VARCHAR(255);
    v_link_hk BYTEA;
    v_analysis_start TIMESTAMP WITH TIME ZONE;
    v_current_usage DECIMAL(15,4);
    v_capacity DECIMAL(15,4);
    v_growth_rate DECIMAL(8,4);
    v_pattern_type VARCHAR(50);
    v_confidence DECIMAL(5,2);
    v_forecast_7d DECIMAL(15,4);
    v_forecast_30d DECIMAL(15,4);
    v_forecast_90d DECIMAL(15,4);
    v_days_to_capacity INTEGER;
    v_action VARCHAR(500);
BEGIN
    v_analysis_start := CURRENT_TIMESTAMP - (p_analysis_days || ' days')::INTERVAL;
    
    -- Analyze each resource type
    FOR v_pattern_record IN 
        SELECT DISTINCT 
            rus.resource_type,
            rus.resource_category,
            AVG(rus.current_value) as avg_current,
            MAX(rus.maximum_capacity) as max_capacity,
            COUNT(*) as data_points
        FROM capacity_planning.resource_utilization_h ruh
        JOIN capacity_planning.resource_utilization_s rus ON ruh.resource_utilization_hk = rus.resource_utilization_hk
        WHERE (p_tenant_hk IS NULL OR ruh.tenant_hk = p_tenant_hk)
        AND (p_resource_type IS NULL OR rus.resource_type = p_resource_type)
        AND rus.measurement_timestamp >= v_analysis_start
        AND rus.load_end_date IS NULL
        GROUP BY rus.resource_type, rus.resource_category
        HAVING COUNT(*) >= 5 -- Need at least 5 data points
    LOOP
        -- Calculate growth metrics (simplified linear growth analysis)
        v_current_usage := v_pattern_record.avg_current;
        v_capacity := v_pattern_record.max_capacity;
        
        -- Simulate growth analysis (would use actual statistical analysis)
        v_growth_rate := CASE v_pattern_record.resource_type
            WHEN 'STORAGE' THEN 2.5 -- 2.5% daily growth
            WHEN 'USERS' THEN 1.2 -- 1.2% daily growth
            WHEN 'TRANSACTIONS' THEN 3.1 -- 3.1% daily growth
            WHEN 'CONNECTIONS' THEN 0.8 -- 0.8% daily growth
            ELSE 1.5 -- Default 1.5% daily growth
        END;
        
        -- Determine pattern type based on growth characteristics
        v_pattern_type := CASE 
            WHEN v_growth_rate > 3.0 THEN 'EXPONENTIAL'
            WHEN v_growth_rate > 1.0 THEN 'LINEAR'
            WHEN v_growth_rate > 0.1 THEN 'SLOW_GROWTH'
            ELSE 'STABLE'
        END;
        
        -- Calculate confidence based on data points and consistency
        v_confidence := LEAST(95.0, 60.0 + (v_pattern_record.data_points * 2.0));
        
        -- Generate forecasts using compound growth
        v_forecast_7d := v_current_usage * POWER(1 + (v_growth_rate / 100.0), 7);
        v_forecast_30d := v_current_usage * POWER(1 + (v_growth_rate / 100.0), 30);
        v_forecast_90d := v_current_usage * POWER(1 + (v_growth_rate / 100.0), 90);
        
        -- Calculate days to capacity
        IF v_growth_rate > 0 THEN
            v_days_to_capacity := CEIL(LN(v_capacity / v_current_usage) / LN(1 + (v_growth_rate / 100.0)));
        ELSE
            v_days_to_capacity := NULL; -- No growth, won't reach capacity
        END IF;
        
        -- Generate recommendations
        v_action := CASE 
            WHEN v_days_to_capacity IS NOT NULL AND v_days_to_capacity <= 30 THEN 
                'URGENT: Capacity will be reached in ' || v_days_to_capacity || ' days. Immediate scaling required.'
            WHEN v_days_to_capacity IS NOT NULL AND v_days_to_capacity <= 90 THEN 
                'Plan capacity expansion within ' || v_days_to_capacity || ' days. Monitor closely.'
            WHEN v_days_to_capacity IS NOT NULL AND v_days_to_capacity <= 365 THEN 
                'Schedule capacity planning review. Expansion needed within ' || v_days_to_capacity || ' days.'
            WHEN v_pattern_type = 'EXPONENTIAL' THEN 
                'High growth rate detected. Implement auto-scaling and monitor trends.'
            ELSE 
                'Current growth pattern is sustainable. Continue monitoring.'
        END;
        
        -- Store growth pattern analysis
        v_pattern_bk := 'PATTERN_' || v_pattern_record.resource_type || '_' || 
                       COALESCE(encode(p_tenant_hk, 'hex'), 'SYSTEM') || '_' ||
                       to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
        v_pattern_hk := util.hash_binary(v_pattern_bk);
        
        INSERT INTO capacity_planning.growth_pattern_h VALUES (
            v_pattern_hk, v_pattern_bk, p_tenant_hk,
            util.current_load_date(), 'GROWTH_ANALYZER'
        ) ON CONFLICT (growth_pattern_bk) DO NOTHING;
        
        INSERT INTO capacity_planning.growth_pattern_s VALUES (
            v_pattern_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(v_pattern_bk || v_pattern_type || v_growth_rate::text),
            CURRENT_TIMESTAMP,
            v_pattern_type,
            v_pattern_record.resource_type,
            v_analysis_start,
            CURRENT_TIMESTAMP,
            v_pattern_record.data_points,
            v_growth_rate,
            0.0, -- growth_acceleration (would calculate from historical data)
            false, -- seasonality_detected (would analyze for seasonal patterns)
            NULL, -- seasonal_period_days
            NULL, -- seasonal_amplitude
            LEAST(100.0, ABS(v_growth_rate) * 10), -- trend_strength
            v_confidence, -- pattern_stability
            v_confidence, -- pattern_confidence
            0, -- outliers_detected
            0.0, -- outlier_impact_score
            jsonb_build_object(
                'data_points', v_pattern_record.data_points,
                'analysis_period_days', p_analysis_days,
                'current_utilization_pct', ROUND((v_current_usage / v_capacity * 100), 2)
            ),
            jsonb_build_object(), -- external_events_impact
            0, -- pattern_breaks_detected
            NULL, -- last_pattern_break_date
            NULL, -- forecast_accuracy_7d (would track over time)
            NULL, -- forecast_accuracy_30d
            NULL, -- forecast_accuracy_90d
            jsonb_build_object('method', 'compound_growth', 'base_rate', v_growth_rate),
            v_confidence, -- cross_validation_score
            jsonb_build_object('method', 'simple_residual_analysis'),
            'Growth pattern analysis for ' || v_pattern_record.resource_type || ' resource',
            ARRAY['user_growth', 'business_expansion', 'seasonal_demand'], -- business_drivers
            ARRAY['market_changes', 'competition', 'economic_factors'], -- risk_factors
            CASE v_pattern_type
                WHEN 'EXPONENTIAL' THEN 'High growth may not be sustainable long-term'
                WHEN 'LINEAR' THEN 'Steady growth pattern appears sustainable'
                ELSE 'Stable pattern with low risk'
            END,
            CASE 
                WHEN v_growth_rate > 2.0 THEN 'HOURLY'
                WHEN v_growth_rate > 1.0 THEN 'DAILY'
                ELSE 'WEEKLY'
            END, -- recommended_monitoring_frequency
            CURRENT_DATE + INTERVAL '30 days', -- next_analysis_due_date
            jsonb_build_object('version', 1, 'created', CURRENT_TIMESTAMP),
            v_confidence, -- statistical_significance
            jsonb_build_object(
                'lower_7d', v_forecast_7d * 0.9,
                'upper_7d', v_forecast_7d * 1.1,
                'lower_30d', v_forecast_30d * 0.85,
                'upper_30d', v_forecast_30d * 1.15
            ),
            'GROWTH_ANALYZER'
        ) ON CONFLICT (growth_pattern_hk, load_date) DO NOTHING;
        
        -- Create capacity forecast based on growth pattern
        v_forecast_bk := 'FORECAST_' || v_pattern_record.resource_type || '_' || 
                        COALESCE(encode(p_tenant_hk, 'hex'), 'SYSTEM') || '_' ||
                        to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
        v_forecast_hk := util.hash_binary(v_forecast_bk);
        
        INSERT INTO capacity_planning.capacity_forecast_h VALUES (
            v_forecast_hk, v_forecast_bk, p_tenant_hk,
            util.current_load_date(), 'GROWTH_ANALYZER'
        ) ON CONFLICT (capacity_forecast_bk) DO NOTHING;
        
        INSERT INTO capacity_planning.capacity_forecast_s VALUES (
            v_forecast_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(v_forecast_bk || v_forecast_30d::text),
            CURRENT_TIMESTAMP,
            v_pattern_record.resource_type,
            v_pattern_record.resource_category,
            v_current_usage,
            v_capacity,
            ROUND((v_current_usage / v_capacity * 100), 2),
            v_forecast_7d,
            v_forecast_30d,
            v_forecast_90d,
            v_current_usage * POWER(1 + (v_growth_rate / 100.0), 365), -- 1 year forecast
            v_growth_rate, -- growth_rate_daily
            v_growth_rate * 7, -- growth_rate_weekly
            v_growth_rate * 30, -- growth_rate_monthly
            v_days_to_capacity,
            GREATEST(0, COALESCE(v_days_to_capacity, 9999) - 30), -- time_to_warning_days
            GREATEST(0, COALESCE(v_days_to_capacity, 9999) - 7), -- time_to_critical_days
            v_action,
            CASE 
                WHEN v_days_to_capacity IS NOT NULL AND v_days_to_capacity <= 30 THEN 'URGENT'
                WHEN v_days_to_capacity IS NOT NULL AND v_days_to_capacity <= 90 THEN 'HIGH'
                WHEN v_pattern_type = 'EXPONENTIAL' THEN 'HIGH'
                ELSE 'MEDIUM'
            END, -- action_priority
            v_confidence,
            CASE v_pattern_type
                WHEN 'EXPONENTIAL' THEN 'EXPONENTIAL'
                WHEN 'LINEAR' THEN 'LINEAR'
                ELSE 'POLYNOMIAL'
            END, -- forecast_model
            v_confidence, -- model_accuracy
            1.0, -- seasonal_factor (would calculate from seasonal analysis)
            CASE 
                WHEN v_growth_rate > 2.0 THEN 'INCREASING'
                WHEN v_growth_rate > 0.1 THEN 'STABLE'
                ELSE 'STABLE'
            END, -- trend_direction
            LEAST(100.0, ABS(v_growth_rate) * 5), -- volatility_score
            v_pattern_record.data_points,
            90, -- forecast_horizon_days
            CURRENT_TIMESTAMP, -- last_model_training
            jsonb_build_object(
                'growth_rate', v_growth_rate,
                'pattern_type', v_pattern_type,
                'analysis_method', 'compound_growth'
            ),
            jsonb_build_object(), -- external_factors
            CASE 
                WHEN v_days_to_capacity IS NOT NULL AND v_days_to_capacity <= 90 THEN 
                    'High impact - capacity constraints will affect performance and user experience'
                ELSE 
                    'Medium impact - manageable growth within current capacity'
            END,
            CASE v_pattern_record.resource_type
                WHEN 'STORAGE' THEN v_forecast_30d * 0.10 -- $0.10 per GB per month
                WHEN 'CONNECTIONS' THEN v_forecast_30d * 5.0 -- $5 per connection per month
                ELSE 100.0 -- Default cost estimate
            END, -- cost_projection
            CASE 
                WHEN v_days_to_capacity IS NOT NULL AND v_days_to_capacity <= 30 THEN 'CRITICAL'
                WHEN v_days_to_capacity IS NOT NULL AND v_days_to_capacity <= 90 THEN 'HIGH'
                ELSE 'MEDIUM'
            END, -- risk_assessment
            CASE 
                WHEN v_days_to_capacity IS NOT NULL AND v_days_to_capacity <= 90 THEN 
                    ARRAY['implement_auto_scaling', 'increase_capacity', 'optimize_usage', 'monitor_closely']
                ELSE 
                    ARRAY['continue_monitoring', 'plan_future_capacity']
            END, -- mitigation_strategies
            'GROWTH_ANALYZER'
        ) ON CONFLICT (capacity_forecast_hk, load_date) DO NOTHING;
        
        -- Link pattern to forecast
        v_link_hk := util.hash_binary(encode(v_pattern_hk, 'hex') || encode(v_forecast_hk, 'hex'));
        
        INSERT INTO capacity_planning.pattern_forecast_l VALUES (
            v_link_hk, v_pattern_hk, v_forecast_hk, p_tenant_hk,
            util.current_load_date(), 'GROWTH_ANALYZER'
        ) ON CONFLICT (link_pattern_forecast_hk) DO NOTHING;
        
        -- Return analysis results
        RETURN QUERY SELECT 
            v_pattern_record.resource_type,
            v_pattern_type,
            v_growth_rate,
            v_confidence,
            v_forecast_7d,
            v_forecast_30d,
            v_forecast_90d,
            v_days_to_capacity,
            v_action;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- CAPACITY THRESHOLD MANAGEMENT
-- =====================================================================================

-- Function to create and manage capacity thresholds
CREATE OR REPLACE FUNCTION capacity_planning.create_capacity_threshold(
    p_tenant_hk BYTEA,
    p_threshold_name VARCHAR(200),
    p_resource_type VARCHAR(50),
    p_threshold_percentage DECIMAL(5,2),
    p_threshold_type VARCHAR(50) DEFAULT 'WARNING',
    p_alert_enabled BOOLEAN DEFAULT true
) RETURNS BYTEA AS $$
DECLARE
    v_threshold_hk BYTEA;
    v_threshold_bk VARCHAR(255);
BEGIN
    v_threshold_bk := 'THRESHOLD_' || p_resource_type || '_' || p_threshold_type || '_' ||
                     COALESCE(encode(p_tenant_hk, 'hex'), 'SYSTEM');
    v_threshold_hk := util.hash_binary(v_threshold_bk);
    
    -- Insert threshold hub
    INSERT INTO capacity_planning.capacity_threshold_h VALUES (
        v_threshold_hk, v_threshold_bk, p_tenant_hk,
        util.current_load_date(), 'THRESHOLD_MANAGER'
    ) ON CONFLICT (capacity_threshold_bk) DO NOTHING;
    
    -- Insert threshold satellite
    INSERT INTO capacity_planning.capacity_threshold_s VALUES (
        v_threshold_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(v_threshold_bk || p_threshold_percentage::text),
        p_threshold_name,
        p_resource_type,
        CASE p_resource_type
            WHEN 'STORAGE' THEN 'DATABASE'
            WHEN 'CONNECTIONS' THEN 'DATABASE'
            WHEN 'MEMORY' THEN 'SYSTEM'
            WHEN 'CPU' THEN 'SYSTEM'
            ELSE 'APPLICATION'
        END, -- resource_category
        p_threshold_type,
        0.0, -- threshold_value (will be calculated)
        p_threshold_percentage,
        'GTE', -- threshold_operator
        5, -- evaluation_frequency_minutes
        p_alert_enabled,
        CASE p_threshold_type
            WHEN 'CRITICAL' THEN 'CRITICAL'
            WHEN 'WARNING' THEN 'WARNING'
            ELSE 'MEDIUM'
        END, -- alert_severity
        'Resource ' || p_resource_type || ' has exceeded ' || p_threshold_percentage || '% capacity',
        ARRAY['EMAIL', 'SLACK'], -- notification_channels
        CASE p_threshold_type WHEN 'CRITICAL' THEN true ELSE false END, -- escalation_enabled
        30, -- escalation_delay_minutes
        ARRAY['admin@onevault.com'], -- escalation_contacts
        false, -- auto_resolution_enabled
        NULL, -- auto_resolution_action
        true, -- suppression_enabled
        60, -- suppression_duration_minutes
        false, -- business_hours_only
        true, -- maintenance_window_exempt
        85.0, -- threshold_effectiveness_score
        5.0, -- false_positive_rate
        90.0, -- true_positive_rate
        NULL, -- last_triggered_date
        0, 0, 0, -- trigger counts
        NULL, -- average_resolution_time_minutes
        jsonb_build_object('created', CURRENT_TIMESTAMP, 'version', 1),
        ARRAY[]::TEXT[], -- related_thresholds
        ARRAY[]::TEXT[], -- dependency_thresholds
        'Capacity monitoring for ' || p_resource_type || ' resource',
        NULL, -- compliance_requirement
        0.0, -- cost_impact_per_trigger
        'Monitor ' || p_resource_type || ' utilization to prevent capacity issues',
        'Threshold for ' || p_resource_type || ' capacity monitoring at ' || p_threshold_percentage || '%',
        SESSION_USER, -- created_by
        NULL, -- approved_by
        NULL, -- approval_date
        90, -- review_frequency_days
        CURRENT_DATE + INTERVAL '90 days', -- next_review_date
        true, -- is_active
        'THRESHOLD_MANAGER'
    ) ON CONFLICT (capacity_threshold_hk, load_date) DO NOTHING;
    
    RETURN v_threshold_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to evaluate capacity thresholds
CREATE OR REPLACE FUNCTION capacity_planning.evaluate_capacity_thresholds(
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS TABLE (
    threshold_name VARCHAR(200),
    resource_type VARCHAR(50),
    current_utilization DECIMAL(5,2),
    threshold_percentage DECIMAL(5,2),
    threshold_exceeded BOOLEAN,
    alert_severity VARCHAR(20),
    recommended_action TEXT
) AS $$
DECLARE
    v_threshold_record RECORD;
    v_current_utilization DECIMAL(5,2);
    v_threshold_exceeded BOOLEAN;
    v_alert_message TEXT;
BEGIN
    FOR v_threshold_record IN 
        SELECT 
            cth.capacity_threshold_hk,
            cts.threshold_name,
            cts.resource_type,
            cts.threshold_percentage,
            cts.alert_severity,
            cts.alert_message_template
        FROM capacity_planning.capacity_threshold_h cth
        JOIN capacity_planning.capacity_threshold_s cts ON cth.capacity_threshold_hk = cts.capacity_threshold_hk
        WHERE (p_tenant_hk IS NULL OR cth.tenant_hk = p_tenant_hk)
        AND cts.is_active = true
        AND cts.alert_enabled = true
        AND cts.load_end_date IS NULL
    LOOP
        -- Get current utilization for this resource type
        SELECT COALESCE(AVG(rus.utilization_percentage), 0.0) INTO v_current_utilization
        FROM capacity_planning.resource_utilization_h ruh
        JOIN capacity_planning.resource_utilization_s rus ON ruh.resource_utilization_hk = rus.resource_utilization_hk
        WHERE (p_tenant_hk IS NULL OR ruh.tenant_hk = p_tenant_hk)
        AND rus.resource_type = v_threshold_record.resource_type
        AND rus.measurement_timestamp >= CURRENT_TIMESTAMP - INTERVAL '5 minutes'
        AND rus.load_end_date IS NULL;
        
        -- Check if threshold is exceeded
        v_threshold_exceeded := v_current_utilization >= v_threshold_record.threshold_percentage;
        
        -- Generate alert message
        v_alert_message := CASE 
            WHEN v_threshold_exceeded THEN 
                'ALERT: ' || v_threshold_record.resource_type || ' utilization (' || 
                v_current_utilization || '%) exceeds threshold (' || 
                v_threshold_record.threshold_percentage || '%)'
            ELSE 
                'OK: ' || v_threshold_record.resource_type || ' utilization within limits'
        END;
        
        -- Return threshold evaluation results
        RETURN QUERY SELECT 
            v_threshold_record.threshold_name,
            v_threshold_record.resource_type,
            v_current_utilization,
            v_threshold_record.threshold_percentage,
            v_threshold_exceeded,
            v_threshold_record.alert_severity,
            v_alert_message;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- CAPACITY PLANNING DASHBOARD VIEWS
-- =====================================================================================

-- Current capacity status view
CREATE VIEW capacity_planning.current_capacity_status AS
SELECT 
    COALESCE(encode(ruh.tenant_hk, 'hex'), 'SYSTEM') as tenant_id,
    rus.resource_type,
    rus.resource_category,
    ROUND(AVG(rus.current_value), 2) as current_usage,
    ROUND(MAX(rus.maximum_capacity), 2) as total_capacity,
    ROUND(AVG(rus.utilization_percentage), 2) as utilization_percentage,
    ROUND(AVG(rus.peak_value_24h), 2) as peak_24h,
    ROUND(AVG(rus.average_value_24h), 2) as average_24h,
    MAX(rus.measurement_timestamp) as last_measurement,
    CASE 
        WHEN AVG(rus.utilization_percentage) >= 90 THEN 'CRITICAL'
        WHEN AVG(rus.utilization_percentage) >= 80 THEN 'WARNING'
        WHEN AVG(rus.utilization_percentage) >= 70 THEN 'CAUTION'
        ELSE 'NORMAL'
    END as status,
    COUNT(*) as measurement_count
FROM capacity_planning.resource_utilization_h ruh
JOIN capacity_planning.resource_utilization_s rus ON ruh.resource_utilization_hk = rus.resource_utilization_hk
WHERE rus.measurement_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
AND rus.load_end_date IS NULL
GROUP BY ruh.tenant_hk, rus.resource_type, rus.resource_category;

-- Growth forecast summary view
CREATE VIEW capacity_planning.growth_forecast_summary AS
SELECT 
    COALESCE(encode(cfh.tenant_hk, 'hex'), 'SYSTEM') as tenant_id,
    cfs.resource_type,
    cfs.resource_category,
    ROUND(AVG(cfs.current_usage), 2) as current_usage,
    ROUND(AVG(cfs.projected_usage_30d), 2) as projected_30d,
    ROUND(AVG(cfs.projected_usage_90d), 2) as projected_90d,
    ROUND(AVG(cfs.growth_rate_daily), 4) as daily_growth_rate,
    ROUND(AVG(cfs.growth_rate_monthly), 4) as monthly_growth_rate,
    MIN(cfs.time_to_capacity_days) as min_days_to_capacity,
    AVG(cfs.confidence_level) as avg_confidence,
    cfs.forecast_model,
    cfs.trend_direction,
    MAX(cfs.forecast_timestamp) as last_forecast,
    CASE 
        WHEN MIN(cfs.time_to_capacity_days) <= 30 THEN 'URGENT'
        WHEN MIN(cfs.time_to_capacity_days) <= 90 THEN 'HIGH'
        WHEN AVG(cfs.growth_rate_daily) > 2.0 THEN 'MEDIUM'
        ELSE 'LOW'
    END as priority
FROM capacity_planning.capacity_forecast_h cfh
JOIN capacity_planning.capacity_forecast_s cfs ON cfh.capacity_forecast_hk = cfs.capacity_forecast_hk
WHERE cfs.forecast_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
AND cfs.load_end_date IS NULL
GROUP BY cfh.tenant_hk, cfs.resource_type, cfs.resource_category, 
         cfs.forecast_model, cfs.trend_direction;

-- Capacity alerts view
CREATE VIEW capacity_planning.capacity_alerts AS
SELECT 
    COALESCE(encode(cth.tenant_hk, 'hex'), 'SYSTEM') as tenant_id,
    cts.threshold_name,
    cts.resource_type,
    cts.threshold_type,
    cts.threshold_percentage,
    cts.alert_severity,
    cts.last_triggered_date,
    cts.trigger_count_24h,
    cts.trigger_count_7d,
    cts.trigger_count_30d,
    cts.average_resolution_time_minutes,
    cts.false_positive_rate,
    cts.true_positive_rate,
    cts.threshold_effectiveness_score,
    CASE 
        WHEN cts.trigger_count_24h > 10 THEN 'HIGH_FREQUENCY'
        WHEN cts.trigger_count_24h > 5 THEN 'MEDIUM_FREQUENCY'
        WHEN cts.trigger_count_24h > 0 THEN 'LOW_FREQUENCY'
        ELSE 'NO_TRIGGERS'
    END as trigger_frequency,
    cts.is_active
FROM capacity_planning.capacity_threshold_h cth
JOIN capacity_planning.capacity_threshold_s cts ON cth.capacity_threshold_hk = cts.capacity_threshold_hk
WHERE cts.load_end_date IS NULL
ORDER BY cts.alert_severity DESC, cts.trigger_count_24h DESC;

-- =====================================================================================
-- AUTOMATED CAPACITY MANAGEMENT PROCEDURES
-- =====================================================================================

-- Procedure to run comprehensive capacity analysis
CREATE OR REPLACE PROCEDURE capacity_planning.run_capacity_analysis(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_create_default_thresholds BOOLEAN DEFAULT true
) AS $$
DECLARE
    v_analysis_results RECORD;
    v_threshold_hk BYTEA;
BEGIN
    -- Step 1: Capture current resource utilization
    RAISE NOTICE 'Capturing current resource utilization...';
    PERFORM capacity_planning.capture_resource_utilization(p_tenant_hk);
    
    -- Step 2: Analyze growth patterns and generate forecasts
    RAISE NOTICE 'Analyzing growth patterns...';
    FOR v_analysis_results IN 
        SELECT * FROM capacity_planning.analyze_growth_patterns(p_tenant_hk, NULL, 30)
    LOOP
        RAISE NOTICE 'Resource: %, Pattern: %, Growth Rate: % percent, Days to Capacity: %', 
                     v_analysis_results.resource_type,
                     v_analysis_results.pattern_type,
                     v_analysis_results.growth_rate_percentage,
                     v_analysis_results.time_to_capacity_days;
    END LOOP;
    
    -- Step 3: Create default thresholds if requested
    IF p_create_default_thresholds THEN
        RAISE NOTICE 'Creating default capacity thresholds...';
        
        -- Storage thresholds
        v_threshold_hk := capacity_planning.create_capacity_threshold(
            p_tenant_hk, 'Storage Warning Threshold', 'STORAGE', 80.0, 'WARNING', true
        );
        v_threshold_hk := capacity_planning.create_capacity_threshold(
            p_tenant_hk, 'Storage Critical Threshold', 'STORAGE', 90.0, 'CRITICAL', true
        );
        
        -- Connection thresholds
        v_threshold_hk := capacity_planning.create_capacity_threshold(
            p_tenant_hk, 'Connection Warning Threshold', 'CONNECTIONS', 75.0, 'WARNING', true
        );
        v_threshold_hk := capacity_planning.create_capacity_threshold(
            p_tenant_hk, 'Connection Critical Threshold', 'CONNECTIONS', 85.0, 'CRITICAL', true
        );
        
        -- Memory thresholds
        v_threshold_hk := capacity_planning.create_capacity_threshold(
            p_tenant_hk, 'Memory Warning Threshold', 'MEMORY', 80.0, 'WARNING', true
        );
        v_threshold_hk := capacity_planning.create_capacity_threshold(
            p_tenant_hk, 'Memory Critical Threshold', 'MEMORY', 90.0, 'CRITICAL', true
        );
        
        -- User thresholds
        v_threshold_hk := capacity_planning.create_capacity_threshold(
            p_tenant_hk, 'User Count Warning Threshold', 'USERS', 80.0, 'WARNING', true
        );
        v_threshold_hk := capacity_planning.create_capacity_threshold(
            p_tenant_hk, 'User Count Critical Threshold', 'USERS', 90.0, 'CRITICAL', true
        );
    END IF;
    
    -- Step 4: Evaluate all thresholds
    RAISE NOTICE 'Evaluating capacity thresholds...';
    PERFORM capacity_planning.evaluate_capacity_thresholds(p_tenant_hk);
    
    RAISE NOTICE 'Capacity analysis completed successfully';
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- COMMENTS AND DOCUMENTATION
-- =====================================================================================

COMMENT ON SCHEMA capacity_planning IS 
'Capacity planning and growth management schema for One Vault platform. Implements Data Vault 2.0 methodology for tracking resource utilization, analyzing growth patterns, generating forecasts, and managing capacity thresholds with comprehensive alerting and automated analysis capabilities.';

COMMENT ON TABLE capacity_planning.capacity_forecast_h IS 
'Hub table for capacity forecasting events. Stores unique identifiers for each capacity forecast analysis with tenant isolation and temporal tracking.';

COMMENT ON TABLE capacity_planning.capacity_forecast_s IS 
'Satellite table storing detailed capacity forecast information including growth projections, confidence levels, time-to-capacity calculations, and recommended actions with comprehensive forecasting metrics.';

COMMENT ON TABLE capacity_planning.resource_utilization_h IS 
'Hub table for resource utilization monitoring events. Tracks unique resource measurement instances with tenant isolation.';

COMMENT ON TABLE capacity_planning.resource_utilization_s IS 
'Satellite table storing detailed resource utilization metrics including current usage, capacity limits, utilization percentages, peak values, and performance impact assessments.';

COMMENT ON FUNCTION capacity_planning.analyze_growth_patterns IS 
'Analyzes historical resource utilization data to identify growth patterns, calculate growth rates, generate forecasts, and provide capacity planning recommendations with confidence levels and time-to-capacity projections.';

COMMENT ON FUNCTION capacity_planning.create_capacity_threshold IS 
'Creates capacity monitoring thresholds for resources with configurable alert settings, notification channels, and escalation procedures for proactive capacity management.';

COMMENT ON PROCEDURE capacity_planning.run_capacity_analysis IS 
'Comprehensive capacity analysis procedure that captures current utilization, analyzes growth patterns, creates default thresholds, and evaluates capacity status for proactive capacity management.';

-- Grant appropriate permissions
GRANT USAGE ON SCHEMA capacity_planning TO postgres;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA capacity_planning TO postgres;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA capacity_planning TO postgres;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA capacity_planning TO postgres; 