-- AI Automation Engine - "Set and Forget" System
-- Fully automated AI learning and decision-making with minimal human intervention

BEGIN;

-- Create automation schema
CREATE SCHEMA IF NOT EXISTS automation;

-- ==========================================
-- AUTOMATION CONTROL CENTER
-- ==========================================

CREATE TABLE IF NOT EXISTS automation.automation_schedule_h (
    automation_schedule_hk BYTEA PRIMARY KEY,
    automation_schedule_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    CONSTRAINT uk_automation_schedule_h_bk_tenant 
        UNIQUE (automation_schedule_bk, tenant_hk)
);

CREATE TABLE IF NOT EXISTS automation.automation_schedule_s (
    automation_schedule_hk BYTEA NOT NULL REFERENCES automation.automation_schedule_h(automation_schedule_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Automation configuration
    business_domain VARCHAR(100) NOT NULL,
    automation_type VARCHAR(100) NOT NULL,        -- 'data_collection', 'pattern_learning', 'decision_execution'
    automation_name VARCHAR(200) NOT NULL,
    automation_description TEXT,
    
    -- Scheduling
    schedule_type VARCHAR(50) NOT NULL,           -- 'continuous', 'hourly', 'daily', 'weekly', 'trigger_based'
    schedule_expression VARCHAR(100),             -- Cron expression or trigger condition
    last_executed TIMESTAMP WITH TIME ZONE,
    next_scheduled TIMESTAMP WITH TIME ZONE,
    
    -- Execution parameters
    automation_function VARCHAR(200) NOT NULL,    -- Function to execute
    execution_parameters JSONB,                   -- Parameters for the function
    timeout_minutes INTEGER DEFAULT 30,
    retry_attempts INTEGER DEFAULT 3,
    
    -- Status and monitoring
    is_active BOOLEAN DEFAULT true,
    execution_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    average_execution_time_ms INTEGER,
    last_error_message TEXT,
    
    -- Automation rules
    auto_disable_on_failure_count INTEGER DEFAULT 5,
    escalation_rules JSONB,                       -- Who to notify on failures
    success_metrics JSONB,                        -- How to measure success
    
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL,
    
    PRIMARY KEY (automation_schedule_hk, load_date)
);

-- ==========================================
-- AUTOMATED DATA COLLECTION ENGINE
-- ==========================================

CREATE OR REPLACE FUNCTION automation.auto_collect_entity_data(
    p_tenant_hk BYTEA,
    p_business_domain VARCHAR(100),
    p_entity_type VARCHAR(100),
    p_collection_config JSONB
) RETURNS JSONB AS $$
DECLARE
    v_entities_processed INTEGER := 0;
    v_data_points_collected INTEGER := 0;
    v_entity_record RECORD;
    v_collected_data JSONB;
    v_learning_result JSONB;
BEGIN
    -- Get all entities of this type for automated collection
    FOR v_entity_record IN 
        SELECT entity_identifier, last_data_collection
        FROM automation.entity_tracking
        WHERE tenant_hk = p_tenant_hk
        AND business_domain = p_business_domain
        AND entity_type = p_entity_type
        AND is_active = true
        AND (
            last_data_collection IS NULL OR 
            last_data_collection < CURRENT_TIMESTAMP - (p_collection_config->>'collection_interval')::INTERVAL
        )
    LOOP
        -- Simulate data collection (would integrate with actual IoT/sensors/APIs)
        v_collected_data := automation.simulate_data_collection(
            p_business_domain,
            p_entity_type,
            v_entity_record.entity_identifier,
            p_collection_config
        );
        
        -- Automatically feed collected data to AI learning
        IF jsonb_array_length(v_collected_data->'data_points') >= 3 THEN
            v_learning_result := business.ai_learn_from_data(
                p_tenant_hk,
                p_business_domain,
                p_entity_type,
                v_entity_record.entity_identifier,
                v_collected_data->'data_points',
                jsonb_build_object(
                    'automated_collection', true,
                    'collection_timestamp', CURRENT_TIMESTAMP,
                    'collection_source', 'automation_engine'
                )
            );
            
            -- Update tracking
            UPDATE automation.entity_tracking
            SET 
                last_data_collection = CURRENT_TIMESTAMP,
                total_data_points = total_data_points + jsonb_array_length(v_collected_data->'data_points'),
                last_learning_result = v_learning_result
            WHERE tenant_hk = p_tenant_hk
            AND business_domain = p_business_domain
            AND entity_type = p_entity_type
            AND entity_identifier = v_entity_record.entity_identifier;
            
            v_entities_processed := v_entities_processed + 1;
            v_data_points_collected := v_data_points_collected + jsonb_array_length(v_collected_data->'data_points');
        END IF;
    END LOOP;
    
    RETURN jsonb_build_object(
        'automation_type', 'data_collection',
        'execution_timestamp', CURRENT_TIMESTAMP,
        'business_domain', p_business_domain,
        'entity_type', p_entity_type,
        'entities_processed', v_entities_processed,
        'data_points_collected', v_data_points_collected,
        'success', true
    );
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- AUTOMATED DECISION EXECUTION ENGINE
-- ==========================================

CREATE OR REPLACE FUNCTION automation.auto_execute_decisions(
    p_tenant_hk BYTEA,
    p_business_domain VARCHAR(100),
    p_decision_config JSONB
) RETURNS JSONB AS $$
DECLARE
    v_decisions_executed INTEGER := 0;
    v_decisions_pending INTEGER := 0;
    v_pattern_record RECORD;
    v_decision_result JSONB;
    v_automation_rules JSONB;
BEGIN
    -- Get domain configuration for automation rules
    SELECT automation_rules INTO v_automation_rules
    FROM config.ai_business_domain_config
    WHERE tenant_hk = p_tenant_hk
    AND business_domain = p_business_domain
    AND is_active = true;
    
    -- Process high-confidence patterns for automated decisions
    FOR v_pattern_record IN
        SELECT 
            alps.entity_identifier,
            alps.pattern_type,
            alps.confidence_score,
            alps.pattern_data,
            alps.alert_thresholds,
            alps.decision_rules
        FROM business.ai_learning_pattern_s alps
        JOIN business.ai_business_intelligence_h abih ON alps.ai_business_intelligence_hk = abih.ai_business_intelligence_hk
        WHERE abih.tenant_hk = p_tenant_hk
        AND alps.business_domain = p_business_domain
        AND alps.load_end_date IS NULL
        AND alps.confidence_score >= (p_decision_config->>'min_confidence')::DECIMAL
        AND NOT EXISTS (
            -- Don't re-execute recent decisions for same entity/pattern
            SELECT 1 FROM automation.executed_decisions ed
            WHERE ed.tenant_hk = p_tenant_hk
            AND ed.entity_identifier = alps.entity_identifier
            AND ed.pattern_type = alps.pattern_type
            AND ed.execution_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
        )
    LOOP
        -- Check if this pattern meets automation criteria
        IF automation.should_auto_execute_decision(
            v_pattern_record.pattern_type,
            v_pattern_record.confidence_score,
            v_pattern_record.pattern_data,
            v_automation_rules
        ) THEN
            -- Execute the automated decision
            v_decision_result := automation.execute_automated_decision(
                p_tenant_hk,
                p_business_domain,
                v_pattern_record.entity_identifier,
                v_pattern_record.pattern_type,
                v_pattern_record.pattern_data,
                v_pattern_record.decision_rules
            );
            
            -- Log the executed decision
            INSERT INTO automation.executed_decisions (
                tenant_hk,
                business_domain,
                entity_identifier,
                pattern_type,
                decision_type,
                confidence_score,
                execution_timestamp,
                execution_result,
                automation_triggered
            ) VALUES (
                p_tenant_hk,
                p_business_domain,
                v_pattern_record.entity_identifier,
                v_pattern_record.pattern_type,
                v_decision_result->>'decision_type',
                v_pattern_record.confidence_score,
                CURRENT_TIMESTAMP,
                v_decision_result,
                true
            );
            
            v_decisions_executed := v_decisions_executed + 1;
        ELSE
            v_decisions_pending := v_decisions_pending + 1;
        END IF;
    END LOOP;
    
    RETURN jsonb_build_object(
        'automation_type', 'decision_execution',
        'execution_timestamp', CURRENT_TIMESTAMP,
        'business_domain', p_business_domain,
        'decisions_executed', v_decisions_executed,
        'decisions_pending_human_review', v_decisions_pending,
        'success', true
    );
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- AUTOMATED LEARNING OPTIMIZATION
-- ==========================================

CREATE OR REPLACE FUNCTION automation.auto_optimize_learning(
    p_tenant_hk BYTEA,
    p_business_domain VARCHAR(100)
) RETURNS JSONB AS $$
DECLARE
    v_patterns_optimized INTEGER := 0;
    v_low_confidence_patterns INTEGER := 0;
    v_pattern_record RECORD;
    v_optimization_result JSONB;
BEGIN
    -- Identify patterns that need optimization
    FOR v_pattern_record IN
        SELECT 
            alps.ai_business_intelligence_hk,
            alps.pattern_type,
            alps.confidence_score,
            alps.pattern_accuracy,
            alps.predictions_made,
            alps.predictions_correct,
            alps.entity_identifier
        FROM business.ai_learning_pattern_s alps
        JOIN business.ai_business_intelligence_h abih ON alps.ai_business_intelligence_hk = abih.ai_business_intelligence_hk
        WHERE abih.tenant_hk = p_tenant_hk
        AND alps.business_domain = p_business_domain
        AND alps.load_end_date IS NULL
        AND (
            alps.confidence_score < 0.8 OR  -- Low confidence
            (alps.predictions_made > 10 AND 
             alps.predictions_correct::DECIMAL / alps.predictions_made < 0.7) -- Low accuracy
        )
    LOOP
        -- Attempt to improve pattern learning
        v_optimization_result := automation.optimize_pattern_learning(
            p_tenant_hk,
            v_pattern_record.ai_business_intelligence_hk,
            v_pattern_record.pattern_type,
            v_pattern_record.entity_identifier
        );
        
        IF v_optimization_result->>'improved' = 'true' THEN
            v_patterns_optimized := v_patterns_optimized + 1;
        ELSE
            v_low_confidence_patterns := v_low_confidence_patterns + 1;
        END IF;
    END LOOP;
    
    RETURN jsonb_build_object(
        'automation_type', 'learning_optimization',
        'execution_timestamp', CURRENT_TIMESTAMP,
        'business_domain', p_business_domain,
        'patterns_optimized', v_patterns_optimized,
        'patterns_needing_attention', v_low_confidence_patterns,
        'success', true
    );
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- MASTER AUTOMATION ORCHESTRATOR
-- ==========================================

CREATE OR REPLACE FUNCTION automation.run_automation_cycle(
    p_tenant_hk BYTEA,
    p_business_domain VARCHAR(100) DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_domain VARCHAR(100);
    v_automation_results JSONB := '[]'::jsonb;
    v_cycle_result JSONB;
    v_collection_result JSONB;
    v_decision_result JSONB;
    v_optimization_result JSONB;
    v_domains_processed INTEGER := 0;
BEGIN
    -- Process all domains if none specified
    FOR v_domain IN 
        SELECT DISTINCT business_domain 
        FROM config.ai_business_domain_config 
        WHERE tenant_hk = p_tenant_hk 
        AND is_active = true
        AND (p_business_domain IS NULL OR business_domain = p_business_domain)
    LOOP
        -- 1. Automated Data Collection
        v_collection_result := automation.auto_collect_entity_data(
            p_tenant_hk,
            v_domain,
            'all_types',  -- Process all entity types
            '{"collection_interval": "1 hour", "min_data_points": 3}'::jsonb
        );
        
        -- 2. Automated Decision Execution
        v_decision_result := automation.auto_execute_decisions(
            p_tenant_hk,
            v_domain,
            '{"min_confidence": 0.85, "max_decisions_per_cycle": 10}'::jsonb
        );
        
        -- 3. Automated Learning Optimization
        v_optimization_result := automation.auto_optimize_learning(
            p_tenant_hk,
            v_domain
        );
        
        -- Compile domain results
        v_cycle_result := jsonb_build_object(
            'domain', v_domain,
            'data_collection', v_collection_result,
            'decision_execution', v_decision_result,
            'learning_optimization', v_optimization_result,
            'cycle_timestamp', CURRENT_TIMESTAMP
        );
        
        v_automation_results := v_automation_results || v_cycle_result;
        v_domains_processed := v_domains_processed + 1;
    END LOOP;
    
    -- Log automation cycle completion
    INSERT INTO automation.automation_execution_log (
        tenant_hk,
        execution_timestamp,
        domains_processed,
        execution_results,
        cycle_success
    ) VALUES (
        p_tenant_hk,
        CURRENT_TIMESTAMP,
        v_domains_processed,
        v_automation_results,
        true
    );
    
    RETURN jsonb_build_object(
        'automation_cycle_completed', true,
        'execution_timestamp', CURRENT_TIMESTAMP,
        'domains_processed', v_domains_processed,
        'detailed_results', v_automation_results,
        'next_cycle_in', '1 hour'
    );
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- AUTOMATION SETUP FUNCTION
-- ==========================================

CREATE OR REPLACE FUNCTION automation.setup_automation_schedules(
    p_tenant_hk BYTEA,
    p_business_domain VARCHAR(100)
) RETURNS JSONB AS $$
BEGIN
    -- Setup continuous automation cycle (every hour)
    INSERT INTO automation.automation_schedule_h (
        automation_schedule_hk,
        automation_schedule_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary('AUTOMATION_CYCLE_' || p_business_domain),
        'AUTO_CYCLE_' || p_business_domain,
        p_tenant_hk,
        util.current_load_date(),
        'AUTOMATION_SETUP'
    ) ON CONFLICT DO NOTHING;
    
    INSERT INTO automation.automation_schedule_s (
        automation_schedule_hk,
        load_date,
        hash_diff,
        business_domain,
        automation_type,
        automation_name,
        automation_description,
        schedule_type,
        schedule_expression,
        automation_function,
        execution_parameters,
        timeout_minutes,
        is_active,
        tenant_hk,
        record_source
    ) VALUES (
        util.hash_binary('AUTOMATION_CYCLE_' || p_business_domain),
        util.current_load_date(),
        util.hash_binary('AUTO_CYCLE_' || p_business_domain || 'HOURLY'),
        p_business_domain,
        'full_automation_cycle',
        'Automated Learning and Decision Cycle',
        'Runs complete automation cycle: data collection, learning, and decision execution',
        'hourly',
        '0 * * * *',  -- Every hour
        'automation.run_automation_cycle',
        jsonb_build_object('business_domain', p_business_domain),
        60,  -- 60 minute timeout
        true,
        p_tenant_hk,
        'AUTOMATION_SETUP'
    );
    
    RETURN jsonb_build_object(
        'automation_setup_complete', true,
        'business_domain', p_business_domain,
        'schedules_created', 1,
        'full_cycle_frequency', 'hourly',
        'status', 'active'
    );
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- SUPPORTING TABLES
-- ==========================================

CREATE TABLE IF NOT EXISTS automation.entity_tracking (
    tenant_hk BYTEA NOT NULL,
    business_domain VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_identifier VARCHAR(255) NOT NULL,
    last_data_collection TIMESTAMP WITH TIME ZONE,
    total_data_points INTEGER DEFAULT 0,
    last_learning_result JSONB,
    is_active BOOLEAN DEFAULT true,
    created_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (tenant_hk, business_domain, entity_type, entity_identifier)
);

CREATE TABLE IF NOT EXISTS automation.executed_decisions (
    tenant_hk BYTEA NOT NULL,
    business_domain VARCHAR(100) NOT NULL,
    entity_identifier VARCHAR(255) NOT NULL,
    pattern_type VARCHAR(100) NOT NULL,
    decision_type VARCHAR(100) NOT NULL,
    confidence_score DECIMAL(5,4),
    execution_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    execution_result JSONB,
    automation_triggered BOOLEAN DEFAULT true,
    
    PRIMARY KEY (tenant_hk, business_domain, entity_identifier, pattern_type, execution_timestamp)
);

CREATE TABLE IF NOT EXISTS automation.automation_execution_log (
    execution_id SERIAL PRIMARY KEY,
    tenant_hk BYTEA NOT NULL,
    execution_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    domains_processed INTEGER,
    execution_results JSONB,
    cycle_success BOOLEAN
);

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

CREATE OR REPLACE FUNCTION automation.simulate_data_collection(
    p_business_domain VARCHAR(100),
    p_entity_type VARCHAR(100),
    p_entity_id VARCHAR(255),
    p_config JSONB
) RETURNS JSONB AS $$
BEGIN
    -- Simplified data simulation - would integrate with real sensors/APIs
    RETURN jsonb_build_object(
        'data_points', jsonb_build_array(
            jsonb_build_object('timestamp', CURRENT_TIMESTAMP, 'value', random() * 100),
            jsonb_build_object('timestamp', CURRENT_TIMESTAMP - INTERVAL '1 hour', 'value', random() * 100),
            jsonb_build_object('timestamp', CURRENT_TIMESTAMP - INTERVAL '2 hours', 'value', random() * 100)
        ),
        'collection_source', 'automated_simulation'
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION automation.should_auto_execute_decision(
    p_pattern_type VARCHAR(100),
    p_confidence DECIMAL(5,4),
    p_pattern_data JSONB,
    p_automation_rules JSONB
) RETURNS BOOLEAN AS $$
BEGIN
    -- Simplified decision logic - would be more sophisticated
    RETURN p_confidence >= 0.9 AND p_automation_rules ? p_pattern_type;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION automation.execute_automated_decision(
    p_tenant_hk BYTEA,
    p_business_domain VARCHAR(100),
    p_entity_id VARCHAR(255),
    p_pattern_type VARCHAR(100),
    p_pattern_data JSONB,
    p_decision_rules JSONB
) RETURNS JSONB AS $$
BEGIN
    -- Simplified automation execution - would integrate with actual systems
    RETURN jsonb_build_object(
        'decision_type', 'automated_' || p_pattern_type,
        'execution_success', true,
        'action_taken', 'Pattern-based decision executed automatically',
        'timestamp', CURRENT_TIMESTAMP
    );
END;
$$ LANGUAGE plpgsql;

-- Create indexes for automation performance
CREATE INDEX IF NOT EXISTS idx_automation_schedule_s_active_schedule 
ON automation.automation_schedule_s (is_active, next_scheduled) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_entity_tracking_collection_due 
ON automation.entity_tracking (business_domain, last_data_collection) 
WHERE is_active = true;

COMMIT; 