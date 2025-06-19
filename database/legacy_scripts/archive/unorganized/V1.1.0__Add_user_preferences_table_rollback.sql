-- Rollback: Add user preferences table
-- Version: 1.1.0
-- Created: 2025-06-16T20:55:01.151189

-- Add rollback commands below
-- DROP TABLE IF EXISTS business.new_feature_h CASCADE;

-- Log rollback
SELECT util.log_deployment_start(
    'ROLLBACK: Add user preferences table (v1.1.0)',
    'Rolling back: '
);
