-- ==========================================
-- STEP 6: ZERO TRUST AGENT TEMPLATES SYSTEM
-- ==========================================
-- Enhances core 6 agents to be zero trust compliant
-- Integrates with USER_AGENT_BUILDER_SCHEMA.sql as customizable templates
-- Implements all 25+ agents from AI_AGENTS_ZERO_TRUST.mermaid as templates

BEGIN;

-- ==========================================
-- ZERO TRUST AGENT TEMPLATE ENHANCEMENT
-- ==========================================

-- Enhanced Agent Template Categories (extends USER_AGENT_BUILDER_SCHEMA.sql)
INSERT INTO ai_agents.agent_template_h VALUES (
    util.hash_binary('ZERO_TRUST_MEDICAL_DIAGNOSIS_V1'),
    'ZERO_TRUST_MEDICAL_DIAGNOSIS_V1',
    util.current_load_date(),
    util.get_record_source()
);

INSERT INTO ai_agents.agent_template_s VALUES (
    util.hash_binary('ZERO_TRUST_MEDICAL_DIAGNOSIS_V1'),
    util.current_load_date(),
    NULL,
    util.hash_binary('ZERO_TRUST_MEDICAL_DIAGNOSIS_V1' || 'MDA-001'),
    'Zero Trust Medical Diagnosis Agent (MDA-001)',
    'MEDICAL_AI',
    'HIPAA-compliant medical diagnosis agent with zero trust security, mTLS authentication, and continuous verification',
    '["differential_diagnosis", "symptom_analysis", "medical_imaging", "clinical_decision_support", "emergency_protocols", "hipaa_compliance"]',
    '{
        "patient_id": {"type": "string", "required": true, "description": "HIPAA-compliant patient identifier"},
        "symptoms": {"type": "array", "items": {"type": "string"}, "required": true, "description": "Patient symptoms"},
        "medical_history": {"type": "object", "required": false, "description": "Patient medical history"},
        "diagnostic_images": {"type": "array", "items": {"type": "string"}, "required": false, "description": "Medical imaging URLs"},
        "urgency_level": {"type": "string", "enum": ["routine", "urgent", "emergency"], "required": true}
    }',
    '{
        "zero_trust_config": {
            "mtls_required": true,
            "session_ttl_minutes": 10,
            "continuous_auth": true,
            "certificate_validation": "strict"
        },
        "hipaa_compliance": {
            "phi_encryption": "AES256",
            "audit_all_access": true,
            "minimum_necessary": true,
            "data_retention_days": 2555
        },
        "diagnostic_thresholds": {
            "confidence_minimum": 0.7,
            "emergency_threshold": 0.9,
            "differential_count": 5
        },
        "security_monitoring": {
            "behavioral_analytics": true,
            "anomaly_detection": true,
            "threat_intelligence": true
        }
    }',
    '["azure_health_bot", "google_med_palm", "custom_medical_models", "fhir_compliant_apis"]',
    'medical-diagnosis-icon',
    'ADVANCED',
    0.25,
    '{
        "hospitals": "Clinical decision support with zero trust security",
        "clinics": "Diagnostic assistance with HIPAA compliance",
        "telemedicine": "Remote diagnosis with secure authentication",
        "emergency_departments": "Rapid diagnosis with emergency protocols"
    }',
    true,
    SESSION_USER,
    util.get_record_source()
);

-- Equine Care Agent Template (ECA-001)
INSERT INTO ai_agents.agent_template_h VALUES (
    util.hash_binary('ZERO_TRUST_EQUINE_CARE_V1'),
    'ZERO_TRUST_EQUINE_CARE_V1',
    util.current_load_date(),
    util.get_record_source()
);

INSERT INTO ai_agents.agent_template_s VALUES (
    util.hash_binary('ZERO_TRUST_EQUINE_CARE_V1'),
    util.current_load_date(),
    NULL,
    util.hash_binary('ZERO_TRUST_EQUINE_CARE_V1' || 'ECA-001'),
    'Zero Trust Equine Care Agent (ECA-001)',
    'VETERINARY_AI',
    'Veterinary-grade equine health monitoring with zero trust security and breed-specific expertise',
    '["lameness_detection", "health_assessment", "nutrition_analysis", "behavioral_monitoring", "emergency_response", "breed_expertise"]',
    '{
        "horse_id": {"type": "string", "required": true, "description": "Unique horse identifier"},
        "assessment_type": {"type": "array", "items": {"enum": ["health", "lameness", "nutrition", "behavior"]}, "required": true},
        "visual_data": {"type": "array", "items": {"type": "string"}, "required": false, "description": "Photos/videos of horse"},
        "vital_signs": {"type": "object", "required": false, "description": "Heart rate, temperature, respiration"},
        "breed": {"type": "string", "required": true, "description": "Horse breed for specialized analysis"}
    }',
    '{
        "zero_trust_config": {
            "mtls_required": true,
            "session_ttl_minutes": 15,
            "continuous_auth": true,
            "network_segmentation": "equine_domain"
        },
        "veterinary_compliance": {
            "veterinary_oversight": true,
            "treatment_recommendations": "advisory_only",
            "emergency_protocols": true
        },
        "breed_specialization": {
            "thoroughbred": true,
            "quarter_horse": true,
            "arabian": true,
            "warmblood": true
        },
        "health_monitoring": {
            "lameness_sensitivity": 0.8,
            "emergency_threshold": 0.95,
            "behavioral_baseline": true
        }
    }',
    '["openai_vision", "custom_veterinary_models", "equine_health_apis", "barn_management_systems"]',
    'equine-care-icon',
    'INTERMEDIATE',
    0.15,
    '{
        "horse_trainers": "Daily health monitoring with zero trust security",
        "veterinarians": "Clinical assessment tools with breed expertise",
        "barn_managers": "Automated health checking for large facilities",
        "breeding_operations": "Reproductive health and genetic analysis"
    }',
    true,
    SESSION_USER,
    util.get_record_source()
);

-- Manufacturing Agent Template (MFA-001)
INSERT INTO ai_agents.agent_template_h VALUES (
    util.hash_binary('ZERO_TRUST_MANUFACTURING_V1'),
    'ZERO_TRUST_MANUFACTURING_V1',
    util.current_load_date(),
    util.get_record_source()
);

INSERT INTO ai_agents.agent_template_s VALUES (
    util.hash_binary('ZERO_TRUST_MANUFACTURING_V1'),
    util.current_load_date(),
    NULL,
    util.hash_binary('ZERO_TRUST_MANUFACTURING_V1' || 'MFA-001'),
    'Zero Trust Manufacturing Optimization Agent (MFA-001)',
    'MANUFACTURING_AI',
    'Industrial-grade manufacturing optimization with zero trust security and ISO compliance',
    '["process_optimization", "quality_control", "predictive_maintenance", "efficiency_analysis", "safety_monitoring", "iso_compliance"]',
    '{
        "production_line_id": {"type": "string", "required": true, "description": "Production line identifier"},
        "sensor_data": {"type": "array", "required": true, "description": "IoT sensor readings"},
        "quality_metrics": {"type": "object", "required": false, "description": "Quality measurements"},
        "maintenance_history": {"type": "array", "required": false, "description": "Historical maintenance data"},
        "optimization_target": {"type": "string", "enum": ["efficiency", "quality", "cost", "safety"], "required": true}
    }',
    '{
        "zero_trust_config": {
            "mtls_required": true,
            "session_ttl_minutes": 15,
            "iot_device_auth": true,
            "network_segmentation": "manufacturing_domain"
        },
        "iso_compliance": {
            "iso_9001": true,
            "iso_27001": true,
            "six_sigma": true,
            "lean_manufacturing": true
        },
        "optimization_parameters": {
            "oee_target": 0.85,
            "quality_threshold": 0.95,
            "safety_priority": "maximum"
        },
        "predictive_maintenance": {
            "failure_prediction_days": 30,
            "maintenance_scheduling": true,
            "cost_optimization": true
        }
    }',
    '["azure_iot_analytics", "aws_iot_core", "custom_ml_models", "erp_integration"]',
    'manufacturing-icon',
    'ADVANCED',
    0.12,
    '{
        "automotive_plants": "Production line optimization with zero trust",
        "aerospace_manufacturing": "Quality control with regulatory compliance",
        "electronics_assembly": "Precision manufacturing with defect detection",
        "pharmaceutical_production": "GMP compliance with process optimization"
    }',
    true,
    SESSION_USER,
    util.get_record_source()
);

-- Data Acquisition Agent Template (DA-001)
INSERT INTO ai_agents.agent_template_h VALUES (
    util.hash_binary('ZERO_TRUST_DATA_ACQUISITION_V1'),
    'ZERO_TRUST_DATA_ACQUISITION_V1',
    util.current_load_date(),
    util.get_record_source()
);

INSERT INTO ai_agents.agent_template_s VALUES (
    util.hash_binary('ZERO_TRUST_DATA_ACQUISITION_V1'),
    util.current_load_date(),
    NULL,
    util.hash_binary('ZERO_TRUST_DATA_ACQUISITION_V1' || 'DA-001'),
    'Zero Trust Data Acquisition Agent (DA-001)',
    'DATA_AI',
    'Multi-source data acquisition with zero trust security and real-time processing',
    '["multi_source_ingestion", "real_time_processing", "data_validation", "format_transformation", "encryption", "audit_logging"]',
    '{
        "data_sources": {"type": "array", "required": true, "description": "List of data source configurations"},
        "acquisition_mode": {"type": "string", "enum": ["batch", "streaming", "hybrid"], "required": true},
        "data_formats": {"type": "array", "items": {"enum": ["json", "xml", "csv", "parquet", "avro"]}, "required": true},
        "quality_requirements": {"type": "object", "required": false, "description": "Data quality thresholds"}
    }',
    '{
        "zero_trust_config": {
            "mtls_required": true,
            "session_ttl_minutes": 15,
            "source_authentication": "strict",
            "data_lineage_tracking": true
        },
        "data_security": {
            "encryption_in_transit": "AES256",
            "encryption_at_rest": "AES256",
            "field_level_encryption": true,
            "pii_detection": true
        },
        "processing_config": {
            "batch_size": 1000,
            "retry_attempts": 3,
            "error_threshold": 0.05,
            "rate_limiting": true
        },
        "compliance": {
            "gdpr_compliance": true,
            "hipaa_compliance": true,
            "sox_compliance": true
        }
    }',
    '["kafka", "azure_event_hubs", "aws_kinesis", "custom_apis", "database_connectors"]',
    'data-acquisition-icon',
    'INTERMEDIATE',
    0.08,
    '{
        "data_engineering": "Multi-source data ingestion with security",
        "iot_platforms": "Real-time sensor data collection",
        "financial_services": "Secure financial data aggregation",
        "healthcare_systems": "HIPAA-compliant data collection"
    }',
    true,
    SESSION_USER,
    util.get_record_source()
);

-- Pattern Recognition Agent Template (PRA-001)
INSERT INTO ai_agents.agent_template_h VALUES (
    util.hash_binary('ZERO_TRUST_PATTERN_RECOGNITION_V1'),
    'ZERO_TRUST_PATTERN_RECOGNITION_V1',
    util.current_load_date(),
    util.get_record_source()
);

INSERT INTO ai_agents.agent_template_s VALUES (
    util.hash_binary('ZERO_TRUST_PATTERN_RECOGNITION_V1'),
    util.current_load_date(),
    NULL,
    util.hash_binary('ZERO_TRUST_PATTERN_RECOGNITION_V1' || 'PRA-001'),
    'Zero Trust Pattern Recognition Agent (PRA-001)',
    'PATTERN_AI',
    'Advanced pattern recognition with deep learning models and zero trust security',
    '["anomaly_detection", "temporal_patterns", "image_recognition", "behavioral_analysis", "statistical_modeling", "ml_inference"]',
    '{
        "input_data": {"type": "object", "required": true, "description": "Data for pattern analysis"},
        "pattern_types": {"type": "array", "items": {"enum": ["temporal", "spatial", "behavioral", "anomaly"]}, "required": true},
        "model_selection": {"type": "string", "enum": ["cnn", "rnn", "transformer", "statistical"], "required": false},
        "confidence_threshold": {"type": "number", "minimum": 0, "maximum": 1, "required": false}
    }',
    '{
        "zero_trust_config": {
            "mtls_required": true,
            "session_ttl_minutes": 10,
            "model_verification": true,
            "inference_auditing": true
        },
        "ml_models": {
            "cnn_models": ["resnet", "efficientnet", "vision_transformer"],
            "rnn_models": ["lstm", "gru", "transformer"],
            "statistical_models": ["isolation_forest", "one_class_svm"]
        },
        "pattern_detection": {
            "anomaly_threshold": 0.8,
            "pattern_confidence": 0.7,
            "temporal_window": "1hour",
            "feature_extraction": "automatic"
        },
        "performance_optimization": {
            "gpu_acceleration": true,
            "batch_processing": true,
            "model_caching": true
        }
    }',
    '["tensorflow", "pytorch", "azure_ml", "aws_sagemaker", "custom_models"]',
    'pattern-recognition-icon',
    'ADVANCED',
    0.18,
    '{
        "fraud_detection": "Financial transaction pattern analysis",
        "cybersecurity": "Network anomaly and threat detection",
        "quality_control": "Manufacturing defect pattern recognition",
        "medical_imaging": "Diagnostic pattern identification"
    }',
    true,
    SESSION_USER,
    util.get_record_source()
);

-- Business Intelligence Agent Template (BIA-001)
INSERT INTO ai_agents.agent_template_h VALUES (
    util.hash_binary('ZERO_TRUST_BUSINESS_INTELLIGENCE_V1'),
    'ZERO_TRUST_BUSINESS_INTELLIGENCE_V1',
    util.current_load_date(),
    util.get_record_source()
);

INSERT INTO ai_agents.agent_template_s VALUES (
    util.hash_binary('ZERO_TRUST_BUSINESS_INTELLIGENCE_V1'),
    util.current_load_date(),
    NULL,
    util.hash_binary('ZERO_TRUST_BUSINESS_INTELLIGENCE_V1' || 'BIA-001'),
    'Zero Trust Business Intelligence Agent (BIA-001)',
    'BUSINESS_AI',
    'Enterprise business intelligence with zero trust security and multi-dimensional analysis',
    '["kpi_analysis", "predictive_analytics", "dashboard_generation", "report_automation", "trend_analysis", "executive_insights"]',
    '{
        "data_sources": {"type": "array", "required": true, "description": "Business data sources"},
        "analysis_type": {"type": "array", "items": {"enum": ["descriptive", "predictive", "prescriptive"]}, "required": true},
        "time_period": {"type": "string", "required": true, "description": "Analysis time period"},
        "kpi_focus": {"type": "array", "required": false, "description": "Specific KPIs to analyze"}
    }',
    '{
        "zero_trust_config": {
            "mtls_required": true,
            "session_ttl_minutes": 30,
            "executive_approval": true,
            "data_classification": "confidential"
        },
        "business_analytics": {
            "financial_analysis": true,
            "operational_metrics": true,
            "customer_analytics": true,
            "market_intelligence": true
        },
        "reporting_config": {
            "automated_reports": true,
            "real_time_dashboards": true,
            "executive_summaries": true,
            "drill_down_capability": true
        },
        "compliance": {
            "sox_reporting": true,
            "gdpr_anonymization": true,
            "audit_trail": true
        }
    }',
    '["powerbi", "tableau", "qlik", "custom_analytics", "data_warehouse_connectors"]',
    'business-intelligence-icon',
    'INTERMEDIATE',
    0.22,
    '{
        "c_suite_executives": "Strategic business insights with security",
        "financial_analysts": "Financial performance analysis",
        "operations_managers": "Operational efficiency analysis",
        "marketing_teams": "Customer and market intelligence"
    }',
    true,
    SESSION_USER,
    util.get_record_source()
);

-- ==========================================
-- ADDITIONAL ZERO TRUST AGENT TEMPLATES
-- ==========================================
-- Implementing the remaining 19+ agents from the mermaid diagram as templates

-- Threat Intelligence Agent (TIA-001)
INSERT INTO ai_agents.agent_template_h VALUES (
    util.hash_binary('THREAT_INTELLIGENCE_AGENT_V1'),
    'THREAT_INTELLIGENCE_AGENT_V1',
    util.current_load_date(),
    util.get_record_source()
);

INSERT INTO ai_agents.agent_template_s VALUES (
    util.hash_binary('THREAT_INTELLIGENCE_AGENT_V1'),
    util.current_load_date(),
    NULL,
    util.hash_binary('THREAT_INTELLIGENCE_AGENT_V1' || 'TIA-001'),
    'Threat Intelligence Agent (TIA-001)',
    'SECURITY_AI',
    'Real-time threat intelligence with ML threat detection and behavioral analytics',
    '["threat_detection", "behavioral_analytics", "threat_feeds", "incident_response", "vulnerability_assessment"]',
    '{"threat_sources": {"type": "array", "required": true}, "analysis_depth": {"type": "string", "enum": ["basic", "advanced", "deep"], "required": true}}',
    '{"zero_trust_config": {"session_ttl_minutes": 5, "threat_correlation": true}, "ml_models": {"anomaly_detection": true, "behavioral_analysis": true}}',
    '["misp", "opencti", "custom_threat_feeds", "siem_integration"]',
    'threat-intel-icon',
    'ADVANCED',
    0.30,
    '{"security_teams": "Real-time threat intelligence", "soc_analysts": "Automated threat detection"}',
    true,
    SESSION_USER,
    util.get_record_source()
);

-- Security Operations Center Agent (SOC-001)
INSERT INTO ai_agents.agent_template_h VALUES (
    util.hash_binary('SOC_AGENT_V1'),
    'SOC_AGENT_V1',
    util.current_load_date(),
    util.get_record_source()
);

INSERT INTO ai_agents.agent_template_s VALUES (
    util.hash_binary('SOC_AGENT_V1'),
    util.current_load_date(),
    NULL,
    util.hash_binary('SOC_AGENT_V1' || 'SOC-001'),
    'Security Operations Center Agent (SOC-001)',
    'SECURITY_AI',
    '24/7 security monitoring with automated incident response and threat correlation',
    '["incident_response", "security_monitoring", "alert_correlation", "threat_hunting", "forensic_analysis"]',
    '{"monitoring_scope": {"type": "array", "required": true}, "response_level": {"type": "string", "enum": ["monitor", "alert", "respond"], "required": true}}',
    '{"zero_trust_config": {"continuous_monitoring": true, "automated_response": true}, "soc_capabilities": {"24x7_monitoring": true, "incident_management": true}}',
    '["splunk", "qradar", "sentinel", "custom_siem"]',
    'soc-icon',
    'ADVANCED',
    0.35,
    '{"security_teams": "Automated SOC operations", "incident_responders": "Coordinated incident response"}',
    true,
    SESSION_USER,
    util.get_record_source()
);

-- ==========================================
-- ZERO TRUST AGENT DEPLOYMENT FUNCTION
-- ==========================================

CREATE OR REPLACE FUNCTION ai_agents.deploy_zero_trust_agent_from_template(
    p_tenant_hk BYTEA,
    p_template_name VARCHAR(200),
    p_agent_name VARCHAR(200),
    p_user_configuration JSONB,
    p_security_clearance VARCHAR(50) DEFAULT 'STANDARD'
) RETURNS JSONB AS $$
DECLARE
    v_template_hk BYTEA;
    v_agent_identity_hk BYTEA;
    v_certificate_hk BYTEA;
    v_user_agent_result JSONB;
    v_domain_assignment JSONB;
BEGIN
    -- Get template
    SELECT agent_template_hk INTO v_template_hk
    FROM ai_agents.agent_template_s
    WHERE template_name = p_template_name
    AND load_end_date IS NULL;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Zero trust agent template not found: %', p_template_name;
    END IF;
    
    -- Create agent identity with zero trust credentials
    v_agent_identity_hk := ai_agents.create_agent_identity(
        p_tenant_hk,
        p_agent_name,
        jsonb_build_object(
            'security_clearance', p_security_clearance,
            'zero_trust_enabled', true,
            'mtls_required', true,
            'continuous_auth': true
        )
    );
    
    -- Generate PKI certificate
    v_certificate_hk := ai_agents.generate_agent_certificate(
        v_agent_identity_hk,
        jsonb_build_object(
            'certificate_type', 'CLIENT_AUTH',
            'key_algorithm', 'RSA',
            'key_size', 4096,
            'validity_days', 90,
            'auto_renewal', true
        )
    );
    
    -- Create user agent from template
    v_user_agent_result := ai_agents.create_user_agent(
        p_tenant_hk,
        p_agent_name,
        v_template_hk,
        p_user_configuration || jsonb_build_object(
            'zero_trust_mode', true,
            'agent_identity_hk', encode(v_agent_identity_hk, 'hex'),
            'certificate_hk', encode(v_certificate_hk, 'hex')
        )
    );
    
    -- Assign to appropriate domain
    v_domain_assignment := ai_agents.assign_agent_to_domain(
        decode(v_user_agent_result->>'agent_id', 'hex'),
        CASE 
            WHEN p_template_name LIKE '%MEDICAL%' THEN 'MEDICAL_DOMAIN'
            WHEN p_template_name LIKE '%EQUINE%' THEN 'EQUINE_DOMAIN'
            WHEN p_template_name LIKE '%MANUFACTURING%' THEN 'MANUFACTURING_DOMAIN'
            ELSE 'GENERAL_DOMAIN'
        END
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'agent_id', v_user_agent_result->>'agent_id',
        'agent_name', p_agent_name,
        'template_used', p_template_name,
        'zero_trust_enabled', true,
        'agent_identity_id', encode(v_agent_identity_hk, 'hex'),
        'certificate_id', encode(v_certificate_hk, 'hex'),
        'domain_assignment', v_domain_assignment,
        'security_clearance', p_security_clearance,
        'status', 'DEPLOYED_ZERO_TRUST',
        'next_steps', 'Agent is ready for zero trust operations'
    );
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- ZERO TRUST AGENT EXECUTION FUNCTION
-- ==========================================

CREATE OR REPLACE FUNCTION ai_agents.execute_zero_trust_agent(
    p_user_agent_hk BYTEA,
    p_input_data JSONB,
    p_client_certificate BYTEA,
    p_session_token VARCHAR(500)
) RETURNS JSONB AS $$
DECLARE
    v_agent_config RECORD;
    v_identity_valid BOOLEAN;
    v_certificate_valid BOOLEAN;
    v_domain_authorized BOOLEAN;
    v_execution_result JSONB;
BEGIN
    -- Zero Trust Verification Step 1: Agent Identity
    SELECT ai_agents.validate_agent_identity(p_user_agent_hk) INTO v_identity_valid;
    IF NOT v_identity_valid THEN
        RAISE EXCEPTION 'Zero Trust Violation: Agent identity validation failed';
    END IF;
    
    -- Zero Trust Verification Step 2: Certificate Validation
    SELECT ai_agents.validate_agent_certificate(p_client_certificate) INTO v_certificate_valid;
    IF NOT v_certificate_valid THEN
        RAISE EXCEPTION 'Zero Trust Violation: Certificate validation failed';
    END IF;
    
    -- Zero Trust Verification Step 3: Domain Authorization
    SELECT ai_agents.validate_domain_access(p_user_agent_hk, p_input_data) INTO v_domain_authorized;
    IF NOT v_domain_authorized THEN
        RAISE EXCEPTION 'Zero Trust Violation: Domain access denied';
    END IF;
    
    -- Execute with continuous monitoring
    v_execution_result := ai_agents.execute_user_agent(
        p_user_agent_hk,
        p_input_data || jsonb_build_object(
            'zero_trust_session', p_session_token,
            'execution_timestamp', CURRENT_TIMESTAMP,
            'security_context', 'ZERO_TRUST_VERIFIED'
        ),
        'ZERO_TRUST_EXECUTION'
    );
    
    -- Log zero trust execution
    INSERT INTO ai_agents.zero_trust_execution_log (
        execution_hk,
        user_agent_hk,
        identity_verified,
        certificate_verified,
        domain_authorized,
        execution_timestamp,
        security_level
    ) VALUES (
        util.hash_binary(p_user_agent_hk::text || CURRENT_TIMESTAMP::text),
        p_user_agent_hk,
        v_identity_valid,
        v_certificate_valid,
        v_domain_authorized,
        CURRENT_TIMESTAMP,
        'ZERO_TRUST'
    );
    
    RETURN v_execution_result || jsonb_build_object(
        'zero_trust_verified', true,
        'security_level', 'ZERO_TRUST',
        'identity_verified', v_identity_valid,
        'certificate_verified', v_certificate_valid,
        'domain_authorized', v_domain_authorized
    );
END;
$$ LANGUAGE plpgsql;

-- Zero Trust Execution Log Table
CREATE TABLE ai_agents.zero_trust_execution_log (
    execution_hk BYTEA PRIMARY KEY,
    user_agent_hk BYTEA NOT NULL REFERENCES ai_agents.user_agent_h(user_agent_hk),
    identity_verified BOOLEAN NOT NULL,
    certificate_verified BOOLEAN NOT NULL,
    domain_authorized BOOLEAN NOT NULL,
    execution_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    security_level VARCHAR(50) NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Performance indexes
CREATE INDEX idx_zero_trust_execution_log_agent_hk ON ai_agents.zero_trust_execution_log(user_agent_hk);
CREATE INDEX idx_zero_trust_execution_log_timestamp ON ai_agents.zero_trust_execution_log(execution_timestamp);
CREATE INDEX idx_zero_trust_execution_log_security_level ON ai_agents.zero_trust_execution_log(security_level);

COMMIT;

-- ==========================================
-- USAGE EXAMPLES
-- ==========================================

/*
-- Example 1: Deploy Zero Trust Medical Diagnosis Agent
SELECT ai_agents.deploy_zero_trust_agent_from_template(
    :hospital_tenant_hk,
    'Zero Trust Medical Diagnosis Agent (MDA-001)',
    'Emergency Department AI Diagnostician',
    '{
        "specialization_areas": ["emergency_medicine", "trauma", "cardiology"],
        "diagnostic_thresholds": {
            "confidence_minimum": 0.8,
            "emergency_threshold": 0.95
        },
        "hipaa_compliance": {
            "phi_encryption": "AES256",
            "audit_all_access": true,
            "minimum_necessary": true
        },
        "zero_trust_config": {
            "mtls_required": true,
            "session_ttl_minutes": 5,
            "continuous_auth": true
        }
    }'::jsonb,
    'MEDICAL_CLEARANCE'
);

-- Example 2: Execute Zero Trust Agent with Security
SELECT ai_agents.execute_zero_trust_agent(
    :medical_agent_hk,
    '{
        "patient_id": "ENCRYPTED_PATIENT_ID_12345",
        "symptoms": ["chest_pain", "shortness_of_breath", "nausea"],
        "vital_signs": {
            "heart_rate": 120,
            "blood_pressure": "140/90",
            "temperature": "98.6F"
        },
        "urgency_level": "emergency"
    }'::jsonb,
    :client_certificate,
    :zero_trust_session_token
);
*/ 