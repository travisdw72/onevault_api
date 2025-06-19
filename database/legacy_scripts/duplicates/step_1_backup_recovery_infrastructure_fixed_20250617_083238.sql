-- =====================================================================================
-- Script: step_1_backup_recovery_infrastructure_fixed.sql
-- Description: Backup & Recovery Infrastructure Implementation - Phase 1 (FIXED ROLES)
-- Version: 1.1
-- Date: 2024-12-19
-- Author: One Vault Development Team
-- 
-- Purpose: Implement comprehensive backup and recovery capabilities with automated 
--          scheduling, verification, and point-in-time recovery for production readiness
-- Fixed: Updated role references to match existing database roles
-- =====================================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================================================
-- BACKUP MANAGEMENT SCHEMA
-- =====================================================================================

-- Create backup management schema
CREATE SCHEMA IF NOT EXISTS backup_mgmt;

-- Set schema comment
COMMENT ON SCHEMA backup_mgmt IS 
'Backup and recovery management infrastructure for Data Vault 2.0 platform with automated scheduling, verification, and compliance tracking';

-- =====================================================================================
-- HUB TABLES
-- =====================================================================================

-- Backup execution hub - stores unique backup instances
CREATE TABLE backup_mgmt.backup_execution_h (
    backup_hk BYTEA PRIMARY KEY,
    backup_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide backups
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Constraints and indexes
    CONSTRAINT chk_backup_execution_h_backup_hk_not_null CHECK (backup_hk IS NOT NULL),
    CONSTRAINT chk_backup_execution_h_backup_bk_format CHECK (backup_bk ~ '^[A-Z_0-9]+_\d{8}_\d{6}$')
);

-- Recovery operation hub - stores unique recovery instances  
CREATE TABLE backup_mgmt.recovery_operation_h (
    recovery_hk BYTEA PRIMARY KEY,
    recovery_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Constraints
    CONSTRAINT chk_recovery_operation_h_recovery_hk_not_null CHECK (recovery_hk IS NOT NULL),
    CONSTRAINT chk_recovery_operation_h_recovery_bk_format CHECK (recovery_bk ~ '^RECOVERY_[A-Z_0-9]+_\d{8}_\d{6}$')
);

-- Backup schedule hub - stores backup scheduling configurations
CREATE TABLE backup_mgmt.backup_schedule_h (
    schedule_hk BYTEA PRIMARY KEY,
    schedule_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Constraints
    CONSTRAINT chk_backup_schedule_h_schedule_hk_not_null CHECK (schedule_hk IS NOT NULL)
);

-- =====================================================================================
-- SATELLITE TABLES
-- =====================================================================================

-- Backup execution satellite - stores backup execution details and status
CREATE TABLE backup_mgmt.backup_execution_s (
    backup_hk BYTEA NOT NULL REFERENCES backup_mgmt.backup_execution_h(backup_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Backup configuration
    backup_type VARCHAR(50) NOT NULL CHECK (backup_type IN ('FULL', 'INCREMENTAL', 'DIFFERENTIAL', 'PITR', 'LOGICAL')),
    backup_scope VARCHAR(50) NOT NULL CHECK (backup_scope IN ('SYSTEM', 'TENANT', 'SCHEMA', 'TABLE')),
    backup_method VARCHAR(50) NOT NULL DEFAULT 'PG_BASEBACKUP' CHECK (backup_method IN ('PG_BASEBACKUP', 'PG_DUMP', 'CUSTOM', 'WAL_ARCHIVE')),
    
    -- Execution timing
    backup_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    backup_end_time TIMESTAMP WITH TIME ZONE,
    backup_duration_seconds INTEGER,
    
    -- Status and results
    backup_status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (backup_status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED', 'PARTIAL')),
    backup_size_bytes BIGINT,
    compressed_size_bytes BIGINT,
    compression_ratio DECIMAL(5,2),
    
    -- Storage and location
    backup_location TEXT NOT NULL,
    backup_filename VARCHAR(500),
    storage_type VARCHAR(50) DEFAULT 'LOCAL' CHECK (storage_type IN ('LOCAL', 'S3', 'GCS', 'AZURE', 'NFS')),
    
    -- Retention and compliance
    retention_period INTERVAL NOT NULL DEFAULT '7 years', -- IRS/HIPAA compliance
    retention_policy VARCHAR(100) DEFAULT 'STANDARD_7_YEAR',
    expiration_date DATE,
    
    -- Verification and integrity
    verification_status VARCHAR(20) DEFAULT 'PENDING' CHECK (verification_status IN ('PENDING', 'VERIFIED', 'FAILED', 'SKIPPED')),
    verification_date TIMESTAMP WITH TIME ZONE,
    checksum_algorithm VARCHAR(20) DEFAULT 'SHA256',
    checksum_value VARCHAR(128),
    integrity_verified BOOLEAN DEFAULT false,
    
    -- Recovery testing
    recovery_tested BOOLEAN DEFAULT false,
    recovery_test_date TIMESTAMP WITH TIME ZONE,
    recovery_test_success BOOLEAN,
    
    -- Error handling
    error_message TEXT,
    error_code VARCHAR(50),
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    
    -- Metadata
    initiated_by VARCHAR(100) DEFAULT SESSION_USER,
    backup_priority INTEGER DEFAULT 5 CHECK (backup_priority BETWEEN 1 AND 10),
    tags JSONB,
    additional_metadata JSONB,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Primary key and constraints
    PRIMARY KEY (backup_hk, load_date),
    CONSTRAINT chk_backup_execution_s_end_after_start CHECK (backup_end_time IS NULL OR backup_end_time >= backup_start_time),
    CONSTRAINT chk_backup_execution_s_size_positive CHECK (backup_size_bytes IS NULL OR backup_size_bytes >= 0),
    CONSTRAINT chk_backup_execution_s_compression_valid CHECK (compression_ratio IS NULL OR (compression_ratio >= 0 AND compression_ratio <= 100))
);

-- Recovery operation satellite - stores recovery operation details
CREATE TABLE backup_mgmt.recovery_operation_s (
    recovery_hk BYTEA NOT NULL REFERENCES backup_mgmt.recovery_operation_h(recovery_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Recovery configuration
    recovery_type VARCHAR(50) NOT NULL CHECK (recovery_type IN ('FULL_RESTORE', 'POINT_IN_TIME', 'PARTIAL_RESTORE', 'TABLE_RESTORE')),
    source_backup_hk BYTEA REFERENCES backup_mgmt.backup_execution_h(backup_hk),
    target_point_in_time TIMESTAMP WITH TIME ZONE,
    recovery_target VARCHAR(100), -- Database, schema, or table name
    
    -- Execution details
    recovery_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    recovery_end_time TIMESTAMP WITH TIME ZONE,
    recovery_duration_seconds INTEGER,
    recovery_status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (recovery_status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    
    -- Validation
    validation_performed BOOLEAN DEFAULT false,
    validation_status VARCHAR(20) CHECK (validation_status IN ('PASSED', 'FAILED', 'PARTIAL')),
    data_integrity_verified BOOLEAN DEFAULT false,
    
    -- Results
    records_recovered BIGINT,
    data_size_recovered BIGINT,
    recovery_success_rate DECIMAL(5,2),
    
    -- Error handling
    error_message TEXT,
    error_code VARCHAR(50),
    
    -- Metadata
    initiated_by VARCHAR(100) DEFAULT SESSION_USER,
    recovery_reason TEXT,
    approval_required BOOLEAN DEFAULT true,
    approved_by VARCHAR(100),
    approval_date TIMESTAMP WITH TIME ZONE,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (recovery_hk, load_date),
    CONSTRAINT chk_recovery_operation_s_end_after_start CHECK (recovery_end_time IS NULL OR recovery_end_time >= recovery_start_time)
);

-- Backup schedule satellite - stores scheduling configuration
CREATE TABLE backup_mgmt.backup_schedule_s (
    schedule_hk BYTEA NOT NULL REFERENCES backup_mgmt.backup_schedule_h(schedule_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Schedule configuration
    schedule_name VARCHAR(200) NOT NULL,
    backup_type VARCHAR(50) NOT NULL CHECK (backup_type IN ('FULL', 'INCREMENTAL', 'DIFFERENTIAL')),
    schedule_expression VARCHAR(100) NOT NULL, -- Cron expression
    timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- Execution windows
    execution_window_start TIME,
    execution_window_end TIME,
    max_execution_duration INTERVAL DEFAULT '4 hours',
    
    -- Schedule status
    is_active BOOLEAN DEFAULT true,
    next_execution_time TIMESTAMP WITH TIME ZONE,
    last_execution_time TIMESTAMP WITH TIME ZONE,
    execution_count INTEGER DEFAULT 0,
    
    -- Retention policy
    retention_period INTERVAL NOT NULL DEFAULT '7 years',
    max_backup_count INTEGER DEFAULT 30, -- Rolling count for incremental backups
    
    -- Notification settings
    notify_on_success BOOLEAN DEFAULT false,
    notify_on_failure BOOLEAN DEFAULT true,
    notification_recipients TEXT[],
    
    -- Priority and resources
    backup_priority INTEGER DEFAULT 5 CHECK (backup_priority BETWEEN 1 AND 10),
    resource_constraints JSONB, -- CPU/memory limits during backup
    
    -- Metadata
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    schedule_description TEXT,
    tags JSONB,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    PRIMARY KEY (schedule_hk, load_date),
    CONSTRAINT chk_backup_schedule_s_window_valid CHECK (
        execution_window_start IS NULL OR execution_window_end IS NULL OR 
        execution_window_end > execution_window_start
    )
);

-- =====================================================================================
-- LINK TABLES
-- =====================================================================================

-- Backup dependency link - tracks backup dependencies and relationships
CREATE TABLE backup_mgmt.backup_dependency_l (
    link_backup_dependency_hk BYTEA PRIMARY KEY,
    source_backup_hk BYTEA NOT NULL REFERENCES backup_mgmt.backup_execution_h(backup_hk),
    dependent_backup_hk BYTEA NOT NULL REFERENCES backup_mgmt.backup_execution_h(backup_hk),
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Ensure no self-dependencies
    CONSTRAINT chk_no_self_dependency CHECK (source_backup_hk != dependent_backup_hk)
);

-- Schedule execution link - links schedules to their executions
CREATE TABLE backup_mgmt.schedule_execution_l (
    link_schedule_execution_hk BYTEA PRIMARY KEY,
    schedule_hk BYTEA NOT NULL REFERENCES backup_mgmt.backup_schedule_h(schedule_hk),
    backup_hk BYTEA NOT NULL REFERENCES backup_mgmt.backup_execution_h(backup_hk),
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Recovery backup link - links recovery operations to source backups
CREATE TABLE backup_mgmt.recovery_backup_l (
    link_recovery_backup_hk BYTEA PRIMARY KEY,
    recovery_hk BYTEA NOT NULL REFERENCES backup_mgmt.recovery_operation_h(recovery_hk),
    backup_hk BYTEA NOT NULL REFERENCES backup_mgmt.backup_execution_h(backup_hk),
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- =====================================================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================================================

-- Hub table indexes
CREATE INDEX idx_backup_execution_h_tenant_hk ON backup_mgmt.backup_execution_h(tenant_hk);
CREATE INDEX idx_backup_execution_h_load_date ON backup_mgmt.backup_execution_h(load_date);

CREATE INDEX idx_recovery_operation_h_tenant_hk ON backup_mgmt.recovery_operation_h(tenant_hk);
CREATE INDEX idx_recovery_operation_h_load_date ON backup_mgmt.recovery_operation_h(load_date);

CREATE INDEX idx_backup_schedule_h_tenant_hk ON backup_mgmt.backup_schedule_h(tenant_hk);

-- Satellite table indexes
CREATE INDEX idx_backup_execution_s_status ON backup_mgmt.backup_execution_s(backup_status) WHERE load_end_date IS NULL;
CREATE INDEX idx_backup_execution_s_start_time ON backup_mgmt.backup_execution_s(backup_start_time) WHERE load_end_date IS NULL;
CREATE INDEX idx_backup_execution_s_type_scope ON backup_mgmt.backup_execution_s(backup_type, backup_scope) WHERE load_end_date IS NULL;
CREATE INDEX idx_backup_execution_s_expiration ON backup_mgmt.backup_execution_s(expiration_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_backup_execution_s_verification ON backup_mgmt.backup_execution_s(verification_status) WHERE load_end_date IS NULL;

CREATE INDEX idx_recovery_operation_s_status ON backup_mgmt.recovery_operation_s(recovery_status) WHERE load_end_date IS NULL;
CREATE INDEX idx_recovery_operation_s_start_time ON backup_mgmt.recovery_operation_s(recovery_start_time) WHERE load_end_date IS NULL;

CREATE INDEX idx_backup_schedule_s_active ON backup_mgmt.backup_schedule_s(is_active) WHERE load_end_date IS NULL;
CREATE INDEX idx_backup_schedule_s_next_execution ON backup_mgmt.backup_schedule_s(next_execution_time) WHERE load_end_date IS NULL AND is_active = true;

-- Link table indexes
CREATE INDEX idx_backup_dependency_l_source ON backup_mgmt.backup_dependency_l(source_backup_hk);
CREATE INDEX idx_backup_dependency_l_dependent ON backup_mgmt.backup_dependency_l(dependent_backup_hk);
CREATE INDEX idx_schedule_execution_l_schedule ON backup_mgmt.schedule_execution_l(schedule_hk);
CREATE INDEX idx_schedule_execution_l_backup ON backup_mgmt.schedule_execution_l(backup_hk);
CREATE INDEX idx_recovery_backup_l_recovery ON backup_mgmt.recovery_backup_l(recovery_hk);
CREATE INDEX idx_recovery_backup_l_backup ON backup_mgmt.recovery_backup_l(backup_hk);

-- =====================================================================================
-- TABLE COMMENTS
-- =====================================================================================

COMMENT ON TABLE backup_mgmt.backup_execution_h IS 'Hub table storing unique backup execution instances with tenant isolation for Data Vault 2.0 platform';
COMMENT ON TABLE backup_mgmt.backup_execution_s IS 'Satellite table storing detailed backup execution information including status, verification, and compliance metadata';
COMMENT ON TABLE backup_mgmt.recovery_operation_h IS 'Hub table storing unique recovery operation instances';
COMMENT ON TABLE backup_mgmt.recovery_operation_s IS 'Satellite table storing detailed recovery operation information and validation results';
COMMENT ON TABLE backup_mgmt.backup_schedule_h IS 'Hub table storing unique backup schedule configurations';
COMMENT ON TABLE backup_mgmt.backup_schedule_s IS 'Satellite table storing backup scheduling configuration and execution tracking';
COMMENT ON TABLE backup_mgmt.backup_dependency_l IS 'Link table tracking dependencies between backup operations';
COMMENT ON TABLE backup_mgmt.schedule_execution_l IS 'Link table connecting backup schedules to their executions';
COMMENT ON TABLE backup_mgmt.recovery_backup_l IS 'Link table connecting recovery operations to their source backups';

-- =====================================================================================
-- COLUMN COMMENTS  
-- =====================================================================================

-- Backup execution satellite key columns
COMMENT ON COLUMN backup_mgmt.backup_execution_s.backup_type IS 'Type of backup: FULL (complete database), INCREMENTAL (changes since last backup), DIFFERENTIAL (changes since last full), PITR (point-in-time), LOGICAL (pg_dump)';
COMMENT ON COLUMN backup_mgmt.backup_execution_s.backup_scope IS 'Scope of backup: SYSTEM (entire database cluster), TENANT (single tenant data), SCHEMA (specific schema), TABLE (specific table)';
COMMENT ON COLUMN backup_mgmt.backup_execution_s.retention_period IS 'Data retention period for compliance (default 7 years for IRS/HIPAA requirements)';
COMMENT ON COLUMN backup_mgmt.backup_execution_s.verification_status IS 'Status of backup verification: PENDING (not yet verified), VERIFIED (integrity confirmed), FAILED (verification failed), SKIPPED (verification bypassed)';
COMMENT ON COLUMN backup_mgmt.backup_execution_s.checksum_algorithm IS 'Algorithm used for backup integrity verification (SHA256 default for security)';
COMMENT ON COLUMN backup_mgmt.backup_execution_s.recovery_tested IS 'Indicates whether recovery from this backup has been tested';

-- Recovery operation satellite key columns  
COMMENT ON COLUMN backup_mgmt.recovery_operation_s.recovery_type IS 'Type of recovery: FULL_RESTORE (complete restoration), POINT_IN_TIME (restore to specific timestamp), PARTIAL_RESTORE (subset of data), TABLE_RESTORE (specific table only)';
COMMENT ON COLUMN backup_mgmt.recovery_operation_s.target_point_in_time IS 'Specific timestamp for point-in-time recovery operations';
COMMENT ON COLUMN backup_mgmt.recovery_operation_s.data_integrity_verified IS 'Indicates whether recovered data integrity has been verified';
COMMENT ON COLUMN backup_mgmt.recovery_operation_s.approval_required IS 'Indicates whether recovery operation requires management approval';

-- Schedule satellite key columns
COMMENT ON COLUMN backup_mgmt.backup_schedule_s.schedule_expression IS 'Cron expression defining backup schedule frequency and timing';
COMMENT ON COLUMN backup_mgmt.backup_schedule_s.execution_window_start IS 'Start time of allowed execution window for backup operations';
COMMENT ON COLUMN backup_mgmt.backup_schedule_s.execution_window_end IS 'End time of allowed execution window for backup operations';
COMMENT ON COLUMN backup_mgmt.backup_schedule_s.max_backup_count IS 'Maximum number of backups to retain for rolling backup strategy';

-- =====================================================================================
-- SECURITY AND PERMISSIONS (FIXED FOR EXISTING ROLES)
-- =====================================================================================

-- Grant schema usage to existing application roles
GRANT USAGE ON SCHEMA backup_mgmt TO authenticated_users;  -- FIXED: plural form that exists
GRANT USAGE ON SCHEMA backup_mgmt TO dv_admin;           -- FIXED: use existing dv_admin role
GRANT USAGE ON SCHEMA backup_mgmt TO app_user;           -- Use existing app_user role

-- Grant table permissions for backup operations
GRANT SELECT ON ALL TABLES IN SCHEMA backup_mgmt TO authenticated_users;
GRANT SELECT ON ALL TABLES IN SCHEMA backup_mgmt TO dv_reader;  -- Use existing read role
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA backup_mgmt TO dv_admin;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA backup_mgmt TO dv_loader; -- Use existing loader role

-- Grant sequence permissions (if any are created later)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA backup_mgmt TO dv_admin;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA backup_mgmt TO dv_loader;

-- Row Level Security policies will be implemented in separate security script

-- =====================================================================================
-- COMPLETION MESSAGE
-- =====================================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Backup & Recovery Infrastructure Schema - Phase 1 completed successfully (ROLE FIXED)';
    RAISE NOTICE '📊 Tables created: 9 (3 hubs, 3 satellites, 3 links)';
    RAISE NOTICE '🔍 Indexes created: 15 performance and constraint indexes';
    RAISE NOTICE '🔐 Security: Permissions granted to existing roles (authenticated_users, dv_admin, dv_reader, dv_loader, app_user)';
    RAISE NOTICE '📝 Next Steps: Deploy backup procedures and functions (step_2)';
    RAISE NOTICE '🎯 Roles Fixed: Updated to use existing database roles instead of non-existent authenticated_user';
END $$; 