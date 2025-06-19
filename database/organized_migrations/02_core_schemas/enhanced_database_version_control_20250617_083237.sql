-- =====================================================
-- ENHANCED DATABASE VERSION CONTROL SYSTEM
-- Git-like functionality for database schema management
-- =====================================================

-- Create schema for version control
CREATE SCHEMA IF NOT EXISTS version_control;

-- Migration tracking with full Git-like features
CREATE TABLE version_control.schema_migration_h (
    migration_hk BYTEA PRIMARY KEY,
    migration_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide migrations
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'DATABASE_MIGRATION'
);

CREATE TABLE version_control.schema_migration_s (
    migration_hk BYTEA NOT NULL REFERENCES version_control.schema_migration_h(migration_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Migration identification
    version_number VARCHAR(50) NOT NULL,           -- e.g., "2.1.5", "feature-ai-v1.0"
    migration_type VARCHAR(50) NOT NULL,           -- MAJOR, MINOR, PATCH, FEATURE, HOTFIX
    migration_name VARCHAR(255) NOT NULL,
    migration_description TEXT,
    
    -- Git-like features
    author_name VARCHAR(100) NOT NULL,
    author_email VARCHAR(255),
    commit_hash VARCHAR(64),                       -- Git commit hash if applicable
    branch_name VARCHAR(100),                      -- Git branch name
    tags TEXT[],                                   -- Version tags
    
    -- File tracking
    migration_files JSONB,                         -- Array of SQL files executed
    rollback_files JSONB,                          -- Array of rollback SQL files
    
    -- Execution tracking
    execution_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, RUNNING, COMPLETED, FAILED, ROLLED_BACK
    execution_start TIMESTAMP WITH TIME ZONE,
    execution_end TIMESTAMP WITH TIME ZONE,
    execution_duration_ms INTEGER,
    
    -- Dependencies and ordering
    depends_on VARCHAR(255)[],                     -- Other migrations this depends on
    migration_order INTEGER,                       -- Execution order
    
    -- Rollback information
    is_rollback_safe BOOLEAN DEFAULT true,
    rollback_strategy VARCHAR(50) DEFAULT 'SCRIPT', -- SCRIPT, SNAPSHOT, RECREATE
    rollback_notes TEXT,
    
    -- Environment tracking
    target_environments VARCHAR(50)[] DEFAULT ARRAY['development', 'staging', 'production'],
    deployed_environments JSONB DEFAULT '{}',     -- Track which environments this is deployed to
    
    -- Safety and validation
    requires_approval BOOLEAN DEFAULT false,
    approved_by VARCHAR(100),
    approval_date TIMESTAMP WITH TIME ZONE,
    validation_queries TEXT[],                     -- Queries to validate migration success
    
    record_source VARCHAR(100) NOT NULL DEFAULT 'DATABASE_MIGRATION',
    PRIMARY KEY (migration_hk, load_date)
);

-- Environment deployment tracking
CREATE TABLE version_control.environment_deployment_h (
    deployment_hk BYTEA PRIMARY KEY,
    deployment_bk VARCHAR(255) NOT NULL,
    migration_hk BYTEA NOT NULL REFERENCES version_control.schema_migration_h(migration_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'ENVIRONMENT_DEPLOYMENT'
);

CREATE TABLE version_control.environment_deployment_s (
    deployment_hk BYTEA NOT NULL REFERENCES version_control.environment_deployment_h(deployment_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    environment_name VARCHAR(50) NOT NULL,         -- development, staging, production
    deployment_method VARCHAR(50) DEFAULT 'MANUAL', -- MANUAL, CI_CD, AUTOMATED
    deployment_status VARCHAR(20) DEFAULT 'PENDING',
    
    -- Pre-deployment validation
    pre_checks_passed BOOLEAN DEFAULT false,
    pre_check_results JSONB,
    
    -- Deployment execution
    deployed_by VARCHAR(100) NOT NULL,
    deployment_start TIMESTAMP WITH TIME ZONE,
    deployment_end TIMESTAMP WITH TIME ZONE,
    deployment_log TEXT,
    
    -- Post-deployment validation
    post_checks_passed BOOLEAN DEFAULT false,
    post_check_results JSONB,
    performance_impact_assessment JSONB,
    
    -- Rollback capability
    rollback_available BOOLEAN DEFAULT true,
    rollback_tested BOOLEAN DEFAULT false,
    
    record_source VARCHAR(100) NOT NULL DEFAULT 'ENVIRONMENT_DEPLOYMENT',
    PRIMARY KEY (deployment_hk, load_date)
);

-- Schema diff tracking (like git diff)
CREATE TABLE version_control.schema_diff_h (
    diff_hk BYTEA PRIMARY KEY,
    diff_bk VARCHAR(255) NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'SCHEMA_DIFF'
);

CREATE TABLE version_control.schema_diff_s (
    diff_hk BYTEA NOT NULL REFERENCES version_control.schema_diff_h(diff_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    from_version VARCHAR(50),
    to_version VARCHAR(50),
    diff_type VARCHAR(50) NOT NULL,               -- TABLE_ADDED, COLUMN_MODIFIED, INDEX_DROPPED, etc.
    
    schema_name VARCHAR(63),
    object_name VARCHAR(255),
    object_type VARCHAR(50),                      -- TABLE, FUNCTION, INDEX, CONSTRAINT, etc.
    
    change_description TEXT,
    sql_statement TEXT,                           -- SQL to make this change
    reverse_sql_statement TEXT,                   -- SQL to undo this change
    
    impact_assessment VARCHAR(50),                -- LOW, MEDIUM, HIGH, BREAKING
    affects_data BOOLEAN DEFAULT false,
    requires_downtime BOOLEAN DEFAULT false,
    
    record_source VARCHAR(100) NOT NULL DEFAULT 'SCHEMA_DIFF',
    PRIMARY KEY (diff_hk, load_date)
);

-- =====================================================
-- VERSION CONTROL FUNCTIONS
-- =====================================================

-- Create a new migration
CREATE OR REPLACE FUNCTION version_control.create_migration(
    p_version_number VARCHAR(50),
    p_migration_type VARCHAR(50),
    p_migration_name VARCHAR(255),
    p_migration_description TEXT,
    p_author_name VARCHAR(100),
    p_author_email VARCHAR(255) DEFAULT NULL,
    p_migration_files JSONB DEFAULT NULL,
    p_rollback_files JSONB DEFAULT NULL,
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_migration_hk BYTEA;
    v_migration_bk VARCHAR(255);
BEGIN
    v_migration_bk := 'MIGRATION_' || p_version_number || '_' || 
                      regexp_replace(p_migration_name, '[^a-zA-Z0-9_]', '_', 'g');
    v_migration_hk := util.hash_binary(v_migration_bk);
    
    -- Insert hub record
    INSERT INTO version_control.schema_migration_h VALUES (
        v_migration_hk, v_migration_bk, p_tenant_hk,
        util.current_load_date(), 'DATABASE_MIGRATION'
    );
    
    -- Insert satellite record
    INSERT INTO version_control.schema_migration_s VALUES (
        v_migration_hk, util.current_load_date(), NULL,
        util.hash_binary(v_migration_bk || p_version_number || p_migration_type),
        p_version_number, p_migration_type, p_migration_name, p_migration_description,
        p_author_name, p_author_email, NULL, NULL, ARRAY[]::TEXT[],
        p_migration_files, p_rollback_files,
        'PENDING', NULL, NULL, NULL,
        ARRAY[]::VARCHAR(255)[], 
        (SELECT COALESCE(MAX(migration_order), 0) + 1 FROM version_control.schema_migration_s WHERE load_end_date IS NULL),
        true, 'SCRIPT', NULL,
        ARRAY['development', 'staging', 'production'], '{}',
        false, NULL, NULL, ARRAY[]::TEXT[],
        'DATABASE_MIGRATION'
    );
    
    RETURN v_migration_hk;
END;
$$ LANGUAGE plpgsql;

-- Get migration status (like git status)
CREATE OR REPLACE FUNCTION version_control.get_migration_status(
    p_environment VARCHAR(50) DEFAULT 'development'
) RETURNS TABLE (
    version_number VARCHAR(50),
    migration_name VARCHAR(255),
    execution_status VARCHAR(20),
    deployed_in_env BOOLEAN,
    execution_date TIMESTAMP WITH TIME ZONE,
    author_name VARCHAR(100),
    migration_type VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sms.version_number,
        sms.migration_name,
        sms.execution_status,
        (sms.deployed_environments->>p_environment)::BOOLEAN AS deployed_in_env,
        sms.execution_end,
        sms.author_name,
        sms.migration_type
    FROM version_control.schema_migration_s sms
    WHERE sms.load_end_date IS NULL
    ORDER BY sms.migration_order;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VIEWS FOR EASY QUERYING
-- =====================================================

-- Current migration status view
CREATE OR REPLACE VIEW version_control.migration_dashboard AS
SELECT 
    sm.migration_bk,
    sms.version_number,
    sms.migration_name,
    sms.migration_type,
    sms.execution_status,
    sms.author_name,
    sms.execution_start,
    sms.execution_end,
    sms.execution_duration_ms,
    sms.deployed_environments,
    sms.is_rollback_safe
FROM version_control.schema_migration_h sm
JOIN version_control.schema_migration_s sms ON sm.migration_hk = sms.migration_hk
WHERE sms.load_end_date IS NULL
ORDER BY sms.migration_order;

-- Log this deployment
SELECT util.log_deployment_start(
    'Enhanced Database Version Control System',
    'Git-like version control for database schema management with full audit trails and environment tracking'
);

RAISE NOTICE '✅ Enhanced Database Version Control System deployed successfully!';
RAISE NOTICE '📊 Use these views to monitor migrations:';
RAISE NOTICE '   - version_control.migration_dashboard';
RAISE NOTICE '🔧 Use these functions to manage migrations:';
RAISE NOTICE '   - version_control.create_migration()';
RAISE NOTICE '   - version_control.get_migration_status()'; 