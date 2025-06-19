-- =====================================================
-- PHASE 3B: BUSINESS LAYER LINKS - Data Vault 2.0
-- Universal Site Tracking Entity Relationships
-- =====================================================

-- Ensure business schema exists
CREATE SCHEMA IF NOT EXISTS business;

-- =====================================================
-- DATA VAULT 2.0 LINK TABLES
-- =====================================================

-- =====================================================
-- LINK 1: Session-Visitor Link
-- Connects visitors to their sessions
-- =====================================================
CREATE TABLE IF NOT EXISTS business.session_visitor_l (
    link_session_visitor_hk BYTEA PRIMARY KEY,
    site_session_hk BYTEA NOT NULL REFERENCES business.site_session_h(site_session_hk),
    site_visitor_hk BYTEA NOT NULL REFERENCES business.site_visitor_h(site_visitor_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    -- Ensure unique relationship per tenant
    CONSTRAINT uk_session_visitor_tenant UNIQUE (site_session_hk, site_visitor_hk, tenant_hk)
);

-- Indexes for session-visitor link
CREATE INDEX IF NOT EXISTS idx_session_visitor_l_session_hk 
ON business.session_visitor_l(site_session_hk);

CREATE INDEX IF NOT EXISTS idx_session_visitor_l_visitor_hk 
ON business.session_visitor_l(site_visitor_hk);

CREATE INDEX IF NOT EXISTS idx_session_visitor_l_tenant_hk 
ON business.session_visitor_l(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_session_visitor_l_load_date 
ON business.session_visitor_l(load_date);

-- =====================================================
-- LINK 2: Event-Session Link
-- Connects events to their sessions
-- =====================================================
CREATE TABLE IF NOT EXISTS business.event_session_l (
    link_event_session_hk BYTEA PRIMARY KEY,
    site_event_hk BYTEA NOT NULL REFERENCES business.site_event_h(site_event_hk),
    site_session_hk BYTEA NOT NULL REFERENCES business.site_session_h(site_session_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    -- Ensure unique relationship per tenant
    CONSTRAINT uk_event_session_tenant UNIQUE (site_event_hk, site_session_hk, tenant_hk)
);

-- Indexes for event-session link
CREATE INDEX IF NOT EXISTS idx_event_session_l_event_hk 
ON business.event_session_l(site_event_hk);

CREATE INDEX IF NOT EXISTS idx_event_session_l_session_hk 
ON business.event_session_l(site_session_hk);

CREATE INDEX IF NOT EXISTS idx_event_session_l_tenant_hk 
ON business.event_session_l(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_event_session_l_load_date 
ON business.event_session_l(load_date);

-- =====================================================
-- LINK 3: Event-Page Link
-- Connects events to the pages where they occurred
-- =====================================================
CREATE TABLE IF NOT EXISTS business.event_page_l (
    link_event_page_hk BYTEA PRIMARY KEY,
    site_event_hk BYTEA NOT NULL REFERENCES business.site_event_h(site_event_hk),
    site_page_hk BYTEA NOT NULL REFERENCES business.site_page_h(site_page_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    -- Ensure unique relationship per tenant
    CONSTRAINT uk_event_page_tenant UNIQUE (site_event_hk, site_page_hk, tenant_hk)
);

-- Indexes for event-page link
CREATE INDEX IF NOT EXISTS idx_event_page_l_event_hk 
ON business.event_page_l(site_event_hk);

CREATE INDEX IF NOT EXISTS idx_event_page_l_page_hk 
ON business.event_page_l(site_page_hk);

CREATE INDEX IF NOT EXISTS idx_event_page_l_tenant_hk 
ON business.event_page_l(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_event_page_l_load_date 
ON business.event_page_l(load_date);

-- =====================================================
-- LINK 4: Event-Business Item Link
-- Connects events to business items (products, services, content, features)
-- =====================================================
CREATE TABLE IF NOT EXISTS business.event_business_item_l (
    link_event_business_item_hk BYTEA PRIMARY KEY,
    site_event_hk BYTEA NOT NULL REFERENCES business.site_event_h(site_event_hk),
    business_item_hk BYTEA NOT NULL REFERENCES business.business_item_h(business_item_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    -- Ensure unique relationship per tenant
    CONSTRAINT uk_event_business_item_tenant UNIQUE (site_event_hk, business_item_hk, tenant_hk)
);

-- Indexes for event-business item link
CREATE INDEX IF NOT EXISTS idx_event_business_item_l_event_hk 
ON business.event_business_item_l(site_event_hk);

CREATE INDEX IF NOT EXISTS idx_event_business_item_l_business_item_hk 
ON business.event_business_item_l(business_item_hk);

CREATE INDEX IF NOT EXISTS idx_event_business_item_l_tenant_hk 
ON business.event_business_item_l(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_event_business_item_l_load_date 
ON business.event_business_item_l(load_date);

-- =====================================================
-- LINK 5: Session-Page Link
-- Connects sessions to pages visited during the session
-- =====================================================
CREATE TABLE IF NOT EXISTS business.session_page_l (
    link_session_page_hk BYTEA PRIMARY KEY,
    site_session_hk BYTEA NOT NULL REFERENCES business.site_session_h(site_session_hk),
    site_page_hk BYTEA NOT NULL REFERENCES business.site_page_h(site_page_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    -- Allow multiple visits to same page in a session
    CONSTRAINT uk_session_page_load_date UNIQUE (site_session_hk, site_page_hk, tenant_hk, load_date)
);

-- Indexes for session-page link
CREATE INDEX IF NOT EXISTS idx_session_page_l_session_hk 
ON business.session_page_l(site_session_hk);

CREATE INDEX IF NOT EXISTS idx_session_page_l_page_hk 
ON business.session_page_l(site_page_hk);

CREATE INDEX IF NOT EXISTS idx_session_page_l_tenant_hk 
ON business.session_page_l(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_session_page_l_load_date 
ON business.session_page_l(load_date);

-- =====================================================
-- LINK 6: Visitor-Business Item Link
-- Connects visitors to business items they've interacted with
-- =====================================================
CREATE TABLE IF NOT EXISTS business.visitor_business_item_l (
    link_visitor_business_item_hk BYTEA PRIMARY KEY,
    site_visitor_hk BYTEA NOT NULL REFERENCES business.site_visitor_h(site_visitor_hk),
    business_item_hk BYTEA NOT NULL REFERENCES business.business_item_h(business_item_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    -- Allow multiple interactions with same item over time
    CONSTRAINT uk_visitor_business_item_load_date UNIQUE (site_visitor_hk, business_item_hk, tenant_hk, load_date)
);

-- Indexes for visitor-business item link
CREATE INDEX IF NOT EXISTS idx_visitor_business_item_l_visitor_hk 
ON business.visitor_business_item_l(site_visitor_hk);

CREATE INDEX IF NOT EXISTS idx_visitor_business_item_l_business_item_hk 
ON business.visitor_business_item_l(business_item_hk);

CREATE INDEX IF NOT EXISTS idx_visitor_business_item_l_tenant_hk 
ON business.visitor_business_item_l(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_visitor_business_item_l_load_date 
ON business.visitor_business_item_l(load_date);

-- =====================================================
-- LINK MANAGEMENT FUNCTIONS
-- =====================================================

-- Function to create or get session-visitor link
CREATE OR REPLACE FUNCTION business.get_or_create_session_visitor_link(
    p_session_hk BYTEA,
    p_visitor_hk BYTEA,
    p_tenant_hk BYTEA,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_link_hk BYTEA;
BEGIN
    -- Generate link hash key
    v_link_hk := util.hash_binary(
        encode(p_session_hk, 'hex') || 
        encode(p_visitor_hk, 'hex') || 
        encode(p_tenant_hk, 'hex')
    );
    
    -- Insert if not exists
    INSERT INTO business.session_visitor_l (
        link_session_visitor_hk, site_session_hk, site_visitor_hk, 
        tenant_hk, load_date, record_source
    ) VALUES (
        v_link_hk, p_session_hk, p_visitor_hk, 
        p_tenant_hk, util.current_load_date(), p_record_source
    ) ON CONFLICT (link_session_visitor_hk) DO NOTHING;
    
    RETURN v_link_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to create or get event-session link
CREATE OR REPLACE FUNCTION business.get_or_create_event_session_link(
    p_event_hk BYTEA,
    p_session_hk BYTEA,
    p_tenant_hk BYTEA,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_link_hk BYTEA;
BEGIN
    -- Generate link hash key
    v_link_hk := util.hash_binary(
        encode(p_event_hk, 'hex') || 
        encode(p_session_hk, 'hex') || 
        encode(p_tenant_hk, 'hex')
    );
    
    -- Insert if not exists
    INSERT INTO business.event_session_l (
        link_event_session_hk, site_event_hk, site_session_hk, 
        tenant_hk, load_date, record_source
    ) VALUES (
        v_link_hk, p_event_hk, p_session_hk, 
        p_tenant_hk, util.current_load_date(), p_record_source
    ) ON CONFLICT (link_event_session_hk) DO NOTHING;
    
    RETURN v_link_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to create or get event-page link
CREATE OR REPLACE FUNCTION business.get_or_create_event_page_link(
    p_event_hk BYTEA,
    p_page_hk BYTEA,
    p_tenant_hk BYTEA,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_link_hk BYTEA;
BEGIN
    -- Generate link hash key
    v_link_hk := util.hash_binary(
        encode(p_event_hk, 'hex') || 
        encode(p_page_hk, 'hex') || 
        encode(p_tenant_hk, 'hex')
    );
    
    -- Insert if not exists
    INSERT INTO business.event_page_l (
        link_event_page_hk, site_event_hk, site_page_hk, 
        tenant_hk, load_date, record_source
    ) VALUES (
        v_link_hk, p_event_hk, p_page_hk, 
        p_tenant_hk, util.current_load_date(), p_record_source
    ) ON CONFLICT (link_event_page_hk) DO NOTHING;
    
    RETURN v_link_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to create or get event-business item link
CREATE OR REPLACE FUNCTION business.get_or_create_event_business_item_link(
    p_event_hk BYTEA,
    p_business_item_hk BYTEA,
    p_tenant_hk BYTEA,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_link_hk BYTEA;
BEGIN
    -- Generate link hash key
    v_link_hk := util.hash_binary(
        encode(p_event_hk, 'hex') || 
        encode(p_business_item_hk, 'hex') || 
        encode(p_tenant_hk, 'hex')
    );
    
    -- Insert if not exists
    INSERT INTO business.event_business_item_l (
        link_event_business_item_hk, site_event_hk, business_item_hk, 
        tenant_hk, load_date, record_source
    ) VALUES (
        v_link_hk, p_event_hk, p_business_item_hk, 
        p_tenant_hk, util.current_load_date(), p_record_source
    ) ON CONFLICT (link_event_business_item_hk) DO NOTHING;
    
    RETURN v_link_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to create or get session-page link
CREATE OR REPLACE FUNCTION business.get_or_create_session_page_link(
    p_session_hk BYTEA,
    p_page_hk BYTEA,
    p_tenant_hk BYTEA,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_link_hk BYTEA;
    v_current_time TIMESTAMP WITH TIME ZONE;
BEGIN
    v_current_time := util.current_load_date();
    
    -- Generate link hash key with timestamp for multiple visits
    v_link_hk := util.hash_binary(
        encode(p_session_hk, 'hex') || 
        encode(p_page_hk, 'hex') || 
        encode(p_tenant_hk, 'hex') ||
        v_current_time::text
    );
    
    -- Insert new link (allows multiple visits to same page)
    INSERT INTO business.session_page_l (
        link_session_page_hk, site_session_hk, site_page_hk, 
        tenant_hk, load_date, record_source
    ) VALUES (
        v_link_hk, p_session_hk, p_page_hk, 
        p_tenant_hk, v_current_time, p_record_source
    );
    
    RETURN v_link_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to create or get visitor-business item link
CREATE OR REPLACE FUNCTION business.get_or_create_visitor_business_item_link(
    p_visitor_hk BYTEA,
    p_business_item_hk BYTEA,
    p_tenant_hk BYTEA,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_link_hk BYTEA;
    v_current_time TIMESTAMP WITH TIME ZONE;
BEGIN
    v_current_time := util.current_load_date();
    
    -- Generate link hash key with timestamp for multiple interactions
    v_link_hk := util.hash_binary(
        encode(p_visitor_hk, 'hex') || 
        encode(p_business_item_hk, 'hex') || 
        encode(p_tenant_hk, 'hex') ||
        v_current_time::text
    );
    
    -- Insert new link (allows multiple interactions with same item)
    INSERT INTO business.visitor_business_item_l (
        link_visitor_business_item_hk, site_visitor_hk, business_item_hk, 
        tenant_hk, load_date, record_source
    ) VALUES (
        v_link_hk, p_visitor_hk, p_business_item_hk, 
        p_tenant_hk, v_current_time, p_record_source
    );
    
    RETURN v_link_hk;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- COMPREHENSIVE LINK CREATION FUNCTION
-- =====================================================

-- Function to create all relevant links for a tracking event
CREATE OR REPLACE FUNCTION business.create_tracking_event_links(
    p_tenant_hk BYTEA,
    p_session_id VARCHAR(255),
    p_visitor_id VARCHAR(255),
    p_event_timestamp TIMESTAMP WITH TIME ZONE,
    p_event_type VARCHAR(50),
    p_page_url VARCHAR(500),
    p_business_item_name VARCHAR(255) DEFAULT NULL,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS TABLE (
    session_visitor_link_hk BYTEA,
    event_session_link_hk BYTEA,
    event_page_link_hk BYTEA,
    event_business_item_link_hk BYTEA,
    session_page_link_hk BYTEA,
    visitor_business_item_link_hk BYTEA
) AS $$
DECLARE
    v_session_hk BYTEA;
    v_visitor_hk BYTEA;
    v_event_hk BYTEA;
    v_page_hk BYTEA;
    v_business_item_hk BYTEA;
    v_event_bk VARCHAR(255);
    v_session_visitor_link_hk BYTEA;
    v_event_session_link_hk BYTEA;
    v_event_page_link_hk BYTEA;
    v_event_business_item_link_hk BYTEA;
    v_session_page_link_hk BYTEA;
    v_visitor_business_item_link_hk BYTEA;
BEGIN
    -- Get or create hub records
    v_session_hk := business.get_or_create_site_session_hk(p_session_id, p_tenant_hk, p_record_source);
    v_visitor_hk := business.get_or_create_site_visitor_hk(p_visitor_id, p_tenant_hk, p_record_source);
    v_page_hk := business.get_or_create_site_page_hk(p_page_url, p_tenant_hk, p_record_source);
    
    -- Create event business key and hash key
    v_event_bk := 'evt_' || to_char(p_event_timestamp, 'YYYYMMDD_HH24MISS_US') || '_' || 
                  p_session_id || '_' || p_event_type;
    v_event_hk := business.get_or_create_site_event_hk(v_event_bk, p_tenant_hk, p_record_source);
    
    -- Create business item if specified
    IF p_business_item_name IS NOT NULL THEN
        v_business_item_hk := business.get_or_create_business_item_hk(
            p_business_item_name, p_tenant_hk, p_record_source
        );
    END IF;
    
    -- Create all relevant links
    
    -- 1. Session-Visitor Link (one per session-visitor combination)
    v_session_visitor_link_hk := business.get_or_create_session_visitor_link(
        v_session_hk, v_visitor_hk, p_tenant_hk, p_record_source
    );
    
    -- 2. Event-Session Link (connects this event to session)
    v_event_session_link_hk := business.get_or_create_event_session_link(
        v_event_hk, v_session_hk, p_tenant_hk, p_record_source
    );
    
    -- 3. Event-Page Link (connects this event to page)
    v_event_page_link_hk := business.get_or_create_event_page_link(
        v_event_hk, v_page_hk, p_tenant_hk, p_record_source
    );
    
    -- 4. Session-Page Link (connects session to page visited)
    v_session_page_link_hk := business.get_or_create_session_page_link(
        v_session_hk, v_page_hk, p_tenant_hk, p_record_source
    );
    
    -- 5. Event-Business Item Link (if business item involved)
    IF v_business_item_hk IS NOT NULL THEN
        v_event_business_item_link_hk := business.get_or_create_event_business_item_link(
            v_event_hk, v_business_item_hk, p_tenant_hk, p_record_source
        );
        
        -- 6. Visitor-Business Item Link (tracks visitor interest in items)
        v_visitor_business_item_link_hk := business.get_or_create_visitor_business_item_link(
            v_visitor_hk, v_business_item_hk, p_tenant_hk, p_record_source
        );
    END IF;
    
    RETURN QUERY SELECT 
        v_session_visitor_link_hk,
        v_event_session_link_hk,
        v_event_page_link_hk,
        v_event_business_item_link_hk,
        v_session_page_link_hk,
        v_visitor_business_item_link_hk;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- LINK STATISTICS AND MONITORING FUNCTIONS
-- =====================================================

-- Function to get link table statistics
CREATE OR REPLACE FUNCTION business.get_link_statistics(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_hours_back INTEGER DEFAULT 24
) RETURNS TABLE (
    link_table VARCHAR(100),
    total_links BIGINT,
    unique_relationships BIGINT,
    recent_activity BIGINT,
    growth_rate DECIMAL(5,2)
) AS $$
DECLARE
    v_cutoff_time TIMESTAMP WITH TIME ZONE;
BEGIN
    v_cutoff_time := CURRENT_TIMESTAMP - INTERVAL '1 hour' * p_hours_back;
    
    RETURN QUERY
    WITH link_stats AS (
        SELECT 'session_visitor_l' as link_table,
               COUNT(*) as total_links,
               COUNT(DISTINCT (site_session_hk, site_visitor_hk)) as unique_relationships,
               COUNT(*) FILTER (WHERE load_date >= v_cutoff_time) as recent_activity
        FROM business.session_visitor_l
        WHERE (p_tenant_hk IS NULL OR tenant_hk = p_tenant_hk)
        
        UNION ALL
        
        SELECT 'event_session_l' as link_table,
               COUNT(*) as total_links,
               COUNT(DISTINCT (site_event_hk, site_session_hk)) as unique_relationships,
               COUNT(*) FILTER (WHERE load_date >= v_cutoff_time) as recent_activity
        FROM business.event_session_l
        WHERE (p_tenant_hk IS NULL OR tenant_hk = p_tenant_hk)
        
        UNION ALL
        
        SELECT 'event_page_l' as link_table,
               COUNT(*) as total_links,
               COUNT(DISTINCT (site_event_hk, site_page_hk)) as unique_relationships,
               COUNT(*) FILTER (WHERE load_date >= v_cutoff_time) as recent_activity
        FROM business.event_page_l
        WHERE (p_tenant_hk IS NULL OR tenant_hk = p_tenant_hk)
        
        UNION ALL
        
        SELECT 'event_business_item_l' as link_table,
               COUNT(*) as total_links,
               COUNT(DISTINCT (site_event_hk, business_item_hk)) as unique_relationships,
               COUNT(*) FILTER (WHERE load_date >= v_cutoff_time) as recent_activity
        FROM business.event_business_item_l
        WHERE (p_tenant_hk IS NULL OR tenant_hk = p_tenant_hk)
        
        UNION ALL
        
        SELECT 'session_page_l' as link_table,
               COUNT(*) as total_links,
               COUNT(DISTINCT (site_session_hk, site_page_hk)) as unique_relationships,
               COUNT(*) FILTER (WHERE load_date >= v_cutoff_time) as recent_activity
        FROM business.session_page_l
        WHERE (p_tenant_hk IS NULL OR tenant_hk = p_tenant_hk)
        
        UNION ALL
        
        SELECT 'visitor_business_item_l' as link_table,
               COUNT(*) as total_links,
               COUNT(DISTINCT (site_visitor_hk, business_item_hk)) as unique_relationships,
               COUNT(*) FILTER (WHERE load_date >= v_cutoff_time) as recent_activity
        FROM business.visitor_business_item_l
        WHERE (p_tenant_hk IS NULL OR tenant_hk = p_tenant_hk)
    )
    SELECT 
        ls.link_table,
        ls.total_links,
        ls.unique_relationships,
        ls.recent_activity,
        ROUND(
            CASE WHEN ls.total_links > 0 THEN
                ls.recent_activity * 100.0 / ls.total_links
            ELSE 0 END, 2
        ) as growth_rate
    FROM link_stats ls
    ORDER BY ls.total_links DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to analyze relationship patterns
CREATE OR REPLACE FUNCTION business.analyze_visitor_journey_patterns(
    p_tenant_hk BYTEA,
    p_hours_back INTEGER DEFAULT 168  -- Default 1 week
) RETURNS TABLE (
    pattern_type VARCHAR(50),
    pattern_description VARCHAR(200),
    occurrence_count BIGINT,
    avg_session_duration_minutes DECIMAL(10,2),
    conversion_indicator BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    WITH visitor_sessions AS (
        SELECT 
            svl.site_visitor_hk,
            svl.site_session_hk,
            COUNT(DISTINCT esl.site_event_hk) as event_count,
            COUNT(DISTINCT spl.site_page_hk) as page_count,
            COUNT(DISTINCT ebil.business_item_hk) as item_count,
            EXISTS(
                SELECT 1 FROM business.event_business_item_l ebil2
                JOIN business.site_event_h seh ON ebil2.site_event_hk = seh.site_event_hk
                WHERE ebil2.site_session_hk = svl.site_session_hk
                AND seh.site_event_bk LIKE '%transaction%'
            ) as has_transaction
        FROM business.session_visitor_l svl
        LEFT JOIN business.event_session_l esl ON svl.site_session_hk = esl.site_session_hk
        LEFT JOIN business.session_page_l spl ON svl.site_session_hk = spl.site_session_hk
        LEFT JOIN business.event_business_item_l ebil ON esl.site_event_hk = ebil.site_event_hk
        WHERE svl.tenant_hk = p_tenant_hk
        AND svl.load_date >= CURRENT_TIMESTAMP - INTERVAL '1 hour' * p_hours_back
        GROUP BY svl.site_visitor_hk, svl.site_session_hk
    )
    SELECT 
        'single_page_session' as pattern_type,
        'Visitors who viewed only one page' as pattern_description,
        COUNT(*) as occurrence_count,
        0.0 as avg_session_duration_minutes,
        false as conversion_indicator
    FROM visitor_sessions
    WHERE page_count = 1 AND event_count <= 2
    
    UNION ALL
    
    SELECT 
        'multi_page_browser' as pattern_type,
        'Visitors who browsed multiple pages without item interaction' as pattern_description,
        COUNT(*) as occurrence_count,
        0.0 as avg_session_duration_minutes,
        false as conversion_indicator
    FROM visitor_sessions
    WHERE page_count > 3 AND item_count = 0
    
    UNION ALL
    
    SELECT 
        'item_explorer' as pattern_type,
        'Visitors who interacted with multiple items' as pattern_description,
        COUNT(*) as occurrence_count,
        0.0 as avg_session_duration_minutes,
        BOOL_OR(has_transaction) as conversion_indicator
    FROM visitor_sessions
    WHERE item_count > 2
    
    UNION ALL
    
    SELECT 
        'converter' as pattern_type,
        'Visitors who completed transactions' as pattern_description,
        COUNT(*) as occurrence_count,
        0.0 as avg_session_duration_minutes,
        true as conversion_indicator
    FROM visitor_sessions
    WHERE has_transaction = true
    
    ORDER BY occurrence_count DESC;
END;
$$ LANGUAGE plpgsql;

-- Add table comments for documentation
COMMENT ON TABLE business.session_visitor_l IS 
'Data Vault 2.0 link table connecting site sessions to visitors. Maintains tenant isolation and supports multi-session visitor tracking with privacy compliance.';

COMMENT ON TABLE business.event_session_l IS 
'Data Vault 2.0 link table connecting tracking events to sessions. Essential for session-based analytics and visitor journey mapping.';

COMMENT ON TABLE business.event_page_l IS 
'Data Vault 2.0 link table connecting events to pages. Enables page-level analytics and user interaction tracking across the site.';

COMMENT ON TABLE business.event_business_item_l IS 
'Data Vault 2.0 link table connecting events to business items (products, services, content, features). Universal support for multi-industry analytics.';

COMMENT ON FUNCTION business.create_tracking_event_links IS 
'Creates all relevant Data Vault 2.0 link relationships for a tracking event. Comprehensive function for maintaining entity relationships in universal site tracking.';

COMMENT ON FUNCTION business.get_link_statistics IS 
'Provides comprehensive statistics on Data Vault 2.0 link table activity including growth rates and relationship counts for monitoring and optimization.';

-- Grant appropriate permissions
-- These would be set based on your security model
-- GRANT USAGE ON SCHEMA business TO tracking_processor_role;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA business TO tracking_processor_role;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA business TO tracking_processor_role;

-- =====================================================
-- BUSINESS LINKS LAYER COMPLETE
-- Universal site tracking Data Vault 2.0 relationships
-- Ready for satellite data and comprehensive analytics
-- ===================================================== 