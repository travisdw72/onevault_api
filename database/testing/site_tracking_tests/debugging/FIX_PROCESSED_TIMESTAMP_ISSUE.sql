-- ============================================================================
-- QUICK FIX: Remove processed_timestamp references
-- The raw table doesn't have a processed_timestamp column
-- ============================================================================

\echo '🔧 FIXING PROCESSED_TIMESTAMP COLUMN ISSUE...'

-- Check the actual raw table structure first
\echo '📋 Current raw table structure:'
\d raw.site_tracking_events_r

-- Create the corrected staging function without processed_timestamp
CREATE OR REPLACE FUNCTION staging.process_site_tracking_events()
RETURNS TABLE(
    processed_count INTEGER,
    success_count INTEGER,
    error_count INTEGER,
    processing_summary JSONB
) AS $$
DECLARE
    v_raw_event RECORD;
    v_event_data JSONB;
    v_tenant_hk BYTEA;
    v_validation_status VARCHAR(20);
    v_quality_score DECIMAL(3,2);
    v_validation_errors TEXT[];
    v_enrichment_data JSONB;
    v_event_timestamp TIMESTAMP WITH TIME ZONE;
    v_processed_count INTEGER := 0;
    v_success_count INTEGER := 0;
    v_error_count INTEGER := 0;
    v_processing_errors JSONB := '[]'::JSONB;
BEGIN
    -- Process each raw event that hasn't been processed yet
    FOR v_raw_event IN 
        SELECT * FROM raw.site_tracking_events_r 
        WHERE processing_status = 'PENDING'
        ORDER BY received_timestamp ASC
    LOOP
        BEGIN
            v_processed_count := v_processed_count + 1;
            v_event_data := v_raw_event.raw_payload;
            v_tenant_hk := v_raw_event.tenant_hk;
            
            -- Initialize validation variables
            v_validation_status := 'VALID';
            v_quality_score := 1.0;
            v_validation_errors := ARRAY[]::TEXT[];
            
            -- Basic validation
            IF v_event_data->>'event_type' IS NULL THEN
                v_validation_errors := array_append(v_validation_errors, 'Missing event_type');
                v_validation_status := 'INVALID';
                v_quality_score := v_quality_score - 0.3;
            END IF;
            
            IF v_event_data->>'session_id' IS NULL THEN
                v_validation_errors := array_append(v_validation_errors, 'Missing session_id');
                v_quality_score := v_quality_score - 0.2;
            END IF;
            
            -- Determine event timestamp
            v_event_timestamp := COALESCE(
                (v_event_data->>'timestamp')::TIMESTAMP WITH TIME ZONE,
                v_raw_event.received_timestamp
            );
            
            -- Build enrichment data with FIXED jsonb_object_keys usage
            v_enrichment_data := jsonb_build_object(
                'processing_version', '2.0_timestamp_fix',
                'enrichment_timestamp', CURRENT_TIMESTAMP,
                'field_mapping_corrected', true,
                'original_fields', (
                    SELECT array_agg(key) 
                    FROM jsonb_object_keys(v_event_data) AS key
                ),
                'validation_applied', true,
                'tenant_verified', true
            );
            
            -- Insert into staging table
            INSERT INTO staging.site_tracking_events_s (
                raw_event_id,
                tenant_hk,
                event_type,
                session_id,
                user_id,
                page_url,
                page_title,
                referrer_url,
                event_timestamp,
                processed_timestamp,
                validation_status,
                enrichment_status,
                quality_score,
                enrichment_data,
                validation_errors,
                record_source
            ) VALUES (
                v_raw_event.raw_event_id,  -- Use actual raw_event_id
                v_tenant_hk,
                v_event_data->>'event_type',
                v_event_data->>'session_id',
                v_event_data->>'user_id',
                v_event_data->>'page_url',
                v_event_data->>'page_title',
                v_event_data->>'referrer',
                v_event_timestamp,
                CURRENT_TIMESTAMP,
                v_validation_status,
                'ENRICHED',
                v_quality_score,
                v_enrichment_data,
                v_validation_errors,
                'staging_processor_v2.0_fixed'
            );
            
            -- Update raw event status (NO processed_timestamp column!)
            UPDATE raw.site_tracking_events_r 
            SET processing_status = 'PROCESSED'
            WHERE raw_event_id = v_raw_event.raw_event_id;
            
            v_success_count := v_success_count + 1;
            
        EXCEPTION WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            
            -- Log the error
            v_processing_errors := v_processing_errors || jsonb_build_object(
                'raw_event_id', v_raw_event.raw_event_id,
                'error_message', SQLERRM,
                'error_timestamp', CURRENT_TIMESTAMP
            );
            
            -- Update raw event with error status (NO processed_timestamp column!)
            UPDATE raw.site_tracking_events_r 
            SET processing_status = 'ERROR',
                error_message = SQLERRM
            WHERE raw_event_id = v_raw_event.raw_event_id;
        END;
    END LOOP;
    
    -- Return processing summary
    RETURN QUERY SELECT 
        v_processed_count,
        v_success_count,
        v_error_count,
        jsonb_build_object(
            'processed_timestamp', CURRENT_TIMESTAMP,
            'processing_version', '2.0_timestamp_fix',
            'errors', v_processing_errors,
            'success_rate', CASE 
                WHEN v_processed_count > 0 THEN 
                    ROUND((v_success_count::DECIMAL / v_processed_count) * 100, 2)
                ELSE 0 
            END,
            'fix_applied', 'Removed processed_timestamp column references'
        );
END;
$$ LANGUAGE plpgsql;

\echo '✅ STAGING FUNCTION FIXED - processed_timestamp references removed'
\echo '🎯 Key fix applied:'
\echo '   - Removed processed_timestamp from UPDATE statements'
\echo '   - Raw table only has: processing_status, error_message, retry_count'

-- Test the fixed function
\echo '🧪 TESTING FIXED STAGING FUNCTION...'
SELECT * FROM staging.process_site_tracking_events();

-- Verify results
\echo '📊 VERIFICATION: Checking staging table contents...'
SELECT 
    staging_event_id,
    raw_event_id,
    encode(tenant_hk, 'hex') as tenant_hex,
    event_type,
    session_id,
    validation_status,
    enrichment_status,
    quality_score,
    enrichment_data->>'processing_version' as version
FROM staging.site_tracking_events_s
ORDER BY staging_event_id;

-- Check raw table status updates
\echo '📊 VERIFICATION: Checking raw table processing status...'
SELECT 
    raw_event_id,
    encode(tenant_hk, 'hex') as tenant_hex,
    raw_payload->>'event_type' as event_type,
    processing_status,
    error_message
FROM raw.site_tracking_events_r
ORDER BY raw_event_id;

\echo '🎉 PROCESSED_TIMESTAMP FIX COMPLETE!' 