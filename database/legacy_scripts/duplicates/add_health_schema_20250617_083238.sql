-- =====================================================
-- ONE BARN HEALTH MANAGEMENT SCHEMA
-- Data Vault 2.0 Implementation
-- =====================================================

-- Create health schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS health;
GRANT USAGE ON SCHEMA health TO barn_user;

-- =====================================================
-- PRACTITIONER MANAGEMENT (Veterinarians, Farriers, etc.)
-- =====================================================

-- Practitioner Hub (Veterinarians, Farriers, Dentists, etc.)
CREATE TABLE health.practitioner_h (
    practitioner_hk BYTEA PRIMARY KEY,
    practitioner_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(practitioner_bk, tenant_hk)
);

-- Practitioner Details Satellite
CREATE TABLE health.practitioner_details_s (
    practitioner_hk BYTEA NOT NULL REFERENCES health.practitioner_h(practitioner_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    practitioner_type VARCHAR(50) NOT NULL, -- VETERINARIAN, FARRIER, DENTIST, CHIROPRACTOR
    license_number VARCHAR(100),
    license_state VARCHAR(50),
    license_expiry_date DATE,
    clinic_name VARCHAR(255),
    phone VARCHAR(50),
    mobile_phone VARCHAR(50),
    email VARCHAR(255),
    emergency_phone VARCHAR(50),
    address_street VARCHAR(255),
    address_city VARCHAR(100),
    address_state VARCHAR(50),
    address_zip VARCHAR(20),
    specializations TEXT[],
    service_area_radius INTEGER, -- Miles from base location
    hourly_rate DECIMAL(10,2),
    emergency_rate DECIMAL(10,2),
    travel_fee DECIMAL(10,2),
    minimum_charge DECIMAL(10,2),
    payment_terms VARCHAR(100),
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    is_emergency_available BOOLEAN DEFAULT false,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (practitioner_hk, load_date)
);

-- =====================================================
-- APPOINTMENT MANAGEMENT
-- =====================================================

-- Appointment Hub
CREATE TABLE health.appointment_h (
    appointment_hk BYTEA PRIMARY KEY,
    appointment_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(appointment_bk, tenant_hk)
);

-- Appointment Details Satellite
CREATE TABLE health.appointment_details_s (
    appointment_hk BYTEA NOT NULL REFERENCES health.appointment_h(appointment_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    estimated_duration INTEGER, -- Minutes
    appointment_type VARCHAR(100) NOT NULL, -- ROUTINE, EMERGENCY, FOLLOW_UP, VACCINATION
    service_type VARCHAR(100) NOT NULL, -- VET_EXAM, FARRIER, DENTAL, CHIROPRACTIC
    purpose VARCHAR(255) NOT NULL,
    location VARCHAR(255), -- Stall number, arena, etc.
    status VARCHAR(50) DEFAULT 'SCHEDULED', -- SCHEDULED, CONFIRMED, IN_PROGRESS, COMPLETED, CANCELLED, NO_SHOW
    priority VARCHAR(20) DEFAULT 'NORMAL', -- LOW, NORMAL, HIGH, EMERGENCY
    estimated_cost DECIMAL(10,2),
    actual_cost DECIMAL(10,2),
    travel_fee DECIMAL(10,2),
    emergency_fee DECIMAL(10,2),
    special_instructions TEXT,
    preparation_notes TEXT,
    weather_dependent BOOLEAN DEFAULT false,
    requires_sedation BOOLEAN DEFAULT false,
    requires_assistant BOOLEAN DEFAULT false,
    completed_timestamp TIMESTAMP WITH TIME ZONE,
    cancelled_reason TEXT,
    no_show_reason TEXT,
    follow_up_required BOOLEAN DEFAULT false,
    follow_up_date DATE,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (appointment_hk, load_date)
);

-- Horse-Appointment Link
CREATE TABLE health.horse_appointment_l (
    link_horse_appointment_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    appointment_hk BYTEA NOT NULL REFERENCES health.appointment_h(appointment_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Practitioner-Appointment Link
CREATE TABLE health.practitioner_appointment_l (
    link_practitioner_appointment_hk BYTEA PRIMARY KEY,
    practitioner_hk BYTEA NOT NULL REFERENCES health.practitioner_h(practitioner_hk),
    appointment_hk BYTEA NOT NULL REFERENCES health.appointment_h(appointment_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- =====================================================
-- TREATMENT MANAGEMENT
-- =====================================================

-- Treatment Hub
CREATE TABLE health.treatment_h (
    treatment_hk BYTEA PRIMARY KEY,
    treatment_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(treatment_bk, tenant_hk)
);

-- Treatment Details Satellite
CREATE TABLE health.treatment_details_s (
    treatment_hk BYTEA NOT NULL REFERENCES health.treatment_h(treatment_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    treatment_date DATE NOT NULL,
    treatment_time TIME,
    treatment_type VARCHAR(100) NOT NULL, -- VACCINATION, MEDICATION, SURGERY, THERAPY, SHOEING
    treatment_category VARCHAR(50) NOT NULL, -- PREVENTIVE, THERAPEUTIC, EMERGENCY, ROUTINE
    procedure_name VARCHAR(255) NOT NULL,
    diagnosis VARCHAR(255),
    symptoms_observed TEXT,
    treatment_description TEXT NOT NULL,
    medications_administered TEXT[],
    dosage_instructions TEXT,
    administration_method VARCHAR(100), -- ORAL, INJECTION, TOPICAL, IV
    treatment_location VARCHAR(100), -- STALL, CLINIC, ARENA, TRAILER
    anesthesia_used BOOLEAN DEFAULT false,
    anesthesia_type VARCHAR(100),
    complications TEXT,
    treatment_outcome VARCHAR(100), -- SUCCESSFUL, PARTIAL, UNSUCCESSFUL, ONGOING
    follow_up_required BOOLEAN DEFAULT false,
    follow_up_instructions TEXT,
    next_treatment_date DATE,
    restrictions TEXT, -- Activity restrictions
    cost DECIMAL(10,2),
    insurance_claim_number VARCHAR(100),
    practitioner_notes TEXT,
    owner_instructions TEXT,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (treatment_hk, load_date)
);

-- Horse-Treatment Link
CREATE TABLE health.horse_treatment_l (
    link_horse_treatment_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    treatment_hk BYTEA NOT NULL REFERENCES health.treatment_h(treatment_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Practitioner-Treatment Link
CREATE TABLE health.practitioner_treatment_l (
    link_practitioner_treatment_hk BYTEA PRIMARY KEY,
    practitioner_hk BYTEA NOT NULL REFERENCES health.practitioner_h(practitioner_hk),
    treatment_hk BYTEA NOT NULL REFERENCES health.treatment_h(treatment_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- =====================================================
-- HEALTH DOCUMENT MANAGEMENT
-- =====================================================

-- Health Document Hub (Coggins, Vaccinations, Health Certificates)
CREATE TABLE health.health_document_h (
    health_document_hk BYTEA PRIMARY KEY,
    health_document_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(health_document_bk, tenant_hk)
);

-- Health Document Details Satellite
CREATE TABLE health.health_document_details_s (
    health_document_hk BYTEA NOT NULL REFERENCES health.health_document_h(health_document_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    document_type VARCHAR(100) NOT NULL, -- COGGINS, HEALTH_CERTIFICATE, VACCINATION_RECORD, LAB_RESULT
    document_name VARCHAR(255) NOT NULL,
    document_number VARCHAR(100),
    issue_date DATE NOT NULL,
    expiry_date DATE,
    issuing_authority VARCHAR(255),
    issuing_practitioner VARCHAR(255),
    test_results TEXT,
    test_method VARCHAR(100),
    laboratory_name VARCHAR(255),
    compliance_status VARCHAR(50) DEFAULT 'CURRENT', -- CURRENT, EXPIRED, PENDING, INVALID
    required_for TEXT[], -- TRAVEL, COMPETITION, BOARDING, SALE
    document_url VARCHAR(500), -- Link to stored document
    document_hash VARCHAR(64), -- For document integrity
    verification_code VARCHAR(100),
    notes TEXT,
    reminder_sent BOOLEAN DEFAULT false,
    renewal_reminder_days INTEGER DEFAULT 30,
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (health_document_hk, load_date)
);

-- Horse-Health Document Link
CREATE TABLE health.horse_health_document_l (
    link_horse_health_document_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    health_document_hk BYTEA NOT NULL REFERENCES health.health_document_h(health_document_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- =====================================================
-- HEALTH MONITORING & TRACKING
-- =====================================================

-- Health Monitoring Hub (Daily health checks, vital signs)
CREATE TABLE health.health_monitoring_h (
    health_monitoring_hk BYTEA PRIMARY KEY,
    health_monitoring_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(health_monitoring_bk, tenant_hk)
);

-- Health Monitoring Details Satellite
CREATE TABLE health.health_monitoring_details_s (
    health_monitoring_hk BYTEA NOT NULL REFERENCES health.health_monitoring_h(health_monitoring_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    monitoring_date DATE NOT NULL,
    monitoring_time TIME,
    monitoring_type VARCHAR(100) NOT NULL, -- DAILY_CHECK, VITAL_SIGNS, WEIGHT, TEMPERATURE
    recorded_by VARCHAR(255), -- Staff member name
    temperature DECIMAL(4,1), -- Fahrenheit
    heart_rate INTEGER, -- BPM
    respiratory_rate INTEGER, -- Breaths per minute
    weight_pounds INTEGER,
    body_condition_score DECIMAL(2,1), -- 1-9 scale
    appetite VARCHAR(50), -- EXCELLENT, GOOD, FAIR, POOR, NONE
    water_consumption VARCHAR(50), -- NORMAL, INCREASED, DECREASED
    energy_level VARCHAR(50), -- HIGH, NORMAL, LOW, LETHARGIC
    attitude VARCHAR(50), -- ALERT, NORMAL, DULL, AGGRESSIVE
    gait_assessment VARCHAR(100), -- SOUND, SLIGHT_LAMENESS, MODERATE_LAMENESS, SEVERE_LAMENESS
    coat_condition VARCHAR(50), -- EXCELLENT, GOOD, FAIR, POOR
    mucous_membrane_color VARCHAR(50), -- PINK, PALE, YELLOW, BLUE, RED
    capillary_refill_time DECIMAL(2,1), -- Seconds
    digital_pulse VARCHAR(50), -- NORMAL, STRONG, WEAK, ABSENT
    gut_sounds VARCHAR(50), -- NORMAL, INCREASED, DECREASED, ABSENT
    manure_consistency VARCHAR(50), -- NORMAL, SOFT, HARD, LOOSE, WATERY
    urination VARCHAR(50), -- NORMAL, FREQUENT, INFREQUENT, STRAINING
    observations TEXT,
    concerns TEXT,
    action_taken TEXT,
    follow_up_required BOOLEAN DEFAULT false,
    veterinarian_notified BOOLEAN DEFAULT false,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (health_monitoring_hk, load_date)
);

-- Horse-Health Monitoring Link
CREATE TABLE health.horse_health_monitoring_l (
    link_horse_health_monitoring_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    health_monitoring_hk BYTEA NOT NULL REFERENCES health.health_monitoring_h(health_monitoring_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- =====================================================
-- REFERENCE DATA FOR HEALTH MANAGEMENT
-- =====================================================

-- Treatment Types Reference
CREATE TABLE ref.treatment_type_r (
    treatment_type_code VARCHAR(20) PRIMARY KEY,
    treatment_type_name VARCHAR(100) NOT NULL,
    treatment_category VARCHAR(50) NOT NULL, -- PREVENTIVE, THERAPEUTIC, EMERGENCY, ROUTINE
    typical_duration INTEGER, -- Minutes
    requires_practitioner BOOLEAN DEFAULT true,
    requires_sedation BOOLEAN DEFAULT false,
    typical_cost_min DECIMAL(10,2),
    typical_cost_max DECIMAL(10,2),
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Medication Reference
CREATE TABLE ref.medication_r (
    medication_code VARCHAR(20) PRIMARY KEY,
    medication_name VARCHAR(255) NOT NULL,
    generic_name VARCHAR(255),
    medication_type VARCHAR(100), -- ANTIBIOTIC, ANTI_INFLAMMATORY, ANALGESIC, VACCINE
    dosage_form VARCHAR(50), -- TABLET, INJECTION, PASTE, POWDER
    strength VARCHAR(100),
    withdrawal_period_days INTEGER, -- For competition
    prescription_required BOOLEAN DEFAULT true,
    controlled_substance BOOLEAN DEFAULT false,
    storage_requirements TEXT,
    side_effects TEXT,
    contraindications TEXT,
    is_active BOOLEAN DEFAULT true,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Practitioner indexes
CREATE INDEX idx_practitioner_h_practitioner_bk_tenant ON health.practitioner_h(practitioner_bk, tenant_hk);
CREATE INDEX idx_practitioner_details_s_type ON health.practitioner_details_s(practitioner_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_practitioner_details_s_active ON health.practitioner_details_s(is_active) WHERE load_end_date IS NULL;

-- Appointment indexes
CREATE INDEX idx_appointment_h_appointment_bk_tenant ON health.appointment_h(appointment_bk, tenant_hk);
CREATE INDEX idx_appointment_details_s_date ON health.appointment_details_s(appointment_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_appointment_details_s_status ON health.appointment_details_s(status) WHERE load_end_date IS NULL;
CREATE INDEX idx_appointment_details_s_type ON health.appointment_details_s(appointment_type) WHERE load_end_date IS NULL;

-- Treatment indexes
CREATE INDEX idx_treatment_h_treatment_bk_tenant ON health.treatment_h(treatment_bk, tenant_hk);
CREATE INDEX idx_treatment_details_s_date ON health.treatment_details_s(treatment_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_treatment_details_s_type ON health.treatment_details_s(treatment_type) WHERE load_end_date IS NULL;

-- Health document indexes
CREATE INDEX idx_health_document_h_document_bk_tenant ON health.health_document_h(health_document_bk, tenant_hk);
CREATE INDEX idx_health_document_details_s_type ON health.health_document_details_s(document_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_health_document_details_s_expiry ON health.health_document_details_s(expiry_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_health_document_details_s_compliance ON health.health_document_details_s(compliance_status) WHERE load_end_date IS NULL;

-- Health monitoring indexes
CREATE INDEX idx_health_monitoring_h_monitoring_bk_tenant ON health.health_monitoring_h(health_monitoring_bk, tenant_hk);
CREATE INDEX idx_health_monitoring_details_s_date ON health.health_monitoring_details_s(monitoring_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_health_monitoring_details_s_type ON health.health_monitoring_details_s(monitoring_type) WHERE load_end_date IS NULL;

-- Link table indexes
CREATE INDEX idx_horse_appointment_l_horse ON health.horse_appointment_l(horse_hk);
CREATE INDEX idx_horse_appointment_l_appointment ON health.horse_appointment_l(appointment_hk);
CREATE INDEX idx_practitioner_appointment_l_practitioner ON health.practitioner_appointment_l(practitioner_hk);
CREATE INDEX idx_practitioner_appointment_l_appointment ON health.practitioner_appointment_l(appointment_hk);
CREATE INDEX idx_horse_treatment_l_horse ON health.horse_treatment_l(horse_hk);
CREATE INDEX idx_horse_treatment_l_treatment ON health.horse_treatment_l(treatment_hk);
CREATE INDEX idx_horse_health_document_l_horse ON health.horse_health_document_l(horse_hk);
CREATE INDEX idx_horse_health_document_l_document ON health.horse_health_document_l(health_document_hk);
CREATE INDEX idx_horse_health_monitoring_l_horse ON health.horse_health_monitoring_l(horse_hk);

-- =====================================================
-- INITIAL REFERENCE DATA
-- =====================================================

-- Insert common treatment types
INSERT INTO ref.treatment_type_r (treatment_type_code, treatment_type_name, treatment_category, typical_duration, requires_practitioner, typical_cost_min, typical_cost_max, description) VALUES
('VAC_CORE', 'Core Vaccinations', 'PREVENTIVE', 30, true, 150.00, 250.00, 'Annual core vaccinations including tetanus, EEE/WEE, West Nile, rabies'),
('VAC_RISK', 'Risk-Based Vaccinations', 'PREVENTIVE', 20, true, 50.00, 150.00, 'Risk-based vaccinations such as strangles, flu/rhino, Potomac horse fever'),
('COGGINS', 'Coggins Test', 'PREVENTIVE', 15, true, 45.00, 75.00, 'Annual Coggins test for equine infectious anemia'),
('DENTAL', 'Dental Examination', 'ROUTINE', 45, true, 200.00, 400.00, 'Routine dental examination and floating'),
('FARRIER', 'Farrier Service', 'ROUTINE', 60, true, 150.00, 300.00, 'Hoof trimming and shoeing services'),
('WELLNESS', 'Wellness Examination', 'ROUTINE', 45, true, 100.00, 200.00, 'Annual wellness examination'),
('EMERGENCY', 'Emergency Call', 'EMERGENCY', 60, true, 300.00, 800.00, 'Emergency veterinary call'),
('LAMENESS', 'Lameness Examination', 'THERAPEUTIC', 90, true, 200.00, 500.00, 'Lameness evaluation and diagnosis');

-- Insert common medications
INSERT INTO ref.medication_r (medication_code, medication_name, generic_name, medication_type, dosage_form, prescription_required, withdrawal_period_days) VALUES
('BUTE', 'Phenylbutazone', 'Phenylbutazone', 'ANTI_INFLAMMATORY', 'TABLET', true, 7),
('BANAMINE', 'Banamine', 'Flunixin Meglumine', 'ANTI_INFLAMMATORY', 'INJECTION', true, 1),
('PENICILLIN', 'Penicillin G', 'Penicillin G Procaine', 'ANTIBIOTIC', 'INJECTION', true, 10),
('DORMOSEDAN', 'Dormosedan', 'Detomidine', 'SEDATIVE', 'INJECTION', true, 7),
('ADEQUAN', 'Adequan', 'Polysulfated Glycosaminoglycan', 'JOINT_THERAPY', 'INJECTION', true, 0);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA health TO barn_user;

-- Success message
SELECT 'Health Management Schema Successfully Created!' as status; 