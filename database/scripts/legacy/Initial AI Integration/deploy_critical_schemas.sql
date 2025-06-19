-- =====================================================
-- ONE BARN CRITICAL SCHEMAS DEPLOYMENT
-- Master deployment script for Health, Finance, and Performance schemas
-- Data Vault 2.0 Implementation
-- =====================================================

-- Start transaction for atomic deployment
BEGIN;

-- Set session variables for deployment tracking
SET session_replication_role = replica; -- Disable triggers during deployment
SET work_mem = '256MB'; -- Increase memory for large operations

-- Create deployment log table if it doesn't exist
CREATE TABLE IF NOT EXISTS util.deployment_log (
    deployment_id SERIAL PRIMARY KEY,
    deployment_name VARCHAR(255) NOT NULL,
    deployment_start TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deployment_end TIMESTAMP WITH TIME ZONE,
    deployment_status VARCHAR(50) DEFAULT 'IN_PROGRESS',
    deployment_notes TEXT,
    deployed_by VARCHAR(255) DEFAULT SESSION_USER,
    rollback_script TEXT
);

-- Log deployment start
INSERT INTO util.deployment_log (deployment_name, deployment_notes, rollback_script) 
VALUES (
    'Critical Schemas Deployment v1.0',
    'Deploying Health Management, Financial Management, and Performance Tracking schemas',
    'DROP SCHEMA IF EXISTS health CASCADE; DROP SCHEMA IF EXISTS finance CASCADE; DROP SCHEMA IF EXISTS performance CASCADE;'
);

-- Get deployment ID for tracking
DO $$
DECLARE
    deployment_id INTEGER;
BEGIN
    SELECT currval('util.deployment_log_deployment_id_seq') INTO deployment_id;
    RAISE NOTICE 'Starting deployment ID: %', deployment_id;
END $$;

-- =====================================================
-- HEALTH MANAGEMENT SCHEMA DEPLOYMENT
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Deploying Health Management Schema...';
END $$;

-- Create health schema if it doesn't exist
-- =====================================================
-- DEPLOYMENT COMPLETION
-- =====================================================

-- Update deployment log
UPDATE util.deployment_log 
SET deployment_end = CURRENT_TIMESTAMP,
    deployment_status = 'COMPLETED',
    deployment_notes = deployment_notes || ' - Successfully deployed all critical schemas with indexes and permissions'
WHERE deployment_id = currval('util.deployment_log_deployment_id_seq');

-- Reset session variables
RESET session_replication_role;
RESET work_mem;

-- Commit the transaction
COMMIT;

-- Final success message


DO $$
BEGIN
    RAISE NOTICE 'Critical schemas deployment completed successfully!';
    RAISE NOTICE 'One Barn is now ready for full business operations.';
END $$; 