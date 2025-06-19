-- =====================================================
-- PHASE 1: RAW LAYER - Site Tracking Implementation
-- Simple ETL Landing Zone (No Hub/Satellite Structure)
-- =====================================================

-- Create raw schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS raw;

-- Raw event ingestion table - simple landing zone for all tracking events
CREATE TABLE IF NOT EXISTS raw.site_tracking_events_r (
    raw_event_id SERIAL PRIMARY KEY,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    api_key_hk BYTEA,                         -- Reference to API key used
    received_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    client_ip INET,
    user_agent TEXT,
    raw_payload JSONB NOT NULL,               -- Complete original event data
    batch_id VARCHAR(100),                    -- For batch processing correlation
    processing_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, PROCESSING, PROCESSED, ERROR
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    record_source VARCHAR(100) DEFAULT 'site_tracker',
    
    -- Constraints
    CONSTRAINT chk_processing_status CHECK (processing_status IN ('PENDING', 'PROCESSING', 'PROCESSED', 'ERROR')),
    CONSTRAINT chk_retry_count_positive CHECK (retry_count >= 0)
);

-- Performance indexes for high-traffic sites
CREATE INDEX IF NOT EXISTS idx_site_tracking_events_r_received_timestamp 
ON raw.site_tracking_events_r(received_timestamp);

CREATE INDEX IF NOT EXISTS idx_site_tracking_events_r_processing_status 
ON raw.site_tracking_events_r(processing_status);

CREATE INDEX IF NOT EXISTS idx_site_tracking_events_r_tenant_hk 
ON raw.site_tracking_events_r(tenant_hk);

-- Composite index for efficient tenant + status queries
CREATE INDEX IF NOT EXISTS idx_site_tracking_events_r_tenant_status 
ON raw.site_tracking_events_r(tenant_hk, processing_status);

-- Partition-friendly index for high-volume tracking
CREATE INDEX IF NOT EXISTS idx_site_tracking_events_r_tenant_month 
ON raw.site_tracking_events_r(tenant_hk, DATE_TRUNC('month', received_timestamp));

-- Raw data ingestion function - simple event landing
CREATE OR REPLACE FUNCTION raw.ingest_tracking_event(
    p_tenant_hk BYTEA,
    p_api_key_hk BYTEA,
    p_client_ip INET,
    p_user_agent TEXT,
    p_event_data JSONB
) RETURNS INTEGER AS $$
DECLARE
    v_raw_event_id INTEGER;
    v_batch_id VARCHAR(100);
BEGIN
    -- Input validation
    IF p_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'Tenant hash key cannot be null';
    END IF;
    
    IF p_event_data IS NULL OR p_event_data = '{}'::JSONB THEN
        RAISE EXCEPTION 'Event data cannot be null or empty';
    END IF;
    
    -- Generate batch ID for processing correlation
    v_batch_id := 'BATCH_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS') || '_' || 
                  substring(encode(util.hash_binary(encode(p_tenant_hk, 'hex') || CURRENT_TIMESTAMP::text), 'hex'), 1, 8);
    
    -- Insert raw event
    INSERT INTO raw.site_tracking_events_r (
        tenant_hk, 
        api_key_hk,
        client_ip, 
        user_agent, 
        raw_payload, 
        batch_id,
        record_source
    ) VALUES (
        p_tenant_hk, 
        p_api_key_hk,
        p_client_ip, 
        p_user_agent, 
        p_event_data, 
        v_batch_id,
        'site_tracker'
    ) RETURNING raw_event_id INTO v_raw_event_id;
    
    -- Trigger async processing notification
    PERFORM pg_notify('process_tracking_events', jsonb_build_object(
        'raw_event_id', v_raw_event_id,
        'tenant_hk', encode(p_tenant_hk, 'hex'),
        'batch_id', v_batch_id,
        'event_type', p_event_data->>'evt_type',
        'timestamp', CURRENT_TIMESTAMP
    )::text);
    
    -- Return the raw event ID for tracking
    RETURN v_raw_event_id;
    
EXCEPTION WHEN OTHERS THEN
    -- Log error and re-raise with context
    RAISE EXCEPTION 'Failed to ingest tracking event for tenant %: %', encode(p_tenant_hk, 'hex'), SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Batch processing function for high-volume ingestion
CREATE OR REPLACE FUNCTION raw.ingest_tracking_events_batch(
    p_tenant_hk BYTEA,
    p_api_key_hk BYTEA,
    p_client_ip INET,
    p_user_agent TEXT,
    p_events_array JSONB
) RETURNS TABLE (
    batch_id VARCHAR(100),
    events_processed INTEGER,
    events_failed INTEGER,
    raw_event_ids INTEGER[]
) AS $$
DECLARE
    v_batch_id VARCHAR(100);
    v_processed_count INTEGER := 0;
    v_failed_count INTEGER := 0;
    v_event_ids INTEGER[] := ARRAY[]::INTEGER[];
    v_event JSONB;
    v_raw_event_id INTEGER;
BEGIN
    -- Generate batch ID
    v_batch_id := 'BATCH_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS') || '_' || 
                  substring(encode(util.hash_binary(encode(p_tenant_hk, 'hex') || CURRENT_TIMESTAMP::text), 'hex'), 1, 8);
    
    -- Process each event in the array
    FOR i IN 0..jsonb_array_length(p_events_array) - 1 LOOP
        BEGIN
            v_event := p_events_array->i;
            
            INSERT INTO raw.site_tracking_events_r (
                tenant_hk, api_key_hk, client_ip, user_agent, raw_payload, batch_id, record_source
            ) VALUES (
                p_tenant_hk, p_api_key_hk, p_client_ip, p_user_agent, v_event, v_batch_id, 'site_tracker'
            ) RETURNING raw_event_id INTO v_raw_event_id;
            
            v_event_ids := array_append(v_event_ids, v_raw_event_id);
            v_processed_count := v_processed_count + 1;
            
        EXCEPTION WHEN OTHERS THEN
            v_failed_count := v_failed_count + 1;
            -- Continue processing other events
        END;
    END LOOP;
    
    -- Trigger batch processing notification
    IF v_processed_count > 0 THEN
        PERFORM pg_notify('process_tracking_events_batch', jsonb_build_object(
            'batch_id', v_batch_id,
            'tenant_hk', encode(p_tenant_hk, 'hex'),
            'events_processed', v_processed_count,
            'events_failed', v_failed_count,
            'timestamp', CURRENT_TIMESTAMP
        )::text);
    END IF;
    
    RETURN QUERY SELECT v_batch_id, v_processed_count, v_failed_count, v_event_ids;
END;
$$ LANGUAGE plpgsql;

-- Function to get raw event processing stats
CREATE OR REPLACE FUNCTION raw.get_processing_stats(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_hours_back INTEGER DEFAULT 24
) RETURNS TABLE (
    tenant_hk BYTEA,
    total_events BIGINT,
    processed_events BIGINT,
    pending_events BIGINT,
    error_events BIGINT,
    processing_rate DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.tenant_hk,
        COUNT(*) as total_events,
        COUNT(*) FILTER (WHERE r.processing_status = 'PROCESSED') as processed_events,
        COUNT(*) FILTER (WHERE r.processing_status = 'PENDING') as pending_events,
        COUNT(*) FILTER (WHERE r.processing_status = 'ERROR') as error_events,
        ROUND(
            CASE WHEN COUNT(*) > 0 THEN
                COUNT(*) FILTER (WHERE r.processing_status = 'PROCESSED') * 100.0 / COUNT(*)
            ELSE 0 END, 2
        ) as processing_rate
    FROM raw.site_tracking_events_r r
    WHERE (p_tenant_hk IS NULL OR r.tenant_hk = p_tenant_hk)
    AND r.received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour' * p_hours_back
    GROUP BY r.tenant_hk
    ORDER BY total_events DESC;
END;
$$ LANGUAGE plpgsql;

-- Add table comments for documentation
COMMENT ON TABLE raw.site_tracking_events_r IS 
'Raw tracking events landing table for universal site analytics. Simple ETL landing zone that stores all tracking events exactly as received from frontend clients.';

COMMENT ON FUNCTION raw.ingest_tracking_event IS 
'Primary function for ingesting single tracking events into the raw landing zone. Uses tenant_hk for proper multi-tenant isolation.';

-- Raw layer implementation complete
SELECT 'Raw layer for universal site tracking created successfully!' as status; 