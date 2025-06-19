-- =====================================================================================
-- Step 13: SOX Compliance Automation (FIXED) - Using Existing Compliance Schema
-- =====================================================================================
-- Enhances existing compliance schema with SOX automation infrastructure
-- Fixes errors and integrates with current database structure
-- =====================================================================================

-- Starting Step 13: SOX Compliance Automation (FIXED)...
-- This enhances existing compliance schema with SOX automation


-- ==================================================
-- SOX CONTROL PERIOD MANAGEMENT
-- ==================================================

-- SOX Control Period Hub (quarterly periods)
CREATE TABLE compliance.sox_control_period_h (
    control_period_hk BYTEA PRIMARY KEY,
    control_period_bk VARCHAR(255) NOT NULL,   -- "2024_Q1", "2024_Q2", etc.
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- SOX Control Period Status
CREATE TABLE compliance.sox_control_period_s (
    control_period_hk BYTEA NOT NULL REFERENCES compliance.sox_control_period_h(control_period_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    fiscal_year INTEGER NOT NULL,
    fiscal_quarter INTEGER NOT NULL CHECK (fiscal_quarter BETWEEN 1 AND 4),
    period_start_date DATE NOT NULL,
    period_end_date DATE NOT NULL,
    certification_due_date DATE NOT NULL,       -- 45 days after quarter end
    period_status VARCHAR(20) DEFAULT 'OPEN',  -- OPEN, TESTING, CERTIFIED, ARCHIVED
    total_controls INTEGER DEFAULT 0,
    controls_tested INTEGER DEFAULT 0,
    controls_passed INTEGER DEFAULT 0,
    ceo_certified BOOLEAN DEFAULT false,
    cfo_certified BOOLEAN DEFAULT false,
    external_auditor_reviewed BOOLEAN DEFAULT false,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (control_period_hk, load_date)
);

-- ==================================================
-- SOX CONTROL DEFINITIONS
-- ==================================================

-- SOX Control Hub
CREATE TABLE compliance.sox_control_h (
    sox_control_hk BYTEA PRIMARY KEY,
    sox_control_bk VARCHAR(255) NOT NULL,      -- "SOX_404_IT_ACCESS_001"
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- SOX Control Details
CREATE TABLE compliance.sox_control_s (
    sox_control_hk BYTEA NOT NULL REFERENCES compliance.sox_control_h(sox_control_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    control_category VARCHAR(50) NOT NULL,     -- ITGC, ENTITY_LEVEL, PROCESS_LEVEL
    control_type VARCHAR(50) NOT NULL,         -- PREVENTIVE, DETECTIVE, MANUAL, AUTOMATED
    control_description TEXT NOT NULL,
    control_objective TEXT NOT NULL,
    risk_rating VARCHAR(20) DEFAULT 'MEDIUM',  -- LOW, MEDIUM, HIGH, CRITICAL
    testing_frequency VARCHAR(20) DEFAULT 'QUARTERLY', -- QUARTERLY, ANNUAL
    automation_level VARCHAR(20) DEFAULT 'MANUAL', -- MANUAL, SEMI_AUTO, FULLY_AUTO
    owner_role VARCHAR(100) NOT NULL,
    is_key_control BOOLEAN DEFAULT false,
    pcaob_relevance BOOLEAN DEFAULT true,      -- Public Company Accounting Oversight Board
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (sox_control_hk, load_date)
);

-- ==================================================
-- SOX CONTROL TESTING
-- ==================================================

-- SOX Control Test Hub
CREATE TABLE compliance.sox_control_test_h (
    control_test_hk BYTEA PRIMARY KEY,
    control_test_bk VARCHAR(255) NOT NULL,     -- "SOX_404_IT_ACCESS_001_2024_Q1_TEST"
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- SOX Control Test Results
CREATE TABLE compliance.sox_control_test_s (
    control_test_hk BYTEA NOT NULL REFERENCES compliance.sox_control_test_h(control_test_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    sox_control_hk BYTEA NOT NULL REFERENCES compliance.sox_control_h(sox_control_hk),
    control_period_hk BYTEA NOT NULL REFERENCES compliance.sox_control_period_h(control_period_hk),
    test_date DATE NOT NULL,
    tested_by VARCHAR(100) NOT NULL,
    test_method VARCHAR(50) NOT NULL,          -- INQUIRY, OBSERVATION, INSPECTION, AUTOMATED
    sample_size INTEGER DEFAULT 1,
    exceptions_identified INTEGER DEFAULT 0,
    test_result VARCHAR(20) NOT NULL,          -- EFFECTIVE, INEFFECTIVE, DEFICIENT
    test_evidence TEXT,
    deficiency_description TEXT,
    management_response TEXT,
    remediation_plan TEXT,
    remediation_due_date DATE,
    reviewer VARCHAR(100),
    review_date DATE,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (control_test_hk, load_date)
);

-- ==================================================
-- SOX MANAGEMENT CERTIFICATIONS
-- ==================================================

-- SOX Certification Hub
CREATE TABLE compliance.sox_certification_h (
    certification_hk BYTEA PRIMARY KEY,
    certification_bk VARCHAR(255) NOT NULL,    -- "SOX_CEO_CERT_2024_Q1"
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- SOX Certification Details
CREATE TABLE compliance.sox_certification_s (
    certification_hk BYTEA NOT NULL REFERENCES compliance.sox_certification_h(certification_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    control_period_hk BYTEA NOT NULL REFERENCES compliance.sox_control_period_h(control_period_hk),
    certification_type VARCHAR(50) NOT NULL,   -- CEO_302, CFO_302, CEO_404, CFO_404
    certifying_officer VARCHAR(100) NOT NULL,
    certification_date TIMESTAMP WITH TIME ZONE NOT NULL,
    certification_statement TEXT NOT NULL,
    disclosure_controls_effective BOOLEAN,
    internal_controls_effective BOOLEAN,
    material_weaknesses_disclosed BOOLEAN DEFAULT false,
    significant_deficiencies_disclosed BOOLEAN DEFAULT false,
    changes_in_controls BOOLEAN DEFAULT false,
    officer_signature_hash BYTEA,             -- Digital signature
    legal_review_completed BOOLEAN DEFAULT false,
    legal_reviewer VARCHAR(100),
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (certification_hk, load_date)
);

-- ==================================================
-- SOX EVIDENCE MANAGEMENT
-- ==================================================

-- SOX Evidence Hub
CREATE TABLE compliance.sox_evidence_h (
    evidence_hk BYTEA PRIMARY KEY,
    evidence_bk VARCHAR(255) NOT NULL,         -- "SOX_EVIDENCE_2024_Q1_001"
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- SOX Evidence Details
CREATE TABLE compliance.sox_evidence_s (
    evidence_hk BYTEA NOT NULL REFERENCES compliance.sox_evidence_h(evidence_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    control_test_hk BYTEA REFERENCES compliance.sox_control_test_h(control_test_hk),
    evidence_type VARCHAR(50) NOT NULL,        -- SCREENSHOT, REPORT, EMAIL, AUDIT_LOG
    evidence_description TEXT NOT NULL,
    file_path TEXT,
    file_hash BYTEA,                          -- For integrity verification
    created_by VARCHAR(100) NOT NULL,
    evidence_date DATE NOT NULL,
    retention_period INTERVAL DEFAULT '7 years',
    confidentiality_level VARCHAR(20) DEFAULT 'CONFIDENTIAL',
    reviewer VARCHAR(100),
    review_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (evidence_hk, load_date)
);

-- ==================================================
-- INDEXES FOR PERFORMANCE
-- ==================================================

-- SOX Control Period Indexes
CREATE INDEX idx_sox_control_period_h_tenant_year_quarter 
ON compliance.sox_control_period_h USING btree (tenant_hk);

CREATE INDEX idx_sox_control_period_s_year_quarter 
ON compliance.sox_control_period_s USING btree (fiscal_year, fiscal_quarter);

CREATE INDEX idx_sox_control_period_s_status 
ON compliance.sox_control_period_s USING btree (period_status) 
WHERE load_end_date IS NULL;

-- SOX Control Indexes
CREATE INDEX idx_sox_control_h_tenant 
ON compliance.sox_control_h USING btree (tenant_hk);

CREATE INDEX idx_sox_control_s_category_type 
ON compliance.sox_control_s USING btree (control_category, control_type) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_sox_control_s_key_controls 
ON compliance.sox_control_s USING btree (is_key_control) 
WHERE load_end_date IS NULL AND is_key_control = true;

-- SOX Control Test Indexes
CREATE INDEX idx_sox_control_test_h_tenant 
ON compliance.sox_control_test_h USING btree (tenant_hk);

CREATE INDEX idx_sox_control_test_s_period_control 
ON compliance.sox_control_test_s USING btree (control_period_hk, sox_control_hk) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_sox_control_test_s_result 
ON compliance.sox_control_test_s USING btree (test_result) 
WHERE load_end_date IS NULL;

-- ==================================================
-- SOX AUTOMATION FUNCTIONS
-- ==================================================

-- Create new SOX control period
CREATE OR REPLACE FUNCTION compliance.create_sox_control_period(
    p_tenant_hk BYTEA,
    p_fiscal_year INTEGER,
    p_fiscal_quarter INTEGER,
    p_period_start_date DATE,
    p_period_end_date DATE
) RETURNS BYTEA AS $$
DECLARE
    v_period_hk BYTEA;
    v_period_bk VARCHAR(255);
    v_due_date DATE;
BEGIN
    -- Generate business key and hash key
    v_period_bk := p_fiscal_year::text || '_Q' || p_fiscal_quarter::text;
    v_period_hk := util.hash_binary(encode(p_tenant_hk, 'hex') || '_' || v_period_bk);
    
    -- Calculate certification due date (45 days after quarter end)
    v_due_date := p_period_end_date + INTERVAL '45 days';
    
    -- Insert hub record
    INSERT INTO compliance.sox_control_period_h VALUES (
        v_period_hk, v_period_bk, p_tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    -- Insert satellite record
    INSERT INTO compliance.sox_control_period_s VALUES (
        v_period_hk, util.current_load_date(), NULL,
        util.hash_binary(v_period_bk || p_fiscal_year::text || p_fiscal_quarter::text),
        p_fiscal_year, p_fiscal_quarter,
        p_period_start_date, p_period_end_date, v_due_date,
        'OPEN', 0, 0, 0, false, false, false,
        util.get_record_source()
    );
    
    RETURN v_period_hk;
END;
$$ LANGUAGE plpgsql;

-- Create SOX control definition
CREATE OR REPLACE FUNCTION compliance.create_sox_control(
    p_tenant_hk BYTEA,
    p_control_id VARCHAR(100),
    p_control_category VARCHAR(50),
    p_control_type VARCHAR(50),
    p_control_description TEXT,
    p_control_objective TEXT,
    p_owner_role VARCHAR(100),
    p_risk_rating VARCHAR(20) DEFAULT 'MEDIUM',
    p_is_key_control BOOLEAN DEFAULT false
) RETURNS BYTEA AS $$
DECLARE
    v_control_hk BYTEA;
    v_control_bk VARCHAR(255);
BEGIN
    v_control_bk := p_control_id;
    v_control_hk := util.hash_binary(encode(p_tenant_hk, 'hex') || '_' || v_control_bk);
    
    -- Insert hub record
    INSERT INTO compliance.sox_control_h VALUES (
        v_control_hk, v_control_bk, p_tenant_hk,
        util.current_load_date(), util.get_record_source()
    ) ON CONFLICT DO NOTHING;
    
    -- Insert satellite record
    INSERT INTO compliance.sox_control_s VALUES (
        v_control_hk, util.current_load_date(), NULL,
        util.hash_binary(v_control_bk || p_control_description || p_control_objective),
        p_control_category, p_control_type,
        p_control_description, p_control_objective,
        p_risk_rating, 'QUARTERLY', 'MANUAL',
        p_owner_role, p_is_key_control, true, true,
        util.get_record_source()
    );
    
    RETURN v_control_hk;
END;
$$ LANGUAGE plpgsql;

-- Execute SOX control test
CREATE OR REPLACE FUNCTION compliance.execute_sox_control_test(
    p_tenant_hk BYTEA,
    p_sox_control_hk BYTEA,
    p_control_period_hk BYTEA,
    p_tested_by VARCHAR(100),
    p_test_method VARCHAR(50),
    p_test_result VARCHAR(20),
    p_sample_size INTEGER DEFAULT 1,
    p_exceptions_identified INTEGER DEFAULT 0,
    p_test_evidence TEXT DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_test_hk BYTEA;
    v_test_bk VARCHAR(255);
    v_control_bk VARCHAR(255);
    v_period_bk VARCHAR(255);
BEGIN
    -- Get business keys for naming
    SELECT sox_control_bk INTO v_control_bk
    FROM compliance.sox_control_h 
    WHERE sox_control_hk = p_sox_control_hk;
    
    SELECT control_period_bk INTO v_period_bk
    FROM compliance.sox_control_period_h 
    WHERE control_period_hk = p_control_period_hk;
    
    v_test_bk := v_control_bk || '_' || v_period_bk || '_TEST';
    v_test_hk := util.hash_binary(encode(p_tenant_hk, 'hex') || '_' || v_test_bk || '_' || CURRENT_TIMESTAMP::text);
    
    -- Insert hub record
    INSERT INTO compliance.sox_control_test_h VALUES (
        v_test_hk, v_test_bk, p_tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    -- Insert satellite record
    INSERT INTO compliance.sox_control_test_s VALUES (
        v_test_hk, util.current_load_date(), NULL,
        util.hash_binary(v_test_bk || p_test_result || p_tested_by),
        p_sox_control_hk, p_control_period_hk, CURRENT_DATE,
        p_tested_by, p_test_method, p_sample_size, p_exceptions_identified,
        p_test_result, p_test_evidence, NULL, NULL, NULL, NULL, NULL,
        util.get_record_source()
    );
    
    RETURN v_test_hk;
END;
$$ LANGUAGE plpgsql;

-- Management certification function
CREATE OR REPLACE FUNCTION compliance.create_sox_certification(
    p_tenant_hk BYTEA,
    p_control_period_hk BYTEA,
    p_certification_type VARCHAR(50),
    p_certifying_officer VARCHAR(100),
    p_certification_statement TEXT,
    p_disclosure_controls_effective BOOLEAN,
    p_internal_controls_effective BOOLEAN
) RETURNS BYTEA AS $$
DECLARE
    v_cert_hk BYTEA;
    v_cert_bk VARCHAR(255);
    v_period_bk VARCHAR(255);
BEGIN
    -- Get period business key
    SELECT control_period_bk INTO v_period_bk
    FROM compliance.sox_control_period_h 
    WHERE control_period_hk = p_control_period_hk;
    
    v_cert_bk := 'SOX_' || p_certification_type || '_' || v_period_bk;
    v_cert_hk := util.hash_binary(encode(p_tenant_hk, 'hex') || '_' || v_cert_bk);
    
    -- Insert hub record
    INSERT INTO compliance.sox_certification_h VALUES (
        v_cert_hk, v_cert_bk, p_tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    -- Insert satellite record
    INSERT INTO compliance.sox_certification_s VALUES (
        v_cert_hk, util.current_load_date(), NULL,
        util.hash_binary(v_cert_bk || p_certifying_officer || CURRENT_TIMESTAMP::text),
        p_control_period_hk, p_certification_type, p_certifying_officer,
        CURRENT_TIMESTAMP, p_certification_statement,
        p_disclosure_controls_effective, p_internal_controls_effective,
        false, false, false, NULL, false, NULL,
        util.get_record_source()
    );
    
    RETURN v_cert_hk;
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- SOX DASHBOARD AND REPORTING
-- ==================================================

-- SOX compliance dashboard view
CREATE OR REPLACE VIEW compliance.sox_compliance_dashboard AS
SELECT 
    cp.control_period_bk,
    cps.fiscal_year,
    cps.fiscal_quarter,
    cps.period_status,
    cps.certification_due_date,
    cps.total_controls,
    cps.controls_tested,
    cps.controls_passed,
    CASE 
        WHEN cps.controls_tested > 0 THEN 
            ROUND((cps.controls_passed::DECIMAL / cps.controls_tested) * 100, 2)
        ELSE 0 
    END as pass_rate_percent,
    cps.ceo_certified,
    cps.cfo_certified,
    cps.external_auditor_reviewed,
    CASE 
        WHEN cps.certification_due_date < CURRENT_DATE THEN 'OVERDUE'
        WHEN cps.certification_due_date <= CURRENT_DATE + INTERVAL '7 days' THEN 'DUE_SOON'
        ELSE 'ON_TRACK'
    END as status_indicator
FROM compliance.sox_control_period_h cp
JOIN compliance.sox_control_period_s cps ON cp.control_period_hk = cps.control_period_hk
WHERE cps.load_end_date IS NULL
ORDER BY cps.fiscal_year DESC, cps.fiscal_quarter DESC;

-- ==================================================
-- INITIAL SOX CONTROL SETUP
-- ==================================================

-- Function to setup default SOX controls
CREATE OR REPLACE FUNCTION compliance.setup_default_sox_controls(
    p_tenant_hk BYTEA
) RETURNS INTEGER AS $$
DECLARE
    v_controls_created INTEGER := 0;
    v_control_hk BYTEA;
BEGIN
    -- IT General Controls (ITGC)
    SELECT compliance.create_sox_control(
        p_tenant_hk, 'SOX_ITGC_ACCESS_001', 'ITGC', 'PREVENTIVE',
        'User access management and provisioning controls',
        'Ensure only authorized users have access to financial systems',
        'IT Security Officer', 'HIGH', true
    ) INTO v_control_hk;
    v_controls_created := v_controls_created + 1;
    
    SELECT compliance.create_sox_control(
        p_tenant_hk, 'SOX_ITGC_CHANGE_002', 'ITGC', 'PREVENTIVE',
        'Change management controls for financial applications',
        'Ensure all changes to financial systems are authorized and tested',
        'IT Change Manager', 'HIGH', true
    ) INTO v_control_hk;
    v_controls_created := v_controls_created + 1;
    
    SELECT compliance.create_sox_control(
        p_tenant_hk, 'SOX_ITGC_BACKUP_003', 'ITGC', 'DETECTIVE',
        'Data backup and recovery procedures',
        'Ensure financial data is backed up and recoverable',
        'Database Administrator', 'MEDIUM', false
    ) INTO v_control_hk;
    v_controls_created := v_controls_created + 1;
    
    -- Entity Level Controls
    SELECT compliance.create_sox_control(
        p_tenant_hk, 'SOX_ENTITY_TONE_001', 'ENTITY_LEVEL', 'MANUAL',
        'Tone at the top and control environment assessment',
        'Ensure management demonstrates commitment to integrity and ethical values',
        'Chief Executive Officer', 'HIGH', true
    ) INTO v_control_hk;
    v_controls_created := v_controls_created + 1;
    
    SELECT compliance.create_sox_control(
        p_tenant_hk, 'SOX_ENTITY_OVERSIGHT_002', 'ENTITY_LEVEL', 'MANUAL',
        'Board oversight of financial reporting',
        'Ensure board provides appropriate oversight of financial reporting process',
        'Board Chair', 'HIGH', true
    ) INTO v_control_hk;
    v_controls_created := v_controls_created + 1;
    
    -- Process Level Controls
    SELECT compliance.create_sox_control(
        p_tenant_hk, 'SOX_PROCESS_REVENUE_001', 'PROCESS_LEVEL', 'AUTOMATED',
        'Revenue recognition controls',
        'Ensure revenue is recognized in accordance with accounting standards',
        'Controller', 'HIGH', true
    ) INTO v_control_hk;
    v_controls_created := v_controls_created + 1;
    
    SELECT compliance.create_sox_control(
        p_tenant_hk, 'SOX_PROCESS_EXPENSE_002', 'PROCESS_LEVEL', 'SEMI_AUTO',
        'Expense accrual and cut-off controls',
        'Ensure expenses are recorded in the correct period',
        'Accounting Manager', 'MEDIUM', false
    ) INTO v_control_hk;
    v_controls_created := v_controls_created + 1;
    
    RETURN v_controls_created;
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- COMMENTS FOR DOCUMENTATION
-- ==================================================

COMMENT ON SCHEMA compliance IS 'Enhanced compliance schema with SOX Sarbanes-Oxley Act automation';

COMMENT ON TABLE compliance.sox_control_period_h IS 'Hub table for SOX control testing periods (quarterly)';
COMMENT ON TABLE compliance.sox_control_period_s IS 'Status and details of SOX control periods with certification tracking';

COMMENT ON TABLE compliance.sox_control_h IS 'Hub table for SOX control definitions';
COMMENT ON TABLE compliance.sox_control_s IS 'Details of SOX controls including categories, objectives, and ownership';

COMMENT ON TABLE compliance.sox_control_test_h IS 'Hub table for SOX control test executions';
COMMENT ON TABLE compliance.sox_control_test_s IS 'Results and evidence from SOX control testing';

COMMENT ON TABLE compliance.sox_certification_h IS 'Hub table for management SOX certifications';
COMMENT ON TABLE compliance.sox_certification_s IS 'Management certification details for SOX compliance (CEO/CFO)';

COMMENT ON TABLE compliance.sox_evidence_h IS 'Hub table for SOX compliance evidence management';
COMMENT ON TABLE compliance.sox_evidence_s IS 'Evidence details supporting SOX control testing and compliance';

-- SOX Compliance Automation (FIXED) deployment completed successfully!
-- Enhanced existing compliance schema with SOX Section 302 and 404 capabilities