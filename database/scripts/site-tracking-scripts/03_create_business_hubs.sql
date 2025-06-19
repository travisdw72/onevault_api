-- =====================================================
-- PHASE 3A: BUSINESS LAYER HUBS - Data Vault 2.0
-- Universal Site Tracking Business Entities
-- =====================================================

-- Ensure business schema exists
CREATE SCHEMA IF NOT EXISTS business;

-- =====================================================
-- HUB 1: Site Session Hub
-- Represents unique visitor sessions across the site
-- =====================================================
CREATE TABLE IF NOT EXISTS business.site_session_h (
    site_session_hk BYTEA PRIMARY KEY,
    site_session_bk VARCHAR(255) NOT NULL UNIQUE,    -- session_1234567890_abc123
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    -- Constraints for data quality
    CONSTRAINT chk_site_session_bk_format CHECK (
        site_session_bk ~ '^(sess_|session_)[a-zA-Z0-9_-]+$'
    )
);

-- Indexes for site session hub
CREATE INDEX IF NOT EXISTS idx_site_session_h_tenant_hk 
ON business.site_session_h(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_site_session_h_bk 
ON business.site_session_h(site_session_bk);

CREATE INDEX IF NOT EXISTS idx_site_session_h_load_date 
ON business.site_session_h(load_date);

-- =====================================================
-- HUB 2: Site Visitor Hub  
-- Represents unique visitors (privacy-safe identification)
-- =====================================================
CREATE TABLE IF NOT EXISTS business.site_visitor_h (
    site_visitor_hk BYTEA PRIMARY KEY,
    site_visitor_bk VARCHAR(255) NOT NULL UNIQUE,    -- visitor_hashed_identifier
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    -- Constraints for data quality
    CONSTRAINT chk_site_visitor_bk_format CHECK (
        site_visitor_bk ~ '^visitor_[a-zA-Z0-9]+$'
    )
);

-- Indexes for site visitor hub
CREATE INDEX IF NOT EXISTS idx_site_visitor_h_tenant_hk 
ON business.site_visitor_h(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_site_visitor_h_bk 
ON business.site_visitor_h(site_visitor_bk);

CREATE INDEX IF NOT EXISTS idx_site_visitor_h_load_date 
ON business.site_visitor_h(load_date);

-- =====================================================
-- HUB 3: Site Event Hub
-- Represents individual tracking events/interactions
-- =====================================================
CREATE TABLE IF NOT EXISTS business.site_event_h (
    site_event_hk BYTEA PRIMARY KEY,
    site_event_bk VARCHAR(255) NOT NULL UNIQUE,      -- evt_timestamp_sessionId_eventType
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    -- Constraints for data quality
    CONSTRAINT chk_site_event_bk_format CHECK (
        site_event_bk ~ '^evt_[a-zA-Z0-9_-]+$'
    )
);

-- Indexes for site event hub
CREATE INDEX IF NOT EXISTS idx_site_event_h_tenant_hk 
ON business.site_event_h(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_site_event_h_bk 
ON business.site_event_h(site_event_bk);

CREATE INDEX IF NOT EXISTS idx_site_event_h_load_date 
ON business.site_event_h(load_date);

-- =====================================================
-- HUB 4: Site Page Hub
-- Represents unique pages/URLs on the site
-- =====================================================
CREATE TABLE IF NOT EXISTS business.site_page_h (
    site_page_hk BYTEA PRIMARY KEY,
    site_page_bk VARCHAR(500) NOT NULL UNIQUE,       -- normalized page URL
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    -- Constraints for data quality
    CONSTRAINT chk_site_page_bk_not_empty CHECK (
        LENGTH(TRIM(site_page_bk)) > 0
    )
);

-- Indexes for site page hub
CREATE INDEX IF NOT EXISTS idx_site_page_h_tenant_hk 
ON business.site_page_h(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_site_page_h_bk 
ON business.site_page_h(site_page_bk);

CREATE INDEX IF NOT EXISTS idx_site_page_h_load_date 
ON business.site_page_h(load_date);

-- Text search index for page URLs
CREATE INDEX IF NOT EXISTS idx_site_page_h_bk_text 
ON business.site_page_h USING gin(to_tsvector('english', site_page_bk));

-- =====================================================
-- HUB 5: Business Item Hub (Universal)
-- Represents items/products/services/features/content
-- =====================================================
CREATE TABLE IF NOT EXISTS business.business_item_h (
    business_item_hk BYTEA PRIMARY KEY,
    business_item_bk VARCHAR(255) NOT NULL,   -- item identifier (can have duplicates across tenants)
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    -- Unique constraint per tenant (same item can exist for different tenants)
    CONSTRAINT uk_business_item_h_bk_tenant UNIQUE (business_item_bk, tenant_hk),
    
    -- Constraints for data quality
    CONSTRAINT chk_business_item_bk_not_empty CHECK (
        LENGTH(TRIM(business_item_bk)) > 0
    )
);

-- Indexes for business item hub
CREATE INDEX IF NOT EXISTS idx_business_item_h_tenant_hk 
ON business.business_item_h(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_business_item_h_bk 
ON business.business_item_h(business_item_bk);

CREATE INDEX IF NOT EXISTS idx_business_item_h_load_date 
ON business.business_item_h(load_date);

-- Text search index for item names
CREATE INDEX IF NOT EXISTS idx_business_item_h_bk_text 
ON business.business_item_h USING gin(to_tsvector('english', business_item_bk));

-- =====================================================
-- HUB MANAGEMENT FUNCTIONS
-- =====================================================

-- Function to create or get site session hub record
CREATE OR REPLACE FUNCTION business.get_or_create_site_session_hk(
    p_session_bk VARCHAR(255),
    p_tenant_hk BYTEA,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_session_hk BYTEA;
BEGIN
    -- Generate hash key
    v_session_hk := util.hash_binary(p_session_bk || encode(p_tenant_hk, 'hex'));
    
    -- Insert if not exists
    INSERT INTO business.site_session_h (
        site_session_hk, site_session_bk, tenant_hk, load_date, record_source
    ) VALUES (
        v_session_hk, p_session_bk, p_tenant_hk, util.current_load_date(), p_record_source
    ) ON CONFLICT (site_session_hk) DO NOTHING;
    
    RETURN v_session_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to create or get site visitor hub record
CREATE OR REPLACE FUNCTION business.get_or_create_site_visitor_hk(
    p_visitor_bk VARCHAR(255),
    p_tenant_hk BYTEA,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_visitor_hk BYTEA;
BEGIN
    -- Generate hash key
    v_visitor_hk := util.hash_binary(p_visitor_bk || encode(p_tenant_hk, 'hex'));
    
    -- Insert if not exists
    INSERT INTO business.site_visitor_h (
        site_visitor_hk, site_visitor_bk, tenant_hk, load_date, record_source
    ) VALUES (
        v_visitor_hk, p_visitor_bk, p_tenant_hk, util.current_load_date(), p_record_source
    ) ON CONFLICT (site_visitor_hk) DO NOTHING;
    
    RETURN v_visitor_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to create or get site event hub record
CREATE OR REPLACE FUNCTION business.get_or_create_site_event_hk(
    p_event_bk VARCHAR(255),
    p_tenant_hk BYTEA,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_event_hk BYTEA;
BEGIN
    -- Generate hash key
    v_event_hk := util.hash_binary(p_event_bk || encode(p_tenant_hk, 'hex'));
    
    -- Insert if not exists
    INSERT INTO business.site_event_h (
        site_event_hk, site_event_bk, tenant_hk, load_date, record_source
    ) VALUES (
        v_event_hk, p_event_bk, p_tenant_hk, util.current_load_date(), p_record_source
    ) ON CONFLICT (site_event_hk) DO NOTHING;
    
    RETURN v_event_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to create or get site page hub record
CREATE OR REPLACE FUNCTION business.get_or_create_site_page_hk(
    p_page_bk VARCHAR(500),
    p_tenant_hk BYTEA,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_page_hk BYTEA;
    v_normalized_url VARCHAR(500);
BEGIN
    -- Normalize the page URL
    v_normalized_url := business.normalize_page_url(p_page_bk);
    
    -- Generate hash key
    v_page_hk := util.hash_binary(v_normalized_url || encode(p_tenant_hk, 'hex'));
    
    -- Insert if not exists
    INSERT INTO business.site_page_h (
        site_page_hk, site_page_bk, tenant_hk, load_date, record_source
    ) VALUES (
        v_page_hk, v_normalized_url, p_tenant_hk, util.current_load_date(), p_record_source
    ) ON CONFLICT (site_page_hk) DO NOTHING;
    
    RETURN v_page_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to create or get business item hub record
CREATE OR REPLACE FUNCTION business.get_or_create_business_item_hk(
    p_item_bk VARCHAR(255),
    p_tenant_hk BYTEA,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_item_hk BYTEA;
BEGIN
    -- Generate hash key
    v_item_hk := util.hash_binary(p_item_bk || encode(p_tenant_hk, 'hex'));
    
    -- Insert if not exists
    INSERT INTO business.business_item_h (
        business_item_hk, business_item_bk, tenant_hk, load_date, record_source
    ) VALUES (
        v_item_hk, p_item_bk, p_tenant_hk, util.current_load_date(), p_record_source
    ) ON CONFLICT (business_item_hk) DO NOTHING;
    
    RETURN v_item_hk;
END;
$$ LANGUAGE plpgsql;

-- Utility function for URL normalization
CREATE OR REPLACE FUNCTION business.normalize_page_url(
    p_url VARCHAR(500)
) RETURNS VARCHAR(500) AS $$
BEGIN
    RETURN CASE 
        WHEN p_url IS NULL THEN '/unknown'
        WHEN p_url = '' THEN '/home'
        ELSE 
            -- Remove query parameters and fragments, convert to lowercase
            LOWER(
                SPLIT_PART(
                    SPLIT_PART(p_url, '?', 1), 
                    '#', 1
                )
            )
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to get hub statistics
CREATE OR REPLACE FUNCTION business.get_hub_statistics(
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS TABLE (
    hub_name VARCHAR(50),
    total_records BIGINT,
    tenant_hk BYTEA,
    last_load_date TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'site_session' as hub_name, COUNT(*) as total_records, 
           h.tenant_hk, MAX(h.load_date) as last_load_date
    FROM business.site_session_h h
    WHERE p_tenant_hk IS NULL OR h.tenant_hk = p_tenant_hk
    GROUP BY h.tenant_hk
    
    UNION ALL
    
    SELECT 'site_visitor' as hub_name, COUNT(*) as total_records,
           h.tenant_hk, MAX(h.load_date) as last_load_date
    FROM business.site_visitor_h h
    WHERE p_tenant_hk IS NULL OR h.tenant_hk = p_tenant_hk
    GROUP BY h.tenant_hk
    
    UNION ALL
    
    SELECT 'site_event' as hub_name, COUNT(*) as total_records,
           h.tenant_hk, MAX(h.load_date) as last_load_date
    FROM business.site_event_h h
    WHERE p_tenant_hk IS NULL OR h.tenant_hk = p_tenant_hk
    GROUP BY h.tenant_hk
    
    UNION ALL
    
    SELECT 'site_page' as hub_name, COUNT(*) as total_records,
           h.tenant_hk, MAX(h.load_date) as last_load_date
    FROM business.site_page_h h
    WHERE p_tenant_hk IS NULL OR h.tenant_hk = p_tenant_hk
    GROUP BY h.tenant_hk
    
    UNION ALL
    
    SELECT 'business_item' as hub_name, COUNT(*) as total_records,
           h.tenant_hk, MAX(h.load_date) as last_load_date
    FROM business.business_item_h h
    WHERE p_tenant_hk IS NULL OR h.tenant_hk = p_tenant_hk
    GROUP BY h.tenant_hk
    
    ORDER BY hub_name, tenant_hk;
END;
$$ LANGUAGE plpgsql;

-- Add table comments for documentation
COMMENT ON TABLE business.site_session_h IS 
'Hub table for unique site sessions following Data Vault 2.0 methodology.';

COMMENT ON TABLE business.site_visitor_h IS 
'Hub table for unique site visitors with privacy-safe identification.';

COMMENT ON TABLE business.site_event_h IS 
'Hub table for individual tracking events and interactions.';

COMMENT ON TABLE business.site_page_h IS 
'Hub table for unique pages and URLs with normalization.';

COMMENT ON TABLE business.business_item_h IS 
'Hub table for business items (products, services, content) across all verticals.';

-- Business hubs implementation complete
SELECT 'Business hubs for universal site tracking created successfully!' as status; 