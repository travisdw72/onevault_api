-- Data Vault 2.0 Database Creation Script - Part 2
-- Following naming conventions from Naming_Conventions.md
-- This script creates the core tables for tenant management and authentication

-- =============================================
-- 1. Core Tenant Tables
-- =============================================

-- Hub table for tenants
CREATE TABLE auth.tenant_h (
    tenant_hk BYTEA PRIMARY KEY,
    tenant_bk VARCHAR(255) NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Satellite table for tenant details
CREATE TABLE auth.tenant_profile_s (
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    tenant_name VARCHAR(100) NOT NULL,
    tenant_description VARCHAR(500),
    domain_name VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    subscription_level VARCHAR(50) DEFAULT 'standard',
    subscription_start_date TIMESTAMP WITH TIME ZONE,
    subscription_end_date TIMESTAMP WITH TIME ZONE,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    max_users INTEGER DEFAULT 10,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (tenant_hk, load_date)
);

-- =============================================
-- 2. User Authentication Tables
-- =============================================

-- Hub table for users
CREATE TABLE auth.user_h (
    user_hk BYTEA PRIMARY KEY,
    user_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Satellite table for user details
CREATE TABLE auth.user_profile_s (
    user_hk BYTEA NOT NULL REFERENCES auth.user_h(user_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    job_title VARCHAR(100),
    department VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    last_updated_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (user_hk, load_date)
);

-- Satellite table for authentication data
CREATE TABLE auth.user_auth_s (
    user_hk BYTEA NOT NULL REFERENCES auth.user_h(user_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    username VARCHAR(100) NOT NULL,
    password_hash BYTEA NOT NULL,
    password_salt BYTEA NOT NULL,
    last_login_date TIMESTAMP WITH TIME ZONE,
    password_last_changed TIMESTAMP WITH TIME ZONE,
    failed_login_attempts INTEGER DEFAULT 0,
    account_locked BOOLEAN DEFAULT false,
    account_locked_until TIMESTAMP WITH TIME ZONE,
    password_reset_token VARCHAR(255),
    password_reset_expiry TIMESTAMP WITH TIME ZONE,
    must_change_password BOOLEAN DEFAULT false,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (user_hk, load_date)
);

-- Create unique index on username within user context
-- Note: user_hk already provides tenant isolation in Data Vault 2.0
CREATE UNIQUE INDEX idx_user_auth_username_unique ON auth.user_auth_s (
    user_hk,
    username
) WHERE load_end_date IS NULL;

-- Index for efficient username lookups during authentication
CREATE INDEX idx_user_auth_username ON auth.user_auth_s (username) 
WHERE load_end_date IS NULL;

-- =============================================
-- 3. Role Management Tables
-- =============================================

-- Hub table for roles
CREATE TABLE auth.role_h (
    role_hk BYTEA PRIMARY KEY,
    role_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Satellite table for role details
CREATE TABLE auth.role_definition_s (
    role_hk BYTEA NOT NULL REFERENCES auth.role_h(role_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    role_name VARCHAR(100) NOT NULL,
    role_description VARCHAR(500),
    is_system_role BOOLEAN DEFAULT false,
    permissions JSONB NOT NULL,
    created_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    last_updated_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (role_hk, load_date)
);

-- Link table for user-role assignments
CREATE TABLE auth.user_role_l (
    link_user_role_hk BYTEA PRIMARY KEY,
    user_hk BYTEA NOT NULL REFERENCES auth.user_h(user_hk),
    role_hk BYTEA NOT NULL REFERENCES auth.role_h(role_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Create index for faster role lookups by user
CREATE INDEX idx_user_role_l_user_hk ON auth.user_role_l(user_hk);

-- =============================================
-- 4. Session Management Tables
-- =============================================

-- Hub table for sessions
CREATE TABLE auth.session_h (
    session_hk BYTEA PRIMARY KEY,
    session_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Satellite table for session details
CREATE TABLE auth.session_state_s (
    session_hk BYTEA NOT NULL REFERENCES auth.session_h(session_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    session_start TIMESTAMP WITH TIME ZONE NOT NULL,
    session_end TIMESTAMP WITH TIME ZONE,
    ip_address INET NOT NULL,
    user_agent TEXT,
    session_data JSONB,
    session_status VARCHAR(20) NOT NULL,
    last_activity TIMESTAMP WITH TIME ZONE NOT NULL,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (session_hk, load_date)
);

-- Link table for user-session relationships
CREATE TABLE auth.user_session_l (
    link_user_session_hk BYTEA PRIMARY KEY,
    user_hk BYTEA NOT NULL REFERENCES auth.user_h(user_hk),
    session_hk BYTEA NOT NULL REFERENCES auth.session_h(session_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Create indexes for session management
CREATE INDEX idx_session_state_s_status ON auth.session_state_s(session_status);
CREATE INDEX idx_session_state_s_last_activity ON auth.session_state_s(last_activity);
CREATE INDEX idx_user_session_l_user_hk ON auth.user_session_l(user_hk);

-- =============================================
-- 5. Security Policy Tables
-- =============================================

-- Hub table for security policies
CREATE TABLE auth.security_policy_h (
    security_policy_hk BYTEA PRIMARY KEY,
    security_policy_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Satellite table for security policy details
CREATE TABLE auth.security_policy_s (
    security_policy_hk BYTEA NOT NULL REFERENCES auth.security_policy_h(security_policy_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    policy_name VARCHAR(100) NOT NULL,
    policy_description VARCHAR(500),
    password_min_length INTEGER DEFAULT 8,
    password_require_uppercase BOOLEAN DEFAULT true,
    password_require_lowercase BOOLEAN DEFAULT true,
    password_require_number BOOLEAN DEFAULT true,
    password_require_special BOOLEAN DEFAULT true,
    password_expiry_days INTEGER DEFAULT 90,
    account_lockout_threshold INTEGER DEFAULT 5,
    account_lockout_duration_minutes INTEGER DEFAULT 30,
    session_timeout_minutes INTEGER DEFAULT 60,
    require_mfa BOOLEAN DEFAULT false,
    allowed_ip_ranges TEXT[],
    is_active BOOLEAN DEFAULT true,
    created_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    last_updated_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (security_policy_hk, load_date)
);


-- =============================================
-- Create additional indexes for performance
-- =============================================

-- Tenant indexes
CREATE INDEX idx_tenant_profile_s_is_active ON auth.tenant_profile_s(is_active) 
WHERE load_end_date IS NULL;

-- User indexes
CREATE INDEX idx_user_h_tenant_hk ON auth.user_h(tenant_hk);
CREATE INDEX idx_user_profile_s_email ON auth.user_profile_s(email) 
WHERE load_end_date IS NULL;
CREATE INDEX idx_user_profile_s_is_active ON auth.user_profile_s(is_active) 
WHERE load_end_date IS NULL;
CREATE INDEX idx_user_auth_s_account_locked ON auth.user_auth_s(account_locked) 
WHERE load_end_date IS NULL;

-- Role indexes
CREATE INDEX idx_role_h_tenant_hk ON auth.role_h(tenant_hk);
CREATE INDEX idx_role_definition_s_is_system_role ON auth.role_definition_s(is_system_role) 
WHERE load_end_date IS NULL;

-- Security policy indexes
CREATE INDEX idx_security_policy_h_tenant_hk ON auth.security_policy_h(tenant_hk);
CREATE INDEX idx_security_policy_s_is_active ON auth.security_policy_s(is_active) 
WHERE load_end_date IS NULL;

-- Comment to indicate completion of table creation
COMMENT ON SCHEMA auth IS 'Authentication and authorization schema for Data Vault 2.0 implementation';
