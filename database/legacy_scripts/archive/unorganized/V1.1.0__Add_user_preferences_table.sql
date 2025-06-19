-- Migration: Add user preferences table
-- Version: 1.1.0
-- Created: 2025-06-16T20:55:01.151189
-- Description: 

-- =============================================================================
-- FORWARD MIGRATION
-- =============================================================================

-- Add your database changes below
-- Follow Data Vault 2.0 standards:
-- - Include tenant_hk for isolation
-- - Use proper naming conventions (_h, _s, _l)
-- - Include load_date and record_source

-- Example:
-- CREATE TABLE business.new_feature_h (
--     new_feature_hk BYTEA PRIMARY KEY,
--     new_feature_bk VARCHAR(255) NOT NULL,
--     tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
--     load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
--     record_source VARCHAR(100) NOT NULL
-- );

-- Log deployment
SELECT util.log_deployment_start(
    'Add user preferences table (v1.1.0)',
    ''
);
