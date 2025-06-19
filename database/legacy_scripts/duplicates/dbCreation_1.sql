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

-- Audit tracking dispatcher function
CREATE OR REPLACE FUNCTION util.audit_track_dispatcher()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_table_name text := TG_TABLE_NAME;
    v_table_schema text := TG_TABLE_SCHEMA;
    v_table_suffix text;
BEGIN
    -- Extract table type suffix (_h, _s, _l, _b, _r)
    v_table_suffix := right(v_table_name, 2);
    
    -- Dispatch to appropriate specialized function based on table type
    CASE v_table_suffix
        WHEN '_h' THEN
            PERFORM util.audit_track_hub();
        WHEN '_s' THEN
            PERFORM util.audit_track_satellite();
        WHEN '_l' THEN
            PERFORM util.audit_track_link();
        WHEN '_b' THEN
            PERFORM util.audit_track_bridge();
        WHEN '_r' THEN
            PERFORM util.audit_track_reference();
        ELSE
            -- Handle unknown table types or use default
            PERFORM util.audit_track_default();
    END CASE;
    
    RETURN NULL;
END;
$$;

-- Audit tracking function for hub tables
CREATE OR REPLACE FUNCTION util.audit_track_hub()
RETURNS void
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
END;
$$;

-- Audit tracking function for satellite tables
CREATE OR REPLACE FUNCTION util.audit_track_satellite()
RETURNS void
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
END;
$$;

-- Audit tracking function for link tables
CREATE OR REPLACE FUNCTION util.audit_track_link()
RETURNS void
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
END;
$$;

-- Audit tracking function for bridge tables
CREATE OR REPLACE FUNCTION util.audit_track_bridge()
RETURNS void
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
END;
$$;

-- Audit tracking function for reference tables
CREATE OR REPLACE FUNCTION util.audit_track_reference()
RETURNS void
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
END;
$$;

-- Default audit tracking function for tables that don't match known patterns
CREATE OR REPLACE FUNCTION util.audit_track_default()
RETURNS void
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
END;
$$;

-- Updated function to create audit triggers using the dispatcher
CREATE OR REPLACE FUNCTION util.create_audit_triggers(p_schema_name text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_table_name text;
BEGIN
    FOR v_table_name IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = p_schema_name 
        AND table_type = 'BASE TABLE'
    LOOP
        EXECUTE format('
            CREATE TRIGGER trg_audit_%s
            AFTER INSERT OR UPDATE OR DELETE ON %I.%I
            FOR EACH ROW
            EXECUTE FUNCTION util.audit_track_dispatcher();',
            lower(v_table_name),
            p_schema_name,
            v_table_name
        );
        
        RAISE NOTICE 'Created audit trigger for %.%', p_schema_name, v_table_name;
    END LOOP;
END;
$$;

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
