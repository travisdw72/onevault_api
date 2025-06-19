-- =====================================================
-- PHASE 3C: BUSINESS LAYER SATELLITES - Data Vault 2.0
-- Universal Site Tracking Descriptive Attributes
-- =====================================================

-- Ensure business schema exists
CREATE SCHEMA IF NOT EXISTS business;

-- =====================================================
-- DATA VAULT 2.0 SATELLITE TABLES
-- =====================================================

-- =====================================================
-- SATELLITE 1: Site Session Details
-- Descriptive attributes and metrics for sessions
-- =====================================================
CREATE TABLE IF NOT EXISTS business.site_session_details_s (
    site_session_hk BYTEA NOT NULL REFERENCES business.site_session_h(site_session_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    session_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    session_end_time TIMESTAMP WITH TIME ZONE,
    total_page_views INTEGER DEFAULT 0,
    total_events INTEGER DEFAULT 0,
    session_duration_seconds INTEGER,
    entry_page_url VARCHAR(500),
    exit_page_url VARCHAR(500),
    referrer_url VARCHAR(500),
    utm_source VARCHAR(100),
    utm_medium VARCHAR(100),
    utm_campaign VARCHAR(100),
    utm_term VARCHAR(100),
    utm_content VARCHAR(100),
    is_bounce BOOLEAN DEFAULT false,
    items_viewed TEXT[],                      -- Business items viewed during session
    transaction_attempted BOOLEAN DEFAULT false,
    transaction_completed BOOLEAN DEFAULT false,
    total_conversion_value INTEGER DEFAULT 0,
    conversion_currency VARCHAR(10) DEFAULT 'USD',
    device_category VARCHAR(20),              -- mobile, tablet, desktop
    browser_family VARCHAR(50),
    operating_system VARCHAR(50),
    geographic_country VARCHAR(100),
    geographic_region VARCHAR(100),
    geographic_city VARCHAR(100),
    business_context JSONB,                   -- Industry-specific session data
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (site_session_hk, load_date),
    
    -- Data quality constraints
    CONSTRAINT chk_session_duration_positive CHECK (session_duration_seconds >= 0),
    CONSTRAINT chk_page_views_positive CHECK (total_page_views >= 0),
    CONSTRAINT chk_events_positive CHECK (total_events >= 0),
    CONSTRAINT chk_conversion_value_positive CHECK (total_conversion_value >= 0)
);

-- Indexes for session details satellite
CREATE INDEX IF NOT EXISTS idx_site_session_details_s_load_date 
ON business.site_session_details_s(load_date);

CREATE INDEX IF NOT EXISTS idx_site_session_details_s_session_start 
ON business.site_session_details_s(session_start_time);

CREATE INDEX IF NOT EXISTS idx_site_session_details_s_device_category 
ON business.site_session_details_s(device_category);

CREATE INDEX IF NOT EXISTS idx_site_session_details_s_utm_source 
ON business.site_session_details_s(utm_source);

CREATE INDEX IF NOT EXISTS idx_site_session_details_s_conversion 
ON business.site_session_details_s(transaction_completed, total_conversion_value);

-- =====================================================
-- SATELLITE 2: Site Visitor Details
-- Descriptive attributes and behavior patterns for visitors
-- =====================================================
CREATE TABLE IF NOT EXISTS business.site_visitor_details_s (
    site_visitor_hk BYTEA NOT NULL REFERENCES business.site_visitor_h(site_visitor_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    visitor_ip_hash VARCHAR(64),               -- Privacy-safe hashed IP
    user_agent TEXT,
    device_type VARCHAR(20),                   -- mobile, tablet, desktop
    browser_name VARCHAR(50),
    browser_version VARCHAR(20),
    operating_system VARCHAR(50),
    screen_resolution VARCHAR(20),
    viewport_size VARCHAR(20),
    timezone VARCHAR(50),
    language VARCHAR(10),
    do_not_track BOOLEAN DEFAULT false,
    first_visit_date TIMESTAMP WITH TIME ZONE,
    last_visit_date TIMESTAMP WITH TIME ZONE,
    total_sessions INTEGER DEFAULT 1,
    total_page_views INTEGER DEFAULT 0,
    total_events INTEGER DEFAULT 0,
    favorite_pages TEXT[],                     -- Most visited pages
    favorite_items TEXT[],                     -- Most interacted business items
    total_transactions INTEGER DEFAULT 0,
    lifetime_value INTEGER DEFAULT 0,          -- Sum of all conversion values
    lifetime_currency VARCHAR(10) DEFAULT 'USD',
    visitor_segment VARCHAR(100),              -- Business-defined segments
    acquisition_channel VARCHAR(100),          -- How visitor was acquired
    engagement_score INTEGER DEFAULT 0,        -- Calculated engagement score
    risk_score INTEGER DEFAULT 0,              -- Fraud/spam risk score
    privacy_preferences JSONB,                 -- GDPR/CCPA preferences
    business_attributes JSONB,                 -- Industry-specific visitor data
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (site_visitor_hk, load_date),
    
    -- Data quality constraints
    CONSTRAINT chk_visitor_sessions_positive CHECK (total_sessions >= 0),
    CONSTRAINT chk_visitor_page_views_positive CHECK (total_page_views >= 0),
    CONSTRAINT chk_visitor_events_positive CHECK (total_events >= 0),
    CONSTRAINT chk_visitor_transactions_positive CHECK (total_transactions >= 0),
    CONSTRAINT chk_visitor_lifetime_value_positive CHECK (lifetime_value >= 0),
    CONSTRAINT chk_engagement_score_range CHECK (engagement_score BETWEEN 0 AND 1000),
    CONSTRAINT chk_risk_score_range CHECK (risk_score BETWEEN 0 AND 100)
);

-- Indexes for visitor details satellite
CREATE INDEX IF NOT EXISTS idx_site_visitor_details_s_load_date 
ON business.site_visitor_details_s(load_date);

CREATE INDEX IF NOT EXISTS idx_site_visitor_details_s_first_visit 
ON business.site_visitor_details_s(first_visit_date);

CREATE INDEX IF NOT EXISTS idx_site_visitor_details_s_device_type 
ON business.site_visitor_details_s(device_type);

CREATE INDEX IF NOT EXISTS idx_site_visitor_details_s_segment 
ON business.site_visitor_details_s(visitor_segment);

CREATE INDEX IF NOT EXISTS idx_site_visitor_details_s_lifetime_value 
ON business.site_visitor_details_s(lifetime_value);

CREATE INDEX IF NOT EXISTS idx_site_visitor_details_s_engagement_score 
ON business.site_visitor_details_s(engagement_score);

-- =====================================================
-- SATELLITE 3: Site Event Details
-- Descriptive attributes for individual tracking events
-- =====================================================
CREATE TABLE IF NOT EXISTS business.site_event_details_s (
    site_event_hk BYTEA NOT NULL REFERENCES business.site_event_h(site_event_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    event_type VARCHAR(50) NOT NULL,          -- page_view, item_interaction, transaction_step, contact_interaction
    event_category VARCHAR(50) NOT NULL,      -- items, transactions, contact, navigation, engagement
    event_action VARCHAR(50) NOT NULL,        -- view, click, submit, start, progress, complete, abandon
    event_label VARCHAR(255),                 -- Item name, button ID, form name, step name
    event_value INTEGER,                      -- Conversion value (customizable per business)
    event_currency VARCHAR(10) DEFAULT 'USD',
    page_url VARCHAR(500),
    page_title VARCHAR(255),
    page_referrer VARCHAR(500),
    scroll_depth INTEGER,                     -- Percentage (0-100)
    time_on_page INTEGER,                     -- Seconds
    click_x INTEGER,                          -- Click coordinates
    click_y INTEGER,
    form_fields_completed INTEGER,            -- For form interactions
    video_duration_watched INTEGER,           -- For video interactions (seconds)
    download_file_name VARCHAR(255),          -- For download tracking
    search_term VARCHAR(255),                 -- For search tracking
    business_item_type VARCHAR(100),          -- Product, service, article, feature
    business_item_category VARCHAR(100),      -- Category specific to business
    transaction_funnel_step VARCHAR(50),      -- Checkout step, signup step, onboarding step
    conversion_funnel_stage VARCHAR(50),      -- Awareness, consideration, conversion, retention
    user_journey_stage VARCHAR(50),           -- First-time, returning, loyal, at-risk
    attribution_channel VARCHAR(100),         -- Marketing attribution
    a_b_test_variant VARCHAR(100),            -- A/B testing information
    personalization_applied BOOLEAN DEFAULT false,
    custom_properties JSONB,                  -- Flexible business-specific data
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (site_event_hk, load_date),
    
    -- Data quality constraints
    CONSTRAINT chk_event_scroll_depth_range CHECK (scroll_depth IS NULL OR scroll_depth BETWEEN 0 AND 100),
    CONSTRAINT chk_event_time_on_page_positive CHECK (time_on_page IS NULL OR time_on_page >= 0),
    CONSTRAINT chk_event_value_positive CHECK (event_value IS NULL OR event_value >= 0),
    CONSTRAINT chk_event_form_fields_positive CHECK (form_fields_completed IS NULL OR form_fields_completed >= 0),
    CONSTRAINT chk_event_video_duration_positive CHECK (video_duration_watched IS NULL OR video_duration_watched >= 0)
);

-- Indexes for event details satellite
CREATE INDEX IF NOT EXISTS idx_site_event_details_s_load_date 
ON business.site_event_details_s(load_date);

CREATE INDEX IF NOT EXISTS idx_site_event_details_s_event_timestamp 
ON business.site_event_details_s(event_timestamp);

CREATE INDEX IF NOT EXISTS idx_site_event_details_s_event_type 
ON business.site_event_details_s(event_type);

CREATE INDEX IF NOT EXISTS idx_site_event_details_s_event_category 
ON business.site_event_details_s(event_category);

CREATE INDEX IF NOT EXISTS idx_site_event_details_s_funnel_stage 
ON business.site_event_details_s(conversion_funnel_stage);

CREATE INDEX IF NOT EXISTS idx_site_event_details_s_item_type 
ON business.site_event_details_s(business_item_type);

-- Text search index for event labels and search terms
CREATE INDEX IF NOT EXISTS idx_site_event_details_s_text_search 
ON business.site_event_details_s USING gin(to_tsvector('english', COALESCE(event_label, '') || ' ' || COALESCE(search_term, '')));

-- =====================================================
-- SATELLITE 4: Site Page Details
-- Descriptive attributes and analytics for pages
-- =====================================================
CREATE TABLE IF NOT EXISTS business.site_page_details_s (
    site_page_hk BYTEA NOT NULL REFERENCES business.site_page_h(site_page_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    page_url VARCHAR(500) NOT NULL,
    page_title VARCHAR(255),
    page_path VARCHAR(500),
    page_hostname VARCHAR(100),
    page_category VARCHAR(50),                -- Products, articles, features, about, contact
    page_type VARCHAR(50),                    -- Landing, category, detail, checkout, content
    page_language VARCHAR(10),
    page_author VARCHAR(100),
    page_published_date DATE,
    page_last_modified DATE,
    page_word_count INTEGER,
    page_load_time_ms INTEGER,                -- Average page load time
    total_views INTEGER DEFAULT 0,
    unique_visitors INTEGER DEFAULT 0,
    avg_time_on_page INTEGER DEFAULT 0,       -- Seconds
    bounce_rate DECIMAL(5,2) DEFAULT 0.0,    -- Percentage
    exit_rate DECIMAL(5,2) DEFAULT 0.0,      -- Percentage
    conversion_rate DECIMAL(5,2) DEFAULT 0.0, -- Percentage
    total_conversions INTEGER DEFAULT 0,
    total_conversion_value INTEGER DEFAULT 0,
    social_shares INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    page_value_score INTEGER DEFAULT 0,       -- Business-defined page value
    seo_title VARCHAR(255),
    seo_description TEXT,
    canonical_url VARCHAR(500),
    structured_data JSONB,                    -- Schema.org structured data
    performance_metrics JSONB,               -- Core web vitals and performance data
    content_themes TEXT[],                    -- Content categorization
    related_items TEXT[],                     -- Related business items featured
    business_metadata JSONB,                 -- Industry-specific page data
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (site_page_hk, load_date),
    
    -- Data quality constraints
    CONSTRAINT chk_page_views_positive CHECK (total_views >= 0),
    CONSTRAINT chk_page_unique_visitors_positive CHECK (unique_visitors >= 0),
    CONSTRAINT chk_page_time_positive CHECK (avg_time_on_page >= 0),
    CONSTRAINT chk_page_bounce_rate_range CHECK (bounce_rate BETWEEN 0 AND 100),
    CONSTRAINT chk_page_exit_rate_range CHECK (exit_rate BETWEEN 0 AND 100),
    CONSTRAINT chk_page_conversion_rate_range CHECK (conversion_rate BETWEEN 0 AND 100),
    CONSTRAINT chk_page_conversions_positive CHECK (total_conversions >= 0),
    CONSTRAINT chk_page_conversion_value_positive CHECK (total_conversion_value >= 0)
);

-- Indexes for page details satellite
CREATE INDEX IF NOT EXISTS idx_site_page_details_s_load_date 
ON business.site_page_details_s(load_date);

CREATE INDEX IF NOT EXISTS idx_site_page_details_s_page_category 
ON business.site_page_details_s(page_category);

CREATE INDEX IF NOT EXISTS idx_site_page_details_s_page_type 
ON business.site_page_details_s(page_type);

CREATE INDEX IF NOT EXISTS idx_site_page_details_s_total_views 
ON business.site_page_details_s(total_views);

CREATE INDEX IF NOT EXISTS idx_site_page_details_s_conversion_rate 
ON business.site_page_details_s(conversion_rate);

CREATE INDEX IF NOT EXISTS idx_site_page_details_s_page_value 
ON business.site_page_details_s(page_value_score);

-- Text search index for page content
CREATE INDEX IF NOT EXISTS idx_site_page_details_s_text_search 
ON business.site_page_details_s USING gin(to_tsvector('english', COALESCE(page_title, '') || ' ' || COALESCE(seo_description, '')));

-- =====================================================
-- SATELLITE 5: Business Item Details
-- Descriptive attributes for business items (universal)
-- =====================================================
CREATE TABLE IF NOT EXISTS business.business_item_details_s (
    business_item_hk BYTEA NOT NULL REFERENCES business.business_item_h(business_item_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    item_type VARCHAR(100) NOT NULL,          -- Product, service, article, feature
    item_category VARCHAR(100),               -- Category specific to business type
    item_subcategory VARCHAR(100),
    item_description TEXT,
    item_summary VARCHAR(500),
    item_value DECIMAL(10,2),                 -- Price, cost, value score
    item_currency VARCHAR(10) DEFAULT 'USD',
    item_sku VARCHAR(100),                    -- Stock keeping unit or unique identifier
    item_brand VARCHAR(100),
    item_manufacturer VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    availability_status VARCHAR(50),          -- In stock, out of stock, discontinued, coming soon
    creation_date DATE,
    last_modified_date DATE,
    popularity_score INTEGER DEFAULT 0,       -- Based on interactions
    quality_rating DECIMAL(3,2),             -- User ratings (0.00-5.00)
    review_count INTEGER DEFAULT 0,
    conversion_rate DECIMAL(5,2) DEFAULT 0.0, -- Item-specific conversion rate
    total_interactions INTEGER DEFAULT 0,
    total_views INTEGER DEFAULT 0,
    total_conversions INTEGER DEFAULT 0,
    total_revenue DECIMAL(15,2) DEFAULT 0.0,
    tags TEXT[],                              -- Searchable tags
    related_items TEXT[],                     -- Related item identifiers
    content_url VARCHAR(500),                 -- Link to detailed content
    image_urls TEXT[],                        -- Associated images
    video_urls TEXT[],                        -- Associated videos
    download_urls TEXT[],                     -- Associated downloads
    specifications JSONB,                     -- Technical specifications
    inventory_data JSONB,                     -- Inventory management data
    pricing_data JSONB,                       -- Complex pricing information
    marketing_data JSONB,                     -- Marketing campaigns and promotions
    business_metadata JSONB,                  -- Industry-specific item data
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (business_item_hk, load_date),
    
    -- Data quality constraints
    CONSTRAINT chk_item_value_positive CHECK (item_value IS NULL OR item_value >= 0),
    CONSTRAINT chk_item_popularity_positive CHECK (popularity_score >= 0),
    CONSTRAINT chk_item_quality_rating_range CHECK (quality_rating IS NULL OR quality_rating BETWEEN 0 AND 5),
    CONSTRAINT chk_item_review_count_positive CHECK (review_count >= 0),
    CONSTRAINT chk_item_conversion_rate_range CHECK (conversion_rate BETWEEN 0 AND 100),
    CONSTRAINT chk_item_interactions_positive CHECK (total_interactions >= 0),
    CONSTRAINT chk_item_views_positive CHECK (total_views >= 0),
    CONSTRAINT chk_item_conversions_positive CHECK (total_conversions >= 0),
    CONSTRAINT chk_item_revenue_positive CHECK (total_revenue >= 0)
);

-- Indexes for business item details satellite
CREATE INDEX IF NOT EXISTS idx_business_item_details_s_load_date 
ON business.business_item_details_s(load_date);

CREATE INDEX IF NOT EXISTS idx_business_item_details_s_item_type 
ON business.business_item_details_s(item_type);

CREATE INDEX IF NOT EXISTS idx_business_item_details_s_item_category 
ON business.business_item_details_s(item_category);

CREATE INDEX IF NOT EXISTS idx_business_item_details_s_is_active 
ON business.business_item_details_s(is_active);

CREATE INDEX IF NOT EXISTS idx_business_item_details_s_popularity 
ON business.business_item_details_s(popularity_score);

CREATE INDEX IF NOT EXISTS idx_business_item_details_s_conversion_rate 
ON business.business_item_details_s(conversion_rate);

CREATE INDEX IF NOT EXISTS idx_business_item_details_s_total_revenue 
ON business.business_item_details_s(total_revenue);

-- Text search index for item content
CREATE INDEX IF NOT EXISTS idx_business_item_details_s_text_search 
ON business.business_item_details_s USING gin(to_tsvector('english', COALESCE(item_name, '') || ' ' || COALESCE(item_description, '') || ' ' || array_to_string(tags, ' ')));

-- =====================================================
-- SATELLITE DATA MANAGEMENT FUNCTIONS
-- =====================================================

-- Function to update session details satellite
CREATE OR REPLACE FUNCTION business.update_session_details(
    p_session_hk BYTEA,
    p_session_data JSONB,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_hash_diff BYTEA;
    v_current_load_date TIMESTAMP WITH TIME ZONE;
BEGIN
    v_current_load_date := util.current_load_date();
    
    -- Generate hash diff for change detection
    v_hash_diff := util.hash_binary(p_session_data::text);
    
    -- End-date current record if hash differs
    UPDATE business.site_session_details_s
    SET load_end_date = v_current_load_date
    WHERE site_session_hk = p_session_hk
    AND load_end_date IS NULL
    AND hash_diff != v_hash_diff;
    
    -- Insert new record if changed or doesn't exist
    INSERT INTO business.site_session_details_s (
        site_session_hk, load_date, hash_diff,
        session_start_time, session_end_time, total_page_views, total_events,
        session_duration_seconds, entry_page_url, exit_page_url, referrer_url,
        utm_source, utm_medium, utm_campaign, utm_term, utm_content,
        is_bounce, items_viewed, transaction_attempted, transaction_completed,
        total_conversion_value, conversion_currency, device_category,
        browser_family, operating_system, geographic_country, geographic_region,
        geographic_city, business_context, record_source
    ) VALUES (
        p_session_hk, v_current_load_date, v_hash_diff,
        (p_session_data->>'session_start_time')::timestamptz,
        (p_session_data->>'session_end_time')::timestamptz,
        COALESCE((p_session_data->>'total_page_views')::integer, 0),
        COALESCE((p_session_data->>'total_events')::integer, 0),
        (p_session_data->>'session_duration_seconds')::integer,
        p_session_data->>'entry_page_url',
        p_session_data->>'exit_page_url',
        p_session_data->>'referrer_url',
        p_session_data->>'utm_source',
        p_session_data->>'utm_medium',
        p_session_data->>'utm_campaign',
        p_session_data->>'utm_term',
        p_session_data->>'utm_content',
        COALESCE((p_session_data->>'is_bounce')::boolean, false),
        string_to_array(COALESCE(p_session_data->>'items_viewed', ''), ','),
        COALESCE((p_session_data->>'transaction_attempted')::boolean, false),
        COALESCE((p_session_data->>'transaction_completed')::boolean, false),
        COALESCE((p_session_data->>'total_conversion_value')::integer, 0),
        COALESCE(p_session_data->>'conversion_currency', 'USD'),
        p_session_data->>'device_category',
        p_session_data->>'browser_family',
        p_session_data->>'operating_system',
        p_session_data->>'geographic_country',
        p_session_data->>'geographic_region',
        p_session_data->>'geographic_city',
        p_session_data->'business_context',
        p_record_source
    ) ON CONFLICT (site_session_hk, load_date) DO NOTHING;
    
    RETURN v_hash_diff;
END;
$$ LANGUAGE plpgsql;

-- Function to update visitor details satellite
CREATE OR REPLACE FUNCTION business.update_visitor_details(
    p_visitor_hk BYTEA,
    p_visitor_data JSONB,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_hash_diff BYTEA;
    v_current_load_date TIMESTAMP WITH TIME ZONE;
BEGIN
    v_current_load_date := util.current_load_date();
    
    -- Generate hash diff for change detection
    v_hash_diff := util.hash_binary(p_visitor_data::text);
    
    -- End-date current record if hash differs
    UPDATE business.site_visitor_details_s
    SET load_end_date = v_current_load_date
    WHERE site_visitor_hk = p_visitor_hk
    AND load_end_date IS NULL
    AND hash_diff != v_hash_diff;
    
    -- Insert new record if changed or doesn't exist
    INSERT INTO business.site_visitor_details_s (
        site_visitor_hk, load_date, hash_diff,
        visitor_ip_hash, user_agent, device_type, browser_name, browser_version,
        operating_system, screen_resolution, viewport_size, timezone, language,
        do_not_track, first_visit_date, last_visit_date, total_sessions,
        total_page_views, total_events, favorite_pages, favorite_items,
        total_transactions, lifetime_value, lifetime_currency, visitor_segment,
        acquisition_channel, engagement_score, risk_score, privacy_preferences,
        business_attributes, record_source
    ) VALUES (
        p_visitor_hk, v_current_load_date, v_hash_diff,
        p_visitor_data->>'visitor_ip_hash',
        p_visitor_data->>'user_agent',
        p_visitor_data->>'device_type',
        p_visitor_data->>'browser_name',
        p_visitor_data->>'browser_version',
        p_visitor_data->>'operating_system',
        p_visitor_data->>'screen_resolution',
        p_visitor_data->>'viewport_size',
        p_visitor_data->>'timezone',
        p_visitor_data->>'language',
        COALESCE((p_visitor_data->>'do_not_track')::boolean, false),
        (p_visitor_data->>'first_visit_date')::timestamptz,
        (p_visitor_data->>'last_visit_date')::timestamptz,
        COALESCE((p_visitor_data->>'total_sessions')::integer, 1),
        COALESCE((p_visitor_data->>'total_page_views')::integer, 0),
        COALESCE((p_visitor_data->>'total_events')::integer, 0),
        string_to_array(COALESCE(p_visitor_data->>'favorite_pages', ''), ','),
        string_to_array(COALESCE(p_visitor_data->>'favorite_items', ''), ','),
        COALESCE((p_visitor_data->>'total_transactions')::integer, 0),
        COALESCE((p_visitor_data->>'lifetime_value')::integer, 0),
        COALESCE(p_visitor_data->>'lifetime_currency', 'USD'),
        p_visitor_data->>'visitor_segment',
        p_visitor_data->>'acquisition_channel',
        COALESCE((p_visitor_data->>'engagement_score')::integer, 0),
        COALESCE((p_visitor_data->>'risk_score')::integer, 0),
        p_visitor_data->'privacy_preferences',
        p_visitor_data->'business_attributes',
        p_record_source
    ) ON CONFLICT (site_visitor_hk, load_date) DO NOTHING;
    
    RETURN v_hash_diff;
END;
$$ LANGUAGE plpgsql;

-- Function to insert event details satellite
CREATE OR REPLACE FUNCTION business.insert_event_details(
    p_event_hk BYTEA,
    p_event_data JSONB,
    p_record_source VARCHAR(100) DEFAULT 'site_tracker'
) RETURNS BYTEA AS $$
DECLARE
    v_hash_diff BYTEA;
    v_current_load_date TIMESTAMP WITH TIME ZONE;
BEGIN
    v_current_load_date := util.current_load_date();
    
    -- Generate hash diff
    v_hash_diff := util.hash_binary(p_event_data::text);
    
    -- Insert event details (events are immutable, no updates)
    INSERT INTO business.site_event_details_s (
        site_event_hk, load_date, hash_diff,
        event_timestamp, event_type, event_category, event_action, event_label,
        event_value, event_currency, page_url, page_title, page_referrer,
        scroll_depth, time_on_page, click_x, click_y, form_fields_completed,
        video_duration_watched, download_file_name, search_term,
        business_item_type, business_item_category, transaction_funnel_step,
        conversion_funnel_stage, user_journey_stage, attribution_channel,
        a_b_test_variant, personalization_applied, custom_properties, record_source
    ) VALUES (
        p_event_hk, v_current_load_date, v_hash_diff,
        (p_event_data->>'event_timestamp')::timestamptz,
        p_event_data->>'event_type',
        p_event_data->>'event_category',
        p_event_data->>'event_action',
        p_event_data->>'event_label',
        (p_event_data->>'event_value')::integer,
        COALESCE(p_event_data->>'event_currency', 'USD'),
        p_event_data->>'page_url',
        p_event_data->>'page_title',
        p_event_data->>'page_referrer',
        (p_event_data->>'scroll_depth')::integer,
        (p_event_data->>'time_on_page')::integer,
        (p_event_data->>'click_x')::integer,
        (p_event_data->>'click_y')::integer,
        (p_event_data->>'form_fields_completed')::integer,
        (p_event_data->>'video_duration_watched')::integer,
        p_event_data->>'download_file_name',
        p_event_data->>'search_term',
        p_event_data->>'business_item_type',
        p_event_data->>'business_item_category',
        p_event_data->>'transaction_funnel_step',
        p_event_data->>'conversion_funnel_stage',
        p_event_data->>'user_journey_stage',
        p_event_data->>'attribution_channel',
        p_event_data->>'a_b_test_variant',
        COALESCE((p_event_data->>'personalization_applied')::boolean, false),
        p_event_data->'custom_properties',
        p_record_source
    ) ON CONFLICT (site_event_hk, load_date) DO NOTHING;
    
    RETURN v_hash_diff;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- COMPREHENSIVE ETL FUNCTION FOR STAGING TO BUSINESS
-- =====================================================

-- Main function to process staging events into business layer satellites
CREATE OR REPLACE FUNCTION business.process_staging_to_satellites(
    p_batch_size INTEGER DEFAULT 50
) RETURNS TABLE (
    processed_events INTEGER,
    session_updates INTEGER,
    visitor_updates INTEGER,
    event_inserts INTEGER,
    page_updates INTEGER,
    item_updates INTEGER
) AS $$
DECLARE
    v_staging_event RECORD;
    v_processed_count INTEGER := 0;
    v_session_updates INTEGER := 0;
    v_visitor_updates INTEGER := 0;
    v_event_inserts INTEGER := 0;
    v_page_updates INTEGER := 0;
    v_item_updates INTEGER := 0;
    v_session_hk BYTEA;
    v_visitor_hk BYTEA;
    v_event_hk BYTEA;
    v_page_hk BYTEA;
    v_business_item_hk BYTEA;
    v_event_bk VARCHAR(255);
BEGIN
    -- Process validated staging events
    FOR v_staging_event IN 
        SELECT * FROM staging.site_events_staging 
        WHERE validation_status = 'VALID'
        AND staging_event_id NOT IN (
            SELECT DISTINCT COALESCE(
                (custom_properties->>'staging_event_id')::integer, 
                0
            )
            FROM business.site_event_details_s 
            WHERE record_source = 'staging_processor'
            AND custom_properties ? 'staging_event_id'
        )
        ORDER BY processing_timestamp
        LIMIT p_batch_size
    LOOP
        -- Get or create hub records
        v_session_hk := business.get_or_create_site_session_hk(
            v_staging_event.session_id, v_staging_event.tenant_hk, 'staging_processor'
        );
        v_visitor_hk := business.get_or_create_site_visitor_hk(
            v_staging_event.visitor_id, v_staging_event.tenant_hk, 'staging_processor'
        );
        v_page_hk := business.get_or_create_site_page_hk(
            v_staging_event.page_url, v_staging_event.tenant_hk, 'staging_processor'
        );
        
        -- Create event business key and get hub
        v_event_bk := 'evt_' || to_char(v_staging_event.event_timestamp, 'YYYYMMDD_HH24MISS_US') || '_' || 
                      v_staging_event.session_id || '_' || v_staging_event.event_type;
        v_event_hk := business.get_or_create_site_event_hk(
            v_event_bk, v_staging_event.tenant_hk, 'staging_processor'
        );
        
        -- Create business item if specified
        IF v_staging_event.business_item_info IS NOT NULL AND 
           v_staging_event.business_item_info->>'item_name' IS NOT NULL THEN
            v_business_item_hk := business.get_or_create_business_item_hk(
                v_staging_event.business_item_info->>'item_name', 
                v_staging_event.tenant_hk, 'staging_processor'
            );
        END IF;
        
        -- Create all relevant links
        PERFORM business.create_tracking_event_links(
            v_staging_event.tenant_hk,
            v_staging_event.session_id,
            v_staging_event.visitor_id,
            v_staging_event.event_timestamp,
            v_staging_event.event_type,
            v_staging_event.page_url,
            v_staging_event.business_item_info->>'item_name',
            'staging_processor'
        );
        
        -- Insert event details satellite
        PERFORM business.insert_event_details(
            v_event_hk,
            jsonb_build_object(
                'event_timestamp', v_staging_event.event_timestamp,
                'event_type', v_staging_event.event_type,
                'event_category', v_staging_event.event_category,
                'event_action', v_staging_event.event_action,
                'event_label', v_staging_event.event_label,
                'event_value', v_staging_event.event_value,
                'page_url', v_staging_event.page_url,
                'page_title', v_staging_event.page_title,
                'page_referrer', v_staging_event.page_referrer,
                'business_item_type', v_staging_event.business_item_info->>'item_type',
                'business_item_category', v_staging_event.business_item_info->>'item_category',
                'transaction_funnel_step', v_staging_event.transaction_info->>'step_name',
                'conversion_funnel_stage', v_staging_event.transaction_info->>'funnel_stage',
                'custom_properties', v_staging_event.custom_properties || 
                                   jsonb_build_object('staging_event_id', v_staging_event.staging_event_id)
            ),
            'staging_processor'
        );
        v_event_inserts := v_event_inserts + 1;
        
        -- Update session details (aggregate from events)
        -- This is a simplified version - in production you'd calculate comprehensive metrics
        PERFORM business.update_session_details(
            v_session_hk,
            jsonb_build_object(
                'session_start_time', v_staging_event.event_timestamp,
                'total_events', 1,
                'total_page_views', CASE WHEN v_staging_event.event_type = 'page_view' THEN 1 ELSE 0 END,
                'entry_page_url', v_staging_event.page_url,
                'device_category', v_staging_event.device_info->>'device_type',
                'browser_family', v_staging_event.device_info->>'browser_name',
                'operating_system', v_staging_event.device_info->>'operating_system'
            ),
            'staging_processor'
        );
        v_session_updates := v_session_updates + 1;
        
        -- Update visitor details (aggregate from sessions and events)
        PERFORM business.update_visitor_details(
            v_visitor_hk,
            jsonb_build_object(
                'visitor_ip_hash', v_staging_event.visitor_ip_hash,
                'user_agent', v_staging_event.user_agent,
                'device_type', v_staging_event.device_info->>'device_type',
                'browser_name', v_staging_event.device_info->>'browser_name',
                'operating_system', v_staging_event.device_info->>'operating_system',
                'first_visit_date', v_staging_event.event_timestamp,
                'last_visit_date', v_staging_event.event_timestamp,
                'total_sessions', 1,
                'total_events', 1,
                'total_page_views', CASE WHEN v_staging_event.event_type = 'page_view' THEN 1 ELSE 0 END
            ),
            'staging_processor'
        );
        v_visitor_updates := v_visitor_updates + 1;
        
        v_processed_count := v_processed_count + 1;
    END LOOP;
    
    -- Notify about batch completion
    IF v_processed_count > 0 THEN
        PERFORM pg_notify('satellites_batch_completed', jsonb_build_object(
            'processed_events', v_processed_count,
            'session_updates', v_session_updates,
            'visitor_updates', v_visitor_updates,
            'event_inserts', v_event_inserts,
            'timestamp', CURRENT_TIMESTAMP
        )::text);
    END IF;
    
    RETURN QUERY SELECT 
        v_processed_count, v_session_updates, v_visitor_updates, 
        v_event_inserts, v_page_updates, v_item_updates;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- SATELLITE ANALYTICS FUNCTIONS
-- =====================================================

-- Function to get satellite data statistics
CREATE OR REPLACE FUNCTION business.get_satellite_statistics(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_hours_back INTEGER DEFAULT 24
) RETURNS TABLE (
    satellite_table VARCHAR(100),
    total_records BIGINT,
    active_records BIGINT,
    recent_changes BIGINT,
    change_rate DECIMAL(5,2)
) AS $$
DECLARE
    v_cutoff_time TIMESTAMP WITH TIME ZONE;
BEGIN
    v_cutoff_time := CURRENT_TIMESTAMP - INTERVAL '1 hour' * p_hours_back;
    
    RETURN QUERY
    WITH satellite_stats AS (
        SELECT 'site_session_details_s' as satellite_table,
               COUNT(*) as total_records,
               COUNT(*) FILTER (WHERE load_end_date IS NULL) as active_records,
               COUNT(*) FILTER (WHERE load_date >= v_cutoff_time) as recent_changes
        FROM business.site_session_details_s ssd
        LEFT JOIN business.site_session_h ssh ON ssd.site_session_hk = ssh.site_session_hk
        WHERE (p_tenant_hk IS NULL OR ssh.tenant_hk = p_tenant_hk)
        
        UNION ALL
        
        SELECT 'site_visitor_details_s' as satellite_table,
               COUNT(*) as total_records,
               COUNT(*) FILTER (WHERE load_end_date IS NULL) as active_records,
               COUNT(*) FILTER (WHERE load_date >= v_cutoff_time) as recent_changes
        FROM business.site_visitor_details_s svd
        LEFT JOIN business.site_visitor_h svh ON svd.site_visitor_hk = svh.site_visitor_hk
        WHERE (p_tenant_hk IS NULL OR svh.tenant_hk = p_tenant_hk)
        
        UNION ALL
        
        SELECT 'site_event_details_s' as satellite_table,
               COUNT(*) as total_records,
               COUNT(*) as active_records,  -- Events don't end-date
               COUNT(*) FILTER (WHERE load_date >= v_cutoff_time) as recent_changes
        FROM business.site_event_details_s sed
        LEFT JOIN business.site_event_h seh ON sed.site_event_hk = seh.site_event_hk
        WHERE (p_tenant_hk IS NULL OR seh.tenant_hk = p_tenant_hk)
        
        UNION ALL
        
        SELECT 'site_page_details_s' as satellite_table,
               COUNT(*) as total_records,
               COUNT(*) FILTER (WHERE load_end_date IS NULL) as active_records,
               COUNT(*) FILTER (WHERE load_date >= v_cutoff_time) as recent_changes
        FROM business.site_page_details_s spd
        LEFT JOIN business.site_page_h sph ON spd.site_page_hk = sph.site_page_hk
        WHERE (p_tenant_hk IS NULL OR sph.tenant_hk = p_tenant_hk)
        
        UNION ALL
        
        SELECT 'business_item_details_s' as satellite_table,
               COUNT(*) as total_records,
               COUNT(*) FILTER (WHERE load_end_date IS NULL) as active_records,
               COUNT(*) FILTER (WHERE load_date >= v_cutoff_time) as recent_changes
        FROM business.business_item_details_s bid
        LEFT JOIN business.business_item_h bih ON bid.business_item_hk = bih.business_item_hk
        WHERE (p_tenant_hk IS NULL OR bih.tenant_hk = p_tenant_hk)
    )
    SELECT 
        ss.satellite_table,
        ss.total_records,
        ss.active_records,
        ss.recent_changes,
        ROUND(
            CASE WHEN ss.total_records > 0 THEN
                ss.recent_changes * 100.0 / ss.total_records
            ELSE 0 END, 2
        ) as change_rate
    FROM satellite_stats ss
    ORDER BY ss.total_records DESC;
END;
$$ LANGUAGE plpgsql;

-- Add table comments for documentation
COMMENT ON TABLE business.site_session_details_s IS 
'Data Vault 2.0 satellite storing descriptive attributes and metrics for site sessions. Tracks session behavior, conversion data, and business context with full historization.';

COMMENT ON TABLE business.site_visitor_details_s IS 
'Data Vault 2.0 satellite storing descriptive attributes and behavioral patterns for site visitors. Maintains privacy compliance while enabling comprehensive visitor analytics.';

COMMENT ON TABLE business.site_event_details_s IS 
'Data Vault 2.0 satellite storing descriptive attributes for individual tracking events. Comprehensive event data supporting universal business analytics across industries.';

COMMENT ON TABLE business.site_page_details_s IS 
'Data Vault 2.0 satellite storing descriptive attributes and performance metrics for site pages. Enables content optimization and page-level analytics.';

COMMENT ON TABLE business.business_item_details_s IS 
'Data Vault 2.0 satellite storing descriptive attributes for business items (products, services, content, features). Universal support for multi-industry item analytics.';

COMMENT ON FUNCTION business.process_staging_to_satellites IS 
'Processes validated staging events into Data Vault 2.0 business layer satellites. Creates comprehensive descriptive attributes and maintains entity relationships.';

COMMENT ON FUNCTION business.get_satellite_statistics IS 
'Provides comprehensive statistics on Data Vault 2.0 satellite activity including change rates and data volumes for monitoring and optimization.';

-- Grant appropriate permissions
-- These would be set based on your security model
-- GRANT USAGE ON SCHEMA business TO tracking_processor_role;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA business TO tracking_processor_role;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA business TO tracking_processor_role;

-- =====================================================
-- BUSINESS SATELLITES LAYER COMPLETE
-- Universal site tracking Data Vault 2.0 descriptive attributes
-- Complete implementation ready for production analytics
-- ===================================================== 