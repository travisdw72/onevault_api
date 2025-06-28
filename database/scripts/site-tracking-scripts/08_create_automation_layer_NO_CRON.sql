-- =====================================================
-- SITE TRACKING AUTOMATION LAYER (NO CRON VERSION)
-- =====================================================
-- Purpose: Complete automation for site tracking pipeline
-- Components: Combined pipeline function + monitoring (NO pg_cron dependency)
-- Dependencies: All previous layers (01-07) must be deployed first
-- =====================================================

-- Combined Pipeline Function
CREATE OR REPLACE FUNCTION staging.process_complete_pipeline()
RETURNS TABLE (
    total_processed INTEGER,
    raw_to_staging_count INTEGER,
    staging_to_business_count INTEGER,
    total_success_count INTEGER,
    total_error_count INTEGER,
    processing_summary JSONB
) AS $$
DECLARE
    v_raw_results RECORD;
    v_business_results RECORD;
    v_total_processed INTEGER := 0;
    v_total_success INTEGER := 0;
    v_total_errors INTEGER := 0;
    v_processing_summary JSONB;
BEGIN
    RAISE NOTICE '🚀 Starting complete site tracking pipeline...';
    
    -- Step 1: Process Raw → Staging
    RAISE NOTICE '📥 Step 1: Processing raw events to staging...';
    
    SELECT * INTO v_raw_results 
    FROM staging.process_site_tracking_events() 
    LIMIT 1;
    
    RAISE NOTICE '✅ Raw → Staging: % processed, % success, % errors', 
                 v_raw_results.processed_count, 
                 v_raw_results.success_count, 
                 v_raw_results.error_count;
    
    -- Step 2: Process Staging → Business
    RAISE NOTICE '🏢 Step 2: Processing staging events to business...';
    
    SELECT * INTO v_business_results 
    FROM staging.process_staging_to_business() 
    LIMIT 1;
    
    RAISE NOTICE '✅ Staging → Business: % processed, % success, % errors', 
                 v_business_results.processed_count, 
                 v_business_results.success_count, 
                 v_business_results.error_count;
    
    -- Calculate totals
    v_total_processed := v_raw_results.processed_count + v_business_results.processed_count;
    v_total_success := v_raw_results.success_count + v_business_results.success_count;
    v_total_errors := v_raw_results.error_count + v_business_results.error_count;
    
    -- Build comprehensive summary
    v_processing_summary := jsonb_build_object(
        'pipeline_execution_timestamp', CURRENT_TIMESTAMP,
        'raw_to_staging', jsonb_build_object(
            'processed', v_raw_results.processed_count,
            'success', v_raw_results.success_count,
            'errors', v_raw_results.error_count,
            'summary', v_raw_results.processing_summary
        ),
        'staging_to_business', jsonb_build_object(
            'processed', v_business_results.processed_count,
            'success', v_business_results.success_count,
            'errors', v_business_results.error_count,
            'summary', v_business_results.processing_summary
        ),
        'pipeline_totals', jsonb_build_object(
            'total_processed', v_total_processed,
            'total_success', v_total_success,
            'total_errors', v_total_errors,
            'success_rate', CASE 
                WHEN v_total_processed > 0 
                THEN ROUND(v_total_success::numeric / v_total_processed * 100, 2)
                ELSE 0 
            END
        )
    );
    
    RAISE NOTICE '🎯 Pipeline Complete: % total processed, % success, % errors (%.2f%% success rate)', 
                 v_total_processed, 
                 v_total_success, 
                 v_total_errors,
                 CASE 
                     WHEN v_total_processed > 0 
                     THEN v_total_success::numeric / v_total_processed * 100
                     ELSE 0 
                 END;
    
    -- Log pipeline execution for monitoring
    PERFORM util.log_audit_event(
        'PIPELINE_EXECUTION'::VARCHAR(100),
        'SITE_TRACKING'::VARCHAR(100),
        'complete_pipeline'::VARCHAR(255),
        SESSION_USER::VARCHAR(100),
        v_processing_summary
    );
    
    RETURN QUERY SELECT 
        v_total_processed,
        v_raw_results.processed_count,
        v_business_results.processed_count,
        v_total_success,
        v_total_errors,
        v_processing_summary;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION staging.process_complete_pipeline IS 
'Complete site tracking pipeline automation: processes raw events through staging to business layer in a single operation with comprehensive monitoring and audit logging.';

-- =====================================================
-- MONITORING AND MANAGEMENT FUNCTIONS
-- =====================================================

-- Function to check pipeline status
CREATE OR REPLACE FUNCTION staging.get_pipeline_status()
RETURNS TABLE (
    status_type VARCHAR(50),
    metric_name VARCHAR(100),
    metric_value NUMERIC,
    last_updated TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    -- Raw layer status
    SELECT 
        'RAW_LAYER'::VARCHAR(50),
        'pending_events'::VARCHAR(100),
        COUNT(*)::NUMERIC,
        MAX(received_timestamp)
    FROM raw.site_tracking_events_r 
    WHERE processing_status = 'PENDING'
    
    UNION ALL
    
    -- Staging layer status
    SELECT 
        'STAGING_LAYER'::VARCHAR(50),
        'unprocessed_to_business'::VARCHAR(100),
        COUNT(*)::NUMERIC,
        MAX(processed_timestamp)
    FROM staging.site_tracking_events_s 
    WHERE validation_status = 'VALID' 
    AND (processed_to_business IS NULL OR processed_to_business = FALSE)
    
    UNION ALL
    
    -- Business layer status
    SELECT 
        'BUSINESS_LAYER'::VARCHAR(50),
        'events_today'::VARCHAR(100),
        COUNT(*)::NUMERIC,
        MAX(load_date)
    FROM business.site_event_h 
    WHERE load_date >= CURRENT_DATE
    
    UNION ALL
    
    -- Processing performance
    SELECT 
        'PERFORMANCE'::VARCHAR(50),
        'avg_processing_time_minutes'::VARCHAR(100),
        ROUND(AVG(EXTRACT(EPOCH FROM (s.processed_timestamp - r.received_timestamp)) / 60), 2),
        MAX(s.processed_timestamp)
    FROM raw.site_tracking_events_r r
    JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
    WHERE r.received_timestamp >= CURRENT_DATE - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- Function to manually trigger pipeline (for testing/debugging)
CREATE OR REPLACE FUNCTION staging.trigger_pipeline_now()
RETURNS JSONB AS $$
DECLARE
    v_result RECORD;
BEGIN
    SELECT * INTO v_result FROM staging.process_complete_pipeline() LIMIT 1;
    
    RETURN jsonb_build_object(
        'triggered_at', CURRENT_TIMESTAMP,
        'results', row_to_json(v_result)
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- ALTERNATIVE SCHEDULING OPTIONS
-- =====================================================

-- Create a view for easy pipeline monitoring
CREATE OR REPLACE VIEW staging.pipeline_dashboard AS
SELECT 
    'PIPELINE STATUS' as dashboard_section,
    (SELECT COUNT(*) FROM raw.site_tracking_events_r WHERE processing_status = 'PENDING') as raw_pending,
    (SELECT COUNT(*) FROM staging.site_tracking_events_s WHERE processed_to_business IS NULL OR processed_to_business = FALSE) as staging_pending,
    (SELECT COUNT(*) FROM business.site_event_h WHERE load_date >= CURRENT_DATE) as business_events_today,
    CURRENT_TIMESTAMP as last_checked;

-- Create a simple automation trigger function (can be called by external scheduler)
CREATE OR REPLACE FUNCTION staging.auto_process_if_needed()
RETURNS TEXT AS $$
DECLARE
    v_raw_pending INTEGER;
    v_staging_pending INTEGER;
    v_result RECORD;
BEGIN
    -- Check if processing is needed
    SELECT COUNT(*) INTO v_raw_pending 
    FROM raw.site_tracking_events_r 
    WHERE processing_status = 'PENDING';
    
    SELECT COUNT(*) INTO v_staging_pending 
    FROM staging.site_tracking_events_s 
    WHERE validation_status = 'VALID' 
    AND (processed_to_business IS NULL OR processed_to_business = FALSE);
    
    -- Only process if there's work to do
    IF v_raw_pending > 0 OR v_staging_pending > 0 THEN
        SELECT * INTO v_result FROM staging.process_complete_pipeline() LIMIT 1;
        
        RETURN format('Processed: %s total (%s raw→staging, %s staging→business)', 
                     v_result.total_processed,
                     v_result.raw_to_staging_count,
                     v_result.staging_to_business_count);
    ELSE
        RETURN 'No processing needed - all events up to date';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- DEPLOYMENT VERIFICATION
-- =====================================================

-- Test the complete pipeline function
DO $$
DECLARE
    v_test_result RECORD;
BEGIN
    RAISE NOTICE '🧪 Testing complete pipeline function...';
    
    -- Test function exists and is callable
    SELECT * INTO v_test_result FROM staging.process_complete_pipeline() LIMIT 1;
    
    RAISE NOTICE '✅ Pipeline function test complete: % total processed', 
                 v_test_result.total_processed;
    
    RAISE NOTICE '📊 Pipeline Status Check:';
    PERFORM staging.get_pipeline_status();
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Pipeline test failed: %', SQLERRM;
    RAISE;
END $$;

-- =====================================================
-- SUCCESS MESSAGE & INSTRUCTIONS
-- =====================================================
SELECT 
    '🎉 AUTOMATION LAYER DEPLOYED (NO CRON)!' as status,
    'Complete pipeline function available' as message,
    'Manual trigger: SELECT * FROM staging.process_complete_pipeline();' as manual_usage,
    'Auto-check: SELECT * FROM staging.auto_process_if_needed();' as smart_usage,
    'Monitor: SELECT * FROM staging.pipeline_dashboard;' as monitoring,
    'SCHEDULING OPTIONS:' as scheduling_header,
    '1. Windows Task Scheduler (call via psql)' as option1,
    '2. Application-level scheduler' as option2,
    '3. External cron (Linux/Mac)' as option3,
    '4. Manual execution as needed' as option4; 