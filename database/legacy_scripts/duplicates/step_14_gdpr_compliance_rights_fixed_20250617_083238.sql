-- =====================================================================================
-- Step 14: GDPR Data Subject Rights (FIXED) - Using Existing Compliance Schema
-- =====================================================================================
-- Enhances existing compliance schema with GDPR data subject rights implementation
-- Implements right to be forgotten, data portability, consent management
-- =====================================================================================

-- Starting Step 14: GDPR Data Subject Rights (FIXED)...
-- This enhances existing compliance schema with GDPR data subject rights

-- ==================================================
-- GDPR DATA SUBJECT MANAGEMENT
-- ==================================================

-- GDPR Data Subject Hub
CREATE TABLE compliance.gdpr_data_subject_h (
    data_subject_hk BYTEA PRIMARY KEY,
    data_subject_bk VARCHAR(255) NOT NULL,     -- email or user ID
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- GDPR Data Subject Details
CREATE TABLE compliance.gdpr_data_subject_s (
    data_subject_hk BYTEA NOT NULL REFERENCES compliance.gdpr_data_subject_h(data_subject_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    subject_type VARCHAR(50) NOT NULL,         -- USER, CUSTOMER, PATIENT, CONTACT
    registration_date DATE,
    consent_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, GRANTED, WITHDRAWN, EXPIRED
    consent_date TIMESTAMP WITH TIME ZONE,
    consent_method VARCHAR(50),                -- WEB_FORM, EMAIL, PHONE, WRITTEN
    lawful_basis VARCHAR(50) NOT NULL,         -- CONSENT, CONTRACT, LEGAL_OBLIGATION, etc.
    processing_purposes TEXT[] NOT NULL,       -- Array of processing purposes
    data_categories TEXT[] NOT NULL,           -- Array of data categories being processed
    retention_period INTERVAL DEFAULT '7 years',
    anonymization_date DATE,                   -- When data should be anonymized
    is_child BOOLEAN DEFAULT false,            -- Special protections for children
    parent_consent_required BOOLEAN DEFAULT false,
    marketing_consent BOOLEAN DEFAULT false,
    profiling_consent BOOLEAN DEFAULT false,
    automated_decision_consent BOOLEAN DEFAULT false,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (data_subject_hk, load_date)
);

-- ==================================================
-- GDPR RIGHTS REQUESTS
-- ==================================================

-- GDPR Rights Request Hub
CREATE TABLE compliance.gdpr_rights_request_h (
    rights_request_hk BYTEA PRIMARY KEY,
    rights_request_bk VARCHAR(255) NOT NULL,   -- "GDPR_REQ_2024_001"
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- GDPR Rights Request Details
CREATE TABLE compliance.gdpr_rights_request_s (
    rights_request_hk BYTEA NOT NULL REFERENCES compliance.gdpr_rights_request_h(rights_request_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    data_subject_hk BYTEA NOT NULL REFERENCES compliance.gdpr_data_subject_h(data_subject_hk),
    request_type VARCHAR(50) NOT NULL,         -- ACCESS, RECTIFICATION, ERASURE, PORTABILITY, RESTRICTION, OBJECTION
    request_date TIMESTAMP WITH TIME ZONE NOT NULL,
    request_method VARCHAR(50) NOT NULL,       -- EMAIL, WEB_FORM, PHONE, POSTAL
    requester_identity_verified BOOLEAN DEFAULT false,
    verification_method VARCHAR(50),           -- EMAIL_VERIFICATION, ID_CHECK, SECURITY_QUESTIONS
    request_details TEXT,
    urgency_level VARCHAR(20) DEFAULT 'NORMAL', -- LOW, NORMAL, HIGH, URGENT
    response_due_date TIMESTAMP WITH TIME ZONE NOT NULL, -- 30 days max (1 month)
    request_status VARCHAR(20) DEFAULT 'RECEIVED', -- RECEIVED, PROCESSING, COMPLETED, REJECTED, APPEALED
    assigned_to VARCHAR(100),
    processing_notes TEXT,
    completion_date TIMESTAMP WITH TIME ZONE,
    response_method VARCHAR(50),               -- EMAIL, POSTAL, SECURE_DOWNLOAD
    rejection_reason TEXT,
    appeal_deadline DATE,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (rights_request_hk, load_date)
);

-- ==================================================
-- GDPR DATA PROCESSING ACTIVITIES
-- ==================================================

-- GDPR Processing Activity Hub
CREATE TABLE compliance.gdpr_processing_activity_h (
    processing_activity_hk BYTEA PRIMARY KEY,
    processing_activity_bk VARCHAR(255) NOT NULL, -- "USER_AUTHENTICATION", "PAYMENT_PROCESSING"
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- GDPR Processing Activity Details
CREATE TABLE compliance.gdpr_processing_activity_s (
    processing_activity_hk BYTEA NOT NULL REFERENCES compliance.gdpr_processing_activity_h(processing_activity_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    activity_name VARCHAR(200) NOT NULL,
    activity_description TEXT NOT NULL,
    lawful_basis VARCHAR(50) NOT NULL,         -- CONSENT, CONTRACT, LEGAL_OBLIGATION, etc.
    processing_purposes TEXT[] NOT NULL,
    data_categories TEXT[] NOT NULL,           -- Personal data categories processed
    data_subjects_categories TEXT[] NOT NULL,  -- Categories of data subjects
    recipients TEXT[],                         -- Who receives the data
    international_transfers BOOLEAN DEFAULT false,
    transfer_safeguards TEXT,                  -- Adequacy decision, BCRs, etc.
    retention_schedule TEXT NOT NULL,
    security_measures TEXT[] NOT NULL,
    data_protection_impact_assessment BOOLEAN DEFAULT false,
    dpia_date DATE,
    dpia_outcome TEXT,
    controller_name VARCHAR(200) NOT NULL,
    controller_contact VARCHAR(200) NOT NULL,
    dpo_contact VARCHAR(200),                  -- Data Protection Officer
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (processing_activity_hk, load_date)
);

-- ==================================================
-- GDPR CONSENT MANAGEMENT
-- ==================================================

-- GDPR Consent Hub
CREATE TABLE compliance.gdpr_consent_h (
    consent_hk BYTEA PRIMARY KEY,
    consent_bk VARCHAR(255) NOT NULL,          -- "CONSENT_USER_123_MARKETING"
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- GDPR Consent Details
CREATE TABLE compliance.gdpr_consent_s (
    consent_hk BYTEA NOT NULL REFERENCES compliance.gdpr_consent_h(consent_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    data_subject_hk BYTEA NOT NULL REFERENCES compliance.gdpr_data_subject_h(data_subject_hk),
    processing_activity_hk BYTEA NOT NULL REFERENCES compliance.gdpr_processing_activity_h(processing_activity_hk),
    consent_type VARCHAR(50) NOT NULL,         -- EXPLICIT, IMPLIED, OPT_IN, OPT_OUT
    consent_purpose VARCHAR(200) NOT NULL,
    consent_given BOOLEAN NOT NULL,
    consent_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    consent_method VARCHAR(50) NOT NULL,       -- WEB_FORM, EMAIL, PHONE, API
    consent_evidence JSONB,                    -- Record of how consent was captured
    consent_withdrawn BOOLEAN DEFAULT false,
    withdrawal_timestamp TIMESTAMP WITH TIME ZONE,
    withdrawal_method VARCHAR(50),
    withdrawal_reason TEXT,
    consent_expiry_date DATE,
    renewal_required BOOLEAN DEFAULT false,
    granular_permissions JSONB,               -- Specific permissions granted
    ip_address INET,
    user_agent TEXT,
    consent_version VARCHAR(20),              -- Version of consent form/terms
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (consent_hk, load_date)
);

-- ==================================================
-- GDPR DATA PORTABILITY
-- ==================================================

-- GDPR Data Export Hub
CREATE TABLE compliance.gdpr_data_export_h (
    data_export_hk BYTEA PRIMARY KEY,
    data_export_bk VARCHAR(255) NOT NULL,      -- "EXPORT_2024_001"
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- GDPR Data Export Details
CREATE TABLE compliance.gdpr_data_export_s (
    data_export_hk BYTEA NOT NULL REFERENCES compliance.gdpr_data_export_h(data_export_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    rights_request_hk BYTEA NOT NULL REFERENCES compliance.gdpr_rights_request_h(rights_request_hk),
    export_format VARCHAR(50) DEFAULT 'JSON',  -- JSON, XML, CSV, PDF
    export_scope TEXT[] NOT NULL,              -- Which data categories to export
    export_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, PROCESSING, COMPLETED, FAILED
    export_start_time TIMESTAMP WITH TIME ZONE,
    export_completion_time TIMESTAMP WITH TIME ZONE,
    export_file_path TEXT,
    export_file_size BIGINT,
    export_file_hash BYTEA,                    -- For integrity verification
    encryption_used BOOLEAN DEFAULT true,
    encryption_key_id VARCHAR(100),
    download_expiry DATE DEFAULT CURRENT_DATE + INTERVAL '30 days',
    download_count INTEGER DEFAULT 0,
    max_downloads INTEGER DEFAULT 3,
    export_errors TEXT,
    quality_check_passed BOOLEAN DEFAULT false,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (data_export_hk, load_date)
);

-- ==================================================
-- GDPR ERASURE (RIGHT TO BE FORGOTTEN)
-- ==================================================

-- GDPR Erasure Hub
CREATE TABLE compliance.gdpr_erasure_h (
    erasure_hk BYTEA PRIMARY KEY,
    erasure_bk VARCHAR(255) NOT NULL,          -- "ERASURE_2024_001"
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- GDPR Erasure Details
CREATE TABLE compliance.gdpr_erasure_s (
    erasure_hk BYTEA NOT NULL REFERENCES compliance.gdpr_erasure_h(erasure_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    rights_request_hk BYTEA NOT NULL REFERENCES compliance.gdpr_rights_request_h(rights_request_hk),
    erasure_type VARCHAR(50) NOT NULL,         -- DELETION, ANONYMIZATION, PSEUDONYMIZATION
    erasure_scope TEXT[] NOT NULL,             -- Which data to erase
    erasure_method VARCHAR(50) NOT NULL,       -- SECURE_DELETE, OVERWRITE, ANONYMIZE
    erasure_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, PROCESSING, COMPLETED, FAILED
    erasure_start_time TIMESTAMP WITH TIME ZONE,
    erasure_completion_time TIMESTAMP WITH TIME ZONE,
    tables_affected TEXT[] NOT NULL,           -- List of tables affected
    records_processed INTEGER DEFAULT 0,
    records_erased INTEGER DEFAULT 0,
    records_anonymized INTEGER DEFAULT 0,
    backup_notification_sent BOOLEAN DEFAULT false, -- Notify backup systems
    third_party_notification_sent BOOLEAN DEFAULT false, -- Notify data processors
    verification_completed BOOLEAN DEFAULT false,
    verification_date DATE,
    verification_method VARCHAR(50),
    legal_hold_check BOOLEAN DEFAULT false,   -- Check for legal hold requirements
    retention_override BOOLEAN DEFAULT false, -- Override normal retention
    override_reason TEXT,
    audit_trail JSONB,                        -- Detailed audit of erasure process
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (erasure_hk, load_date)
);

-- ==================================================
-- INDEXES FOR PERFORMANCE
-- ==================================================

-- GDPR Data Subject Indexes
CREATE INDEX idx_gdpr_data_subject_h_tenant 
ON compliance.gdpr_data_subject_h USING btree (tenant_hk);

CREATE INDEX idx_gdpr_data_subject_s_consent_status 
ON compliance.gdpr_data_subject_s USING btree (consent_status) 
WHERE load_end_date IS NULL;

-- GDPR Rights Request Indexes
CREATE INDEX idx_gdpr_rights_request_h_tenant 
ON compliance.gdpr_rights_request_h USING btree (tenant_hk);

CREATE INDEX idx_gdpr_rights_request_s_status_due 
ON compliance.gdpr_rights_request_s USING btree (request_status, response_due_date) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_gdpr_rights_request_s_type 
ON compliance.gdpr_rights_request_s USING btree (request_type) 
WHERE load_end_date IS NULL;

-- GDPR Consent Indexes
CREATE INDEX idx_gdpr_consent_h_tenant 
ON compliance.gdpr_consent_h USING btree (tenant_hk);

CREATE INDEX idx_gdpr_consent_s_subject_activity 
ON compliance.gdpr_consent_s USING btree (data_subject_hk, processing_activity_hk) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_gdpr_consent_s_withdrawn 
ON compliance.gdpr_consent_s USING btree (consent_withdrawn) 
WHERE load_end_date IS NULL AND consent_withdrawn = true;

-- ==================================================
-- GDPR AUTOMATION FUNCTIONS
-- ==================================================

-- Register data subject
CREATE OR REPLACE FUNCTION compliance.register_gdpr_data_subject(
    p_tenant_hk BYTEA,
    p_subject_identifier VARCHAR(255),
    p_subject_type VARCHAR(50),
    p_lawful_basis VARCHAR(50),
    p_processing_purposes TEXT[],
    p_data_categories TEXT[]
) RETURNS BYTEA AS $$
DECLARE
    v_subject_hk BYTEA;
BEGIN
    v_subject_hk := util.hash_binary(encode(p_tenant_hk, 'hex') || '_' || p_subject_identifier);
    
    -- Insert hub record
    INSERT INTO compliance.gdpr_data_subject_h VALUES (
        v_subject_hk, p_subject_identifier, p_tenant_hk,
        util.current_load_date(), util.get_record_source()
    ) ON CONFLICT DO NOTHING;
    
    -- Insert satellite record
    INSERT INTO compliance.gdpr_data_subject_s VALUES (
        v_subject_hk, util.current_load_date(), NULL,
        util.hash_binary(p_subject_identifier || p_subject_type || p_lawful_basis),
        p_subject_type, CURRENT_DATE, 'PENDING', NULL, NULL,
        p_lawful_basis, p_processing_purposes, p_data_categories,
        '7 years'::INTERVAL, NULL, false, false, false, false, false,
        util.get_record_source()
    );
    
    RETURN v_subject_hk;
END;
$$ LANGUAGE plpgsql;

-- Submit GDPR rights request
CREATE OR REPLACE FUNCTION compliance.submit_gdpr_rights_request(
    p_tenant_hk BYTEA,
    p_data_subject_hk BYTEA,
    p_request_type VARCHAR(50),
    p_request_method VARCHAR(50),
    p_request_details TEXT DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_request_hk BYTEA;
    v_request_bk VARCHAR(255);
    v_due_date TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Generate request business key
    v_request_bk := 'GDPR_REQ_' || to_char(CURRENT_TIMESTAMP, 'YYYY_MM_DD_HH24MISS');
    v_request_hk := util.hash_binary(encode(p_tenant_hk, 'hex') || '_' || v_request_bk);
    
    -- Calculate due date (30 days for most requests, extended possible)
    v_due_date := CURRENT_TIMESTAMP + INTERVAL '30 days';
    
    -- Insert hub record
    INSERT INTO compliance.gdpr_rights_request_h VALUES (
        v_request_hk, v_request_bk, p_tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    -- Insert satellite record
    INSERT INTO compliance.gdpr_rights_request_s VALUES (
        v_request_hk, util.current_load_date(), NULL,
        util.hash_binary(v_request_bk || p_request_type || CURRENT_TIMESTAMP::text),
        p_data_subject_hk, p_request_type, CURRENT_TIMESTAMP,
        p_request_method, false, NULL, p_request_details,
        'NORMAL', v_due_date, 'RECEIVED', NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        util.get_record_source()
    );
    
    RETURN v_request_hk;
END;
$$ LANGUAGE plpgsql;

-- Record consent
CREATE OR REPLACE FUNCTION compliance.record_gdpr_consent(
    p_tenant_hk BYTEA,
    p_data_subject_hk BYTEA,
    p_processing_activity_hk BYTEA,
    p_consent_type VARCHAR(50),
    p_consent_purpose VARCHAR(200),
    p_consent_given BOOLEAN,
    p_consent_method VARCHAR(50),
    p_consent_evidence JSONB DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_consent_hk BYTEA;
    v_consent_bk VARCHAR(255);
BEGIN
    -- Generate consent business key
    SELECT 'CONSENT_' || data_subject_bk || '_' || processing_activity_bk
    INTO v_consent_bk
    FROM compliance.gdpr_data_subject_h ds, compliance.gdpr_processing_activity_h pa
    WHERE ds.data_subject_hk = p_data_subject_hk 
    AND pa.processing_activity_hk = p_processing_activity_hk;
    
    v_consent_hk := util.hash_binary(encode(p_tenant_hk, 'hex') || '_' || v_consent_bk || '_' || CURRENT_TIMESTAMP::text);
    
    -- Insert hub record
    INSERT INTO compliance.gdpr_consent_h VALUES (
        v_consent_hk, v_consent_bk, p_tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    -- Insert satellite record
    INSERT INTO compliance.gdpr_consent_s VALUES (
        v_consent_hk, util.current_load_date(), NULL,
        util.hash_binary(v_consent_bk || p_consent_given::text || CURRENT_TIMESTAMP::text),
        p_data_subject_hk, p_processing_activity_hk,
        p_consent_type, p_consent_purpose, p_consent_given,
        CURRENT_TIMESTAMP, p_consent_method, p_consent_evidence,
        false, NULL, NULL, NULL, NULL, false, NULL,
        inet_client_addr(), current_setting('application_name', true), '1.0',
        util.get_record_source()
    );
    
    RETURN v_consent_hk;
END;
$$ LANGUAGE plpgsql;

-- Process data portability request
CREATE OR REPLACE FUNCTION compliance.process_data_portability_request(
    p_tenant_hk BYTEA,
    p_rights_request_hk BYTEA,
    p_export_format VARCHAR(50) DEFAULT 'JSON',
    p_export_scope TEXT[] DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_export_hk BYTEA;
    v_export_bk VARCHAR(255);
BEGIN
    v_export_bk := 'EXPORT_' || to_char(CURRENT_TIMESTAMP, 'YYYY_MM_DD_HH24MISS');
    v_export_hk := util.hash_binary(encode(p_tenant_hk, 'hex') || '_' || v_export_bk);
    
    -- Insert hub record
    INSERT INTO compliance.gdpr_data_export_h VALUES (
        v_export_hk, v_export_bk, p_tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    -- Insert satellite record
    INSERT INTO compliance.gdpr_data_export_s VALUES (
        v_export_hk, util.current_load_date(), NULL,
        util.hash_binary(v_export_bk || p_export_format),
        p_rights_request_hk, p_export_format,
        COALESCE(p_export_scope, ARRAY['profile', 'preferences', 'activity']),
        'PENDING', NULL, NULL, NULL, NULL, NULL, true, NULL,
        CURRENT_DATE + INTERVAL '30 days', 0, 3, NULL, false,
        util.get_record_source()
    );
    
    RETURN v_export_hk;
END;
$$ LANGUAGE plpgsql;

-- Process erasure request (right to be forgotten)
CREATE OR REPLACE FUNCTION compliance.process_erasure_request(
    p_tenant_hk BYTEA,
    p_rights_request_hk BYTEA,
    p_erasure_type VARCHAR(50) DEFAULT 'ANONYMIZATION',
    p_erasure_scope TEXT[] DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_erasure_hk BYTEA;
    v_erasure_bk VARCHAR(255);
BEGIN
    v_erasure_bk := 'ERASURE_' || to_char(CURRENT_TIMESTAMP, 'YYYY_MM_DD_HH24MISS');
    v_erasure_hk := util.hash_binary(encode(p_tenant_hk, 'hex') || '_' || v_erasure_bk);
    
    -- Insert hub record
    INSERT INTO compliance.gdpr_erasure_h VALUES (
        v_erasure_hk, v_erasure_bk, p_tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    -- Insert satellite record
    INSERT INTO compliance.gdpr_erasure_s VALUES (
        v_erasure_hk, util.current_load_date(), NULL,
        util.hash_binary(v_erasure_bk || p_erasure_type),
        p_rights_request_hk, p_erasure_type,
        COALESCE(p_erasure_scope, ARRAY['profile', 'activity', 'preferences']),
        CASE WHEN p_erasure_type = 'DELETION' THEN 'SECURE_DELETE' ELSE 'ANONYMIZE' END,
        'PENDING', NULL, NULL,
        ARRAY['user_profile_s', 'user_preferences_s', 'audit_detail_s'],
        0, 0, 0, false, false, false, NULL, NULL, false, false, NULL, NULL,
        util.get_record_source()
    );
    
    RETURN v_erasure_hk;
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- GDPR DASHBOARD AND REPORTING
-- ==================================================

-- GDPR compliance dashboard view
CREATE OR REPLACE VIEW compliance.gdpr_compliance_dashboard AS
SELECT 
    'Rights Requests' as metric_category,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE rrs.request_status = 'RECEIVED') as pending_count,
    COUNT(*) FILTER (WHERE rrs.response_due_date < CURRENT_TIMESTAMP AND rrs.request_status NOT IN ('COMPLETED', 'REJECTED')) as overdue_count,
    ROUND(AVG(EXTRACT(EPOCH FROM (COALESCE(rrs.completion_date, CURRENT_TIMESTAMP) - rrs.request_date))/86400), 1) as avg_response_days
FROM compliance.gdpr_rights_request_h rrh
JOIN compliance.gdpr_rights_request_s rrs ON rrh.rights_request_hk = rrs.rights_request_hk
WHERE rrs.load_end_date IS NULL
AND rrs.request_date >= CURRENT_DATE - INTERVAL '90 days'

UNION ALL

SELECT 
    'Data Subjects',
    COUNT(*),
    COUNT(*) FILTER (WHERE dss.consent_status = 'GRANTED'),
    COUNT(*) FILTER (WHERE dss.consent_status = 'WITHDRAWN'),
    ROUND(AVG(CURRENT_DATE - dss.registration_date), 1)
FROM compliance.gdpr_data_subject_h dsh
JOIN compliance.gdpr_data_subject_s dss ON dsh.data_subject_hk = dss.data_subject_hk
WHERE dss.load_end_date IS NULL

UNION ALL

SELECT 
    'Consents',
    COUNT(*),
    COUNT(*) FILTER (WHERE cs.consent_given = true AND cs.consent_withdrawn = false),
    COUNT(*) FILTER (WHERE cs.consent_withdrawn = true),
    ROUND(AVG(CURRENT_DATE - cs.consent_timestamp::date), 1)
FROM compliance.gdpr_consent_h ch
JOIN compliance.gdpr_consent_s cs ON ch.consent_hk = cs.consent_hk
WHERE cs.load_end_date IS NULL;

-- ==================================================
-- INITIAL GDPR SETUP
-- ==================================================

-- Function to setup default GDPR processing activities
CREATE OR REPLACE FUNCTION compliance.setup_default_gdpr_activities(
    p_tenant_hk BYTEA
) RETURNS INTEGER AS $$
DECLARE
    v_activities_created INTEGER := 0;
    v_activity_hk BYTEA;
BEGIN
    -- User Authentication Activity
    SELECT compliance.create_gdpr_processing_activity(
        p_tenant_hk, 'USER_AUTHENTICATION',
        'User login and authentication services',
        'CONTRACT',
        ARRAY['Service Delivery', 'Security'],
        ARRAY['Contact details', 'Authentication data'],
        ARRAY['Platform users']
    ) INTO v_activity_hk;
    v_activities_created := v_activities_created + 1;
    
    -- Financial Transaction Processing
    SELECT compliance.create_gdpr_processing_activity(
        p_tenant_hk, 'FINANCIAL_PROCESSING',
        'Processing financial transactions and payments',
        'CONTRACT',
        ARRAY['Payment Processing', 'Tax Compliance'],
        ARRAY['Financial data', 'Transaction history'],
        ARRAY['Customers', 'Business entities']
    ) INTO v_activity_hk;
    v_activities_created := v_activities_created + 1;
    
    -- Marketing Communications
    SELECT compliance.create_gdpr_processing_activity(
        p_tenant_hk, 'MARKETING_COMMUNICATIONS',
        'Marketing emails and promotional communications',
        'CONSENT',
        ARRAY['Marketing', 'Product updates'],
        ARRAY['Contact details', 'Preferences'],
        ARRAY['Subscribers', 'Customers']
    ) INTO v_activity_hk;
    v_activities_created := v_activities_created + 1;
    
    RETURN v_activities_created;
END;
$$ LANGUAGE plpgsql;

-- Helper function to create processing activities
CREATE OR REPLACE FUNCTION compliance.create_gdpr_processing_activity(
    p_tenant_hk BYTEA,
    p_activity_id VARCHAR(100),
    p_activity_description TEXT,
    p_lawful_basis VARCHAR(50),
    p_processing_purposes TEXT[],
    p_data_categories TEXT[],
    p_data_subjects_categories TEXT[]
) RETURNS BYTEA AS $$
DECLARE
    v_activity_hk BYTEA;
BEGIN
    v_activity_hk := util.hash_binary(encode(p_tenant_hk, 'hex') || '_' || p_activity_id);
    
    -- Insert hub record
    INSERT INTO compliance.gdpr_processing_activity_h VALUES (
        v_activity_hk, p_activity_id, p_tenant_hk,
        util.current_load_date(), util.get_record_source()
    ) ON CONFLICT DO NOTHING;
    
    -- Insert satellite record
    INSERT INTO compliance.gdpr_processing_activity_s VALUES (
        v_activity_hk, util.current_load_date(), NULL,
        util.hash_binary(p_activity_id || p_activity_description),
        p_activity_id, p_activity_description, p_lawful_basis,
        p_processing_purposes, p_data_categories, p_data_subjects_categories,
        NULL, false, NULL, 'As per retention policy', ARRAY['Encryption', 'Access controls'],
        false, NULL, NULL, 'Data Controller', 'privacy@company.com', 'dpo@company.com', true,
        util.get_record_source()
    );
    
    RETURN v_activity_hk;
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- COMMENTS FOR DOCUMENTATION
-- ==================================================

COMMENT ON TABLE compliance.gdpr_data_subject_h IS 'Hub table for GDPR data subjects requiring privacy protection';
COMMENT ON TABLE compliance.gdpr_data_subject_s IS 'Data subject details including consent status and processing basis';

COMMENT ON TABLE compliance.gdpr_rights_request_h IS 'Hub table for GDPR data subject rights requests';
COMMENT ON TABLE compliance.gdpr_rights_request_s IS 'Rights request details including access, portability, erasure requests';

COMMENT ON TABLE compliance.gdpr_processing_activity_h IS 'Hub table for GDPR processing activities requiring documentation';
COMMENT ON TABLE compliance.gdpr_processing_activity_s IS 'Processing activity details including lawful basis and data categories';

COMMENT ON TABLE compliance.gdpr_consent_h IS 'Hub table for GDPR consent management';
COMMENT ON TABLE compliance.gdpr_consent_s IS 'Consent details including granular permissions and withdrawal tracking';

COMMENT ON TABLE compliance.gdpr_data_export_h IS 'Hub table for GDPR data portability exports';
COMMENT ON TABLE compliance.gdpr_data_export_s IS 'Data export details for data portability requests';

COMMENT ON TABLE compliance.gdpr_erasure_h IS 'Hub table for GDPR right to be forgotten processing';
COMMENT ON TABLE compliance.gdpr_erasure_s IS 'Erasure details including anonymization and deletion tracking';

-- GDPR Data Subject Rights (FIXED) deployment completed successfully!
-- Enhanced existing compliance schema with GDPR data subject rights capabilities