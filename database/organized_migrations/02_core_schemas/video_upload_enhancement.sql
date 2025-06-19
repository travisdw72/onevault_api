-- Video Upload Enhancement for One Vault Platform
-- Adds comprehensive video storage and management capabilities

-- Start transaction
BEGIN;

-- Create media storage schema
CREATE SCHEMA IF NOT EXISTS media;

-- Media File Hub
CREATE TABLE media.media_file_h (
    media_file_hk BYTEA PRIMARY KEY,
    media_file_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    CONSTRAINT uk_media_file_h_bk_tenant 
        UNIQUE (media_file_bk, tenant_hk)
);

COMMENT ON TABLE media.media_file_h IS 
'Hub table for media files including videos, images, and documents with tenant isolation.';

-- Media File Details Satellite
CREATE TABLE media.media_file_details_s (
    media_file_hk BYTEA NOT NULL REFERENCES media.media_file_h(media_file_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- File identification
    original_filename VARCHAR(500) NOT NULL,
    file_extension VARCHAR(10) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    
    -- Storage information
    storage_provider VARCHAR(50) NOT NULL DEFAULT 'LOCAL', -- LOCAL, AWS_S3, AZURE_BLOB, GCP_STORAGE
    storage_path TEXT NOT NULL,
    storage_bucket VARCHAR(100),
    storage_region VARCHAR(50),
    
    -- File metadata
    file_hash_sha256 VARCHAR(64) NOT NULL, -- For integrity verification
    upload_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    uploaded_by_user_hk BYTEA REFERENCES auth.user_h(user_hk),
    
    -- Media-specific metadata
    media_type VARCHAR(20) NOT NULL CHECK (media_type IN ('VIDEO', 'IMAGE', 'AUDIO', 'DOCUMENT', 'OTHER')),
    duration_seconds INTEGER, -- For video/audio files
    width_pixels INTEGER, -- For video/image files
    height_pixels INTEGER, -- For video/image files
    frame_rate DECIMAL(5,2), -- For video files
    bitrate_kbps INTEGER, -- For video/audio files
    codec VARCHAR(50), -- Video/audio codec
    
    -- Processing status
    processing_status VARCHAR(20) DEFAULT 'UPLOADED' CHECK (processing_status IN ('UPLOADED', 'PROCESSING', 'PROCESSED', 'FAILED', 'QUARANTINED')),
    processing_started_at TIMESTAMP WITH TIME ZONE,
    processing_completed_at TIMESTAMP WITH TIME ZONE,
    processing_error TEXT,
    
    -- Security and compliance
    virus_scan_status VARCHAR(20) DEFAULT 'PENDING' CHECK (virus_scan_status IN ('PENDING', 'CLEAN', 'INFECTED', 'FAILED')),
    virus_scan_timestamp TIMESTAMP WITH TIME ZONE,
    content_rating VARCHAR(20) DEFAULT 'UNRATED' CHECK (content_rating IN ('UNRATED', 'SAFE', 'MODERATE', 'RESTRICTED', 'BLOCKED')),
    
    -- Access control
    is_public BOOLEAN DEFAULT false,
    access_level VARCHAR(20) DEFAULT 'PRIVATE' CHECK (access_level IN ('PUBLIC', 'TENANT', 'PRIVATE', 'RESTRICTED')),
    expiration_date TIMESTAMP WITH TIME ZONE,
    
    -- Metadata and tags
    file_metadata JSONB, -- Technical metadata from file analysis
    user_tags TEXT[], -- User-defined tags
    ai_generated_tags TEXT[], -- AI-generated content tags
    description TEXT,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (media_file_hk, load_date)
);

COMMENT ON TABLE media.media_file_details_s IS 
'Detailed metadata for media files including technical specifications, processing status, and security information.';

-- Video Processing Hub (for video-specific processing tasks)
CREATE TABLE media.video_processing_h (
    video_processing_hk BYTEA PRIMARY KEY,
    video_processing_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    CONSTRAINT uk_video_processing_h_bk_tenant 
        UNIQUE (video_processing_bk, tenant_hk)
);

-- Video Processing Details Satellite
CREATE TABLE media.video_processing_details_s (
    video_processing_hk BYTEA NOT NULL REFERENCES media.video_processing_h(video_processing_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    media_file_hk BYTEA NOT NULL REFERENCES media.media_file_h(media_file_hk),
    processing_type VARCHAR(50) NOT NULL, -- TRANSCODE, THUMBNAIL, WATERMARK, COMPRESS, ANALYZE
    processing_status VARCHAR(20) DEFAULT 'QUEUED' CHECK (processing_status IN ('QUEUED', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    
    -- Processing configuration
    target_format VARCHAR(20), -- MP4, WEBM, AVI, etc.
    target_resolution VARCHAR(20), -- 1080p, 720p, 480p, etc.
    target_bitrate_kbps INTEGER,
    target_codec VARCHAR(50),
    
    -- Processing results
    output_file_path TEXT,
    output_file_size_bytes BIGINT,
    processing_duration_ms INTEGER,
    
    -- Timestamps
    queued_at TIMESTAMP WITH TIME ZONE NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Error handling
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    
    -- Processing metadata
    processing_parameters JSONB,
    processing_results JSONB,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (video_processing_hk, load_date)
);

-- Media Access Log Hub (for tracking access and downloads)
CREATE TABLE media.media_access_log_h (
    media_access_hk BYTEA PRIMARY KEY,
    media_access_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Media Access Log Details Satellite
CREATE TABLE media.media_access_log_details_s (
    media_access_hk BYTEA NOT NULL REFERENCES media.media_access_log_h(media_access_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    media_file_hk BYTEA NOT NULL REFERENCES media.media_file_h(media_file_hk),
    user_hk BYTEA REFERENCES auth.user_h(user_hk),
    
    -- Access details
    access_type VARCHAR(20) NOT NULL CHECK (access_type IN ('VIEW', 'DOWNLOAD', 'STREAM', 'THUMBNAIL', 'METADATA')),
    access_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Request information
    ip_address INET,
    user_agent TEXT,
    referer_url TEXT,
    
    -- Response information
    response_status INTEGER, -- HTTP status code
    bytes_served BIGINT,
    response_time_ms INTEGER,
    
    -- Security and compliance
    access_granted BOOLEAN NOT NULL,
    denial_reason TEXT,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (media_access_hk, load_date)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_media_file_details_s_tenant_type 
ON media.media_file_details_s (media_file_hk, media_type, upload_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_media_file_details_s_processing_status 
ON media.media_file_details_s (processing_status, upload_timestamp DESC) 
WHERE load_end_date IS NULL AND processing_status != 'PROCESSED';

CREATE INDEX IF NOT EXISTS idx_media_file_details_s_virus_scan 
ON media.media_file_details_s (virus_scan_status, virus_scan_timestamp DESC) 
WHERE load_end_date IS NULL AND virus_scan_status = 'PENDING';

CREATE INDEX IF NOT EXISTS idx_video_processing_details_s_status 
ON media.video_processing_details_s (processing_status, queued_at ASC) 
WHERE load_end_date IS NULL AND processing_status IN ('QUEUED', 'PROCESSING');

CREATE INDEX IF NOT EXISTS idx_media_access_log_details_s_file_time 
ON media.media_access_log_details_s (media_file_hk, access_timestamp DESC) 
WHERE load_end_date IS NULL;

-- Video upload function
CREATE OR REPLACE FUNCTION media.upload_video_file(
    p_tenant_hk BYTEA,
    p_user_hk BYTEA,
    p_original_filename VARCHAR(500),
    p_file_size_bytes BIGINT,
    p_mime_type VARCHAR(100),
    p_storage_path TEXT,
    p_file_hash_sha256 VARCHAR(64),
    p_duration_seconds INTEGER DEFAULT NULL,
    p_width_pixels INTEGER DEFAULT NULL,
    p_height_pixels INTEGER DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_user_tags TEXT[] DEFAULT ARRAY[]::TEXT[]
) RETURNS TABLE (
    media_file_hk BYTEA,
    upload_status VARCHAR(20),
    processing_required BOOLEAN,
    estimated_processing_time_minutes INTEGER
) AS $$
DECLARE
    v_media_file_hk BYTEA;
    v_media_file_bk VARCHAR(255);
    v_file_extension VARCHAR(10);
    v_processing_required BOOLEAN := false;
    v_estimated_time INTEGER := 0;
BEGIN
    -- Extract file extension
    v_file_extension := LOWER(RIGHT(p_original_filename, POSITION('.' IN REVERSE(p_original_filename)) - 1));
    
    -- Generate business key and hash key
    v_media_file_bk := 'VIDEO_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS') || '_' || 
                       encode(gen_random_bytes(4), 'hex');
    v_media_file_hk := util.hash_binary(v_media_file_bk || encode(p_tenant_hk, 'hex'));
    
    -- Insert hub record
    INSERT INTO media.media_file_h VALUES (
        v_media_file_hk,
        v_media_file_bk,
        p_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    );
    
    -- Insert satellite record
    INSERT INTO media.media_file_details_s VALUES (
        v_media_file_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(p_original_filename || p_file_size_bytes::text || p_file_hash_sha256),
        p_original_filename,
        v_file_extension,
        p_mime_type,
        p_file_size_bytes,
        'LOCAL', -- storage_provider
        p_storage_path,
        NULL, -- storage_bucket
        NULL, -- storage_region
        p_file_hash_sha256,
        CURRENT_TIMESTAMP,
        p_user_hk,
        'VIDEO',
        p_duration_seconds,
        p_width_pixels,
        p_height_pixels,
        NULL, -- frame_rate
        NULL, -- bitrate_kbps
        NULL, -- codec
        'UPLOADED',
        NULL, -- processing_started_at
        NULL, -- processing_completed_at
        NULL, -- processing_error
        'PENDING', -- virus_scan_status
        NULL, -- virus_scan_timestamp
        'UNRATED', -- content_rating
        false, -- is_public
        'PRIVATE', -- access_level
        NULL, -- expiration_date
        NULL, -- file_metadata
        p_user_tags,
        ARRAY[]::TEXT[], -- ai_generated_tags
        p_description,
        util.get_record_source()
    );
    
    -- Determine if processing is required
    IF v_file_extension NOT IN ('mp4', 'webm') OR p_file_size_bytes > 100 * 1024 * 1024 THEN -- 100MB threshold
        v_processing_required := true;
        v_estimated_time := GREATEST(1, (p_file_size_bytes / (10 * 1024 * 1024))::INTEGER); -- ~1 min per 10MB
    END IF;
    
    RETURN QUERY SELECT 
        v_media_file_hk,
        'SUCCESS'::VARCHAR(20),
        v_processing_required,
        v_estimated_time;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION media.upload_video_file IS 
'Handles video file upload registration with metadata storage and processing queue management.';

-- Video streaming function
CREATE OR REPLACE FUNCTION media.get_video_stream_url(
    p_tenant_hk BYTEA,
    p_user_hk BYTEA,
    p_media_file_hk BYTEA,
    p_quality VARCHAR(20) DEFAULT 'AUTO'
) RETURNS TABLE (
    stream_url TEXT,
    access_granted BOOLEAN,
    expires_at TIMESTAMP WITH TIME ZONE,
    available_qualities TEXT[]
) AS $$
DECLARE
    v_file_details RECORD;
    v_access_granted BOOLEAN := false;
    v_stream_url TEXT;
    v_expires_at TIMESTAMP WITH TIME ZONE;
    v_access_log_hk BYTEA;
    v_access_log_bk VARCHAR(255);
BEGIN
    -- Get file details and check access
    SELECT 
        mfd.storage_path,
        mfd.access_level,
        mfd.is_public,
        mfd.processing_status,
        mfd.virus_scan_status,
        mfd.expiration_date
    INTO v_file_details
    FROM media.media_file_details_s mfd
    JOIN media.media_file_h mfh ON mfd.media_file_hk = mfh.media_file_hk
    WHERE mfd.media_file_hk = p_media_file_hk
    AND mfh.tenant_hk = p_tenant_hk
    AND mfd.load_end_date IS NULL;
    
    -- Check access permissions
    IF v_file_details IS NOT NULL THEN
        IF v_file_details.is_public OR 
           v_file_details.access_level IN ('PUBLIC', 'TENANT') OR
           (v_file_details.access_level = 'PRIVATE' AND p_user_hk IS NOT NULL) THEN
            
            -- Check file is ready for streaming
            IF v_file_details.processing_status = 'PROCESSED' AND 
               v_file_details.virus_scan_status = 'CLEAN' AND
               (v_file_details.expiration_date IS NULL OR v_file_details.expiration_date > CURRENT_TIMESTAMP) THEN
                
                v_access_granted := true;
                v_stream_url := '/api/v1/media/stream/' || encode(p_media_file_hk, 'hex') || 
                               CASE WHEN p_quality != 'AUTO' THEN '?quality=' || p_quality ELSE '' END;
                v_expires_at := CURRENT_TIMESTAMP + INTERVAL '24 hours';
            END IF;
        END IF;
    END IF;
    
    -- Log access attempt
    v_access_log_bk := 'ACCESS_' || encode(p_media_file_hk, 'hex') || '_' || 
                       to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    v_access_log_hk := util.hash_binary(v_access_log_bk);
    
    INSERT INTO media.media_access_log_h VALUES (
        v_access_log_hk,
        v_access_log_bk,
        p_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    );
    
    INSERT INTO media.media_access_log_details_s VALUES (
        v_access_log_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(v_access_log_bk || v_access_granted::text),
        p_media_file_hk,
        p_user_hk,
        'STREAM',
        CURRENT_TIMESTAMP,
        inet_client_addr(),
        current_setting('application_name', true),
        NULL, -- referer_url
        CASE WHEN v_access_granted THEN 200 ELSE 403 END,
        NULL, -- bytes_served
        NULL, -- response_time_ms
        v_access_granted,
        CASE WHEN NOT v_access_granted THEN 'Access denied or file not ready' ELSE NULL END,
        util.get_record_source()
    );
    
    RETURN QUERY SELECT 
        v_stream_url,
        v_access_granted,
        v_expires_at,
        ARRAY['360p', '720p', '1080p']::TEXT[]; -- Available qualities
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION media.get_video_stream_url IS 
'Generates secure streaming URLs for video files with access control and logging.';

-- Video analytics function
CREATE OR REPLACE FUNCTION media.get_video_analytics(
    p_tenant_hk BYTEA,
    p_date_from DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_date_to DATE DEFAULT CURRENT_DATE
) RETURNS TABLE (
    total_videos INTEGER,
    total_storage_gb DECIMAL(10,2),
    total_views INTEGER,
    total_downloads INTEGER,
    avg_video_duration_minutes DECIMAL(8,2),
    most_viewed_video_filename VARCHAR(500),
    storage_by_type JSONB,
    daily_upload_stats JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH video_stats AS (
        SELECT 
            COUNT(*) as video_count,
            SUM(mfd.file_size_bytes)::DECIMAL / (1024*1024*1024) as storage_gb,
            AVG(mfd.duration_seconds)::DECIMAL / 60 as avg_duration_min
        FROM media.media_file_details_s mfd
        JOIN media.media_file_h mfh ON mfd.media_file_hk = mfh.media_file_hk
        WHERE mfh.tenant_hk = p_tenant_hk
        AND mfd.media_type = 'VIDEO'
        AND mfd.upload_timestamp::DATE BETWEEN p_date_from AND p_date_to
        AND mfd.load_end_date IS NULL
    ),
    access_stats AS (
        SELECT 
            COUNT(*) FILTER (WHERE mal.access_type = 'VIEW') as view_count,
            COUNT(*) FILTER (WHERE mal.access_type = 'DOWNLOAD') as download_count
        FROM media.media_access_log_details_s mal
        JOIN media.media_access_log_h malh ON mal.media_access_hk = malh.media_access_hk
        WHERE malh.tenant_hk = p_tenant_hk
        AND mal.access_timestamp::DATE BETWEEN p_date_from AND p_date_to
        AND mal.load_end_date IS NULL
    ),
    most_viewed AS (
        SELECT mfd.original_filename
        FROM media.media_access_log_details_s mal
        JOIN media.media_access_log_h malh ON mal.media_access_hk = malh.media_access_hk
        JOIN media.media_file_details_s mfd ON mal.media_file_hk = mfd.media_file_hk
        WHERE malh.tenant_hk = p_tenant_hk
        AND mal.access_type = 'VIEW'
        AND mal.access_timestamp::DATE BETWEEN p_date_from AND p_date_to
        AND mal.load_end_date IS NULL
        AND mfd.load_end_date IS NULL
        GROUP BY mfd.original_filename, mfd.media_file_hk
        ORDER BY COUNT(*) DESC
        LIMIT 1
    )
    SELECT 
        vs.video_count::INTEGER,
        vs.storage_gb,
        acs.view_count::INTEGER,
        acs.download_count::INTEGER,
        vs.avg_duration_min,
        mv.original_filename,
        '{}'::JSONB as storage_by_type, -- Placeholder for detailed breakdown
        '{}'::JSONB as daily_upload_stats -- Placeholder for daily stats
    FROM video_stats vs
    CROSS JOIN access_stats acs
    LEFT JOIN most_viewed mv ON true;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION media.get_video_analytics IS 
'Provides comprehensive analytics for video uploads, storage, and access patterns.';

-- Update tenant storage limits to include video storage
ALTER TABLE auth.tenant_profile_s 
ADD COLUMN IF NOT EXISTS video_storage_limit_gb INTEGER DEFAULT 5,
ADD COLUMN IF NOT EXISTS video_upload_limit_mb INTEGER DEFAULT 500,
ADD COLUMN IF NOT EXISTS max_video_duration_minutes INTEGER DEFAULT 60;

COMMENT ON COLUMN auth.tenant_profile_s.video_storage_limit_gb IS 
'Maximum video storage allowed for tenant in gigabytes';

COMMENT ON COLUMN auth.tenant_profile_s.video_upload_limit_mb IS 
'Maximum individual video file size in megabytes';

COMMENT ON COLUMN auth.tenant_profile_s.max_video_duration_minutes IS 
'Maximum video duration allowed in minutes';

-- Commit transaction
COMMIT; 