-- ==========================================
-- TEMPLATE CUSTOMIZATION EXAMPLES
-- ==========================================
-- Shows how ONE Image AI template serves multiple industries
-- Horse Trainer vs Trucking Company using same base template

BEGIN;

-- ==========================================
-- EXAMPLE 1: HORSE TRAINER CUSTOMIZATION
-- ==========================================

-- Horse trainer creates agent from base Image Analysis template
SELECT ai_agents.create_user_agent(
    :horse_trainer_tenant_hk,
    'Thunder Daily Health Monitor',
    (SELECT agent_template_hk FROM ai_agents.agent_template_s 
     WHERE template_name = 'Image Analysis Agent' AND load_end_date IS NULL),
    '{
        "industry_focus": "equine_health",
        "analysis_prompts": {
            "primary_prompt": "Analyze this horse photo for health indicators including lameness, injuries, body condition, and overall wellness. Look for signs of swelling, cuts, abnormal posture, or movement issues.",
            "specific_checks": [
                "Check legs for swelling or heat",
                "Assess body condition score (1-9 scale)",
                "Look for visible injuries or wounds", 
                "Evaluate posture and stance",
                "Check coat condition and shine",
                "Assess alertness and demeanor"
            ]
        },
        "detection_categories": {
            "injury_detection": {
                "threshold": 0.8,
                "keywords": ["cut", "wound", "swelling", "bruise", "scrape"],
                "alert_level": "high"
            },
            "lameness_indicators": {
                "threshold": 0.7,
                "keywords": ["favoring leg", "uneven stance", "weight shifting"],
                "alert_level": "medium" 
            },
            "body_condition": {
                "threshold": 0.6,
                "scale": "henneke_9_point",
                "ideal_range": [5, 7],
                "alert_level": "low"
            }
        },
        "output_format": {
            "veterinary_terminology": true,
            "include_recommendations": true,
            "reference_baseline": "breed_standards",
            "measurement_units": "hands_and_pounds"
        },
        "ai_model_settings": {
            "preferred_provider": "openai_vision",
            "model_version": "gpt-4-vision-preview",
            "temperature": 0.3,
            "max_tokens": 500
        }
    }'::jsonb,
    '{
        "data_access": "own_horses_only",
        "retention_days": 365,
        "share_insights": false,
        "veterinary_compliance": true
    }'::jsonb,
    '{
        "injury_detected": {
            "threshold": 0.8,
            "notify": ["trainer@barn.com", "vet@clinic.com"],
            "urgency": "high",
            "message_template": "Potential injury detected in {horse_name}. Confidence: {confidence}%. Recommendation: Veterinary examination."
        },
        "lameness_indicators": {
            "threshold": 0.7, 
            "notify": ["trainer@barn.com"],
            "urgency": "medium",
            "message_template": "Lameness indicators observed in {horse_name}. Monitor closely and consider rest."
        }
    }'::jsonb,
    75.00  -- Monthly budget
);

-- ==========================================
-- EXAMPLE 2: TRUCKING COMPANY CUSTOMIZATION  
-- ==========================================

-- Trucking company creates agent from SAME base template
SELECT ai_agents.create_user_agent(
    :trucking_company_tenant_hk,
    'Fleet Vehicle Safety Inspector',
    (SELECT agent_template_hk FROM ai_agents.agent_template_s 
     WHERE template_name = 'Image Analysis Agent' AND load_end_date IS NULL),
    '{
        "industry_focus": "fleet_safety",
        "analysis_prompts": {
            "primary_prompt": "Analyze this commercial vehicle photo for safety issues, damage, wear indicators, and DOT compliance violations. Focus on tires, lights, body damage, and load securement.",
            "specific_checks": [
                "Inspect tire condition and tread depth",
                "Check all lights are functional and visible",
                "Look for body damage, rust, or structural issues",
                "Verify load securement and weight distribution", 
                "Assess overall vehicle roadworthiness",
                "Check for DOT compliance markings visibility"
            ]
        },
        "detection_categories": {
            "safety_violations": {
                "threshold": 0.9,
                "keywords": ["damaged tire", "broken light", "loose load", "rust through"],
                "alert_level": "critical"
            },
            "maintenance_needed": {
                "threshold": 0.7,
                "keywords": ["tire wear", "minor damage", "dirt buildup", "fading paint"],
                "alert_level": "medium"
            },
            "dot_compliance": {
                "threshold": 0.8,
                "keywords": ["missing numbers", "illegible markings", "expired permits"],
                "alert_level": "high"
            }
        },
        "output_format": {
            "dot_terminology": true,
            "include_regulations": true,
            "reference_baseline": "dot_standards",
            "measurement_units": "imperial"
        },
        "ai_model_settings": {
            "preferred_provider": "azure_computer_vision",
            "model_version": "4.0",
            "temperature": 0.2,
            "max_tokens": 400
        }
    }'::jsonb,
    '{
        "data_access": "fleet_vehicles_only",
        "retention_days": 2555,
        "share_insights": true,
        "dot_compliance_required": true
    }'::jsonb,
    '{
        "safety_violation": {
            "threshold": 0.9,
            "notify": ["safety@trucking.com", "dispatch@trucking.com"],
            "urgency": "critical", 
            "message_template": "CRITICAL: Safety violation detected on Vehicle {vehicle_id}. Remove from service immediately. Violation: {violation_details}"
        },
        "maintenance_required": {
            "threshold": 0.7,
            "notify": ["maintenance@trucking.com"],
            "urgency": "medium",
            "message_template": "Vehicle {vehicle_id} requires maintenance attention: {maintenance_details}"
        }
    }'::jsonb,
    200.00  -- Higher budget for commercial use
);

-- ==========================================
-- TEMPLATE EXECUTION COMPARISON
-- ==========================================

-- Horse Trainer Usage
SELECT ai_agents.execute_user_agent(
    :horse_health_agent_hk,
    '{
        "image_url": "https://barn.com/photos/thunder_morning_check.jpg",
        "subject_id": "THUNDER_001",
        "context": "daily_health_assessment",
        "previous_baseline": "historical_health_data"
    }'::jsonb,
    'DAILY_SCHEDULED'
);

-- Expected Horse Result:
/*
{
    "analysis_type": "equine_health_assessment",
    "overall_assessment": "good_condition",
    "findings": {
        "body_condition_score": 6,
        "lameness_indicators": 0.1,
        "injury_detection": 0.0,
        "coat_condition": "excellent",
        "alertness": "normal"
    },
    "recommendations": [
        "Continue current exercise routine",
        "Monitor left front hoof for minor sensitivity",
        "Maintain current nutrition program"
    ],
    "veterinary_notes": "No immediate concerns observed. Routine follow-up recommended.",
    "confidence_score": 0.89
}
*/

-- Trucking Company Usage  
SELECT ai_agents.execute_user_agent(
    :fleet_safety_agent_hk,
    '{
        "image_url": "https://fleet.com/inspections/truck_847_pretrip.jpg",
        "subject_id": "TRUCK_847",
        "context": "pre_trip_inspection",
        "inspection_type": "DOT_compliance_check"
    }'::jsonb,
    'PRE_TRIP_INSPECTION'
);

-- Expected Trucking Result:
/*
{
    "analysis_type": "commercial_vehicle_safety_inspection",
    "overall_status": "roadworthy_with_notes",
    "findings": {
        "tire_condition": "acceptable",
        "lights_functional": "all_operational", 
        "body_condition": "minor_wear",
        "load_securement": "compliant",
        "dot_markings": "visible_and_current"
    },
    "violations": [],
    "maintenance_recommendations": [
        "Schedule tire rotation within 5000 miles",
        "Touch up paint on rear panel",
        "Clean DOT number markings for better visibility"
    ],
    "dot_compliance": "PASS",
    "confidence_score": 0.92
}
*/

-- ==========================================
-- TEMPLATE FLEXIBILITY DEMONSTRATION
-- ==========================================

-- Show how same template adapts to different contexts
CREATE OR REPLACE FUNCTION ai_agents.demonstrate_template_flexibility()
RETURNS TABLE (
    use_case VARCHAR(100),
    industry VARCHAR(50),
    analysis_focus VARCHAR(200),
    key_differences TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'Horse Health Monitoring'::VARCHAR(100),
        'Equine'::VARCHAR(50),
        'Health indicators, lameness, body condition, injuries'::VARCHAR(200),
        'Veterinary terminology, breed standards, health-focused prompts'::TEXT
    
    UNION ALL
    
    SELECT 
        'Fleet Safety Inspection'::VARCHAR(100),
        'Transportation'::VARCHAR(50), 
        'Safety violations, DOT compliance, maintenance needs'::VARCHAR(200),
        'DOT regulations, safety-critical alerts, compliance terminology'::TEXT
        
    UNION ALL
    
    SELECT 
        'Construction Equipment Audit'::VARCHAR(100),
        'Construction'::VARCHAR(50),
        'Equipment condition, safety hazards, operational status'::VARCHAR(200),
        'OSHA compliance, equipment-specific terminology, safety protocols'::TEXT
        
    UNION ALL
    
    SELECT 
        'Food Quality Inspection'::VARCHAR(100),
        'Food Service'::VARCHAR(50),
        'Freshness indicators, contamination, presentation quality'::VARCHAR(200),
        'FDA terminology, food safety standards, expiration monitoring'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- INDUSTRY TEMPLATE PRESETS
-- ==========================================

-- Function to create industry-specific presets
CREATE OR REPLACE FUNCTION ai_agents.create_industry_presets()
RETURNS TEXT AS $$
DECLARE
    v_preset_count INTEGER := 0;
BEGIN
    -- Equine Industry Preset
    INSERT INTO ai_agents.agent_template_s (
        agent_template_hk, load_date, load_end_date, hash_diff,
        template_name, template_category, description, capabilities,
        required_inputs, configuration_schema, default_configuration,
        supported_ai_providers, template_icon, complexity_level,
        estimated_cost_per_use, use_case_examples, is_active,
        created_by, record_source
    ) VALUES (
        util.hash_binary('EQUINE_IMAGE_PRESET_V1'),
        util.current_load_date(), NULL,
        util.hash_binary('EQUINE_PRESET'),
        'Equine Health Image Analyzer (Preset)',
        'IMAGE_AI',
        'Pre-configured for horse health monitoring with veterinary-grade analysis',
        '["injury_detection", "lameness_assessment", "body_condition_scoring", "coat_analysis"]',
        '{"image_url": {"type": "string", "required": true}, "horse_id": {"type": "string", "required": true}}',
        '{"analysis_focus": {"type": "array", "default": ["health", "lameness", "injuries"]}}',
        '{"industry_focus": "equine_health", "veterinary_terminology": true, "confidence_thresholds": {"injury": 0.8, "lameness": 0.7}}',
        '["openai_vision", "azure_computer_vision"]',
        'horse-health-preset',
        'BEGINNER',
        0.08,
        '{"target_users": "Horse trainers, veterinarians, barn managers"}',
        true,
        SESSION_USER,
        util.get_record_source()
    );
    v_preset_count := v_preset_count + 1;
    
    -- Transportation Industry Preset
    INSERT INTO ai_agents.agent_template_s (
        agent_template_hk, load_date, load_end_date, hash_diff,
        template_name, template_category, description, capabilities,
        required_inputs, configuration_schema, default_configuration,
        supported_ai_providers, template_icon, complexity_level,
        estimated_cost_per_use, use_case_examples, is_active,
        created_by, record_source
    ) VALUES (
        util.hash_binary('FLEET_SAFETY_PRESET_V1'),
        util.current_load_date(), NULL,
        util.hash_binary('FLEET_PRESET'),
        'Fleet Safety Image Analyzer (Preset)',
        'IMAGE_AI',
        'Pre-configured for commercial vehicle safety and DOT compliance',
        '["safety_violation_detection", "maintenance_assessment", "dot_compliance_check", "damage_evaluation"]',
        '{"image_url": {"type": "string", "required": true}, "vehicle_id": {"type": "string", "required": true}}',
        '{"inspection_type": {"type": "string", "enum": ["pre_trip", "post_trip", "maintenance", "dot_audit"]}}',
        '{"industry_focus": "fleet_safety", "dot_compliance": true, "safety_critical_alerts": true}',
        '["azure_computer_vision", "google_vision_api"]',
        'truck-safety-preset',
        'INTERMEDIATE',
        0.12,
        '{"target_users": "Fleet managers, safety inspectors, DOT compliance officers"}',
        true,
        SESSION_USER,
        util.get_record_source()
    );
    v_preset_count := v_preset_count + 1;
    
    RETURN 'Created ' || v_preset_count || ' industry-specific presets';
END;
$$ LANGUAGE plpgsql;

-- Initialize industry presets
SELECT ai_agents.create_industry_presets();

COMMIT;

-- ==========================================
-- BENEFITS OF TEMPLATE APPROACH
-- ==========================================

/*
SINGLE TEMPLATE + CUSTOMIZATION BENEFITS:

1. **Code Efficiency**
   - One template serves multiple industries
   - Shared AI infrastructure and processing
   - Reduced development and maintenance overhead

2. **Rapid Deployment** 
   - Industry presets get users started quickly
   - No custom coding for each new use case
   - Template marketplace creates network effects

3. **Consistent Quality**
   - Same proven AI capabilities across industries
   - Standardized error handling and security
   - Unified monitoring and performance tracking

4. **Cost Effectiveness**
   - Shared AI model costs across all users
   - Bulk pricing negotiations with AI providers
   - Economies of scale for platform development

5. **Innovation Acceleration**
   - Users can experiment with different configurations
   - Community-driven template improvements
   - Cross-industry pollination of best practices

EXAMPLE TEMPLATE LIBRARY:
├── Image AI Template
│   ├── Equine Health Preset
│   ├── Fleet Safety Preset  
│   ├── Food Quality Preset
│   └── Generic Image Analysis
├── Voice AI Template
│   ├── Senior Care Preset
│   ├── Customer Service Preset
│   └── Generic Voice Analysis
└── Sensor AI Template
    ├── Predictive Maintenance Preset
    ├── Environmental Monitoring Preset
    └── Generic Sensor Analysis
*/ 