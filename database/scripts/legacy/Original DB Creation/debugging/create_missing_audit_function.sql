-- =============================================
-- create_missing_audit_function.sql
-- Creates the missing util.log_audit_event function that's causing errors
-- This function is being called by the PHP application but doesn't exist
-- =============================================

-- =============================================
-- Create the missing util.log_audit_event function
-- =============================================

CREATE OR REPLACE FUNCTION util.log_audit_event(
    p_event_type TEXT,
    p_resource_type TEXT,
    p_resource_id TEXT,
    p_actor TEXT,
    p_event_details JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_audit_event_hk BYTEA;
    v_audit_event_bk TEXT;
    v_tenant_hk BYTEA;
    v_load_date TIMESTAMP WITH TIME ZONE;
    v_record_source VARCHAR(100);
    v_result JSONB;
BEGIN
    -- Initialize operational variables
    v_load_date := util.current_load_date();
    v_record_source := util.get_record_source();
    
    -- Generate audit event identifiers
    v_audit_event_bk := p_event_type || '_' || p_resource_type || '_' || 
                       COALESCE(p_resource_id, 'UNKNOWN') || '_' || 
                       extract(epoch from v_load_date)::text;
    v_audit_event_hk := util.hash_binary(v_audit_event_bk);
    
    -- Try to determine tenant context from actor or event details
    BEGIN
        -- Try to get tenant from actor (username)
        SELECT uh.tenant_hk INTO v_tenant_hk
        FROM auth.user_h uh
        JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
        WHERE uas.username = p_actor
        AND uas.load_end_date IS NULL
        ORDER BY uas.load_date DESC
        LIMIT 1;
        
        -- If no tenant found from actor, try from event details
        IF v_tenant_hk IS NULL AND p_event_details ? 'tenant_id' THEN
            v_tenant_hk := decode(p_event_details->>'tenant_id', 'hex');
        END IF;
        
        -- If still no tenant, use a default system tenant or create one
        IF v_tenant_hk IS NULL THEN
            -- Use first available tenant as fallback
            SELECT tenant_hk INTO v_tenant_hk
            FROM auth.tenant_h
            ORDER BY load_date ASC
            LIMIT 1;
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        -- If anything fails, continue without tenant context
        v_tenant_hk := NULL;
    END;
    
    -- Check if audit tables exist before trying to insert
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'audit' AND tablename = 'audit_event_h') THEN
        
        -- Insert audit event hub record
        INSERT INTO audit.audit_event_h (
            audit_event_hk,
            audit_event_bk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            v_audit_event_hk,
            v_audit_event_bk,
            v_tenant_hk,
            v_load_date,
            v_record_source
        )
        ON CONFLICT (audit_event_hk) DO NOTHING; -- Avoid duplicates
        
        -- Insert audit detail satellite record
        IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'audit' AND tablename = 'audit_detail_s') THEN
            INSERT INTO audit.audit_detail_s (
                audit_event_hk,
                load_date,
                hash_diff,
                table_name,
                operation,
                changed_by,
                old_data,
                new_data
            ) VALUES (
                v_audit_event_hk,
                v_load_date,
                util.hash_binary(v_audit_event_bk || p_event_type || v_load_date::text),
                p_resource_type,
                p_event_type,
                p_actor,
                NULL, -- old_data - not provided in this context
                p_event_details
            );
        END IF;
        
        v_result := jsonb_build_object(
            'success', true,
            'message', 'Audit event logged successfully',
            'audit_event_hk', encode(v_audit_event_hk, 'hex'),
            'audit_event_bk', v_audit_event_bk
        );
        
    ELSE
        -- Audit tables don't exist - log to application log instead
        RAISE WARNING 'Audit tables do not exist. Event: % by % on %:% - Details: %', 
            p_event_type, p_actor, p_resource_type, p_resource_id, p_event_details;
            
        v_result := jsonb_build_object(
            'success', false,
            'message', 'Audit tables do not exist',
            'warning', 'Event logged to PostgreSQL log instead',
            'event_type', p_event_type,
            'actor', p_actor,
            'resource_type', p_resource_type,
            'resource_id', p_resource_id
        );
    END IF;
    
    RETURN v_result;
    
EXCEPTION WHEN OTHERS THEN
    -- If anything fails, return error but don't break the calling function
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error logging audit event',
        'error_code', SQLSTATE,
        'error_message', SQLERRM,
        'event_type', p_event_type,
        'actor', p_actor
    );
END;
$$;

-- =============================================
-- Create simplified audit tables if they don't exist
-- =============================================

-- Create audit schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS audit;

-- Create audit event hub table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'audit' AND tablename = 'audit_event_h') THEN
        CREATE TABLE audit.audit_event_h (
            audit_event_hk BYTEA PRIMARY KEY,
            audit_event_bk VARCHAR(255) NOT NULL,
            tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            record_source VARCHAR(100) NOT NULL,
            
            -- Constraints
            CONSTRAINT uk_audit_event_h_bk UNIQUE (audit_event_bk)
        );
        
        -- Create index for performance
        CREATE INDEX idx_audit_event_h_tenant_date ON audit.audit_event_h(tenant_hk, load_date);
        CREATE INDEX idx_audit_event_h_load_date ON audit.audit_event_h(load_date);
        
        RAISE NOTICE 'Created audit.audit_event_h table';
    END IF;
END $$;

-- Create audit detail satellite table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'audit' AND tablename = 'audit_detail_s') THEN
        CREATE TABLE audit.audit_detail_s (
            audit_event_hk BYTEA NOT NULL REFERENCES audit.audit_event_h(audit_event_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            load_end_date TIMESTAMP WITH TIME ZONE,
            hash_diff BYTEA NOT NULL,
            table_name VARCHAR(100),
            operation VARCHAR(50),
            changed_by VARCHAR(255),
            old_data JSONB,
            new_data JSONB,
            
            -- Constraints
            PRIMARY KEY (audit_event_hk, load_date),
            CONSTRAINT chk_load_end_date CHECK (load_end_date IS NULL OR load_end_date > load_date)
        );
        
        -- Create indexes for performance
        CREATE INDEX idx_audit_detail_s_table_operation ON audit.audit_detail_s(table_name, operation);
        CREATE INDEX idx_audit_detail_s_changed_by ON audit.audit_detail_s(changed_by);
        CREATE INDEX idx_audit_detail_s_load_date ON audit.audit_detail_s(load_date);
        
        RAISE NOTICE 'Created audit.audit_detail_s table';
    END IF;
END $$;

-- =============================================
-- Test the function
-- =============================================

DO $$
DECLARE
    v_result JSONB;
BEGIN
    RAISE NOTICE '=== TESTING util.log_audit_event FUNCTION ===';
    
    -- Test the function with sample data
    SELECT util.log_audit_event(
        'LOGIN_ATTEMPT',
        'auth.user_auth_s',
        'travisdwoodward72@gmail.com',
        'travisdwoodward72@gmail.com',
        jsonb_build_object(
            'ip_address', '192.168.1.100',
            'user_agent', 'Mozilla/5.0 Test',
            'timestamp', CURRENT_TIMESTAMP
        )
    ) INTO v_result;
    
    RAISE NOTICE 'Test result: %', v_result;
    
    IF (v_result->>'success')::BOOLEAN THEN
        RAISE NOTICE 'SUCCESS: Function is working correctly!';
    ELSE
        RAISE NOTICE 'WARNING: Function returned an error: %', v_result->>'message';
    END IF;
END $$;

-- =============================================
-- Verify the fix
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== AUDIT FUNCTION SETUP COMPLETE ===';
    RAISE NOTICE '';
    RAISE NOTICE 'The missing util.log_audit_event function has been created.';
    RAISE NOTICE 'This should resolve the SQL errors in your PHP application logs.';
    RAISE NOTICE '';
    RAISE NOTICE 'Function signature:';
    RAISE NOTICE 'util.log_audit_event(event_type, resource_type, resource_id, actor, event_details)';
    RAISE NOTICE '';
    RAISE NOTICE 'The function will:';
    RAISE NOTICE '1. Create audit records if audit tables exist';
    RAISE NOTICE '2. Log warnings to PostgreSQL log if audit tables are missing';
    RAISE NOTICE '3. Return success/error status as JSONB';
    RAISE NOTICE '4. Never throw errors that would break your application';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Run the audit_log_analysis_script.sql to verify your data';
    RAISE NOTICE '2. Test your PHP application - the SQL errors should be gone';
    RAISE NOTICE '3. Check if audit records are being created properly';
    RAISE NOTICE '';
END $$; 