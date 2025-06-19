-- Generic AI Business Intelligence Framework
-- Configurable system for any business domain learning and optimization

BEGIN;

-- ==========================================
-- GENERIC AI BUSINESS INTELLIGENCE HUB
-- ==========================================

CREATE TABLE IF NOT EXISTS business.ai_business_intelligence_h (
    ai_business_intelligence_hk BYTEA PRIMARY KEY,
    ai_business_intelligence_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    CONSTRAINT uk_ai_business_intelligence_h_bk_tenant 
        UNIQUE (ai_business_intelligence_bk, tenant_hk)
);

COMMENT ON TABLE business.ai_business_intelligence_h IS 
'Generic hub for AI business intelligence tracking - configurable for any business domain (horses, equipment, patients, products, etc.)';

-- ==========================================
-- AI LEARNING PATTERN SATELLITE  
-- ==========================================

CREATE TABLE IF NOT EXISTS business.ai_learning_pattern_s (
    ai_business_intelligence_hk BYTEA NOT NULL REFERENCES business.ai_business_intelligence_h(ai_business_intelligence_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Generic configuration fields
    business_domain VARCHAR(100) NOT NULL,        -- 'equine_management', 'medical_devices', 'manufacturing'
    entity_type VARCHAR(100) NOT NULL,            -- 'horse', 'mri_machine', 'production_line'
    entity_identifier VARCHAR(255) NOT NULL,      -- 'Thunder_Horse_ID_123', 'MRI_Unit_A7'
    
    -- Learning pattern data
    pattern_type VARCHAR(100) NOT NULL,           -- 'health_trend', 'performance_pattern', 'maintenance_cycle'
    pattern_data JSONB NOT NULL,                  -- Flexible storage for any pattern data
    confidence_score DECIMAL(5,4),                -- How confident we are in this pattern
    sample_size INTEGER,                          -- How many data points learned from
    
    -- Pattern metadata
    learning_algorithm VARCHAR(100),              -- 'time_series', 'clustering', 'regression'
    pattern_discovered_date DATE NOT NULL,
    pattern_last_validated DATE,
    pattern_accuracy DECIMAL(5,4),                -- How accurate predictions have been
    
    -- Business impact tracking
    predictions_made INTEGER DEFAULT 0,
    predictions_correct INTEGER DEFAULT 0,
    business_value_generated DECIMAL(15,2),       -- Money saved/earned from this pattern
    
    -- Configuration and rules
    alert_thresholds JSONB,                       -- Configurable alert conditions
    decision_rules JSONB,                         -- Business rules for this pattern
    
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL,
    
    PRIMARY KEY (ai_business_intelligence_hk, load_date),
    
    CONSTRAINT chk_ai_learning_pattern_s_confidence 
        CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 1)),
    CONSTRAINT chk_ai_learning_pattern_s_accuracy 
        CHECK (pattern_accuracy IS NULL OR (pattern_accuracy >= 0 AND pattern_accuracy <= 1))
);

COMMENT ON TABLE business.ai_learning_pattern_s IS 
'Generic satellite storing AI learning patterns for any business domain with configurable pattern recognition and business rule application.';

-- ==========================================
-- AI DECISION ENGINE SATELLITE
-- ==========================================

CREATE TABLE IF NOT EXISTS business.ai_decision_engine_s (
    ai_business_intelligence_hk BYTEA NOT NULL REFERENCES business.ai_business_intelligence_h(ai_business_intelligence_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Decision context
    decision_type VARCHAR(100) NOT NULL,          -- 'feeding_schedule', 'maintenance_alert', 'inventory_reorder'
    decision_trigger VARCHAR(100) NOT NULL,       -- 'threshold_exceeded', 'pattern_detected', 'schedule_based'
    
    -- Decision input data
    input_data JSONB NOT NULL,                    -- The data that triggered this decision
    applied_rules JSONB,                          -- Which business rules were applied
    pattern_matches JSONB,                        -- Which learned patterns influenced this
    
    -- Decision output
    decision_made JSONB NOT NULL,                 -- The actual decision/recommendation
    confidence_level DECIMAL(5,4),                -- Confidence in this decision
    expected_impact JSONB,                        -- Expected business impact
    
    -- Execution tracking
    decision_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    auto_executed BOOLEAN DEFAULT false,          -- Was this decision executed automatically?
    manual_override BOOLEAN DEFAULT false,        -- Did human override the decision?
    execution_status VARCHAR(50),                 -- 'pending', 'executed', 'cancelled', 'overridden'
    
    -- Outcome tracking (for learning)
    actual_outcome JSONB,                         -- What actually happened
    outcome_measured_date TIMESTAMP WITH TIME ZONE,
    decision_effectiveness DECIMAL(5,4),          -- How effective was this decision (0-1)
    lessons_learned JSONB,                        -- What we learned from this decision
    
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL,
    
    PRIMARY KEY (ai_business_intelligence_hk, load_date)
);

COMMENT ON TABLE business.ai_decision_engine_s IS 
'Generic satellite storing AI-driven business decisions with outcome tracking for continuous learning and improvement across any business domain.';

-- ==========================================  
-- AI RECOMMENDATION SATELLITE
-- ==========================================

CREATE TABLE IF NOT EXISTS business.ai_recommendation_s (
    ai_business_intelligence_hk BYTEA NOT NULL REFERENCES business.ai_business_intelligence_h(ai_business_intelligence_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Recommendation details
    recommendation_type VARCHAR(100) NOT NULL,    -- 'optimization', 'prevention', 'enhancement'
    recommendation_category VARCHAR(100) NOT NULL, -- 'health', 'performance', 'cost', 'efficiency'
    recommendation_title VARCHAR(255) NOT NULL,
    recommendation_description TEXT NOT NULL,
    
    -- Supporting data
    supporting_patterns JSONB,                    -- Patterns that support this recommendation
    supporting_data JSONB,                        -- Data that supports this recommendation
    risk_assessment JSONB,                        -- Risks of following/not following
    
    -- Impact projections
    projected_benefits JSONB,                     -- Expected benefits
    projected_costs JSONB,                        -- Expected costs
    roi_estimate DECIMAL(10,4),                   -- Return on investment estimate
    payback_period_days INTEGER,                  -- Expected payback period
    
    -- Priority and urgency
    priority_score INTEGER DEFAULT 50,            -- 1-100 priority ranking
    urgency_level VARCHAR(20) DEFAULT 'MEDIUM',   -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
    recommended_timeline VARCHAR(100),            -- 'immediately', 'within_week', 'within_month'
    
    -- Tracking and feedback
    recommendation_status VARCHAR(50) DEFAULT 'ACTIVE', -- 'active', 'implemented', 'dismissed', 'expired'
    user_feedback JSONB,                          -- User feedback on recommendations
    implementation_date TIMESTAMP WITH TIME ZONE,
    actual_results JSONB,                         -- Actual results after implementation
    
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL,
    
    PRIMARY KEY (ai_business_intelligence_hk, load_date),
    
    CONSTRAINT chk_ai_recommendation_s_priority 
        CHECK (priority_score >= 1 AND priority_score <= 100),
    CONSTRAINT chk_ai_recommendation_s_urgency 
        CHECK (urgency_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'))
);

COMMENT ON TABLE business.ai_recommendation_s IS 
'Generic satellite storing AI recommendations with ROI tracking and implementation feedback for continuous improvement across any business domain.';

-- ==========================================
-- BUSINESS DOMAIN CONFIGURATION
-- ==========================================

CREATE TABLE IF NOT EXISTS config.ai_business_domain_config (
    domain_config_id SERIAL PRIMARY KEY,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    
    -- Domain identification
    business_domain VARCHAR(100) NOT NULL,        -- 'equine_management', 'healthcare', 'manufacturing'
    domain_display_name VARCHAR(200) NOT NULL,    -- 'Horse Barn Management', 'Medical Equipment'
    
    -- Entity configuration
    entity_types JSONB NOT NULL,                  -- Array of entity types in this domain
    entity_attributes JSONB NOT NULL,             -- Attributes to track for each entity type
    
    -- Learning configuration
    pattern_types JSONB NOT NULL,                 -- Types of patterns to learn
    learning_algorithms JSONB NOT NULL,           -- Which algorithms to use
    learning_rules JSONB NOT NULL,                -- Business rules for learning
    
    -- Decision configuration
    decision_types JSONB NOT NULL,                -- Types of decisions to make
    alert_thresholds JSONB NOT NULL,              -- Configurable thresholds
    automation_rules JSONB NOT NULL,              -- What can be automated
    
    -- Business metrics
    success_metrics JSONB NOT NULL,               -- How to measure success
    roi_calculations JSONB NOT NULL,              -- How to calculate ROI
    
    -- Configuration metadata
    config_version VARCHAR(50) NOT NULL DEFAULT '1.0',
    created_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    
    CONSTRAINT uk_ai_business_domain_config_tenant_domain 
        UNIQUE (tenant_hk, business_domain)
);

COMMENT ON TABLE config.ai_business_domain_config IS 
'Configuration table that defines how the generic AI business intelligence framework should behave for specific business domains.';

-- ==========================================
-- GENERIC AI LEARNING FUNCTION
-- ==========================================

CREATE OR REPLACE FUNCTION business.ai_learn_from_data(
    p_tenant_hk BYTEA,
    p_business_domain VARCHAR(100),
    p_entity_type VARCHAR(100),
    p_entity_id VARCHAR(255),
    p_data_points JSONB,  -- Array of data points to learn from
    p_learning_context JSONB DEFAULT '{}'::jsonb
) RETURNS JSONB AS $$
DECLARE
    v_config RECORD;
    v_intelligence_hk BYTEA;
    v_intelligence_bk VARCHAR(255);
    v_patterns_discovered JSONB := '[]'::jsonb;
    v_learning_results JSONB;
BEGIN
    -- Get domain configuration
    SELECT * INTO v_config
    FROM config.ai_business_domain_config
    WHERE tenant_hk = p_tenant_hk
    AND business_domain = p_business_domain
    AND is_active = true;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Business domain configuration not found: ' || p_business_domain
        );
    END IF;
    
    -- Generate intelligence record ID
    v_intelligence_bk := p_business_domain || '_' || p_entity_type || '_' || p_entity_id || '_LEARNING';
    v_intelligence_hk := util.hash_binary(v_intelligence_bk);
    
    -- Create or update intelligence hub record
    INSERT INTO business.ai_business_intelligence_h (
        ai_business_intelligence_hk,
        ai_business_intelligence_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_intelligence_hk,
        v_intelligence_bk,
        p_tenant_hk,
        util.current_load_date(),
        'AI_LEARNING_ENGINE'
    ) ON CONFLICT (ai_business_intelligence_bk, tenant_hk) DO NOTHING;
    
    -- Simple pattern discovery (would be more sophisticated in real implementation)
    IF jsonb_array_length(p_data_points) >= 5 THEN
        -- End-date previous pattern record
        UPDATE business.ai_learning_pattern_s 
        SET load_end_date = util.current_load_date()
        WHERE ai_business_intelligence_hk = v_intelligence_hk
        AND pattern_type = 'general_trend'
        AND load_end_date IS NULL;
        
        -- Insert new pattern record
        INSERT INTO business.ai_learning_pattern_s (
            ai_business_intelligence_hk,
            load_date,
            hash_diff,
            business_domain,
            entity_type,
            entity_identifier,
            pattern_type,
            pattern_data,
            confidence_score,
            sample_size,
            learning_algorithm,
            pattern_discovered_date,
            pattern_accuracy,
            alert_thresholds,
            decision_rules,
            tenant_hk,
            record_source
        ) VALUES (
            v_intelligence_hk,
            util.current_load_date(),
            util.hash_binary(v_intelligence_bk || 'general_trend'),
            p_business_domain,
            p_entity_type,
            p_entity_id,
            'general_trend',
            jsonb_build_object(
                'pattern_data', p_data_points,
                'learning_context', p_learning_context
            ),
            0.85, -- Simplified confidence
            jsonb_array_length(p_data_points),
            'time_series_analysis',
            CURRENT_DATE,
            0.80, -- Initial accuracy assumption
            v_config.alert_thresholds,
            v_config.automation_rules,
            p_tenant_hk,
            'AI_LEARNING_ENGINE'
        );
        
        v_patterns_discovered := v_patterns_discovered || jsonb_build_object(
            'pattern_type', 'general_trend',
            'confidence', 0.85,
            'sample_size', jsonb_array_length(p_data_points)
        );
    END IF;
    
    -- Build learning results
    v_learning_results := jsonb_build_object(
        'success', true,
        'timestamp', CURRENT_TIMESTAMP,
        'entity', jsonb_build_object(
            'domain', p_business_domain,
            'type', p_entity_type,
            'id', p_entity_id
        ),
        'data_points_processed', jsonb_array_length(p_data_points),
        'patterns_discovered', v_patterns_discovered,
        'intelligence_record_id', encode(v_intelligence_hk, 'hex')
    );
    
    RETURN v_learning_results;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- CONFIGURATION SETUP FUNCTION
-- ==========================================

CREATE OR REPLACE FUNCTION config.setup_business_domain(
    p_tenant_hk BYTEA,
    p_business_domain VARCHAR(100),
    p_domain_display_name VARCHAR(200),
    p_configuration JSONB
) RETURNS JSONB AS $$
BEGIN
    INSERT INTO config.ai_business_domain_config (
        tenant_hk,
        business_domain,
        domain_display_name,
        entity_types,
        entity_attributes,
        pattern_types,
        learning_algorithms,
        learning_rules,
        decision_types,
        alert_thresholds,
        automation_rules,
        success_metrics,
        roi_calculations
    ) VALUES (
        p_tenant_hk,
        p_business_domain,
        p_domain_display_name,
        p_configuration->'entity_types',
        p_configuration->'entity_attributes',
        p_configuration->'pattern_types',
        p_configuration->'learning_algorithms',
        p_configuration->'learning_rules',
        p_configuration->'decision_types',
        p_configuration->'alert_thresholds',
        p_configuration->'automation_rules',
        p_configuration->'success_metrics',
        p_configuration->'roi_calculations'
    ) ON CONFLICT (tenant_hk, business_domain) 
    DO UPDATE SET
        domain_display_name = EXCLUDED.domain_display_name,
        entity_types = EXCLUDED.entity_types,
        entity_attributes = EXCLUDED.entity_attributes,
        pattern_types = EXCLUDED.pattern_types,
        learning_algorithms = EXCLUDED.learning_algorithms,
        learning_rules = EXCLUDED.learning_rules,
        decision_types = EXCLUDED.decision_types,
        alert_thresholds = EXCLUDED.alert_thresholds,
        automation_rules = EXCLUDED.automation_rules,
        success_metrics = EXCLUDED.success_metrics,
        roi_calculations = EXCLUDED.roi_calculations,
        last_updated = CURRENT_TIMESTAMP;
    
    RETURN jsonb_build_object(
        'success', true,
        'domain_configured', p_business_domain,
        'display_name', p_domain_display_name,
        'timestamp', CURRENT_TIMESTAMP
    );
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- GET ENTITY INSIGHTS
-- ==========================================

CREATE OR REPLACE FUNCTION business.get_entity_insights(
    p_tenant_hk BYTEA,
    p_business_domain VARCHAR(100),
    p_entity_type VARCHAR(100),
    p_entity_id VARCHAR(255)
) RETURNS JSONB AS $$
DECLARE
    v_insights JSONB;
    v_patterns JSONB;
BEGIN
    -- Get learned patterns for this entity
    WITH entity_patterns AS (
        SELECT 
            pattern_type,
            confidence_score,
            pattern_data,
            business_value_generated,
            predictions_made,
            predictions_correct,
            pattern_discovered_date
        FROM business.ai_learning_pattern_s alps
        JOIN business.ai_business_intelligence_h abih ON alps.ai_business_intelligence_hk = abih.ai_business_intelligence_hk
        WHERE abih.tenant_hk = p_tenant_hk
        AND alps.business_domain = p_business_domain
        AND alps.entity_type = p_entity_type
        AND alps.entity_identifier = p_entity_id
        AND alps.load_end_date IS NULL
        ORDER BY alps.confidence_score DESC
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'pattern_type', pattern_type,
            'confidence', confidence_score,
            'discovered_date', pattern_discovered_date,
            'predictions_accuracy', CASE 
                WHEN predictions_made > 0 THEN ROUND(predictions_correct::DECIMAL / predictions_made, 4)
                ELSE null
            END,
            'business_value', business_value_generated,
            'summary', pattern_data->'pattern_summary'
        )
    ) INTO v_patterns
    FROM entity_patterns;
    
    -- Build comprehensive insights
    v_insights := jsonb_build_object(
        'entity', jsonb_build_object(
            'domain', p_business_domain,
            'type', p_entity_type,
            'id', p_entity_id
        ),
        'analysis_timestamp', CURRENT_TIMESTAMP,
        'patterns_learned', COALESCE(jsonb_array_length(v_patterns), 0),
        'patterns_detail', COALESCE(v_patterns, '[]'::jsonb),
        'overall_confidence', (
            SELECT AVG(confidence_score)
            FROM business.ai_learning_pattern_s alps
            JOIN business.ai_business_intelligence_h abih ON alps.ai_business_intelligence_hk = abih.ai_business_intelligence_hk
            WHERE abih.tenant_hk = p_tenant_hk
            AND alps.business_domain = p_business_domain
            AND alps.entity_type = p_entity_type
            AND alps.entity_identifier = p_entity_id
            AND alps.load_end_date IS NULL
        ),
        'learning_status', CASE 
            WHEN v_patterns IS NULL THEN 'no_patterns_yet'
            WHEN jsonb_array_length(v_patterns) >= 3 THEN 'well_learned'
            WHEN jsonb_array_length(v_patterns) >= 1 THEN 'learning_in_progress'
            ELSE 'insufficient_data'
        END
    );
    
    RETURN v_insights;
END;
$$ LANGUAGE plpgsql;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_ai_learning_pattern_s_domain_entity 
ON business.ai_learning_pattern_s (business_domain, entity_type, entity_identifier) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_learning_pattern_s_confidence 
ON business.ai_learning_pattern_s (confidence_score DESC, pattern_discovered_date DESC) 
WHERE load_end_date IS NULL;

COMMIT; 