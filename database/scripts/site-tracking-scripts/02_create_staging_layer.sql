-- =====================================================
-- PHASE 2: STAGING LAYER - Site Tracking Implementation
-- Simple ETL Processing Layer (No Hub/Satellite Structure) 
-- =====================================================

-- Create staging schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS staging;

-- Staging table for validated and enriched tracking events
CREATE TABLE IF NOT EXISTS staging.site_tracking_events_s (
    staging_event_id SERIAL PRIMARY KEY,
    raw_event_id INTEGER NOT NULL REFERENCES raw.site_tracking_events_r(raw_event_id),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    
    -- Processed event details
    event_type VARCHAR(50) NOT NULL,
    session_id VARCHAR(255),
    user_id VARCHAR(255),                     -- Client-side user identifier
    page_url TEXT,
    page_title TEXT,
    referrer_url TEXT,
    
    -- Event-specific data
    element_id VARCHAR(255),                  -- For click events
    element_class VARCHAR(255),
    element_text TEXT,
    scroll_depth DECIMAL(5,2),                -- For scroll events  
    time_on_page INTEGER,                     -- Seconds
    
    -- Device and location data
    device_type VARCHAR(50),                  -- desktop, mobile, tablet
    browser_name VARCHAR(100),
    browser_version VARCHAR(50),
    operating_system VARCHAR(100),
    screen_resolution VARCHAR(20),
    viewport_size VARCHAR(20),
    
    -- Geolocation (if available)
    country_code VARCHAR(2),
    region VARCHAR(100),
    city VARCHAR(100),
    timezone VARCHAR(50),
    
    -- UTM and marketing parameters
    utm_source VARCHAR(255),
    utm_medium VARCHAR(255), 
    utm_campaign VARCHAR(255),
    utm_term VARCHAR(255),
    utm_content VARCHAR(255),
    
    -- Timestamps and processing
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    processed_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    validation_status VARCHAR(20) DEFAULT 'VALID',  -- VALID, INVALID, SUSPICIOUS
    enrichment_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, ENRICHED, FAILED
    quality_score DECIMAL(3,2) DEFAULT 1.0,  -- 0.0 to 1.0 data quality score
    
    -- Processing metadata
    processing_notes TEXT,
    enrichment_data JSONB,                    -- Additional enriched data
    validation_errors TEXT[],
    record_source VARCHAR(100) DEFAULT 'site_tracker',
    
    -- Constraints
    CONSTRAINT chk_validation_status CHECK (validation_status IN ('VALID', 'INVALID', 'SUSPICIOUS')),
    CONSTRAINT chk_enrichment_status CHECK (enrichment_status IN ('PENDING', 'ENRICHED', 'FAILED')),
    CONSTRAINT chk_quality_score CHECK (quality_score >= 0.0 AND quality_score <= 1.0)
);

-- Performance indexes for staging queries
CREATE INDEX IF NOT EXISTS idx_site_tracking_events_s_tenant_hk 
ON staging.site_tracking_events_s(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_site_tracking_events_s_event_type 
ON staging.site_tracking_events_s(event_type);

CREATE INDEX IF NOT EXISTS idx_site_tracking_events_s_session_id 
ON staging.site_tracking_events_s(session_id);

CREATE INDEX IF NOT EXISTS idx_site_tracking_events_s_timestamp 
ON staging.site_tracking_events_s(event_timestamp);

CREATE INDEX IF NOT EXISTS idx_site_tracking_events_s_validation_status 
ON staging.site_tracking_events_s(validation_status);

-- Composite index for efficient tenant + date queries (FIXED: removed DATE_TRUNC function)
CREATE INDEX IF NOT EXISTS idx_site_tracking_events_s_tenant_timestamp 
ON staging.site_tracking_events_s(tenant_hk, event_timestamp);

-- Main ETL function: Raw -> Staging validation and enrichment
CREATE OR REPLACE FUNCTION staging.validate_and_enrich_event(
    p_raw_event_id INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_raw_event RECORD;
    v_staging_event_id INTEGER;
    v_event_data JSONB;
    v_validation_errors TEXT[] := ARRAY[]::TEXT[];
    v_quality_score DECIMAL(3,2) := 1.0;
    v_validation_status VARCHAR(20) := 'VALID';
    v_device_info RECORD;
    v_geo_info RECORD;
    v_utm_params RECORD;
BEGIN
    -- Get raw event data
    SELECT * INTO v_raw_event
    FROM raw.site_tracking_events_r 
    WHERE raw_event_id = p_raw_event_id;
    
    IF v_raw_event.raw_event_id IS NULL THEN
        RAISE EXCEPTION 'Raw event % not found', p_raw_event_id;
    END IF;
    
    v_event_data := v_raw_event.raw_payload;
    
    -- Validate required fields
    IF NOT (v_event_data ? 'evt_type') THEN
        v_validation_errors := array_append(v_validation_errors, 'Missing evt_type');
        v_quality_score := v_quality_score - 0.3;
    END IF;
    
    IF NOT (v_event_data ? 'timestamp') THEN
        v_validation_errors := array_append(v_validation_errors, 'Missing timestamp');
        v_quality_score := v_quality_score - 0.2;
    END IF;
    
    IF NOT (v_event_data ? 'page_url') THEN
        v_validation_errors := array_append(v_validation_errors, 'Missing page_url');
        v_quality_score := v_quality_score - 0.2;
    END IF;
    
    -- Check for suspicious patterns
    IF LENGTH(v_event_data->>'page_url') > 2000 THEN
        v_validation_errors := array_append(v_validation_errors, 'Suspicious URL length');
        v_validation_status := 'SUSPICIOUS';
        v_quality_score := v_quality_score - 0.3;
    END IF;
    
    -- Parse device information
    SELECT 
        CASE 
            WHEN v_raw_event.user_agent ~* 'mobile|android|iphone' THEN 'mobile'
            WHEN v_raw_event.user_agent ~* 'tablet|ipad' THEN 'tablet'  
            ELSE 'desktop'
        END as device_type,
        CASE 
            WHEN v_raw_event.user_agent ~* 'chrome' THEN 'Chrome'
            WHEN v_raw_event.user_agent ~* 'firefox' THEN 'Firefox'
            WHEN v_raw_event.user_agent ~* 'safari' THEN 'Safari'
            WHEN v_raw_event.user_agent ~* 'edge' THEN 'Edge'
            ELSE 'Unknown'
        END as browser_name,
        CASE 
            WHEN v_raw_event.user_agent ~* 'windows' THEN 'Windows'
            WHEN v_raw_event.user_agent ~* 'mac os' THEN 'macOS'
            WHEN v_raw_event.user_agent ~* 'linux' THEN 'Linux'
            WHEN v_raw_event.user_agent ~* 'android' THEN 'Android'
            WHEN v_raw_event.user_agent ~* 'ios|iphone|ipad' THEN 'iOS'
            ELSE 'Unknown'
        END as operating_system
    INTO v_device_info;
    
    -- Parse UTM parameters from URL
    SELECT 
        staging.extract_utm_param(v_event_data->>'page_url', 'utm_source') as utm_source,
        staging.extract_utm_param(v_event_data->>'page_url', 'utm_medium') as utm_medium,
        staging.extract_utm_param(v_event_data->>'page_url', 'utm_campaign') as utm_campaign,
        staging.extract_utm_param(v_event_data->>'page_url', 'utm_term') as utm_term,
        staging.extract_utm_param(v_event_data->>'page_url', 'utm_content') as utm_content
    INTO v_utm_params;
    
    -- Determine final validation status
    IF array_length(v_validation_errors, 1) > 3 OR v_quality_score < 0.3 THEN
        v_validation_status := 'INVALID';
    END IF;
    
    -- Insert into staging table
    INSERT INTO staging.site_tracking_events_s (
        raw_event_id, tenant_hk, event_type, session_id, user_id,
        page_url, page_title, referrer_url, element_id, element_class, element_text,
        scroll_depth, time_on_page, device_type, browser_name, operating_system,
        screen_resolution, viewport_size, utm_source, utm_medium, utm_campaign,
        utm_term, utm_content, event_timestamp, validation_status, 
        enrichment_status, quality_score, validation_errors, enrichment_data,
        record_source
    ) VALUES (
        p_raw_event_id, v_raw_event.tenant_hk, v_event_data->>'evt_type',
        v_event_data->>'session_id', v_event_data->>'user_id',
        v_event_data->>'page_url', v_event_data->>'page_title', v_event_data->>'referrer',
        v_event_data->>'element_id', v_event_data->>'element_class', v_event_data->>'element_text',
        COALESCE((v_event_data->>'scroll_depth')::DECIMAL, 0),
        COALESCE((v_event_data->>'time_on_page')::INTEGER, 0),
        v_device_info.device_type, v_device_info.browser_name, v_device_info.operating_system,
        v_event_data->>'screen_resolution', v_event_data->>'viewport_size',
        v_utm_params.utm_source, v_utm_params.utm_medium, v_utm_params.utm_campaign,
        v_utm_params.utm_term, v_utm_params.utm_content,
        COALESCE((v_event_data->>'timestamp')::TIMESTAMP WITH TIME ZONE, v_raw_event.received_timestamp),
        v_validation_status, 'ENRICHED', v_quality_score, v_validation_errors,
        jsonb_build_object(
            'processing_version', '1.0',
            'enrichment_timestamp', CURRENT_TIMESTAMP,
            'user_agent_parsed', true,
            'utm_parsed', true
        ),
        'site_tracker'
    ) RETURNING staging_event_id INTO v_staging_event_id;
    
    -- Update raw event status
    UPDATE raw.site_tracking_events_r 
    SET processing_status = 'PROCESSED'
    WHERE raw_event_id = p_raw_event_id;
    
    -- Trigger business layer processing
    PERFORM pg_notify('process_to_business_layer', jsonb_build_object(
        'staging_event_id', v_staging_event_id,
        'tenant_hk', encode(v_raw_event.tenant_hk, 'hex'),
        'event_type', v_event_data->>'evt_type',
        'validation_status', v_validation_status,
        'timestamp', CURRENT_TIMESTAMP
    )::text);
    
    RETURN v_staging_event_id;
    
EXCEPTION WHEN OTHERS THEN
    -- Update raw event with error
    UPDATE raw.site_tracking_events_r 
    SET processing_status = 'ERROR',
        error_message = SQLERRM
    WHERE raw_event_id = p_raw_event_id;
    
    RAISE EXCEPTION 'Failed to process raw event % to staging: %', p_raw_event_id, SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Helper function to extract UTM parameters from URLs
CREATE OR REPLACE FUNCTION staging.extract_utm_param(
    p_url TEXT,
    p_param_name TEXT
) RETURNS TEXT AS $$
DECLARE
    v_regex_pattern TEXT;
    v_matches TEXT[];
BEGIN
    IF p_url IS NULL OR p_param_name IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Create regex pattern for UTM parameter
    v_regex_pattern := '[?&]' || p_param_name || '=([^&]+)';
    
    -- Extract parameter value
    v_matches := regexp_match(p_url, v_regex_pattern, 'i');
    
    IF v_matches IS NOT NULL AND array_length(v_matches, 1) > 0 THEN
        RETURN url_decode(v_matches[1]);
    END IF;
    
    RETURN NULL;
    
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Helper function for URL decoding (simplified version)
CREATE OR REPLACE FUNCTION staging.url_decode(p_encoded_text TEXT)
RETURNS TEXT AS $$
BEGIN
    IF p_encoded_text IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Basic URL decoding - replace common encoded characters
    RETURN replace(
        replace(
            replace(
                replace(p_encoded_text, '%20', ' '),
                '%21', '!'
            ),
            '%22', '"'
        ),
        '%23', '#'
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to get staging processing statistics
CREATE OR REPLACE FUNCTION staging.get_processing_stats(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_hours_back INTEGER DEFAULT 24
) RETURNS TABLE (
    tenant_hk BYTEA,
    total_events BIGINT,
    valid_events BIGINT,
    invalid_events BIGINT,
    suspicious_events BIGINT,
    avg_quality_score DECIMAL(3,2),
    processing_rate DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.tenant_hk,
        COUNT(*) as total_events,
        COUNT(*) FILTER (WHERE s.validation_status = 'VALID') as valid_events,
        COUNT(*) FILTER (WHERE s.validation_status = 'INVALID') as invalid_events,
        COUNT(*) FILTER (WHERE s.validation_status = 'SUSPICIOUS') as suspicious_events,
        ROUND(AVG(s.quality_score), 2) as avg_quality_score,
        ROUND(
            CASE WHEN COUNT(*) > 0 THEN
                COUNT(*) FILTER (WHERE s.validation_status = 'VALID') * 100.0 / COUNT(*)
            ELSE 0 END, 2
        ) as processing_rate
    FROM staging.site_tracking_events_s s
    WHERE (p_tenant_hk IS NULL OR s.tenant_hk = p_tenant_hk)
    AND s.processed_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour' * p_hours_back
    GROUP BY s.tenant_hk
    ORDER BY total_events DESC;
END;
$$ LANGUAGE plpgsql;

-- Batch processing function for raw events
CREATE OR REPLACE FUNCTION staging.process_raw_events_batch(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_batch_size INTEGER DEFAULT 100
) RETURNS TABLE (
    processed_count INTEGER,
    error_count INTEGER,
    batch_id VARCHAR(100)
) AS $$
DECLARE
    v_raw_event RECORD;
    v_processed_count INTEGER := 0;
    v_error_count INTEGER := 0;
    v_batch_id VARCHAR(100);
BEGIN
    -- Generate batch ID
    v_batch_id := 'STAGING_BATCH_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS') || '_' || 
                  substring(encode(util.hash_binary(CURRENT_TIMESTAMP::text), 'hex'), 1, 8);
    
    -- Process pending raw events
    FOR v_raw_event IN 
        SELECT raw_event_id 
        FROM raw.site_tracking_events_r r
        WHERE r.processing_status = 'PENDING'
        AND (p_tenant_hk IS NULL OR r.tenant_hk = p_tenant_hk)
        ORDER BY r.received_timestamp
        LIMIT p_batch_size
    LOOP
        BEGIN
            PERFORM staging.validate_and_enrich_event(v_raw_event.raw_event_id);
            v_processed_count := v_processed_count + 1;
            
        EXCEPTION WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            -- Continue processing other events
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_processed_count, v_error_count, v_batch_id;
END;
$$ LANGUAGE plpgsql;

-- Add table comments for documentation
COMMENT ON TABLE staging.site_tracking_events_s IS 
'Staging table for validated and enriched tracking events. Simple ETL processing layer that cleans, validates, and enriches raw tracking data before loading to business layer.';

COMMENT ON FUNCTION staging.validate_and_enrich_event IS 
'Main ETL function that processes raw tracking events through validation, enrichment, and quality scoring before loading to staging table.';

-- Staging layer implementation complete
SELECT 'Staging layer for universal site tracking created successfully!' as status;

-- =====================================================
-- MISSING PIECE: STAGING TO BUSINESS PROCESSOR
-- =====================================================

-- Function to process staging events to business layer
CREATE OR REPLACE FUNCTION staging.process_staging_to_business()
RETURNS TABLE (
    processed_count INTEGER,
    success_count INTEGER,
    error_count INTEGER,
    processing_summary JSONB
) AS $$
DECLARE
    v_staging_record RECORD;
    v_processed_count INTEGER := 0;
    v_success_count INTEGER := 0;
    v_error_count INTEGER := 0;
    v_event_hk BYTEA;
    v_session_hk BYTEA;
    v_visitor_hk BYTEA;
    v_page_hk BYTEA;
    v_event_bk VARCHAR(255);
    v_session_bk VARCHAR(255);
    v_visitor_bk VARCHAR(255);
    v_error_details JSONB := '[]'::JSONB;
BEGIN
    RAISE NOTICE '🚀 Processing staging events to business layer...';
    
    -- Process staging records that haven't been moved to business
    FOR v_staging_record IN 
        SELECT * 
        FROM staging.site_tracking_events_s 
        WHERE validation_status = 'VALID'
        AND (processed_to_business IS NULL OR processed_to_business = FALSE)
        ORDER BY processed_timestamp ASC
    LOOP
        v_processed_count := v_processed_count + 1;
        
        BEGIN
            -- Create business keys with correct formats
            v_event_bk := 'evt_staging_' || v_staging_record.staging_event_id::text;
            v_session_bk := 'sess_' || COALESCE(v_staging_record.session_id, 'staging_' || v_staging_record.staging_event_id::text);
            v_visitor_bk := 'visitor_' || COALESCE(
                LOWER(REGEXP_REPLACE(v_staging_record.user_id, '[^a-zA-Z0-9]', '', 'g')), 
                'anonymous' || v_staging_record.staging_event_id::text
            );
            
            -- Create/get business hubs using existing functions
            v_event_hk := business.get_or_create_site_event_hk(
                v_event_bk, v_staging_record.tenant_hk, 'staging_processor'
            );
            
            v_session_hk := business.get_or_create_site_session_hk(
                v_session_bk, v_staging_record.tenant_hk, 'staging_processor'
            );
            
            v_visitor_hk := business.get_or_create_site_visitor_hk(
                v_visitor_bk, v_staging_record.tenant_hk, 'staging_processor'
            );
            
            v_page_hk := business.get_or_create_site_page_hk(
                v_staging_record.page_url, v_staging_record.tenant_hk, 'staging_processor'
            );
            
            -- Create business links using existing functions
            PERFORM business.get_or_create_event_session_link(
                v_event_hk, v_session_hk, v_staging_record.tenant_hk, 'staging_processor'
            );
            
            PERFORM business.get_or_create_event_page_link(
                v_event_hk, v_page_hk, v_staging_record.tenant_hk, 'staging_processor'
            );
            
            PERFORM business.get_or_create_session_visitor_link(
                v_session_hk, v_visitor_hk, v_staging_record.tenant_hk, 'staging_processor'
            );
            
            -- Create event satellite using existing function
            PERFORM business.insert_event_details(
                v_event_hk,
                jsonb_build_object(
                    'event_timestamp', v_staging_record.event_timestamp,
                    'event_type', v_staging_record.event_type,
                    'event_category', 'user_interaction',
                    'event_action', 'click',
                    'page_url', v_staging_record.page_url,
                    'page_title', v_staging_record.page_title,
                    'custom_properties', jsonb_build_object(
                        'staging_event_id', v_staging_record.staging_event_id,
                        'quality_score', v_staging_record.quality_score,
                        'device_type', v_staging_record.device_type,
                        'browser_name', v_staging_record.browser_name
                    )
                ),
                'staging_processor'
            );
            
            -- Mark staging record as processed
            UPDATE staging.site_tracking_events_s 
            SET processed_to_business = TRUE,
                business_processing_timestamp = CURRENT_TIMESTAMP
            WHERE staging_event_id = v_staging_record.staging_event_id;
            
            v_success_count := v_success_count + 1;
            
            RAISE NOTICE '✅ SUCCESS: staging_event_id % → business', v_staging_record.staging_event_id;
            
        EXCEPTION WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            v_error_details := v_error_details || jsonb_build_object(
                'staging_event_id', v_staging_record.staging_event_id,
                'error_message', SQLERRM
            );
            
            RAISE NOTICE '❌ ERROR: staging_event_id % failed - %', v_staging_record.staging_event_id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '🎯 Processing complete: % processed, % success, % errors', 
                 v_processed_count, v_success_count, v_error_count;
    
    RETURN QUERY SELECT 
        v_processed_count,
        v_success_count, 
        v_error_count,
        jsonb_build_object(
            'processed_count', v_processed_count,
            'success_count', v_success_count,
            'error_count', v_error_count,
            'error_details', v_error_details,
            'processing_timestamp', CURRENT_TIMESTAMP
        );
END;
$$ LANGUAGE plpgsql;

-- Add missing columns to staging table for business processing tracking
ALTER TABLE staging.site_tracking_events_s 
ADD COLUMN IF NOT EXISTS processed_to_business BOOLEAN DEFAULT FALSE;

ALTER TABLE staging.site_tracking_events_s 
ADD COLUMN IF NOT EXISTS business_processing_timestamp TIMESTAMP WITH TIME ZONE;

-- Add index for business processing queries
CREATE INDEX IF NOT EXISTS idx_site_tracking_events_s_processed_to_business 
ON staging.site_tracking_events_s(processed_to_business);

COMMENT ON FUNCTION staging.process_staging_to_business IS 
'Processes validated staging events to business layer using existing business hub/link/satellite functions. Bridges the gap between staging and business layers.';

-- Updated success message
SELECT 'Staging layer for universal site tracking created successfully! (WITH staging-to-business processor)' as status; 