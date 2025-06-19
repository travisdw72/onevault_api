-- Data Vault 2.0 Database Creation Script
-- Following naming conventions from Naming_Conventions.md

-- Create schemas
CREATE SCHEMA raw;
CREATE SCHEMA staging;
CREATE SCHEMA business;
CREATE SCHEMA infomart;
CREATE SCHEMA audit;
CREATE SCHEMA auth;
CREATE SCHEMA util;
CREATE SCHEMA validation;
CREATE SCHEMA config;
CREATE SCHEMA metadata;
CREATE SCHEMA archive;
CREATE SCHEMA ref;

DO $$ BEGIN
    RAISE NOTICE 'Starting Core Infrastructure setup...';
    -- Add rollback point
    SAVEPOINT core_infrastructure_start;
EXCEPTION WHEN OTHERS THEN
    -- Roll back to start if anything fails
    ROLLBACK TO core_infrastructure_start;
    RAISE EXCEPTION 'Core Infrastructure setup failed: %', SQLERRM;
END $$;

-- Ensure the pgcrypto extension is available
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Utility functions for Data Vault operations
-- Hash binary function for creating hash keys
CREATE OR REPLACE FUNCTION util.hash_binary(input text)
RETURNS BYTEA
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT DECODE(ENCODE(DIGEST(input, 'sha256'), 'hex'), 'hex');
$$;

-- Hash concatenation function for multiple fields
CREATE OR REPLACE FUNCTION util.hash_concat(VARIADIC args text[])
RETURNS BYTEA
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT util.hash_binary(array_to_string(args, ' | '));
$$;

-- Current load date function
CREATE OR REPLACE FUNCTION util.current_load_date()
RETURNS TIMESTAMP WITH TIME ZONE
LANGUAGE SQL
STABLE
AS $$
    SELECT CURRENT_TIMESTAMP;
$$;

-- Record source function
CREATE OR REPLACE FUNCTION util.get_record_source()
RETURNS VARCHAR(100)
LANGUAGE plpgsql
AS $$
DECLARE
    web_app_source VARCHAR(100);
BEGIN
    -- Get the web_application record source from metadata
    SELECT record_source_code INTO web_app_source
    FROM metadata.record_source
    WHERE record_source_code = 'web_application'
    AND is_active = true
    LIMIT 1;

    -- Return web_application or fallback to system if not found
    RETURN COALESCE(web_app_source, 'system');
END;
$$;

-- Create tenant hub table
CREATE TABLE auth.tenant_h (
    tenant_hk BYTEA PRIMARY KEY,
    tenant_bk VARCHAR(255),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100)
);

-- Create audit event hub table
CREATE TABLE audit.audit_event_h (
    audit_event_hk BYTEA PRIMARY KEY,
    audit_event_bk VARCHAR(255),
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100)
);

-- Create audit detail satellite table
CREATE TABLE audit.audit_detail_s (
    audit_event_hk BYTEA REFERENCES audit.audit_event_h(audit_event_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA,
    table_name VARCHAR(100),
    operation VARCHAR(10),
    changed_by VARCHAR(100),
    old_data JSONB,
    new_data JSONB,
    PRIMARY KEY (audit_event_hk, load_date)
);

-- ADD metadata.record_source table:
CREATE TABLE metadata.record_source (
    record_source_hk BYTEA PRIMARY KEY,
    record_source_code VARCHAR(50) NOT NULL UNIQUE,
    record_source_name VARCHAR(100),
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) DEFAULT 'system'
);

-- INSERT standard record sources:
INSERT INTO metadata.record_source (
    record_source_hk, record_source_code, record_source_name, description
) VALUES 
(util.hash_binary('web_application'), 'web_application', 'Web Application', 'Main web application interface'),
(util.hash_binary('mobile_app'), 'mobile_app', 'Mobile Application', 'Mobile application interface'),
(util.hash_binary('api'), 'api', 'API Access', 'Direct API access for integrations'),
(util.hash_binary('system'), 'system', 'System Process', 'Internal system processes'),
(util.hash_binary('migration'), 'migration', 'Data Migration', 'Data migration processes');

-- Audit tracking function for hub tables
CREATE OR REPLACE FUNCTION util.audit_track_hub()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_audit_event_hk BYTEA;
    v_tenant_hk BYTEA;
    v_audit_event_bk VARCHAR(255);
BEGIN
    -- Hub tables have tenant_hk directly
    v_tenant_hk := NEW.tenant_hk;
    
    -- Generate audit event business key
    v_audit_event_bk := 'audit_hub_' || TG_TABLE_NAME || '_' || 
                        to_char(util.current_load_date(), 'YYMMDD_HH24MISS');
    
    -- Create hash key from business key
    v_audit_event_hk := util.hash_binary(v_audit_event_bk);
    
    -- Create audit event record
    INSERT INTO audit.audit_event_h (
        audit_event_hk,
        audit_event_bk,
        tenant_hk,
        record_source
    ) VALUES (
        v_audit_event_hk,
        v_audit_event_bk,
        v_tenant_hk,
        util.get_record_source()
    );

    -- Create audit detail record
    INSERT INTO audit.audit_detail_s (
        audit_event_hk,
        hash_diff,
        table_name,
        operation,
        changed_by,
        old_data,
        new_data
    ) VALUES (
        v_audit_event_hk,
        util.hash_binary(concat(TG_TABLE_SCHEMA, '.', TG_TABLE_NAME, TG_OP, SESSION_USER)),
        TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
        TG_OP,
        SESSION_USER,
        to_jsonb(OLD),
        to_jsonb(NEW)
    );
    
    RETURN NEW;
END;
$$;

-- Audit tracking function for satellite tables
CREATE OR REPLACE FUNCTION util.audit_track_satellite()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_audit_event_hk BYTEA;
    v_tenant_hk BYTEA;
    v_audit_event_bk VARCHAR(255);
    v_entity_hk BYTEA;
    v_hub_schema text;
    v_hub_table text;
    v_entity_name text;
BEGIN
    -- Satellites don't have tenant_hk directly, need to get from hub
    -- First, get the entity hash key which is always present in satellites
    -- The column name varies based on the entity, but it's the first part of the table name
    v_entity_name := split_part(TG_TABLE_NAME, '_', 1);
    
    -- Use dynamic SQL to get the entity hash key value
    EXECUTE format('SELECT ($1).%I', v_entity_name || '_hk')
    INTO v_entity_hk
    USING NEW;
    
    -- Determine the hub table name from satellite name
    -- Example: customer_profile_s -> customer_h
    v_hub_table := v_entity_name || '_h';
    v_hub_schema := TG_TABLE_SCHEMA; -- Assume same schema, adjust if needed
    
    -- Look up tenant_hk from the hub table
    EXECUTE format('
        SELECT tenant_hk 
        FROM %I.%I 
        WHERE %I = $1', 
        v_hub_schema, v_hub_table, v_entity_name || '_hk'
    ) INTO v_tenant_hk USING v_entity_hk;
    
    -- Generate audit event business key
    v_audit_event_bk := 'audit_sat_' || TG_TABLE_NAME || '_' || 
                        to_char(util.current_load_date(), 'YYMMDD_HH24MISS');
    
    -- Create hash key from business key
    v_audit_event_hk := util.hash_binary(v_audit_event_bk);
    
    -- Create audit event record
    INSERT INTO audit.audit_event_h (
        audit_event_hk,
        audit_event_bk,
        tenant_hk,
        record_source
    ) VALUES (
        v_audit_event_hk,
        v_audit_event_bk,
        v_tenant_hk,
        util.get_record_source()
    );

    -- Create audit detail record
    INSERT INTO audit.audit_detail_s (
        audit_event_hk,
        hash_diff,
        table_name,
        operation,
        changed_by,
        old_data,
        new_data
    ) VALUES (
        v_audit_event_hk,
        util.hash_binary(concat(TG_TABLE_SCHEMA, '.', TG_TABLE_NAME, TG_OP, SESSION_USER)),
        TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
        TG_OP,
        SESSION_USER,
        to_jsonb(OLD),
        to_jsonb(NEW)
    );
    
    RETURN NEW;
END;
$$;

-- Audit tracking function for link tables
CREATE OR REPLACE FUNCTION util.audit_track_link()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_audit_event_hk BYTEA;
    v_tenant_hk BYTEA;
    v_audit_event_bk VARCHAR(255);
BEGIN
    -- Link tables have tenant_hk directly
    v_tenant_hk := NEW.tenant_hk;
    
    -- Generate audit event business key
    v_audit_event_bk := 'audit_link_' || TG_TABLE_NAME || '_' || 
                        to_char(util.current_load_date(), 'YYMMDD_HH24MISS');
    
    -- Create hash key from business key
    v_audit_event_hk := util.hash_binary(v_audit_event_bk);
    
    -- Create audit event record
    INSERT INTO audit.audit_event_h (
        audit_event_hk,
        audit_event_bk,
        tenant_hk,
        record_source
    ) VALUES (
        v_audit_event_hk,
        v_audit_event_bk,
        v_tenant_hk,
        util.get_record_source()
    );

    -- Create audit detail record
    INSERT INTO audit.audit_detail_s (
        audit_event_hk,
        hash_diff,
        table_name,
        operation,
        changed_by,
        old_data,
        new_data
    ) VALUES (
        v_audit_event_hk,
        util.hash_binary(concat(TG_TABLE_SCHEMA, '.', TG_TABLE_NAME, TG_OP, SESSION_USER)),
        TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
        TG_OP,
        SESSION_USER,
        to_jsonb(OLD),
        to_jsonb(NEW)
    );
    
    RETURN NEW;
END;
$$;

-- Audit tracking function for bridge tables
CREATE OR REPLACE FUNCTION util.audit_track_bridge()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_audit_event_hk BYTEA;
    v_tenant_hk BYTEA;
    v_audit_event_bk VARCHAR(255);
BEGIN
    -- Bridge tables might not have tenant_hk directly
    -- This is a simplified version - in practice, you might need to look up tenant_hk
    -- from related tables or use a default tenant
    
    -- For now, use a default tenant if not available
    BEGIN
        v_tenant_hk := NEW.tenant_hk;
    EXCEPTION WHEN OTHERS THEN
        -- Get a default tenant (first tenant in the system)
        SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h LIMIT 1;
    END;
    
    -- Generate audit event business key
    v_audit_event_bk := 'audit_bridge_' || TG_TABLE_NAME || '_' || 
                        to_char(util.current_load_date(), 'YYMMDD_HH24MISS');
    
    -- Create hash key from business key
    v_audit_event_hk := util.hash_binary(v_audit_event_bk);
    
    -- Create audit event record
    INSERT INTO audit.audit_event_h (
        audit_event_hk,
        audit_event_bk,
        tenant_hk,
        record_source
    ) VALUES (
        v_audit_event_hk,
        v_audit_event_bk,
        v_tenant_hk,
        util.get_record_source()
    );

    -- Create audit detail record
    INSERT INTO audit.audit_detail_s (
        audit_event_hk,
        hash_diff,
        table_name,
        operation,
        changed_by,
        old_data,
        new_data
    ) VALUES (
        v_audit_event_hk,
        util.hash_binary(concat(TG_TABLE_SCHEMA, '.', TG_TABLE_NAME, TG_OP, SESSION_USER)),
        TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
        TG_OP,
        SESSION_USER,
        to_jsonb(OLD),
        to_jsonb(NEW)
    );
    
    RETURN NEW;
END;
$$;

-- Audit tracking function for reference tables
CREATE OR REPLACE FUNCTION util.audit_track_reference()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_audit_event_hk BYTEA;
    v_tenant_hk BYTEA;
    v_audit_event_bk VARCHAR(255);
BEGIN
    -- Reference tables typically don't have tenant_hk
    -- Use a default tenant for auditing purposes
    SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h LIMIT 1;
    
    -- Generate audit event business key
    v_audit_event_bk := 'audit_ref_' || TG_TABLE_NAME || '_' || 
                        to_char(util.current_load_date(), 'YYMMDD_HH24MISS');
    
    -- Create hash key from business key
    v_audit_event_hk := util.hash_binary(v_audit_event_bk);
    
    -- Create audit event record
    INSERT INTO audit.audit_event_h (
        audit_event_hk,
        audit_event_bk,
        tenant_hk,
        record_source
    ) VALUES (
        v_audit_event_hk,
        v_audit_event_bk,
        v_tenant_hk,
        util.get_record_source()
    );

    -- Create audit detail record
    INSERT INTO audit.audit_detail_s (
        audit_event_hk,
        hash_diff,
        table_name,
        operation,
        changed_by,
        old_data,
        new_data
    ) VALUES (
        v_audit_event_hk,
        util.hash_binary(concat(TG_TABLE_SCHEMA, '.', TG_TABLE_NAME, TG_OP, SESSION_USER)),
        TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
        TG_OP,
        SESSION_USER,
        to_jsonb(OLD),
        to_jsonb(NEW)
    );
    
    RETURN NEW;
END;
$$;

-- Default audit tracking function for tables that don't match known patterns
CREATE OR REPLACE FUNCTION util.audit_track_default()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_audit_event_hk BYTEA;
    v_tenant_hk BYTEA;
    v_audit_event_bk VARCHAR(255);
BEGIN
    -- Try to get tenant_hk if it exists, otherwise use default
    BEGIN
        v_tenant_hk := NEW.tenant_hk;
    EXCEPTION WHEN OTHERS THEN
        -- Get a default tenant
        SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h LIMIT 1;
    END;
    
    -- Generate audit event business key
    v_audit_event_bk := 'audit_default_' || TG_TABLE_NAME || '_' || 
                        to_char(util.current_load_date(), 'YYMMDD_HH24MISS');
    
    -- Create hash key from business key
    v_audit_event_hk := util.hash_binary(v_audit_event_bk);
    
    -- Create audit event record
    INSERT INTO audit.audit_event_h (
        audit_event_hk,
        audit_event_bk,
        tenant_hk,
        record_source
    ) VALUES (
        v_audit_event_hk,
        v_audit_event_bk,
        v_tenant_hk,
        util.get_record_source()
    );

    -- Create audit detail record
    INSERT INTO audit.audit_detail_s (
        audit_event_hk,
        hash_diff,
        table_name,
        operation,
        changed_by,
        old_data,
        new_data
    ) VALUES (
        v_audit_event_hk,
        util.hash_binary(concat(TG_TABLE_SCHEMA, '.', TG_TABLE_NAME, TG_OP, SESSION_USER)),
        TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
        TG_OP,
        SESSION_USER,
        to_jsonb(OLD),
        to_jsonb(NEW)
    );
    
    RETURN NEW;
END;
$$;

-- Main audit dispatcher that routes to appropriate function based on table type
CREATE OR REPLACE FUNCTION util.audit_track_dispatcher()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_table_name text := TG_TABLE_NAME;
    v_table_suffix text;
    v_audit_event_hk BYTEA;
    v_tenant_hk BYTEA;
    v_audit_event_bk VARCHAR(255);
BEGIN
    -- Extract table type suffix (_h, _s, _l, _b, _r)
    v_table_suffix := right(v_table_name, 2);
    
    -- Handle different table types with embedded logic
    CASE v_table_suffix
        WHEN '_h' THEN
            -- Hub table logic
            BEGIN
                v_tenant_hk := NEW.tenant_hk;
                
                v_audit_event_bk := 'audit_hub_' || TG_TABLE_NAME || '_' || 
                                    to_char(util.current_load_date(), 'YYMMDD_HH24MISS');
                
                v_audit_event_hk := util.hash_binary(v_audit_event_bk);
                
                INSERT INTO audit.audit_event_h (
                    audit_event_hk,
                    audit_event_bk,
                    tenant_hk,
                    record_source
                ) VALUES (
                    v_audit_event_hk,
                    v_audit_event_bk,
                    v_tenant_hk,
                    util.get_record_source()
                );

                INSERT INTO audit.audit_detail_s (
                    audit_event_hk,
                    hash_diff,
                    table_name,
                    operation,
                    changed_by,
                    old_data,
                    new_data
                ) VALUES (
                    v_audit_event_hk,
                    util.hash_binary(concat(TG_TABLE_SCHEMA, '.', TG_TABLE_NAME, TG_OP, SESSION_USER)),
                    TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
                    TG_OP,
                    SESSION_USER,
                    to_jsonb(OLD),
                    to_jsonb(NEW)
                );
            EXCEPTION WHEN OTHERS THEN
                -- If hub audit fails, use default approach
                PERFORM util.audit_track_default();
            END;
            
        WHEN '_s' THEN
            -- Satellite table logic - simplified for now to avoid complexity
            -- You can enhance this later to lookup tenant_hk from hub tables
            BEGIN
                -- Try to get tenant_hk if it exists in the satellite
                BEGIN
                    v_tenant_hk := NEW.tenant_hk;
                EXCEPTION WHEN OTHERS THEN
                    -- Use first available tenant for now
                    SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h LIMIT 1;
                END;
                
                v_audit_event_bk := 'audit_sat_' || TG_TABLE_NAME || '_' || 
                                    to_char(util.current_load_date(), 'YYMMDD_HH24MISS');
                
                v_audit_event_hk := util.hash_binary(v_audit_event_bk);
                
                INSERT INTO audit.audit_event_h (
                    audit_event_hk,
                    audit_event_bk,
                    tenant_hk,
                    record_source
                ) VALUES (
                    v_audit_event_hk,
                    v_audit_event_bk,
                    v_tenant_hk,
                    util.get_record_source()
                );

                INSERT INTO audit.audit_detail_s (
                    audit_event_hk,
                    hash_diff,
                    table_name,
                    operation,
                    changed_by,
                    old_data,
                    new_data
                ) VALUES (
                    v_audit_event_hk,
                    util.hash_binary(concat(TG_TABLE_SCHEMA, '.', TG_TABLE_NAME, TG_OP, SESSION_USER)),
                    TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
                    TG_OP,
                    SESSION_USER,
                    to_jsonb(OLD),
                    to_jsonb(NEW)
                );
            EXCEPTION WHEN OTHERS THEN
                -- Skip audit logging for satellites if it fails - prevents blocking operations
                NULL;
            END;
            
        WHEN '_l' THEN
            -- Link table logic
            BEGIN
                v_tenant_hk := NEW.tenant_hk;
                
                v_audit_event_bk := 'audit_link_' || TG_TABLE_NAME || '_' || 
                                    to_char(util.current_load_date(), 'YYMMDD_HH24MISS');
                
                v_audit_event_hk := util.hash_binary(v_audit_event_bk);
                
                INSERT INTO audit.audit_event_h (
                    audit_event_hk,
                    audit_event_bk,
                    tenant_hk,
                    record_source
                ) VALUES (
                    v_audit_event_hk,
                    v_audit_event_bk,
                    v_tenant_hk,
                    util.get_record_source()
                );

                INSERT INTO audit.audit_detail_s (
                    audit_event_hk,
                    hash_diff,
                    table_name,
                    operation,
                    changed_by,
                    old_data,
                    new_data
                ) VALUES (
                    v_audit_event_hk,
                    util.hash_binary(concat(TG_TABLE_SCHEMA, '.', TG_TABLE_NAME, TG_OP, SESSION_USER)),
                    TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
                    TG_OP,
                    SESSION_USER,
                    to_jsonb(OLD),
                    to_jsonb(NEW)
                );
            EXCEPTION WHEN OTHERS THEN
                -- If link audit fails, use default approach
                PERFORM util.audit_track_default();
            END;
            
        ELSE
            -- For other table types, use default approach
            BEGIN
                -- Try to get tenant_hk if it exists
                BEGIN
                    v_tenant_hk := NEW.tenant_hk;
                EXCEPTION WHEN OTHERS THEN
                    SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h LIMIT 1;
                END;
                
                v_audit_event_bk := 'audit_default_' || TG_TABLE_NAME || '_' || 
                                    to_char(util.current_load_date(), 'YYMMDD_HH24MISS');
                
                v_audit_event_hk := util.hash_binary(v_audit_event_bk);
                
                INSERT INTO audit.audit_event_h (
                    audit_event_hk,
                    audit_event_bk,
                    tenant_hk,
                    record_source
                ) VALUES (
                    v_audit_event_hk,
                    v_audit_event_bk,
                    v_tenant_hk,
                    util.get_record_source()
                );

                INSERT INTO audit.audit_detail_s (
                    audit_event_hk,
                    hash_diff,
                    table_name,
                    operation,
                    changed_by,
                    old_data,
                    new_data
                ) VALUES (
                    v_audit_event_hk,
                    util.hash_binary(concat(TG_TABLE_SCHEMA, '.', TG_TABLE_NAME, TG_OP, SESSION_USER)),
                    TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
                    TG_OP,
                    SESSION_USER,
                    to_jsonb(OLD),
                    to_jsonb(NEW)
                );
            EXCEPTION WHEN OTHERS THEN
                -- If all else fails, just log a notice and continue
                RAISE NOTICE 'Audit logging failed for table %.%: %', TG_TABLE_SCHEMA, TG_TABLE_NAME, SQLERRM;
            END;
    END CASE;
    
    -- Always return NEW for triggers
    RETURN NEW;
END;
$$;

-- =============================================
-- AUTOMATIC AUDIT SYSTEM
-- =============================================

-- Event trigger for automatic audit trigger creation on new tables
CREATE OR REPLACE FUNCTION util.auto_create_audit_triggers()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
DECLARE
    obj record;
    trigger_name text;
    schema_name text;
    table_name text;
BEGIN
    -- Only process table creation events
    FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands() 
    WHERE command_tag = 'CREATE TABLE'
    LOOP
        -- Extract schema and table name
        SELECT schemaname, tablename INTO schema_name, table_name
        FROM pg_tables 
        WHERE schemaname||'.'||tablename = obj.object_identity;
        
        -- Only add triggers to our business schemas
        IF schema_name IN ('auth', 'business', 'raw', 'staging', 'audit', 'util', 'infomart', 'validation', 'config', 'metadata', 'archive', 'ref') THEN
            
            trigger_name := 'trg_audit_' || lower(table_name);
            
            -- Create audit trigger for the new table
            EXECUTE format('
                CREATE TRIGGER %I
                AFTER INSERT OR UPDATE OR DELETE ON %I.%I
                FOR EACH ROW
                EXECUTE FUNCTION util.audit_track_dispatcher();',
                trigger_name,
                schema_name,
                table_name
            );
            
            RAISE NOTICE 'Auto-created audit trigger % for %.%', trigger_name, schema_name, table_name;
        END IF;
    END LOOP;
END;
$$;

-- Create the event trigger to automatically add audit triggers to new tables
CREATE EVENT TRIGGER auto_audit_trigger_creation
ON ddl_command_end
WHEN TAG IN ('CREATE TABLE')
EXECUTE FUNCTION util.auto_create_audit_triggers();

-- Comprehensive audit coverage function to catch any missed tables
CREATE OR REPLACE FUNCTION util.ensure_complete_audit_coverage()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    schema_rec RECORD;
    table_rec RECORD;
    trigger_count INTEGER := 0;
    result_text TEXT := '';
BEGIN
    -- Process all relevant schemas
    FOR schema_rec IN 
        SELECT schema_name 
        FROM information_schema.schemata 
        WHERE schema_name IN ('auth', 'business', 'raw', 'staging', 'audit', 'util', 'infomart', 'validation', 'config', 'metadata', 'archive', 'ref')
    LOOP
        -- Process all tables in each schema
        FOR table_rec IN
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = schema_rec.schema_name
            AND table_type = 'BASE TABLE'
        LOOP
            -- Check if audit trigger already exists
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.triggers
                WHERE trigger_schema = schema_rec.schema_name
                AND event_object_table = table_rec.table_name
                AND trigger_name = 'trg_audit_' || lower(table_rec.table_name)
            ) THEN
                -- Create the audit trigger
                EXECUTE format('
                    CREATE TRIGGER trg_audit_%s
                    AFTER INSERT OR UPDATE OR DELETE ON %I.%I
                    FOR EACH ROW
                    EXECUTE FUNCTION util.audit_track_dispatcher();',
                    lower(table_rec.table_name),
                    schema_rec.schema_name,
                    table_rec.table_name
                );
                
                trigger_count := trigger_count + 1;
                result_text := result_text || format('Created audit trigger for %s.%s%s', 
                    schema_rec.schema_name, table_rec.table_name, chr(10));
            END IF;
        END LOOP;
    END LOOP;
    
    RETURN format('Audit system initialized: %s triggers created%s%s', trigger_count, chr(10), result_text);
END;
$$;

-- Function to find tables missing audit triggers
CREATE OR REPLACE FUNCTION util.find_unaudited_tables()
RETURNS TABLE (
    schema_name TEXT,
    table_name TEXT,
    recommendation TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.table_schema::TEXT,
        t.table_name::TEXT,
        ('Missing audit trigger - will be auto-created on next table creation or run: SELECT util.ensure_complete_audit_coverage();')::TEXT
    FROM information_schema.tables t
    WHERE t.table_schema IN ('auth', 'business', 'raw', 'staging', 'audit', 'util', 'infomart', 'validation', 'config', 'metadata', 'archive', 'ref')
    AND t.table_type = 'BASE TABLE'
    AND NOT EXISTS (
        SELECT 1 FROM information_schema.triggers tr
        WHERE tr.trigger_schema = t.table_schema
        AND tr.event_object_table = t.table_name
        AND tr.trigger_name = 'trg_audit_' || lower(t.table_name)
    )
    ORDER BY t.table_schema, t.table_name;
END;
$$;

-- Enhanced function to create audit triggers for specific schema (backwards compatibility)
CREATE OR REPLACE FUNCTION util.create_audit_triggers(p_schema_name text)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    v_table_name text;
    v_trigger_name text;
    v_trigger_exists boolean;
BEGIN
    FOR v_table_name IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = p_schema_name 
        AND table_type = 'BASE TABLE'
    LOOP
        -- Generate trigger name
        v_trigger_name := 'trg_audit_' || lower(v_table_name);
        
        -- Check if trigger already exists
        SELECT EXISTS (
            SELECT 1 
            FROM information_schema.triggers 
            WHERE trigger_schema = p_schema_name 
            AND event_object_table = v_table_name 
            AND trigger_name = v_trigger_name
        ) INTO v_trigger_exists;
        
        -- Only create trigger if it doesn't exist
        IF NOT v_trigger_exists THEN
            EXECUTE format('
                CREATE TRIGGER %I
                AFTER INSERT OR UPDATE OR DELETE ON %I.%I
                FOR EACH ROW
                EXECUTE FUNCTION util.audit_track_dispatcher();',
                v_trigger_name,
                p_schema_name,
                v_table_name
            );
            
            RAISE NOTICE 'Created audit trigger % for %.%', v_trigger_name, p_schema_name, v_table_name;
        ELSE
            RAISE NOTICE 'Audit trigger % already exists for %.% - skipping', v_trigger_name, p_schema_name, v_table_name;
        END IF;
    END LOOP;
END;
$$;

-- Run initial audit coverage for existing tables
SELECT util.ensure_complete_audit_coverage();

-- Show audit system status
SELECT 
    'Audit System Status' as component,
    'ACTIVE' as status,
    'Event trigger will auto-create audit triggers for new tables' as description
UNION ALL
SELECT 
    'Current Coverage' as component,
    CASE WHEN COUNT(*) = 0 THEN 'COMPLETE' ELSE 'INCOMPLETE' END as status,
    CASE WHEN COUNT(*) = 0 
         THEN 'All tables have audit triggers' 
         ELSE COUNT(*)::text || ' tables missing audit triggers' 
    END as description
FROM util.find_unaudited_tables();

-- =============================================
-- END OF AUDIT SYSTEM SECTION
-- =============================================    

-- Run initial audit coverage
-- SELECT util.ensure_complete_audit_coverage();

-- Example of how to create audit triggers for all tables in a schema
-- SELECT util.create_audit_triggers('auth');
-- SELECT util.create_audit_triggers('business');

-- Reference table example
/*
CREATE TABLE ref.status_codes_r (
    ref_key VARCHAR(50) PRIMARY KEY,
    description VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100)
);

-- Example hub table
CREATE TABLE business.customer_h (
    customer_hk BYTEA PRIMARY KEY,
    customer_bk VARCHAR(255),
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100)
);

-- Example satellite table
CREATE TABLE business.customer_profile_s (
    customer_hk BYTEA REFERENCES business.customer_h(customer_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    hash_diff BYTEA,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(50),
    record_source VARCHAR(100),
    PRIMARY KEY (customer_hk, load_date)
);

-- Example link table
CREATE TABLE business.customer_order_l (
    link_customer_order_hk BYTEA PRIMARY KEY,
    customer_hk BYTEA REFERENCES business.customer_h(customer_hk),
    order_hk BYTEA, -- Would reference order_h if it existed
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100)
);

-- Example bridge table
CREATE TABLE business.order_hierarchy_b (
    bridge_hk BYTEA PRIMARY KEY,
    parent_order_hk BYTEA,
    child_order_hk BYTEA,
    effective_date TIMESTAMP WITH TIME ZONE,
    expiry_date TIMESTAMP WITH TIME ZONE,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100)
);
*/
