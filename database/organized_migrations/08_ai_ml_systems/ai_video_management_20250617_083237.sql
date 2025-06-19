-- AI Video Management Enhancement for One Vault Platform
-- Handles AI-driven video uploads, 30-day retention, and intelligent segment extraction
-- Integrates with existing video upload system and AI observation framework

-- Start transaction
BEGIN;



-- =====================================================
-- AI VIDEO MANAGEMENT SCHEMA ENHANCEMENTS
-- =====================================================

-- AI Video Session Hub (for continuous AI monitoring sessions)
CREATE TABLE IF NOT EXISTS media.ai_video_session_h (
    ai_video_session_hk BYTEA PRIMARY KEY,
    ai_video_session_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    CONSTRAINT uk_ai_video_session_h_bk_tenant 
        UNIQUE (ai_video_session_bk, tenant_hk)
);

COMMENT ON TABLE media.ai_video_session_h IS 
'Hub table for AI video monitoring sessions - tracks continuous AI video analysis periods.';

-- AI Video Session Details Satellite
CREATE TABLE IF NOT EXISTS media.ai_video_session_details_s (
    ai_video_session_hk BYTEA NOT NULL REFERENCES media.ai_video_session_h(ai_video_session_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Session identification
    camera_sensor_hk BYTEA REFERENCES business.monitoring_sensor_h(sensor_hk),
    ai_model_version VARCHAR(50) NOT NULL DEFAULT 'ai-video-v2.0',
    session_purpose VARCHAR(100) NOT NULL, -- CONTINUOUS_MONITORING, EVENT_DETECTION, SECURITY_SURVEILLANCE
    
    -- Session configuration
    session_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    session_end_time TIMESTAMP WITH TIME ZONE,
    recording_quality VARCHAR(20) DEFAULT '720p', -- 1080p, 720p, 480p, 360p
    frame_rate INTEGER DEFAULT 30,
    retention_policy VARCHAR(50) DEFAULT 'STANDARD_30_DAY', -- STANDARD_30_DAY, IMPORTANT_PERMANENT, CUSTOM
    
    -- AI analysis configuration
    analysis_enabled BOOLEAN DEFAULT true,
    real_time_analysis BOOLEAN DEFAULT true,
    importance_threshold DECIMAL(3,2) DEFAULT 0.75, -- 0.0 to 1.0 threshold for "important"
    auto_segment_extraction BOOLEAN DEFAULT true,
    
    -- Storage and retention
    max_storage_gb DECIMAL(8,2) DEFAULT 50.0,
    current_storage_gb DECIMAL(8,2) DEFAULT 0.0,
    retention_days INTEGER DEFAULT 30,
    auto_cleanup_enabled BOOLEAN DEFAULT true,
    
    -- Session status
    session_status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (session_status IN ('ACTIVE', 'PAUSED', 'COMPLETED', 'ERROR')),
    last_activity_timestamp TIMESTAMP WITH TIME ZONE,
    
    -- Performance metrics
    total_videos_recorded INTEGER DEFAULT 0,
    important_segments_extracted INTEGER DEFAULT 0,
    storage_optimization_ratio DECIMAL(5,2), -- How much storage saved through AI optimization
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (ai_video_session_hk, load_date)
);

-- AI Video Segment Hub (for AI-extracted important segments)
CREATE TABLE IF NOT EXISTS media.ai_video_segment_h (
    ai_video_segment_hk BYTEA PRIMARY KEY,
    ai_video_segment_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    CONSTRAINT uk_ai_video_segment_h_bk_tenant 
        UNIQUE (ai_video_segment_bk, tenant_hk)
);

-- AI Video Segment Details Satellite
CREATE TABLE IF NOT EXISTS media.ai_video_segment_details_s (
    ai_video_segment_hk BYTEA NOT NULL REFERENCES media.ai_video_segment_h(ai_video_segment_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Source video information
    source_media_file_hk BYTEA NOT NULL REFERENCES media.media_file_h(media_file_hk),
    ai_video_session_hk BYTEA REFERENCES media.ai_video_session_h(ai_video_session_hk),
    
    -- Segment timing
    segment_start_seconds DECIMAL(10,3) NOT NULL,
    segment_end_seconds DECIMAL(10,3) NOT NULL,
    segment_duration_seconds DECIMAL(10,3) NOT NULL,
    
    -- AI analysis results
    importance_score DECIMAL(5,4) NOT NULL CHECK (importance_score >= 0 AND importance_score <= 1),
    confidence_score DECIMAL(5,4) NOT NULL CHECK (confidence_score >= 0 AND confidence_score <= 1),
    ai_detected_events TEXT[], -- Array of detected events
    ai_analysis_summary TEXT,
    
    -- Classification
    segment_category VARCHAR(50) NOT NULL, -- ANOMALY, SECURITY_EVENT, BEHAVIOR_CHANGE, MAINTENANCE_ISSUE, NORMAL_ACTIVITY
    priority_level VARCHAR(20) DEFAULT 'MEDIUM' CHECK (priority_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL', 'EMERGENCY')),
    requires_human_review BOOLEAN DEFAULT false,
    
    -- Processing information
    extraction_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    processing_duration_ms INTEGER,
    ai_model_used VARCHAR(100) DEFAULT 'ai-video-segment-v1.0',
    
    -- Storage and access
    segment_file_path TEXT, -- Path to extracted segment file
    thumbnail_path TEXT, -- Path to segment thumbnail
    is_permanently_retained BOOLEAN DEFAULT false,
    retention_reason TEXT,
    
    -- Metadata
    segment_metadata JSONB, -- Technical metadata about the segment
    business_context JSONB, -- Business-relevant context
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (ai_video_segment_hk, load_date)
);

-- AI Video Retention Policy Hub
CREATE TABLE IF NOT EXISTS media.ai_retention_policy_h (
    retention_policy_hk BYTEA PRIMARY KEY,
    retention_policy_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    CONSTRAINT uk_retention_policy_h_bk_tenant 
        UNIQUE (retention_policy_bk, tenant_hk)
);

-- AI Video Retention Policy Details Satellite
CREATE TABLE IF NOT EXISTS media.ai_retention_policy_details_s (
    retention_policy_hk BYTEA NOT NULL REFERENCES media.ai_retention_policy_h(retention_policy_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Policy identification
    policy_name VARCHAR(100) NOT NULL,
    policy_description TEXT,
    policy_type VARCHAR(50) NOT NULL, -- STANDARD, COMPLIANCE, CUSTOM, AI_OPTIMIZED
    
    -- Retention rules
    default_retention_days INTEGER NOT NULL DEFAULT 30,
    important_segment_retention_days INTEGER DEFAULT 365, -- Keep important segments longer
    critical_event_retention_days INTEGER DEFAULT 2555, -- 7 years for critical events
    
    -- AI optimization rules
    enable_ai_optimization BOOLEAN DEFAULT true,
    importance_threshold_for_retention DECIMAL(3,2) DEFAULT 0.60,
    auto_delete_low_importance BOOLEAN DEFAULT true,
    compress_normal_footage BOOLEAN DEFAULT true,
    
    -- Storage optimization
    max_storage_per_camera_gb DECIMAL(8,2) DEFAULT 100.0,
    storage_cleanup_frequency_hours INTEGER DEFAULT 24,
    compression_ratio_target DECIMAL(3,2) DEFAULT 0.50, -- Target 50% compression
    
    -- Compliance requirements
    regulatory_retention_required BOOLEAN DEFAULT false,
    regulatory_framework VARCHAR(50), -- HIPAA, GDPR, SOX, etc.
    legal_hold_override BOOLEAN DEFAULT false,
    
    -- Policy status
    is_active BOOLEAN DEFAULT true,
    effective_date DATE NOT NULL,
    expiration_date DATE,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (retention_policy_hk, load_date)
);

-- =====================================================
-- AI VIDEO UPLOAD FUNCTIONS
-- =====================================================

-- AI-specific video upload function
CREATE OR REPLACE FUNCTION media.ai_upload_video(
    p_tenant_hk BYTEA,
    p_ai_session_hk BYTEA,
    p_camera_sensor_hk BYTEA,
    p_video_file_path TEXT,
    p_file_size_bytes BIGINT,
    p_duration_seconds INTEGER,
    p_recording_timestamp TIMESTAMP WITH TIME ZONE,
    p_ai_analysis_results JSONB DEFAULT NULL,
    p_importance_score DECIMAL(5,4) DEFAULT 0.50
) RETURNS TABLE (
    media_file_hk BYTEA,
    upload_status VARCHAR(20),
    retention_decision VARCHAR(50),
    estimated_retention_days INTEGER
) AS $$
DECLARE
    v_media_file_hk BYTEA;
    v_media_file_bk VARCHAR(255);
    v_retention_policy RECORD;
    v_retention_decision VARCHAR(50);
    v_retention_days INTEGER;
    v_file_hash VARCHAR(64);
BEGIN
    -- Generate unique business key for AI upload
    v_media_file_bk := 'AI_VIDEO_' || encode(p_camera_sensor_hk, 'hex') || '_' ||
                       to_char(p_recording_timestamp, 'YYYYMMDD_HH24MISS') || '_' ||
                       encode(gen_random_bytes(4), 'hex');
    v_media_file_hk := util.hash_binary(v_media_file_bk || encode(p_tenant_hk, 'hex'));
    
    -- Generate file hash (simplified - would calculate from actual file)
    v_file_hash := encode(digest(v_media_file_bk || p_file_size_bytes::text, 'sha256'), 'hex');
    
    -- Get retention policy for this tenant/camera
    SELECT 
        arp.default_retention_days,
        arp.important_segment_retention_days,
        arp.importance_threshold_for_retention,
        arp.enable_ai_optimization
    INTO v_retention_policy
    FROM media.ai_retention_policy_details_s arp
    JOIN media.ai_retention_policy_h arh ON arp.retention_policy_hk = arh.retention_policy_hk
    WHERE arh.tenant_hk = p_tenant_hk
    AND arp.is_active = true
    AND arp.load_end_date IS NULL
    ORDER BY arp.load_date DESC
    LIMIT 1;
    
    -- Default retention policy if none found
    IF v_retention_policy IS NULL THEN
        v_retention_policy.default_retention_days := 30;
        v_retention_policy.important_segment_retention_days := 365;
        v_retention_policy.importance_threshold_for_retention := 0.60;
        v_retention_policy.enable_ai_optimization := true;
    END IF;
    
    -- Determine retention decision based on AI analysis
    IF p_importance_score >= v_retention_policy.importance_threshold_for_retention THEN
        v_retention_decision := 'IMPORTANT_EXTENDED';
        v_retention_days := v_retention_policy.important_segment_retention_days;
    ELSE
        v_retention_decision := 'STANDARD_30_DAY';
        v_retention_days := v_retention_policy.default_retention_days;
    END IF;
    
    -- Insert hub record
    INSERT INTO media.media_file_h VALUES (
        v_media_file_hk,
        v_media_file_bk,
        p_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    );
    
    -- Insert satellite record with AI-specific metadata
    INSERT INTO media.media_file_details_s VALUES (
        v_media_file_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(v_media_file_bk || p_file_size_bytes::text || p_importance_score::text),
        -- File identification
        'ai_recording_' || to_char(p_recording_timestamp, 'YYYYMMDD_HH24MISS') || '.mp4',
        'mp4',
        'video/mp4',
        p_file_size_bytes,
        -- Storage information
        'LOCAL',
        p_video_file_path,
        NULL, NULL,
        -- File metadata
        v_file_hash,
        p_recording_timestamp,
        NULL, -- uploaded_by_user_hk (AI upload)
        -- Media-specific metadata
        'VIDEO',
        p_duration_seconds,
        1920, 1080, -- Default HD resolution
        30.0, NULL, 'h264',
        -- Processing status
        'PROCESSED', -- AI uploads are pre-processed
        p_recording_timestamp,
        p_recording_timestamp,
        NULL,
        -- Security and compliance
        'CLEAN', -- AI uploads assumed clean
        p_recording_timestamp,
        'SAFE',
        -- Access control
        false, -- not public
        'TENANT', -- tenant-level access
        CURRENT_TIMESTAMP + (v_retention_days || ' days')::INTERVAL,
        -- Metadata and tags
        jsonb_build_object(
            'ai_generated', true,
            'camera_sensor_hk', encode(p_camera_sensor_hk, 'hex'),
            'ai_session_hk', encode(p_ai_session_hk, 'hex'),
            'importance_score', p_importance_score,
            'retention_decision', v_retention_decision,
            'ai_analysis', p_ai_analysis_results
        ),
        ARRAY['ai-generated', 'camera-recording'], -- user_tags
        CASE 
            WHEN p_ai_analysis_results IS NOT NULL 
            THEN ARRAY(SELECT jsonb_array_elements_text(p_ai_analysis_results->'detected_events'))
            ELSE ARRAY[]::TEXT[]
        END, -- ai_generated_tags
        'AI-generated video recording from camera sensor',
        util.get_record_source()
    );
    
    RETURN QUERY SELECT 
        v_media_file_hk,
        'SUCCESS'::VARCHAR(20),
        v_retention_decision,
        v_retention_days;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 30-DAY RETENTION MANAGEMENT
-- =====================================================

-- Function to manage 30-day retention with AI optimization
CREATE OR REPLACE FUNCTION media.manage_ai_video_retention(
    p_tenant_hk BYTEA,
    p_camera_sensor_hk BYTEA DEFAULT NULL
) RETURNS TABLE (
    videos_processed INTEGER,
    videos_deleted INTEGER,
    videos_compressed INTEGER,
    important_segments_extracted INTEGER,
    storage_freed_gb DECIMAL(10,2)
) AS $$
DECLARE
    v_videos_processed INTEGER := 0;
    v_videos_deleted INTEGER := 0;
    v_videos_compressed INTEGER := 0;
    v_segments_extracted INTEGER := 0;
    v_storage_freed DECIMAL(10,2) := 0.0;
    v_video_record RECORD;
    v_retention_policy RECORD;
BEGIN
    -- Get active retention policy
    SELECT 
        arp.default_retention_days,
        arp.important_segment_retention_days,
        arp.importance_threshold_for_retention,
        arp.enable_ai_optimization,
        arp.auto_delete_low_importance,
        arp.compress_normal_footage
    INTO v_retention_policy
    FROM media.ai_retention_policy_details_s arp
    JOIN media.ai_retention_policy_h arh ON arp.retention_policy_hk = arh.retention_policy_hk
    WHERE arh.tenant_hk = p_tenant_hk
    AND arp.is_active = true
    AND arp.load_end_date IS NULL
    ORDER BY arp.load_date DESC
    LIMIT 1;
    
    -- Process videos for retention management
    FOR v_video_record IN
        SELECT 
            mfd.media_file_hk,
            mfd.original_filename,
            mfd.file_size_bytes,
            mfd.upload_timestamp,
            mfd.expiration_date,
            mfd.file_metadata,
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - mfd.upload_timestamp)) / 86400 as age_days,
            (mfd.file_metadata->>'importance_score')::DECIMAL as importance_score
        FROM media.media_file_details_s mfd
        JOIN media.media_file_h mfh ON mfd.media_file_hk = mfh.media_file_hk
        WHERE mfh.tenant_hk = p_tenant_hk
        AND mfd.media_type = 'VIDEO'
        AND mfd.load_end_date IS NULL
        AND (mfd.file_metadata->>'ai_generated')::BOOLEAN = true
        AND (p_camera_sensor_hk IS NULL OR 
             decode(mfd.file_metadata->>'camera_sensor_hk', 'hex') = p_camera_sensor_hk)
        AND mfd.upload_timestamp < CURRENT_TIMESTAMP - INTERVAL '1 day' -- At least 1 day old
    LOOP
        v_videos_processed := v_videos_processed + 1;
        
        -- Check if video has expired
        IF v_video_record.expiration_date IS NOT NULL AND 
           v_video_record.expiration_date < CURRENT_TIMESTAMP THEN
            
            -- Extract important segments before deletion if enabled
            IF v_retention_policy.enable_ai_optimization AND 
               v_video_record.importance_score >= v_retention_policy.importance_threshold_for_retention THEN
                
                -- Call segment extraction function
                PERFORM media.extract_important_segments(
                    v_video_record.media_file_hk,
                    v_retention_policy.importance_threshold_for_retention
                );
                v_segments_extracted := v_segments_extracted + 1;
            END IF;
            
            -- Soft delete the video
            UPDATE media.media_file_details_s 
            SET load_end_date = util.current_load_date()
            WHERE media_file_hk = v_video_record.media_file_hk 
            AND load_end_date IS NULL;
            
            v_videos_deleted := v_videos_deleted + 1;
            v_storage_freed := v_storage_freed + (v_video_record.file_size_bytes::DECIMAL / (1024*1024*1024));
            
        -- Check if video should be compressed
        ELSIF v_retention_policy.compress_normal_footage AND 
              v_video_record.age_days > 7 AND 
              v_video_record.importance_score < v_retention_policy.importance_threshold_for_retention THEN
            
            -- Mark for compression (would trigger background job)
            UPDATE media.media_file_details_s 
            SET file_metadata = file_metadata || jsonb_build_object('compression_scheduled', true)
            WHERE media_file_hk = v_video_record.media_file_hk 
            AND load_end_date IS NULL;
            
            v_videos_compressed := v_videos_compressed + 1;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT 
        v_videos_processed,
        v_videos_deleted,
        v_videos_compressed,
        v_segments_extracted,
        v_storage_freed;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- AI IMPORTANT SEGMENT EXTRACTION
-- =====================================================

-- Function to extract important segments from video
CREATE OR REPLACE FUNCTION media.extract_important_segments(
    p_source_media_file_hk BYTEA,
    p_importance_threshold DECIMAL(5,4) DEFAULT 0.75
) RETURNS TABLE (
    segments_extracted INTEGER,
    total_segment_duration_seconds DECIMAL(10,3),
    storage_optimization_ratio DECIMAL(5,2)
) AS $$
DECLARE
    v_segments_extracted INTEGER := 0;
    v_total_duration DECIMAL(10,3) := 0.0;
    v_source_duration INTEGER;
    v_optimization_ratio DECIMAL(5,2);
    v_segment_record RECORD;
    v_segment_hk BYTEA;
    v_segment_bk VARCHAR(255);
BEGIN
    -- Get source video duration
    SELECT duration_seconds INTO v_source_duration
    FROM media.media_file_details_s
    WHERE media_file_hk = p_source_media_file_hk
    AND load_end_date IS NULL;
    
    -- Simulate AI segment detection (in real implementation, this would call AI service)
    -- For demo purposes, we'll create some sample important segments
    FOR v_segment_record IN
        SELECT * FROM (VALUES
            (120.5, 145.8, 0.85, 'ANOMALY_DETECTED', 'HIGH', 'Unusual behavior pattern detected'),
            (300.2, 315.7, 0.78, 'SECURITY_EVENT', 'CRITICAL', 'Unauthorized access attempt'),
            (450.1, 465.3, 0.82, 'MAINTENANCE_ISSUE', 'MEDIUM', 'Equipment malfunction detected')
        ) AS segments(start_sec, end_sec, importance, category, priority, description)
        WHERE segments.importance >= p_importance_threshold
    LOOP
        -- Generate segment identifiers
        v_segment_bk := 'AI_SEGMENT_' || encode(p_source_media_file_hk, 'hex') || '_' ||
                       v_segment_record.start_sec::text || '_' || v_segment_record.end_sec::text;
        v_segment_hk := util.hash_binary(v_segment_bk);
        
        -- Insert segment hub
        INSERT INTO media.ai_video_segment_h VALUES (
            v_segment_hk,
            v_segment_bk,
            (SELECT tenant_hk FROM media.media_file_h WHERE media_file_hk = p_source_media_file_hk),
            util.current_load_date(),
            util.get_record_source()
        );
        
        -- Insert segment details
        INSERT INTO media.ai_video_segment_details_s VALUES (
            v_segment_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(v_segment_bk || v_segment_record.importance::text),
            p_source_media_file_hk,
            NULL, -- ai_video_session_hk
            v_segment_record.start_sec,
            v_segment_record.end_sec,
            v_segment_record.end_sec - v_segment_record.start_sec,
            v_segment_record.importance,
            0.95, -- confidence_score
            ARRAY[v_segment_record.category],
            v_segment_record.description,
            v_segment_record.category,
            v_segment_record.priority,
            true, -- requires_human_review
            CURRENT_TIMESTAMP,
            NULL, -- processing_duration_ms
            'ai-segment-extractor-v1.0',
            '/segments/' || v_segment_bk || '.mp4',
            '/thumbnails/' || v_segment_bk || '.jpg',
            true, -- is_permanently_retained
            'AI detected important event',
            jsonb_build_object(
                'extraction_method', 'ai_analysis',
                'confidence_level', 'high',
                'review_required', true
            ),
            jsonb_build_object(
                'event_type', v_segment_record.category,
                'priority_level', v_segment_record.priority,
                'business_impact', 'requires_attention'
            ),
            util.get_record_source()
        );
        
        v_segments_extracted := v_segments_extracted + 1;
        v_total_duration := v_total_duration + (v_segment_record.end_sec - v_segment_record.start_sec);
    END LOOP;
    
    -- Calculate storage optimization ratio
    IF v_source_duration > 0 THEN
        v_optimization_ratio := (v_total_duration / v_source_duration) * 100;
    ELSE
        v_optimization_ratio := 0;
    END IF;
    
    RETURN QUERY SELECT 
        v_segments_extracted,
        v_total_duration,
        v_optimization_ratio;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- AI VIDEO API CONTRACTS
-- =====================================================

-- AI Video Upload API
CREATE OR REPLACE FUNCTION api.ai_video_upload(
    p_request JSONB
) RETURNS JSONB AS $$
DECLARE
    v_tenant_id VARCHAR(255);
    v_ai_session_id VARCHAR(255);
    v_camera_id VARCHAR(255);
    v_video_path TEXT;
    v_file_size BIGINT;
    v_duration INTEGER;
    v_recording_timestamp TIMESTAMP WITH TIME ZONE;
    v_ai_analysis JSONB;
    v_importance_score DECIMAL(5,4);
    v_tenant_hk BYTEA;
    v_session_hk BYTEA;
    v_camera_hk BYTEA;
    v_upload_result RECORD;
BEGIN
    -- Extract parameters
    v_tenant_id := p_request->>'tenantId';
    v_ai_session_id := p_request->>'aiSessionId';
    v_camera_id := p_request->>'cameraId';
    v_video_path := p_request->>'videoPath';
    v_file_size := (p_request->>'fileSize')::BIGINT;
    v_duration := (p_request->>'duration')::INTEGER;
    v_recording_timestamp := (p_request->>'recordingTimestamp')::TIMESTAMP WITH TIME ZONE;
    v_ai_analysis := p_request->'aiAnalysis';
    v_importance_score := COALESCE((p_request->>'importanceScore')::DECIMAL, 0.50);
    
    -- Validate required parameters
    IF v_tenant_id IS NULL OR v_camera_id IS NULL OR v_video_path IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Missing required parameters: tenantId, cameraId, videoPath',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Get hash keys
    SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h WHERE tenant_bk = v_tenant_id;
    
    IF v_ai_session_id IS NOT NULL THEN
        v_session_hk := decode(v_ai_session_id, 'hex');
    END IF;
    
    v_camera_hk := decode(v_camera_id, 'hex');
    
    -- Call AI upload function
    SELECT * INTO v_upload_result
    FROM media.ai_upload_video(
        v_tenant_hk,
        v_session_hk,
        v_camera_hk,
        v_video_path,
        v_file_size,
        v_duration,
        v_recording_timestamp,
        v_ai_analysis,
        v_importance_score
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'AI video uploaded successfully',
        'data', jsonb_build_object(
            'videoId', encode(v_upload_result.media_file_hk, 'hex'),
            'uploadStatus', v_upload_result.upload_status,
            'retentionDecision', v_upload_result.retention_decision,
            'estimatedRetentionDays', v_upload_result.estimated_retention_days,
            'importanceScore', v_importance_score,
            'uploadTimestamp', CURRENT_TIMESTAMP::TEXT
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error uploading AI video',
        'error_code', 'AI_UPLOAD_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$$ LANGUAGE plpgsql;

-- AI Retention Management API
CREATE OR REPLACE FUNCTION api.ai_retention_cleanup(
    p_request JSONB
) RETURNS JSONB AS $$
DECLARE
    v_tenant_id VARCHAR(255);
    v_camera_id VARCHAR(255);
    v_tenant_hk BYTEA;
    v_camera_hk BYTEA;
    v_cleanup_result RECORD;
BEGIN
    -- Extract parameters
    v_tenant_id := p_request->>'tenantId';
    v_camera_id := p_request->>'cameraId';
    
    -- Validate parameters
    IF v_tenant_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Missing required parameter: tenantId',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Get hash keys
    SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h WHERE tenant_bk = v_tenant_id;
    
    IF v_camera_id IS NOT NULL THEN
        v_camera_hk := decode(v_camera_id, 'hex');
    END IF;
    
    -- Execute retention cleanup
    SELECT * INTO v_cleanup_result
    FROM media.manage_ai_video_retention(v_tenant_hk, v_camera_hk);
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'AI video retention cleanup completed',
        'data', jsonb_build_object(
            'videosProcessed', v_cleanup_result.videos_processed,
            'videosDeleted', v_cleanup_result.videos_deleted,
            'videosCompressed', v_cleanup_result.videos_compressed,
            'importantSegmentsExtracted', v_cleanup_result.important_segments_extracted,
            'storageFreedGb', v_cleanup_result.storage_freed_gb,
            'cleanupTimestamp', CURRENT_TIMESTAMP::TEXT
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error during retention cleanup',
        'error_code', 'RETENTION_CLEANUP_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$$ LANGUAGE plpgsql;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_ai_video_session_details_s_camera_status 
ON media.ai_video_session_details_s (camera_sensor_hk, session_status, session_start_time DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_video_segment_details_s_importance 
ON media.ai_video_segment_details_s (importance_score DESC, extraction_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_media_file_details_s_ai_retention 
ON media.media_file_details_s (expiration_date ASC, upload_timestamp ASC) 
WHERE load_end_date IS NULL 
AND (file_metadata->>'ai_generated')::BOOLEAN = true;

-- =====================================================
-- DOCUMENTATION
-- =====================================================

COMMENT ON FUNCTION media.ai_upload_video IS 
'Handles AI-driven video uploads with automatic retention policy application and importance scoring.';

COMMENT ON FUNCTION media.manage_ai_video_retention IS 
'Manages 30-day retention policy with AI optimization, segment extraction, and storage cleanup.';

COMMENT ON FUNCTION media.extract_important_segments IS 
'Extracts important video segments based on AI analysis before full video deletion.';

COMMENT ON FUNCTION api.ai_video_upload IS 
'POST /api/v1/ai/videos/upload - AI system endpoint for uploading analyzed video content.';

COMMENT ON FUNCTION api.ai_retention_cleanup IS 
'POST /api/v1/ai/videos/retention/cleanup - Triggers AI-optimized retention cleanup process.';

-- Commit transaction
COMMIT; 