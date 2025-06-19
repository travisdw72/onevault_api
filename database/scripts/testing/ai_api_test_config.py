# AI API Testing Configuration File
# Contains test scenarios for all AI-related API endpoints

# Database connection configuration (reuse from main config)
from database.scripts.investigate_db_configFile import DATABASE_CONFIG

# Test scenarios for AI API endpoints - Updated to use actual working functions
AI_API_TEST_QUERIES = {
    # =====================================================================
    # AI CHAT SYSTEM TESTS (Using actual working functions)
    # =====================================================================
    
    'ai_secure_chat_basic': {
        'description': 'Test basic AI chat functionality',
        'function': 'api.ai_secure_chat',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_message': 'Hello, can you help me understand my business analytics?',
            'p_context_type': 'business_analytics',
            'p_model_preference': 'gpt-4'
        },
        'expected_fields': ['p_success', 'p_response_text', 'p_interaction_id', 'p_session_id'],
        'test_type': 'functional',
        'audit_validation': True,
        'expected_audit_events': ['ai_chat_request', 'ai_response_generated']
    },
    
    'ai_create_session_valid': {
        'description': 'Create new AI chat session',
        'function': 'api.ai_create_session',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_session_purpose': 'business_consultation',
            'p_user_context': {
                'role': 'business_owner',
                'preferences': ['detailed_analysis', 'financial_focus']
            }
        },
        'expected_fields': ['p_success', 'p_ai_session_id', 'p_session_config'],
        'test_type': 'functional',
        'audit_validation': True,
        'expected_audit_events': ['ai_session_created', 'user_context_logged']
    },
    
    'ai_chat_history_retrieval': {
        'description': 'Retrieve AI chat history for user',
        'function': 'api.ai_chat_history',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_limit': 10,
            'p_offset': 0
        },
        'expected_fields': ['p_success', 'p_interactions', 'p_total_count'],
        'test_type': 'functional',
        'audit_validation': True,
        'expected_audit_events': ['ai_history_accessed', 'data_retrieval_logged']
    },
    
    # =====================================================================
    # AI OBSERVATION SYSTEM TESTS (Using actual working functions)
    # =====================================================================
    
    'ai_log_observation_business': {
        'description': 'Log business observation through AI system',
        'function': 'api.ai_log_observation',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_observation_type': 'business_performance',
            'p_entity_id': 'business-entity-001',
            'p_observation_data': {
                'metric': 'revenue_trend',
                'value': 15.5,
                'period': 'Q4_2024',
                'confidence': 0.92
            }
        },
        'expected_fields': ['p_success', 'p_observation_id', 'p_analysis_id'],
        'test_type': 'functional',
        'audit_validation': True,
        'expected_audit_events': ['ai_observation_logged', 'business_data_analyzed']
    },
    
    'ai_get_observations_filtered': {
        'description': 'Retrieve filtered AI observations',
        'function': 'api.ai_get_observations',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_entity_filter': 'business-entity-001',
            'p_observation_type': 'business_performance',
            'p_limit': 20
        },
        'expected_fields': ['p_success', 'p_observations', 'p_total_count'],
        'test_type': 'functional',
        'audit_validation': True,
        'expected_audit_events': ['ai_observations_retrieved', 'filtered_data_access']
    },
    
    'ai_get_active_alerts_dashboard': {
        'description': 'Get active alerts for dashboard display',
        'function': 'api.ai_get_active_alerts',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_severity_filter': ['HIGH', 'CRITICAL'],
            'p_entity_scope': 'all'
        },
        'expected_fields': ['p_success', 'p_active_alerts', 'p_alert_count'],
        'test_type': 'functional',
        'audit_validation': True,
        'expected_audit_events': ['ai_alerts_accessed', 'dashboard_data_retrieved']
    },
    
    'ai_acknowledge_alert_workflow': {
        'description': 'Acknowledge alert and update status',
        'function': 'api.ai_acknowledge_alert',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_alert_id': 'alert-001',
            'p_acknowledgment_note': 'Reviewed and taking corrective action'
        },
        'expected_fields': ['p_success', 'p_alert_status', 'p_acknowledgment_id'],
        'test_type': 'functional',
        'audit_validation': True,
        'expected_audit_events': ['ai_alert_acknowledged', 'alert_status_changed']
    },
    
    'ai_get_observation_analytics_insights': {
        'description': 'Get comprehensive observation analytics',
        'function': 'api.ai_get_observation_analytics',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_analysis_period': '30_days',
            'p_entity_scope': 'tenant_wide'
        },
        'expected_fields': ['p_success', 'p_analytics_report', 'p_trend_summary'],
        'test_type': 'functional',
        'audit_validation': True,
        'expected_audit_events': ['ai_analytics_generated', 'comprehensive_analysis_performed']
    },
    
    # =====================================================================
    # AI MONITORING SYSTEM TESTS (Using actual working functions)
    # =====================================================================
    
    'ai_monitoring_ingest_data': {
        'description': 'Ingest monitoring data through AI system',
        'function': 'api.ai_monitoring_ingest',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_data_source': 'business_metrics_collector',
            'p_monitoring_data': {
                'timestamp': '2024-12-12T21:00:00Z',
                'entity_id': 'business-entity-001',
                'metrics': {
                    'cpu_usage': 75.2,
                    'memory_usage': 68.5,
                    'active_users': 142
                }
            }
        },
        'expected_fields': ['p_success', 'p_ingestion_id', 'p_processing_status'],
        'test_type': 'functional',
        'audit_validation': True,
        'expected_audit_events': ['ai_monitoring_data_ingested', 'system_metrics_processed']
    },
    
    'ai_monitoring_get_alerts_management': {
        'description': 'Get monitoring alerts for management dashboard',
        'function': 'api.ai_monitoring_get_alerts',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_time_window': '24_hours',
            'p_severity_levels': ['MEDIUM', 'HIGH', 'CRITICAL']
        },
        'expected_fields': ['p_success', 'p_monitoring_alerts', 'p_alert_summary'],
        'test_type': 'functional',
        'audit_validation': True,
        'expected_audit_events': ['ai_monitoring_alerts_accessed', 'management_dashboard_viewed']
    },
    
    'ai_monitoring_acknowledge_alert_system': {
        'description': 'Acknowledge monitoring system alert',
        'function': 'api.ai_monitoring_acknowledge_alert',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_alert_id': 'monitoring-alert-001',
            'p_acknowledged_by': 'system_admin',
            'p_resolution_notes': 'System load balanced, monitoring continues'
        },
        'expected_fields': ['p_success', 'p_acknowledgment_status', 'p_alert_updated'],
        'test_type': 'functional',
        'audit_validation': True,
        'expected_audit_events': ['ai_monitoring_alert_acknowledged', 'system_admin_action']
    },
    
    'ai_monitoring_get_entity_timeline_analysis': {
        'description': 'Get entity timeline for analysis',
        'function': 'api.ai_monitoring_get_entity_timeline',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_entity_id': 'business-entity-001',
            'p_timeline_period': '7_days'
        },
        'expected_fields': ['p_success', 'p_timeline_data', 'p_event_summary'],
        'test_type': 'functional',
        'audit_validation': True,
        'expected_audit_events': ['ai_timeline_analysis_performed', 'entity_history_accessed']
    },
    
    'ai_monitoring_system_health_check': {
        'description': 'Check AI monitoring system health',
        'function': 'api.ai_monitoring_system_health',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_health_check_level': 'comprehensive'
        },
        'expected_fields': ['p_success', 'p_system_health', 'p_performance_metrics'],
        'test_type': 'health_check',
        'audit_validation': True,
        'expected_audit_events': ['ai_system_health_checked', 'performance_metrics_accessed']
    },
    
    # =====================================================================
    # AUDIT TRAIL SPECIFIC TESTS
    # =====================================================================
    
    'ai_audit_trail_comprehensive': {
        'description': 'Test comprehensive audit trail logging for AI operations',
        'function': 'api.ai_secure_chat',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_message': 'Generate financial report for Q4 2024',
            'p_context_type': 'financial_analysis',
            'p_model_preference': 'gpt-4',
            'p_sensitive_data_flag': True,
            'p_compliance_context': 'HIPAA_GDPR'
        },
        'expected_fields': ['p_success', 'p_response_text', 'p_interaction_id', 'p_audit_trail_id'],
        'test_type': 'audit_validation',
        'audit_validation': True,
        'expected_audit_events': [
            'ai_chat_request',
            'sensitive_data_access',
            'financial_data_processed',
            'compliance_check_performed',
            'ai_response_generated',
            'audit_trail_created'
        ]
    },
    
    'ai_audit_data_access_tracking': {
        'description': 'Test audit trail for data access patterns',
        'function': 'api.ai_get_observations',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_entity_filter': 'business-entity-001',
            'p_observation_type': 'financial_performance',
            'p_include_sensitive_metrics': True,
            'p_audit_reason': 'quarterly_compliance_review'
        },
        'expected_fields': ['p_success', 'p_observations', 'p_audit_trail_id', 'p_data_access_log'],
        'test_type': 'audit_validation',
        'audit_validation': True,
        'expected_audit_events': [
            'ai_data_access_requested',
            'entity_data_queried',
            'sensitive_metrics_accessed',
            'compliance_reason_logged',
            'data_access_completed'
        ]
    },
    
    'ai_audit_user_activity_tracking': {
        'description': 'Test audit trail for user activity tracking',
        'function': 'api.ai_create_session',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_session_purpose': 'sensitive_data_analysis',
            'p_user_context': {
                'role': 'compliance_officer',
                'department': 'risk_management',
                'access_level': 'high_privilege'
            },
            'p_audit_metadata': {
                'ip_address': '192.168.1.100',
                'user_agent': 'Mozilla/5.0 Test Browser',
                'session_source': 'web_application'
            }
        },
        'expected_fields': ['p_success', 'p_ai_session_id', 'p_audit_session_id', 'p_compliance_flags'],
        'test_type': 'audit_validation',
        'audit_validation': True,
        'expected_audit_events': [
            'ai_session_creation_requested',
            'user_identity_verified',
            'privilege_level_validated',
            'session_metadata_logged',
            'compliance_flags_set',
            'audit_session_linked'
        ]
    },
    
    # =====================================================================
    # ERROR HANDLING AND EDGE CASE TESTS
    # =====================================================================
    
    'ai_chat_invalid_session': {
        'description': 'Test AI chat with invalid session token',
        'function': 'api.ai_secure_chat',
        'test_data': {
            'p_session_token': 'invalid_session_12345',
            'p_message': 'This should fail due to invalid session'
        },
        'expected_fields': ['p_success', 'p_error_code', 'p_error_message'],
        'test_type': 'error_handling',
        'expected_success': False,
        'audit_validation': True,
        'expected_audit_events': ['ai_invalid_session_attempt', 'authentication_failure']
    },
    
    'ai_observation_missing_data': {
        'description': 'Test observation logging with missing required data',
        'function': 'api.ai_log_observation',
        'test_data': {
            'p_session_token': 'test_session_token_123',
            'p_observation_type': 'incomplete_test'
            # Missing required fields intentionally
        },
        'expected_fields': ['p_success', 'p_error_code', 'p_validation_errors'],
        'test_type': 'error_handling',
        'expected_success': False,
        'audit_validation': True,
        'expected_audit_events': ['ai_validation_failure', 'incomplete_data_rejected']
    }
}

# SQL queries for direct database testing (for validation)
AI_VALIDATION_QUERIES = {
    'check_ai_functions_exist': """
        SELECT 
            routine_name,
            routine_type,
            data_type,
            routine_definition IS NOT NULL as has_definition
        FROM information_schema.routines 
        WHERE routine_schema = 'api' 
        AND routine_name LIKE 'ai_%'
        ORDER BY routine_name;
    """,
    
    'check_ai_tables_exist': """
        SELECT 
            table_schema,
            table_name,
            table_type
        FROM information_schema.tables 
        WHERE table_schema IN ('ai', 'business', 'ai_monitoring')
        AND (table_name LIKE '%ai%' OR table_name LIKE '%conversation%' OR table_name LIKE '%message%')
        ORDER BY table_schema, table_name;
    """,
    
    'get_ai_session_structure': """
        SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default
        FROM information_schema.columns 
        WHERE table_schema = 'ai' 
        AND table_name LIKE '%session%'
        ORDER BY table_name, ordinal_position;
    """,
    
    'check_recent_ai_activity': """
        SELECT 
            COUNT(*) as total_interactions,
            MAX(load_date) as last_interaction,
            COUNT(DISTINCT conversation_hk) as unique_conversations
        FROM ai.conversation_h 
        WHERE load_date >= CURRENT_DATE - INTERVAL '7 days';
    """,
    
    'validate_ai_monitoring_schema': """
        SELECT 
            schemaname,
            tablename,
            tableowner,
            hasindexes,
            hasrules,
            hastriggers
        FROM pg_tables 
        WHERE schemaname = 'ai_monitoring'
        ORDER BY tablename;
    """,
    
    # =====================================================================
    # AUDIT TRAIL VALIDATION QUERIES
    # =====================================================================
    
    'check_audit_tables_exist': """
        SELECT 
            table_schema,
            table_name,
            table_type
        FROM information_schema.tables 
        WHERE table_schema = 'audit'
        AND (table_name LIKE '%audit%' OR table_name LIKE '%log%' OR table_name LIKE '%trail%')
        ORDER BY table_name;
    """,
    
    'validate_audit_event_structure': """
        SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default
        FROM information_schema.columns 
        WHERE table_schema = 'audit' 
        AND table_name LIKE '%event%'
        ORDER BY table_name, ordinal_position;
    """,
    
    'check_recent_audit_activity': """
        SELECT 
            COUNT(*) as total_audit_events,
            MAX(load_date) as last_audit_event,
            MIN(load_date) as first_audit_event
        FROM audit.audit_event_h aeh
        JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
        WHERE aeh.load_date >= CURRENT_DATE - INTERVAL '7 days'
        AND ads.load_end_date IS NULL;
    """,
    
    'validate_ai_audit_integration': """
        SELECT 
            COUNT(*) as ai_related_events,
            MAX(ads.load_date) as last_ai_event
        FROM audit.audit_event_h aeh
        JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
        WHERE ads.table_name LIKE '%ai%' OR ads.operation LIKE '%ai%'
        AND ads.load_end_date IS NULL
        AND aeh.load_date >= CURRENT_DATE - INTERVAL '30 days';
    """,
    
    'validate_audit_retention_policy': """
        SELECT 
            table_name,
            COUNT(*) as total_records,
            MIN(load_date) as oldest_record,
            MAX(load_date) as newest_record,
            COUNT(*) FILTER (WHERE load_date < CURRENT_DATE - INTERVAL '7 years') as records_beyond_retention
        FROM (
            SELECT 'audit_event_h' as table_name, load_date FROM audit.audit_event_h
            UNION ALL
            SELECT 'audit_detail_s' as table_name, load_date FROM audit.audit_detail_s
        ) audit_tables
        GROUP BY table_name
        ORDER BY table_name;
    """
}

# Audit trail validation queries for specific test scenarios
AUDIT_TRAIL_VALIDATION_QUERIES = {
    'validate_ai_chat_audit': """
        SELECT 
            aeh.audit_event_hk,
            ads.table_name,
            ads.operation,
            ads.load_date as event_timestamp,
            ads.changed_by as user_hk,
            'ai_chat_request' as event_type,
            ads.new_data->>'interaction_id' as interaction_id,
            ads.new_data->>'message_type' as message_type,
            ads.new_data->>'model_used' as model_used
        FROM audit.audit_event_h aeh
        JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
        WHERE (ads.table_name LIKE '%ai%' OR ads.table_name LIKE '%conversation%' OR ads.table_name LIKE '%message%')
        AND ads.load_date >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
        AND ads.load_end_date IS NULL
        ORDER BY ads.load_date DESC
        LIMIT 10;
    """,
    
    'validate_ai_observation_audit': """
        SELECT 
            aeh.audit_event_hk,
            ads.table_name,
            ads.operation,
            ads.load_date as event_timestamp,
            'ai_observation_logged' as event_type,
            ads.new_data->>'observation_id' as observation_id,
            ads.new_data->>'entity_id' as entity_id,
            ads.new_data->>'observation_type' as observation_type,
            ads.new_data->>'confidence_score' as confidence_score
        FROM audit.audit_event_h aeh
        JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
        WHERE (ads.table_name LIKE '%observation%' OR ads.table_name LIKE '%ai%')
        AND ads.load_date >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
        AND ads.load_end_date IS NULL
        ORDER BY ads.load_date DESC
        LIMIT 10;
    """,
    
    'validate_security_audit_events': """
        SELECT 
            aeh.audit_event_hk,
            ads.table_name,
            ads.operation,
            ads.load_date as event_timestamp,
            'security_event' as event_type,
            ads.new_data->>'security_level' as security_level,
            ads.new_data->>'violation_type' as violation_type,
            ads.new_data->>'ip_address' as ip_address,
            ads.new_data->>'user_agent' as user_agent
        FROM audit.audit_event_h aeh
        JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
        WHERE ads.operation LIKE '%security%' OR ads.table_name LIKE '%security%'
        AND ads.load_date >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
        AND ads.load_end_date IS NULL
        ORDER BY ads.load_date DESC
        LIMIT 10;
    """,
    
    'validate_compliance_audit_trail': """
        SELECT 
            aeh.audit_event_hk,
            ads.table_name,
            ads.operation,
            ads.load_date as event_timestamp,
            'compliance_event' as event_type,
            ads.new_data->>'regulation' as regulation,
            ads.new_data->>'compliance_check' as compliance_check,
            ads.new_data->>'phi_accessed' as phi_accessed,
            ads.new_data->>'minimum_necessary' as minimum_necessary
        FROM audit.audit_event_h aeh
        JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
        WHERE ads.operation LIKE '%compliance%' OR ads.table_name LIKE '%compliance%'
        AND ads.load_date >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
        AND ads.load_end_date IS NULL
        ORDER BY ads.load_date DESC
        LIMIT 10;
    """
}

# Test execution configuration
TEST_CONFIG = {
    'database': DATABASE_CONFIG,
    'test_execution': {
        'timeout_seconds': 30,
        'retry_attempts': 3,
        'retry_delay_seconds': 2,
        'parallel_execution': False,  # Set to True for load testing
        'detailed_logging': True,
        'audit_validation_enabled': True,  # Enable audit trail validation
        'audit_validation_timeout': 10     # Seconds to wait for audit events
    },
    'authentication': {
        'test_session_token': 'test_session_token_123',
        'test_user_id': 'test-user-001',
        'test_tenant_id': 'test-tenant-001'
    },
    'output': {
        'results_directory': './test_results',
        'summary_report': True,
        'detailed_logs': True,
        'performance_metrics': True,
        'error_analysis': True,
        'audit_trail_report': True,      # Generate audit trail analysis
        'compliance_report': True        # Generate compliance validation report
    },
    'audit_validation': {
        'enabled': True,
        'wait_time_seconds': 2,          # Reduced wait time for faster testing
        'expected_event_timeout': 10,    # Max time to wait for expected events
        'validate_event_details': True,  # Validate event detail content
        'check_retention_compliance': True,  # Verify retention policies
        'hipaa_validation': True,        # Specific HIPAA audit validation
        'gdpr_validation': True          # Specific GDPR audit validation
    }
}

# Test categories for organized execution
TEST_CATEGORIES = {
    'core_ai_chat': [
        'ai_secure_chat_basic',
        'ai_create_session_valid',
        'ai_chat_history_retrieval'
    ],
    'ai_observations': [
        'ai_log_observation_business',
        'ai_get_observations_filtered',
        'ai_get_active_alerts_dashboard',
        'ai_acknowledge_alert_workflow',
        'ai_get_observation_analytics_insights'
    ],
    'ai_monitoring': [
        'ai_monitoring_ingest_data',
        'ai_monitoring_get_alerts_management',
        'ai_monitoring_acknowledge_alert_system',
        'ai_monitoring_get_entity_timeline_analysis',
        'ai_monitoring_system_health_check'
    ],
    'audit_trail_validation': [
        'ai_audit_trail_comprehensive',
        'ai_audit_data_access_tracking',
        'ai_audit_user_activity_tracking'
    ],
    'error_handling': [
        'ai_chat_invalid_session',
        'ai_observation_missing_data'
    ]
}

# Expected response schemas for validation
RESPONSE_SCHEMAS = {
    'ai_chat_response': {
        'required_fields': ['p_success', 'p_response_text', 'p_interaction_id'],
        'optional_fields': ['p_session_id', 'p_model_used', 'p_processing_time_ms', 'p_safety_level', 'p_audit_trail_id'],
        'data_types': {
            'p_success': bool,
            'p_response_text': str,
            'p_interaction_id': str,
            'p_processing_time_ms': int
        }
    },
    'ai_observation_response': {
        'required_fields': ['p_success', 'p_observation_id'],
        'optional_fields': ['p_analysis_id', 'p_alert_triggered', 'p_confidence_score', 'p_audit_trail_id'],
        'data_types': {
            'p_success': bool,
            'p_observation_id': str,
            'p_alert_triggered': bool
        }
    },
    'ai_monitoring_response': {
        'required_fields': ['p_success', 'p_status'],
        'optional_fields': ['p_processing_time_ms', 'p_alerts_generated', 'p_audit_trail_id'],
        'data_types': {
            'p_success': bool,
            'p_status': str
        }
    },
    'error_response': {
        'required_fields': ['p_success', 'p_error_code', 'p_error_message'],
        'optional_fields': ['p_error_details', 'p_suggestions', 'p_audit_trail_id'],
        'data_types': {
            'p_success': bool,
            'p_error_code': str,
            'p_error_message': str
        }
    },
    'audit_response': {
        'required_fields': ['p_success', 'p_audit_trail_id'],
        'optional_fields': ['p_audit_events_logged', 'p_compliance_validated', 'p_retention_applied'],
        'data_types': {
            'p_success': bool,
            'p_audit_trail_id': str,
            'p_audit_events_logged': int
        }
    }
} 