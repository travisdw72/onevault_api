-- =====================================================
-- ROLLBACK: SITE TRACKING AUTOMATION LAYER
-- =====================================================
-- Purpose: Remove all automation layer components
-- Use: When pg_cron is not available or automation needs to be removed
-- =====================================================

-- Remove scheduled jobs (if pg_cron was working)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.unschedule('site-tracking-pipeline');
        RAISE NOTICE '✅ Removed scheduled job: site-tracking-pipeline';
    ELSE
        RAISE NOTICE 'ℹ️ pg_cron not installed, no scheduled jobs to remove';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ℹ️ No scheduled jobs found to remove';
END $$;

-- Drop automation management functions
DROP FUNCTION IF EXISTS staging.resume_pipeline_automation();
DROP FUNCTION IF EXISTS staging.pause_pipeline_automation();
DROP FUNCTION IF EXISTS staging.trigger_pipeline_now();
DROP FUNCTION IF EXISTS staging.get_pipeline_status();

-- Drop the main combined pipeline function
DROP FUNCTION IF EXISTS staging.process_complete_pipeline();

-- Success message
SELECT 
    '🔄 AUTOMATION LAYER ROLLBACK COMPLETE' as status,
    'All automation functions removed' as message,
    'Manual processing still available via:' as note1,
    '  - staging.process_site_tracking_events()' as note2,
    '  - staging.process_staging_to_business()' as note3; 