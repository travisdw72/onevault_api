-- Video Upload API Contracts for One Vault Platform
-- Provides standardized API endpoints for video upload, streaming, and management
-- Follows established API contract patterns with comprehensive error handling

-- Start transaction
BEGIN;

-- =====================================================
-- VIDEO UPLOAD API ENDPOINTS
-- =====================================================

-- Video Upload Initiation API
CREATE OR REPLACE FUNCTION api.video_upload_initiate(
    p_request JSONB
) RETURNS JSONB AS $$
DECLARE
    v_tenant_id VARCHAR(255);
    v_user_id VARCHAR(255);
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_filename VARCHAR(500);
    v_file_size BIGINT;
    v_mime_type VARCHAR(100);
    v_duration INTEGER;
    v_width INTEGER;
    v_height INTEGER;
    v_description TEXT;
    v_tags TEXT[];
    v_upload_result RECORD;
    v_storage_path TEXT;
    v_file_hash VARCHAR(64);
    v_ip_address INET;
    v_user_agent TEXT;
BEGIN
    -- Extract and validate parameters
    v_tenant_id := p_request->>'tenantId';
    v_user_id := p_request->>'userId';
    v_filename := p_request->>'filename';
    v_file_size := (p_request->>'fileSize')::BIGINT;
    v_mime_type := p_request->>'mimeType';
    v_duration := (p_request->>'duration')::INTEGER;
    v_width := (p_request->>'width')::INTEGER;
    v_height := (p_request->>'height')::INTEGER;
    v_description := p_request->>'description';
    v_tags := CASE 
        WHEN p_request->'tags' IS NOT NULL 
        THEN ARRAY(SELECT jsonb_array_elements_text(p_request->'tags'))
        ELSE ARRAY[]::TEXT[]
    END;
    v_file_hash := p_request->>'fileHash';
    v_ip_address := COALESCE((p_request->>'ip_address')::INET, '127.0.0.1'::INET);
    v_user_agent := COALESCE(p_request->>'user_agent', 'Unknown');
    
    -- Validate required parameters
    IF v_tenant_id IS NULL OR v_user_id IS NULL OR v_filename IS NULL OR 
       v_file_size IS NULL OR v_mime_type IS NULL OR v_file_hash IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Missing required parameters: tenantId, userId, filename, fileSize, mimeType, fileHash',
            'error_code', 'MISSING_PARAMETERS',
            'data', jsonb_build_object(
                'required_fields', ARRAY['tenantId', 'userId', 'filename', 'fileSize', 'mimeType', 'fileHash']
            )
        );
    END IF;
    
    -- Validate file type
    IF v_mime_type NOT LIKE 'video/%' THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid file type. Only video files are supported.',
            'error_code', 'INVALID_FILE_TYPE',
            'data', jsonb_build_object(
                'provided_mime_type', v_mime_type,
                'supported_types', ARRAY['video/mp4', 'video/webm', 'video/avi', 'video/mov', 'video/wmv']
            )
        );
    END IF;
    
    -- Get tenant and user hash keys
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h 
    WHERE tenant_bk = v_tenant_id;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid tenant ID',
            'error_code', 'INVALID_TENANT'
        );
    END IF;
    
    SELECT user_hk INTO v_user_hk
    FROM auth.user_h 
    WHERE user_bk = v_user_id AND tenant_hk = v_tenant_hk;
    
    IF v_user_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid user ID for tenant',
            'error_code', 'INVALID_USER'
        );
    END IF;
    
    -- Check tenant video storage limits
    DECLARE
        v_tenant_limits RECORD;
        v_current_usage DECIMAL;
    BEGIN
        SELECT 
            video_storage_limit_gb,
            video_upload_limit_mb,
            max_video_duration_minutes
        INTO v_tenant_limits
        FROM auth.tenant_profile_s 
        WHERE tenant_hk = v_tenant_hk 
        AND load_end_date IS NULL;
        
        -- Check file size limit
        IF v_file_size > (v_tenant_limits.video_upload_limit_mb * 1024 * 1024) THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'File size exceeds tenant limit',
                'error_code', 'FILE_SIZE_LIMIT_EXCEEDED',
                'data', jsonb_build_object(
                    'file_size_mb', ROUND(v_file_size / 1024.0 / 1024.0, 2),
                    'limit_mb', v_tenant_limits.video_upload_limit_mb
                )
            );
        END IF;
        
        -- Check duration limit
        IF v_duration IS NOT NULL AND v_duration > (v_tenant_limits.max_video_duration_minutes * 60) THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Video duration exceeds tenant limit',
                'error_code', 'DURATION_LIMIT_EXCEEDED',
                'data', jsonb_build_object(
                    'duration_minutes', ROUND(v_duration / 60.0, 2),
                    'limit_minutes', v_tenant_limits.max_video_duration_minutes
                )
            );
        END IF;
        
        -- Check storage quota
        SELECT COALESCE(SUM(file_size_bytes), 0)::DECIMAL / (1024*1024*1024) INTO v_current_usage
        FROM media.media_file_details_s mfd
        JOIN media.media_file_h mfh ON mfd.media_file_hk = mfh.media_file_hk
        WHERE mfh.tenant_hk = v_tenant_hk
        AND mfd.media_type = 'VIDEO'
        AND mfd.load_end_date IS NULL;
        
        IF (v_current_usage + (v_file_size::DECIMAL / (1024*1024*1024))) > v_tenant_limits.video_storage_limit_gb THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Storage quota exceeded',
                'error_code', 'STORAGE_QUOTA_EXCEEDED',
                'data', jsonb_build_object(
                    'current_usage_gb', ROUND(v_current_usage, 2),
                    'additional_gb', ROUND(v_file_size::DECIMAL / (1024*1024*1024), 2),
                    'limit_gb', v_tenant_limits.video_storage_limit_gb
                )
            );
        END IF;
    END;
    
    -- Generate storage path
    v_storage_path := '/uploads/' || v_tenant_id || '/videos/' || 
                     to_char(CURRENT_TIMESTAMP, 'YYYY/MM/DD/') || 
                     encode(gen_random_bytes(8), 'hex') || '_' || v_filename;
    
    -- Call video upload function
    SELECT * INTO v_upload_result
    FROM media.upload_video_file(
        v_tenant_hk,
        v_user_hk,
        v_filename,
        v_file_size,
        v_mime_type,
        v_storage_path,
        v_file_hash,
        v_duration,
        v_width,
        v_height,
        v_description,
        v_tags
    );
    
    -- Log the upload initiation
    PERFORM audit.log_security_event(
        'VIDEO_UPLOAD_INITIATED',
        'LOW',
        'Video upload initiated: ' || v_filename || ' (' || ROUND(v_file_size / 1024.0 / 1024.0, 2) || ' MB)',
        v_ip_address,
        v_user_agent,
        v_user_hk,
        'LOW',
        jsonb_build_object(
            'tenant_id', v_tenant_id,
            'user_id', v_user_id,
            'filename', v_filename,
            'file_size_mb', ROUND(v_file_size / 1024.0 / 1024.0, 2),
            'mime_type', v_mime_type,
            'duration_seconds', v_duration,
            'media_file_hk', encode(v_upload_result.media_file_hk, 'hex')
        )
    );
    
    -- Return success response
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Video upload initiated successfully',
        'data', jsonb_build_object(
            'uploadId', encode(v_upload_result.media_file_hk, 'hex'),
            'storagePath', v_storage_path,
            'uploadStatus', v_upload_result.upload_status,
            'processingRequired', v_upload_result.processing_required,
            'estimatedProcessingTimeMinutes', v_upload_result.estimated_processing_time_minutes,
            'uploadUrl', '/api/v1/media/upload/' || encode(v_upload_result.media_file_hk, 'hex'),
            'expiresAt', (CURRENT_TIMESTAMP + INTERVAL '1 hour')::TEXT
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error initiating video upload',
        'error_code', 'UPLOAD_INITIATION_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION api.video_upload_initiate IS 
'POST /api/v1/videos/upload/initiate - Initiates video upload with validation and quota checking';

-- Video Upload Completion API
CREATE OR REPLACE FUNCTION api.video_upload_complete(
    p_request JSONB
) RETURNS JSONB AS $$
DECLARE
    v_tenant_id VARCHAR(255);
    v_user_id VARCHAR(255);
    v_upload_id VARCHAR(255);
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_media_file_hk BYTEA;
    v_actual_file_size BIGINT;
    v_actual_file_hash VARCHAR(64);
    v_processing_metadata JSONB;
    v_ip_address INET;
    v_user_agent TEXT;
BEGIN
    -- Extract parameters
    v_tenant_id := p_request->>'tenantId';
    v_user_id := p_request->>'userId';
    v_upload_id := p_request->>'uploadId';
    v_actual_file_size := (p_request->>'actualFileSize')::BIGINT;
    v_actual_file_hash := p_request->>'actualFileHash';
    v_processing_metadata := p_request->'processingMetadata';
    v_ip_address := COALESCE((p_request->>'ip_address')::INET, '127.0.0.1'::INET);
    v_user_agent := COALESCE(p_request->>'user_agent', 'Unknown');
    
    -- Validate required parameters
    IF v_tenant_id IS NULL OR v_user_id IS NULL OR v_upload_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Missing required parameters: tenantId, userId, uploadId',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Get hash keys
    SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h WHERE tenant_bk = v_tenant_id;
    SELECT user_hk INTO v_user_hk FROM auth.user_h WHERE user_bk = v_user_id AND tenant_hk = v_tenant_hk;
    v_media_file_hk := decode(v_upload_id, 'hex');
    
    -- Verify upload exists and belongs to user/tenant
    IF NOT EXISTS (
        SELECT 1 FROM media.media_file_h mfh
        JOIN media.media_file_details_s mfd ON mfh.media_file_hk = mfd.media_file_hk
        WHERE mfh.media_file_hk = v_media_file_hk
        AND mfh.tenant_hk = v_tenant_hk
        AND mfd.uploaded_by_user_hk = v_user_hk
        AND mfd.processing_status = 'UPLOADED'
        AND mfd.load_end_date IS NULL
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Upload not found or not accessible',
            'error_code', 'UPLOAD_NOT_FOUND'
        );
    END IF;
    
    -- Update upload status to processing
    UPDATE media.media_file_details_s 
    SET load_end_date = util.current_load_date()
    WHERE media_file_hk = v_media_file_hk 
    AND load_end_date IS NULL;
    
    INSERT INTO media.media_file_details_s (
        media_file_hk, load_date, load_end_date, hash_diff,
        original_filename, file_extension, mime_type, file_size_bytes,
        storage_provider, storage_path, storage_bucket, storage_region,
        file_hash_sha256, upload_timestamp, uploaded_by_user_hk,
        media_type, duration_seconds, width_pixels, height_pixels,
        frame_rate, bitrate_kbps, codec,
        processing_status, processing_started_at, processing_completed_at, processing_error,
        virus_scan_status, virus_scan_timestamp, content_rating,
        is_public, access_level, expiration_date,
        file_metadata, user_tags, ai_generated_tags, description,
        record_source
    )
    SELECT 
        media_file_hk, util.current_load_date(), NULL,
        util.hash_binary(original_filename || COALESCE(v_actual_file_size, file_size_bytes)::text || COALESCE(v_actual_file_hash, file_hash_sha256)),
        original_filename, file_extension, mime_type, 
        COALESCE(v_actual_file_size, file_size_bytes),
        storage_provider, storage_path, storage_bucket, storage_region,
        COALESCE(v_actual_file_hash, file_hash_sha256), upload_timestamp, uploaded_by_user_hk,
        media_type, duration_seconds, width_pixels, height_pixels,
        frame_rate, bitrate_kbps, codec,
        'PROCESSING', CURRENT_TIMESTAMP, NULL, NULL,
        virus_scan_status, virus_scan_timestamp, content_rating,
        is_public, access_level, expiration_date,
        COALESCE(v_processing_metadata, file_metadata), user_tags, ai_generated_tags, description,
        record_source
    FROM media.media_file_details_s
    WHERE media_file_hk = v_media_file_hk
    AND load_end_date = util.current_load_date();
    
    -- Log completion
    PERFORM audit.log_security_event(
        'VIDEO_UPLOAD_COMPLETED',
        'LOW',
        'Video upload completed for upload ID: ' || v_upload_id,
        v_ip_address,
        v_user_agent,
        v_user_hk,
        'LOW',
        jsonb_build_object(
            'tenant_id', v_tenant_id,
            'user_id', v_user_id,
            'upload_id', v_upload_id,
            'actual_file_size', v_actual_file_size,
            'processing_metadata', v_processing_metadata
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Video upload completed successfully',
        'data', jsonb_build_object(
            'uploadId', v_upload_id,
            'status', 'PROCESSING',
            'processingStarted', true,
            'estimatedCompletionTime', (CURRENT_TIMESTAMP + INTERVAL '10 minutes')::TEXT
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error completing video upload',
        'error_code', 'UPLOAD_COMPLETION_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$$ LANGUAGE plpgsql;

-- Video Streaming API
CREATE OR REPLACE FUNCTION api.video_get_stream_url(
    p_request JSONB
) RETURNS JSONB AS $$
DECLARE
    v_tenant_id VARCHAR(255);
    v_user_id VARCHAR(255);
    v_video_id VARCHAR(255);
    v_quality VARCHAR(20);
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_media_file_hk BYTEA;
    v_stream_result RECORD;
    v_ip_address INET;
    v_user_agent TEXT;
BEGIN
    -- Extract parameters
    v_tenant_id := p_request->>'tenantId';
    v_user_id := p_request->>'userId';
    v_video_id := p_request->>'videoId';
    v_quality := COALESCE(p_request->>'quality', 'AUTO');
    v_ip_address := COALESCE((p_request->>'ip_address')::INET, '127.0.0.1'::INET);
    v_user_agent := COALESCE(p_request->>'user_agent', 'Unknown');
    
    -- Validate parameters
    IF v_tenant_id IS NULL OR v_video_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Missing required parameters: tenantId, videoId',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Get hash keys
    SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h WHERE tenant_bk = v_tenant_id;
    IF v_user_id IS NOT NULL THEN
        SELECT user_hk INTO v_user_hk FROM auth.user_h WHERE user_bk = v_user_id AND tenant_hk = v_tenant_hk;
    END IF;
    v_media_file_hk := decode(v_video_id, 'hex');
    
    -- Get streaming URL
    SELECT * INTO v_stream_result
    FROM media.get_video_stream_url(v_tenant_hk, v_user_hk, v_media_file_hk, v_quality);
    
    IF v_stream_result.access_granted THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Stream URL generated successfully',
            'data', jsonb_build_object(
                'streamUrl', v_stream_result.stream_url,
                'expiresAt', v_stream_result.expires_at::TEXT,
                'availableQualities', v_stream_result.available_qualities,
                'selectedQuality', v_quality
            )
        );
    ELSE
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Access denied or video not ready for streaming',
            'error_code', 'ACCESS_DENIED',
            'data', jsonb_build_object(
                'videoId', v_video_id,
                'accessLevel', 'RESTRICTED'
            )
        );
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error generating stream URL',
        'error_code', 'STREAM_URL_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$$ LANGUAGE plpgsql;

-- Video List API
CREATE OR REPLACE FUNCTION api.video_list(
    p_request JSONB
) RETURNS JSONB AS $$
DECLARE
    v_tenant_id VARCHAR(255);
    v_user_id VARCHAR(255);
    v_page INTEGER;
    v_page_size INTEGER;
    v_sort_by VARCHAR(50);
    v_sort_direction VARCHAR(4);
    v_filter_type VARCHAR(50);
    v_search_term VARCHAR(255);
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_offset INTEGER;
    v_total_count INTEGER;
    v_videos JSONB;
BEGIN
    -- Extract parameters
    v_tenant_id := p_request->>'tenantId';
    v_user_id := p_request->>'userId';
    v_page := COALESCE((p_request->>'page')::INTEGER, 1);
    v_page_size := COALESCE((p_request->>'pageSize')::INTEGER, 20);
    v_sort_by := COALESCE(p_request->>'sortBy', 'upload_timestamp');
    v_sort_direction := COALESCE(p_request->>'sortDirection', 'DESC');
    v_filter_type := p_request->>'filterType';
    v_search_term := p_request->>'searchTerm';
    
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
    IF v_user_id IS NOT NULL THEN
        SELECT user_hk INTO v_user_hk FROM auth.user_h WHERE user_bk = v_user_id AND tenant_hk = v_tenant_hk;
    END IF;
    
    v_offset := (v_page - 1) * v_page_size;
    
    -- Get total count
    SELECT COUNT(*) INTO v_total_count
    FROM media.media_file_details_s mfd
    JOIN media.media_file_h mfh ON mfd.media_file_hk = mfh.media_file_hk
    WHERE mfh.tenant_hk = v_tenant_hk
    AND mfd.media_type = 'VIDEO'
    AND mfd.load_end_date IS NULL
    AND (v_filter_type IS NULL OR mfd.processing_status = v_filter_type)
    AND (v_search_term IS NULL OR mfd.original_filename ILIKE '%' || v_search_term || '%')
    AND (v_user_hk IS NULL OR mfd.access_level IN ('PUBLIC', 'TENANT') OR mfd.uploaded_by_user_hk = v_user_hk);
    
    -- Get videos
    SELECT jsonb_agg(
        jsonb_build_object(
            'videoId', encode(mfd.media_file_hk, 'hex'),
            'filename', mfd.original_filename,
            'fileSize', mfd.file_size_bytes,
            'duration', mfd.duration_seconds,
            'width', mfd.width_pixels,
            'height', mfd.height_pixels,
            'uploadTimestamp', mfd.upload_timestamp,
            'processingStatus', mfd.processing_status,
            'accessLevel', mfd.access_level,
            'description', mfd.description,
            'tags', mfd.user_tags,
            'thumbnailUrl', '/api/v1/media/thumbnail/' || encode(mfd.media_file_hk, 'hex')
        ) ORDER BY 
            CASE WHEN v_sort_by = 'upload_timestamp' AND v_sort_direction = 'DESC' THEN mfd.upload_timestamp END DESC,
            CASE WHEN v_sort_by = 'upload_timestamp' AND v_sort_direction = 'ASC' THEN mfd.upload_timestamp END ASC,
            CASE WHEN v_sort_by = 'filename' AND v_sort_direction = 'ASC' THEN mfd.original_filename END ASC,
            CASE WHEN v_sort_by = 'filename' AND v_sort_direction = 'DESC' THEN mfd.original_filename END DESC
    ) INTO v_videos
    FROM media.media_file_details_s mfd
    JOIN media.media_file_h mfh ON mfd.media_file_hk = mfh.media_file_hk
    WHERE mfh.tenant_hk = v_tenant_hk
    AND mfd.media_type = 'VIDEO'
    AND mfd.load_end_date IS NULL
    AND (v_filter_type IS NULL OR mfd.processing_status = v_filter_type)
    AND (v_search_term IS NULL OR mfd.original_filename ILIKE '%' || v_search_term || '%')
    AND (v_user_hk IS NULL OR mfd.access_level IN ('PUBLIC', 'TENANT') OR mfd.uploaded_by_user_hk = v_user_hk)
    LIMIT v_page_size OFFSET v_offset;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Videos retrieved successfully',
        'data', jsonb_build_object(
            'videos', COALESCE(v_videos, '[]'::JSONB),
            'pagination', jsonb_build_object(
                'page', v_page,
                'pageSize', v_page_size,
                'totalCount', v_total_count,
                'totalPages', CEIL(v_total_count::DECIMAL / v_page_size)
            ),
            'sorting', jsonb_build_object(
                'sortBy', v_sort_by,
                'sortDirection', v_sort_direction
            )
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error retrieving videos',
        'error_code', 'VIDEO_LIST_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$$ LANGUAGE plpgsql;

-- Video Analytics API
CREATE OR REPLACE FUNCTION api.video_analytics(
    p_request JSONB
) RETURNS JSONB AS $$
DECLARE
    v_tenant_id VARCHAR(255);
    v_date_from DATE;
    v_date_to DATE;
    v_tenant_hk BYTEA;
    v_analytics_result RECORD;
BEGIN
    -- Extract parameters
    v_tenant_id := p_request->>'tenantId';
    v_date_from := COALESCE((p_request->>'dateFrom')::DATE, CURRENT_DATE - INTERVAL '30 days');
    v_date_to := COALESCE((p_request->>'dateTo')::DATE, CURRENT_DATE);
    
    -- Validate parameters
    IF v_tenant_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Missing required parameter: tenantId',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Get tenant hash key
    SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h WHERE tenant_bk = v_tenant_id;
    
    -- Get analytics
    SELECT * INTO v_analytics_result
    FROM media.get_video_analytics(v_tenant_hk, v_date_from, v_date_to);
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Video analytics retrieved successfully',
        'data', jsonb_build_object(
            'totalVideos', v_analytics_result.total_videos,
            'totalStorageGb', v_analytics_result.total_storage_gb,
            'totalViews', v_analytics_result.total_views,
            'totalDownloads', v_analytics_result.total_downloads,
            'avgVideoDurationMinutes', v_analytics_result.avg_video_duration_minutes,
            'mostViewedVideo', v_analytics_result.most_viewed_video_filename,
            'dateRange', jsonb_build_object(
                'from', v_date_from::TEXT,
                'to', v_date_to::TEXT
            )
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error retrieving video analytics',
        'error_code', 'ANALYTICS_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$$ LANGUAGE plpgsql;

-- Video Delete API
CREATE OR REPLACE FUNCTION api.video_delete(
    p_request JSONB
) RETURNS JSONB AS $$
DECLARE
    v_tenant_id VARCHAR(255);
    v_user_id VARCHAR(255);
    v_video_id VARCHAR(255);
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_media_file_hk BYTEA;
    v_video_details RECORD;
    v_ip_address INET;
    v_user_agent TEXT;
BEGIN
    -- Extract parameters
    v_tenant_id := p_request->>'tenantId';
    v_user_id := p_request->>'userId';
    v_video_id := p_request->>'videoId';
    v_ip_address := COALESCE((p_request->>'ip_address')::INET, '127.0.0.1'::INET);
    v_user_agent := COALESCE(p_request->>'user_agent', 'Unknown');
    
    -- Validate parameters
    IF v_tenant_id IS NULL OR v_user_id IS NULL OR v_video_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Missing required parameters: tenantId, userId, videoId',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Get hash keys
    SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h WHERE tenant_bk = v_tenant_id;
    SELECT user_hk INTO v_user_hk FROM auth.user_h WHERE user_bk = v_user_id AND tenant_hk = v_tenant_hk;
    v_media_file_hk := decode(v_video_id, 'hex');
    
    -- Check if video exists and user has permission to delete
    SELECT 
        mfd.original_filename,
        mfd.uploaded_by_user_hk,
        mfd.access_level
    INTO v_video_details
    FROM media.media_file_details_s mfd
    JOIN media.media_file_h mfh ON mfd.media_file_hk = mfh.media_file_hk
    WHERE mfh.media_file_hk = v_media_file_hk
    AND mfh.tenant_hk = v_tenant_hk
    AND mfd.load_end_date IS NULL;
    
    IF v_video_details IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Video not found',
            'error_code', 'VIDEO_NOT_FOUND'
        );
    END IF;
    
    -- Check permissions (only uploader or admin can delete)
    IF v_video_details.uploaded_by_user_hk != v_user_hk THEN
        -- TODO: Add admin role check here
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Insufficient permissions to delete this video',
            'error_code', 'INSUFFICIENT_PERMISSIONS'
        );
    END IF;
    
    -- Soft delete by setting load_end_date
    UPDATE media.media_file_details_s 
    SET load_end_date = util.current_load_date()
    WHERE media_file_hk = v_media_file_hk 
    AND load_end_date IS NULL;
    
    -- Log deletion
    PERFORM audit.log_security_event(
        'VIDEO_DELETED',
        'MEDIUM',
        'Video deleted: ' || v_video_details.original_filename,
        v_ip_address,
        v_user_agent,
        v_user_hk,
        'MEDIUM',
        jsonb_build_object(
            'tenant_id', v_tenant_id,
            'user_id', v_user_id,
            'video_id', v_video_id,
            'filename', v_video_details.original_filename
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Video deleted successfully',
        'data', jsonb_build_object(
            'videoId', v_video_id,
            'filename', v_video_details.original_filename,
            'deletedAt', CURRENT_TIMESTAMP::TEXT
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error deleting video',
        'error_code', 'VIDEO_DELETE_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- API ENDPOINT DOCUMENTATION
-- =====================================================

COMMENT ON FUNCTION api.video_upload_initiate IS 
'POST /api/v1/videos/upload/initiate - Initiates video upload with validation and quota checking';

COMMENT ON FUNCTION api.video_upload_complete IS 
'POST /api/v1/videos/upload/complete - Completes video upload and starts processing';

COMMENT ON FUNCTION api.video_get_stream_url IS 
'GET /api/v1/videos/{videoId}/stream - Gets secure streaming URL for video playback';

COMMENT ON FUNCTION api.video_list IS 
'GET /api/v1/videos - Lists videos with pagination, filtering, and sorting';

COMMENT ON FUNCTION api.video_analytics IS 
'GET /api/v1/videos/analytics - Gets video analytics and usage statistics';

COMMENT ON FUNCTION api.video_delete IS 
'DELETE /api/v1/videos/{videoId} - Soft deletes a video with permission checking';

-- Commit transaction
COMMIT; 