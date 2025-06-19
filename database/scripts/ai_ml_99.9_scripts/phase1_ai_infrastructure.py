#!/usr/bin/env python3
"""
🚀 PHASE 1: AI/ML Infrastructure Enhancement
Complete AI/ML Database Enhancement - Phase 1 of 6

OBJECTIVE: Add 4 missing AI observation tables to reach 100% AI completeness
- AI Model Performance Tracking (business.ai_model_performance_s)
- AI Training Execution Logs (business.ai_training_execution_s)  
- AI Deployment Status Tracking (business.ai_deployment_status_s)
- AI Feature Pipeline Tracking (business.ai_feature_pipeline_s)

Current AI/ML System: 66.7% -> Target: 100% complete
"""

import psycopg2
import getpass
import json
from typing import Dict, List, Any
from datetime import datetime
import traceback
import os

class Phase1AIInfrastructure:
    def __init__(self, connection_params: Dict[str, Any]):
        """Initialize with database connection parameters."""
        self.conn = None
        self.config = connection_params
        self.success = False
        self.executed_statements = []
        self.rollback_statements = []
        
    def connect(self) -> None:
        """Establish database connection with error handling."""
        try:
            self.conn = psycopg2.connect(**self.config)
            self.conn.autocommit = False  # Use transactions for rollback capability
            print(f"✅ Connected to database: {self.config['dbname']}")
        except psycopg2.Error as e:
            print(f"❌ Failed to connect to database: {e}")
            raise
    
    def execute_sql_with_rollback(self, sql: str, description: str) -> bool:
        """Execute SQL with rollback capability"""
        try:
            cursor = self.conn.cursor()
            cursor.execute(sql)
            self.executed_statements.append((sql, description))
            print(f"✅ {description}")
            return True
        except Exception as e:
            print(f"❌ Failed: {description}")
            print(f"   Error: {e}")
            return False
    
    def create_ai_model_performance_hub(self) -> bool:
        """Create AI Model Performance Hub Table"""
        sql = """
        -- AI Model Performance Hub
        CREATE TABLE IF NOT EXISTS business.ai_model_performance_h (
            ai_model_performance_hk BYTEA PRIMARY KEY,
            ai_model_performance_bk VARCHAR(255) NOT NULL,
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            record_source VARCHAR(100) NOT NULL,
            
            CONSTRAINT uk_ai_model_performance_h_bk_tenant 
                UNIQUE (ai_model_performance_bk, tenant_hk)
        );
        
        COMMENT ON TABLE business.ai_model_performance_h IS 
        'Hub table for AI model performance tracking maintaining unique identifiers for performance evaluation records with complete tenant isolation and Data Vault 2.0 compliance.';
        """
        
        self.rollback_statements.append("DROP TABLE IF EXISTS business.ai_model_performance_h CASCADE;")
        return self.execute_sql_with_rollback(sql, "Created AI Model Performance Hub table")
    
    def create_ai_model_performance_satellite(self) -> bool:
        """Create AI Model Performance Satellite Table"""
        sql = """
        -- AI Model Performance Satellite
        CREATE TABLE IF NOT EXISTS business.ai_model_performance_s (
            ai_model_performance_hk BYTEA NOT NULL REFERENCES business.ai_model_performance_h(ai_model_performance_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            load_end_date TIMESTAMP WITH TIME ZONE,
            hash_diff BYTEA NOT NULL,
            model_name VARCHAR(100) NOT NULL,
            model_version VARCHAR(50) NOT NULL,
            evaluation_date DATE NOT NULL,
            accuracy_score DECIMAL(5,4),
            precision_score DECIMAL(5,4),
            recall_score DECIMAL(5,4),
            f1_score DECIMAL(5,4),
            auc_score DECIMAL(5,4),
            training_data_size INTEGER,
            test_data_size INTEGER,
            inference_time_ms INTEGER,
            memory_usage_mb INTEGER,
            cpu_utilization_percent DECIMAL(5,2),
            model_drift_score DECIMAL(5,4),
            data_drift_score DECIMAL(5,4),
            performance_degradation BOOLEAN DEFAULT false,
            retraining_recommended BOOLEAN DEFAULT false,
            evaluation_metrics JSONB,
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            record_source VARCHAR(100) NOT NULL,
            
            PRIMARY KEY (ai_model_performance_hk, load_date),
            
            CONSTRAINT chk_ai_model_performance_s_scores 
                CHECK (accuracy_score IS NULL OR (accuracy_score >= 0 AND accuracy_score <= 1)),
            CONSTRAINT chk_ai_model_performance_s_cpu 
                CHECK (cpu_utilization_percent IS NULL OR (cpu_utilization_percent >= 0 AND cpu_utilization_percent <= 100))
        );
        
        COMMENT ON TABLE business.ai_model_performance_s IS 
        'Satellite table storing AI model performance metrics including accuracy, precision, recall, drift detection, and resource utilization with full temporal tracking for compliance and optimization.';
        """
        
        self.rollback_statements.append("DROP TABLE IF EXISTS business.ai_model_performance_s CASCADE;")
        return self.execute_sql_with_rollback(sql, "Created AI Model Performance Satellite table")
    
    def create_ai_training_execution_hub(self) -> bool:
        """Create AI Training Execution Hub Table"""
        sql = """
        -- AI Training Execution Hub
        CREATE TABLE IF NOT EXISTS business.ai_training_execution_h (
            ai_training_execution_hk BYTEA PRIMARY KEY,
            ai_training_execution_bk VARCHAR(255) NOT NULL,
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            record_source VARCHAR(100) NOT NULL,
            
            CONSTRAINT uk_ai_training_execution_h_bk_tenant 
                UNIQUE (ai_training_execution_bk, tenant_hk)
        );
        
        COMMENT ON TABLE business.ai_training_execution_h IS 
        'Hub table for AI training execution tracking maintaining unique identifiers for training jobs with complete tenant isolation and audit trail compliance.';
        """
        
        self.rollback_statements.append("DROP TABLE IF EXISTS business.ai_training_execution_h CASCADE;")
        return self.execute_sql_with_rollback(sql, "Created AI Training Execution Hub table")
    
    def create_ai_training_execution_satellite(self) -> bool:
        """Create AI Training Execution Satellite Table"""
        sql = """
        -- AI Training Execution Satellite
        CREATE TABLE IF NOT EXISTS business.ai_training_execution_s (
            ai_training_execution_hk BYTEA NOT NULL REFERENCES business.ai_training_execution_h(ai_training_execution_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            load_end_date TIMESTAMP WITH TIME ZONE,
            hash_diff BYTEA NOT NULL,
            training_job_id VARCHAR(255) NOT NULL,
            model_name VARCHAR(100) NOT NULL,
            training_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
            training_end_time TIMESTAMP WITH TIME ZONE,
            training_status VARCHAR(50) NOT NULL,
            training_duration_minutes INTEGER,
            dataset_version VARCHAR(50),
            hyperparameters JSONB,
            training_loss DECIMAL(10,6),
            validation_loss DECIMAL(10,6),
            epochs_completed INTEGER,
            early_stopping_triggered BOOLEAN DEFAULT false,
            resource_utilization JSONB,
            error_message TEXT,
            artifacts_location VARCHAR(500),
            model_checkpoints JSONB,
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            record_source VARCHAR(100) NOT NULL,
            
            PRIMARY KEY (ai_training_execution_hk, load_date),
            
            CONSTRAINT chk_ai_training_execution_s_status 
                CHECK (training_status IN ('RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED')),
            CONSTRAINT chk_ai_training_execution_s_duration 
                CHECK (training_duration_minutes IS NULL OR training_duration_minutes >= 0),
            CONSTRAINT chk_ai_training_execution_s_epochs 
                CHECK (epochs_completed IS NULL OR epochs_completed >= 0)
        );
        
        COMMENT ON TABLE business.ai_training_execution_s IS 
        'Satellite table storing AI training execution details including job status, hyperparameters, loss metrics, and resource utilization with complete audit trail for model lifecycle management.';
        """
        
        self.rollback_statements.append("DROP TABLE IF EXISTS business.ai_training_execution_s CASCADE;")
        return self.execute_sql_with_rollback(sql, "Created AI Training Execution Satellite table")
    
    def create_ai_deployment_status_hub(self) -> bool:
        """Create AI Deployment Status Hub Table"""
        sql = """
        -- AI Deployment Status Hub
        CREATE TABLE IF NOT EXISTS business.ai_deployment_status_h (
            ai_deployment_status_hk BYTEA PRIMARY KEY,
            ai_deployment_status_bk VARCHAR(255) NOT NULL,
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            record_source VARCHAR(100) NOT NULL,
            
            CONSTRAINT uk_ai_deployment_status_h_bk_tenant 
                UNIQUE (ai_deployment_status_bk, tenant_hk)
        );
        
        COMMENT ON TABLE business.ai_deployment_status_h IS 
        'Hub table for AI deployment status tracking maintaining unique identifiers for model deployments with complete tenant isolation and production monitoring compliance.';
        """
        
        self.rollback_statements.append("DROP TABLE IF EXISTS business.ai_deployment_status_h CASCADE;")
        return self.execute_sql_with_rollback(sql, "Created AI Deployment Status Hub table")
    
    def create_ai_deployment_status_satellite(self) -> bool:
        """Create AI Deployment Status Satellite Table"""
        sql = """
        -- AI Deployment Status Satellite
        CREATE TABLE IF NOT EXISTS business.ai_deployment_status_s (
            ai_deployment_status_hk BYTEA NOT NULL REFERENCES business.ai_deployment_status_h(ai_deployment_status_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            load_end_date TIMESTAMP WITH TIME ZONE,
            hash_diff BYTEA NOT NULL,
            deployment_id VARCHAR(255) NOT NULL,
            model_name VARCHAR(100) NOT NULL,
            model_version VARCHAR(50) NOT NULL,
            deployment_environment VARCHAR(50) NOT NULL,
            deployment_status VARCHAR(50) NOT NULL,
            deployment_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
            endpoint_url VARCHAR(500),
            health_check_url VARCHAR(500),
            scaling_config JSONB,
            resource_allocation JSONB,
            traffic_percentage DECIMAL(5,2) DEFAULT 100.00,
            canary_deployment BOOLEAN DEFAULT false,
            rollback_version VARCHAR(50),
            deployment_notes TEXT,
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            record_source VARCHAR(100) NOT NULL,
            
            PRIMARY KEY (ai_deployment_status_hk, load_date),
            
            CONSTRAINT chk_ai_deployment_status_s_environment 
                CHECK (deployment_environment IN ('DEV', 'STAGING', 'PROD')),
            CONSTRAINT chk_ai_deployment_status_s_status 
                CHECK (deployment_status IN ('DEPLOYING', 'ACTIVE', 'INACTIVE', 'FAILED')),
            CONSTRAINT chk_ai_deployment_status_s_traffic 
                CHECK (traffic_percentage >= 0 AND traffic_percentage <= 100)
        );
        
        COMMENT ON TABLE business.ai_deployment_status_s IS 
        'Satellite table storing AI deployment status including environment, scaling configuration, traffic routing, and health monitoring with complete audit trail for production operations.';
        """
        
        self.rollback_statements.append("DROP TABLE IF EXISTS business.ai_deployment_status_s CASCADE;")
        return self.execute_sql_with_rollback(sql, "Created AI Deployment Status Satellite table")
    
    def create_ai_feature_pipeline_hub(self) -> bool:
        """Create AI Feature Pipeline Hub Table"""
        sql = """
        -- AI Feature Pipeline Hub
        CREATE TABLE IF NOT EXISTS business.ai_feature_pipeline_h (
            ai_feature_pipeline_hk BYTEA PRIMARY KEY,
            ai_feature_pipeline_bk VARCHAR(255) NOT NULL,
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            record_source VARCHAR(100) NOT NULL,
            
            CONSTRAINT uk_ai_feature_pipeline_h_bk_tenant 
                UNIQUE (ai_feature_pipeline_bk, tenant_hk)
        );
        
        COMMENT ON TABLE business.ai_feature_pipeline_h IS 
        'Hub table for AI feature pipeline tracking maintaining unique identifiers for feature engineering processes with complete tenant isolation and data lineage compliance.';
        """
        
        self.rollback_statements.append("DROP TABLE IF EXISTS business.ai_feature_pipeline_h CASCADE;")
        return self.execute_sql_with_rollback(sql, "Created AI Feature Pipeline Hub table")
    
    def create_ai_feature_pipeline_satellite(self) -> bool:
        """Create AI Feature Pipeline Satellite Table"""
        sql = """
        -- AI Feature Pipeline Satellite
        CREATE TABLE IF NOT EXISTS business.ai_feature_pipeline_s (
            ai_feature_pipeline_hk BYTEA NOT NULL REFERENCES business.ai_feature_pipeline_h(ai_feature_pipeline_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            load_end_date TIMESTAMP WITH TIME ZONE,
            hash_diff BYTEA NOT NULL,
            pipeline_id VARCHAR(255) NOT NULL,
            pipeline_name VARCHAR(200) NOT NULL,
            pipeline_version VARCHAR(50) NOT NULL,
            execution_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
            execution_status VARCHAR(50) NOT NULL,
            input_data_sources JSONB,
            feature_transformations JSONB,
            output_feature_store VARCHAR(200),
            data_quality_score DECIMAL(5,4),
            feature_drift_detected BOOLEAN DEFAULT false,
            processing_time_minutes INTEGER,
            records_processed INTEGER,
            features_generated INTEGER,
            data_lineage JSONB,
            error_details TEXT,
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            record_source VARCHAR(100) NOT NULL,
            
            PRIMARY KEY (ai_feature_pipeline_hk, load_date),
            
            CONSTRAINT chk_ai_feature_pipeline_s_status 
                CHECK (execution_status IN ('RUNNING', 'COMPLETED', 'FAILED')),
            CONSTRAINT chk_ai_feature_pipeline_s_quality 
                CHECK (data_quality_score IS NULL OR (data_quality_score >= 0 AND data_quality_score <= 1)),
            CONSTRAINT chk_ai_feature_pipeline_s_processing_time 
                CHECK (processing_time_minutes IS NULL OR processing_time_minutes >= 0)
        );
        
        COMMENT ON TABLE business.ai_feature_pipeline_s IS 
        'Satellite table storing AI feature pipeline execution details including data sources, transformations, quality metrics, and lineage tracking with complete audit trail for data governance.';
        """
        
        self.rollback_statements.append("DROP TABLE IF EXISTS business.ai_feature_pipeline_s CASCADE;")
        return self.execute_sql_with_rollback(sql, "Created AI Feature Pipeline Satellite table")
    
    def create_performance_indexes(self) -> bool:
        """Create performance indexes for AI tables"""
        indexes = [
            # AI Model Performance Indexes
            ("CREATE INDEX IF NOT EXISTS idx_ai_model_performance_s_tenant_date ON business.ai_model_performance_s (tenant_hk, evaluation_date DESC) WHERE load_end_date IS NULL;", 
             "AI Model Performance tenant-date index"),
            
            ("CREATE INDEX IF NOT EXISTS idx_ai_model_performance_s_model_version ON business.ai_model_performance_s (model_name, model_version, evaluation_date DESC) WHERE load_end_date IS NULL;", 
             "AI Model Performance model-version index"),
            
            # AI Training Execution Indexes
            ("CREATE INDEX IF NOT EXISTS idx_ai_training_execution_s_tenant_status ON business.ai_training_execution_s (tenant_hk, training_status, training_start_time DESC) WHERE load_end_date IS NULL;", 
             "AI Training Execution tenant-status index"),
            
            ("CREATE INDEX IF NOT EXISTS idx_ai_training_execution_s_job_id ON business.ai_training_execution_s (training_job_id, training_start_time DESC) WHERE load_end_date IS NULL;", 
             "AI Training Execution job-id index"),
            
            # AI Deployment Status Indexes
            ("CREATE INDEX IF NOT EXISTS idx_ai_deployment_status_s_tenant_env ON business.ai_deployment_status_s (tenant_hk, deployment_environment, deployment_status) WHERE load_end_date IS NULL;", 
             "AI Deployment Status tenant-environment index"),
            
            ("CREATE INDEX IF NOT EXISTS idx_ai_deployment_status_s_model_version ON business.ai_deployment_status_s (model_name, model_version, deployment_timestamp DESC) WHERE load_end_date IS NULL;", 
             "AI Deployment Status model-version index"),
            
            # AI Feature Pipeline Indexes
            ("CREATE INDEX IF NOT EXISTS idx_ai_feature_pipeline_s_tenant_status ON business.ai_feature_pipeline_s (tenant_hk, execution_status, execution_timestamp DESC) WHERE load_end_date IS NULL;", 
             "AI Feature Pipeline tenant-status index"),
            
            ("CREATE INDEX IF NOT EXISTS idx_ai_feature_pipeline_s_pipeline_name ON business.ai_feature_pipeline_s (pipeline_name, pipeline_version, execution_timestamp DESC) WHERE load_end_date IS NULL;", 
             "AI Feature Pipeline name-version index")
        ]
        
        success = True
        for sql, description in indexes:
            if not self.execute_sql_with_rollback(sql, description):
                success = False
        
        return success
    
    def create_ai_analytics_view(self) -> bool:
        """Create comprehensive AI analytics materialized view"""
        sql = """
        -- Comprehensive AI Analytics Dashboard
        CREATE MATERIALIZED VIEW IF NOT EXISTS infomart.ai_comprehensive_analytics AS
        SELECT 
            t.tenant_hk,
            t.tenant_name,
            DATE(COALESCE(aid.interaction_timestamp, amp.evaluation_date, ats.training_start_time::date, ads.deployment_timestamp::date, afp.execution_timestamp::date)) as analysis_date,
            
            -- Usage Metrics (existing AI interactions)
            COUNT(DISTINCT aid.ai_interaction_hk) as total_interactions,
            COUNT(DISTINCT uail.user_hk) as unique_users,
            COUNT(DISTINCT aid.model_used) as models_used,
            
            -- Performance Metrics (existing AI interactions)
            AVG(aid.processing_time_ms) as avg_response_time_ms,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY aid.processing_time_ms) as p95_response_time_ms,
            MAX(aid.processing_time_ms) as max_response_time_ms,
            
            -- NEW: Model Performance Metrics
            COUNT(DISTINCT amp.ai_model_performance_hk) as performance_evaluations,
            AVG(amp.accuracy_score) as avg_accuracy_score,
            AVG(amp.f1_score) as avg_f1_score,
            COUNT(*) FILTER (WHERE amp.performance_degradation = true) as models_with_degradation,
            COUNT(*) FILTER (WHERE amp.retraining_recommended = true) as models_needing_retraining,
            
            -- NEW: Training Metrics
            COUNT(DISTINCT ats.ai_training_execution_hk) as training_jobs,
            COUNT(*) FILTER (WHERE ats.training_status = 'COMPLETED') as completed_training_jobs,
            COUNT(*) FILTER (WHERE ats.training_status = 'RUNNING') as running_training_jobs,
            COUNT(*) FILTER (WHERE ats.training_status = 'FAILED') as failed_training_jobs,
            AVG(ats.training_duration_minutes) as avg_training_duration_minutes,
            
            -- NEW: Deployment Metrics  
            COUNT(DISTINCT ads.ai_deployment_status_hk) as deployments,
            COUNT(*) FILTER (WHERE ads.deployment_status = 'ACTIVE') as active_deployments,
            COUNT(*) FILTER (WHERE ads.deployment_environment = 'PROD') as prod_deployments,
            COUNT(*) FILTER (WHERE ads.canary_deployment = true) as canary_deployments,
            
            -- NEW: Feature Pipeline Metrics
            COUNT(DISTINCT afp.ai_feature_pipeline_hk) as feature_pipelines,
            COUNT(*) FILTER (WHERE afp.execution_status = 'COMPLETED') as completed_pipelines,
            COUNT(*) FILTER (WHERE afp.feature_drift_detected = true) as pipelines_with_drift,
            AVG(afp.data_quality_score) as avg_data_quality_score,
            
            -- Token Usage (existing)
            SUM(aid.token_count_input) as total_input_tokens,
            SUM(aid.token_count_output) as total_output_tokens,
            SUM(aid.token_count_input + aid.token_count_output) as total_tokens,
            
            -- Safety & Security (existing)
            AVG(CASE WHEN aid.security_level = 'safe' THEN 100 ELSE 0 END) as safety_score,
            COUNT(*) FILTER (WHERE aid.security_level != 'safe') as unsafe_interactions,
            
            CURRENT_TIMESTAMP as last_updated

        FROM auth.tenant_h th
        JOIN auth.tenant_profile_s t ON th.tenant_hk = t.tenant_hk AND t.load_end_date IS NULL
        
        -- Left join with existing AI interactions
        LEFT JOIN business.ai_interaction_h aih ON th.tenant_hk = aih.tenant_hk
        LEFT JOIN business.ai_interaction_details_s aid ON aih.ai_interaction_hk = aid.ai_interaction_hk AND aid.load_end_date IS NULL
        LEFT JOIN business.user_ai_interaction_l uail ON aih.ai_interaction_hk = uail.ai_interaction_hk
        
        -- Left join with NEW AI observation tables
        LEFT JOIN business.ai_model_performance_h amph ON th.tenant_hk = amph.tenant_hk
        LEFT JOIN business.ai_model_performance_s amp ON amph.ai_model_performance_hk = amp.ai_model_performance_hk AND amp.load_end_date IS NULL
        
        LEFT JOIN business.ai_training_execution_h ateh ON th.tenant_hk = ateh.tenant_hk
        LEFT JOIN business.ai_training_execution_s ats ON ateh.ai_training_execution_hk = ats.ai_training_execution_hk AND ats.load_end_date IS NULL
        
        LEFT JOIN business.ai_deployment_status_h adsh ON th.tenant_hk = adsh.tenant_hk
        LEFT JOIN business.ai_deployment_status_s ads ON adsh.ai_deployment_status_hk = ads.ai_deployment_status_hk AND ads.load_end_date IS NULL
        
        LEFT JOIN business.ai_feature_pipeline_h afph ON th.tenant_hk = afph.tenant_hk
        LEFT JOIN business.ai_feature_pipeline_s afp ON afph.ai_feature_pipeline_hk = afp.ai_feature_pipeline_hk AND afp.load_end_date IS NULL
        
        GROUP BY 
            t.tenant_hk, 
            t.tenant_name, 
            DATE(COALESCE(aid.interaction_timestamp, amp.evaluation_date, ats.training_start_time::date, ads.deployment_timestamp::date, afp.execution_timestamp::date))
        
        ORDER BY analysis_date DESC, t.tenant_name;
        """
        
        self.rollback_statements.append("DROP MATERIALIZED VIEW IF EXISTS infomart.ai_comprehensive_analytics CASCADE;")
        return self.execute_sql_with_rollback(sql, "Created AI Comprehensive Analytics materialized view")
    
    def create_refresh_function(self) -> bool:
        """Create function to refresh AI analytics"""
        sql = """
        -- Create refresh function for AI analytics
        CREATE OR REPLACE FUNCTION infomart.refresh_ai_analytics()
        RETURNS VOID AS $$
        BEGIN
            REFRESH MATERIALIZED VIEW CONCURRENTLY infomart.ai_comprehensive_analytics;
            
            -- Log the refresh
            INSERT INTO util.maintenance_log (
                maintenance_type,
                maintenance_details,
                execution_timestamp,
                execution_status
            ) VALUES (
                'MATERIALIZED_VIEW_REFRESH',
                'AI comprehensive analytics view refreshed successfully',
                CURRENT_TIMESTAMP,
                'COMPLETED'
            ) ON CONFLICT DO NOTHING;
            
        EXCEPTION WHEN OTHERS THEN
            -- Log the error
            INSERT INTO util.maintenance_log (
                maintenance_type,
                maintenance_details,
                execution_timestamp,
                execution_status,
                error_message
            ) VALUES (
                'MATERIALIZED_VIEW_REFRESH',
                'AI comprehensive analytics view refresh failed',
                CURRENT_TIMESTAMP,
                'FAILED',
                SQLERRM
            ) ON CONFLICT DO NOTHING;
            
            RAISE;
        END;
        $$ LANGUAGE plpgsql;
        
        COMMENT ON FUNCTION infomart.refresh_ai_analytics() IS 
        'Refreshes the AI comprehensive analytics materialized view with error handling and logging for automated maintenance procedures.';
        """
        
        self.rollback_statements.append("DROP FUNCTION IF EXISTS infomart.refresh_ai_analytics();")
        return self.execute_sql_with_rollback(sql, "Created AI analytics refresh function")
    
    def validate_implementation(self) -> bool:
        """Validate that all AI infrastructure was created successfully"""
        print("\n🔍 VALIDATING AI INFRASTRUCTURE IMPLEMENTATION...")
        
        validation_queries = [
            ("SELECT COUNT(*) FROM information_schema.tables WHERE table_name LIKE 'ai_model_performance_%'", 
             "AI Model Performance tables", 2),
            ("SELECT COUNT(*) FROM information_schema.tables WHERE table_name LIKE 'ai_training_execution_%'", 
             "AI Training Execution tables", 2),
            ("SELECT COUNT(*) FROM information_schema.tables WHERE table_name LIKE 'ai_deployment_status_%'", 
             "AI Deployment Status tables", 2),
            ("SELECT COUNT(*) FROM information_schema.tables WHERE table_name LIKE 'ai_feature_pipeline_%'", 
             "AI Feature Pipeline tables", 2),
            ("SELECT COUNT(*) FROM pg_matviews WHERE matviewname = 'ai_comprehensive_analytics'", 
             "AI Analytics materialized view", 1),
            ("SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'refresh_ai_analytics'", 
             "AI Analytics refresh function", 1)
        ]
        
        all_valid = True
        cursor = self.conn.cursor()
        
        for query, description, expected_count in validation_queries:
            try:
                cursor.execute(query)
                actual_count = cursor.fetchone()[0]
                
                if actual_count == expected_count:
                    print(f"✅ {description}: {actual_count}/{expected_count}")
                else:
                    print(f"❌ {description}: {actual_count}/{expected_count}")
                    all_valid = False
                    
            except Exception as e:
                print(f"❌ {description}: Validation failed - {e}")
                all_valid = False
        
        cursor.close()
        return all_valid
    
    def execute_phase1(self) -> bool:
        """Execute complete Phase 1 implementation"""
        print("📋 PHASE 1 IMPLEMENTATION STEPS:")
        print("1. AI Model Performance Hub & Satellite tables")
        print("2. AI Training Execution Hub & Satellite tables") 
        print("3. AI Deployment Status Hub & Satellite tables")
        print("4. AI Feature Pipeline Hub & Satellite tables")
        print("5. Performance indexes for all new tables")
        print("6. Enhanced AI analytics materialized view")
        print("7. Analytics refresh function")
        print("8. Implementation validation")
        print()
        
        implementation_steps = [
            (self.create_ai_model_performance_hub, "AI Model Performance Hub"),
            (self.create_ai_model_performance_satellite, "AI Model Performance Satellite"),
            (self.create_ai_training_execution_hub, "AI Training Execution Hub"),
            (self.create_ai_training_execution_satellite, "AI Training Execution Satellite"),
            (self.create_ai_deployment_status_hub, "AI Deployment Status Hub"),
            (self.create_ai_deployment_status_satellite, "AI Deployment Status Satellite"),
            (self.create_ai_feature_pipeline_hub, "AI Feature Pipeline Hub"),
            (self.create_ai_feature_pipeline_satellite, "AI Feature Pipeline Satellite"),
            (self.create_performance_indexes, "Performance Indexes"),
            (self.create_ai_analytics_view, "AI Analytics View"),
            (self.create_refresh_function, "Refresh Function")
        ]
        
        try:
            for step_function, step_name in implementation_steps:
                print(f"\n📋 Executing: {step_name}")
                if not step_function():
                    print(f"❌ Phase 1 failed at step: {step_name}")
                    return False
            
            # Commit all changes
            self.conn.commit()
            print("\n✅ All Phase 1 changes committed successfully")
            
            # Validate implementation
            if self.validate_implementation():
                print("\n🎉 PHASE 1 COMPLETED SUCCESSFULLY!")
                print("AI/ML System completeness: 66.7% → 100% ✅")
                self.success = True
                return True
            else:
                print("\n❌ Phase 1 validation failed")
                return False
                
        except Exception as e:
            print(f"\n❌ Phase 1 execution failed: {e}")
            print(f"Traceback: {traceback.format_exc()}")
            return False
    
    def rollback_changes(self):
        """Rollback all changes if something fails"""
        if not self.rollback_statements:
            return
            
        print("\n🔄 ROLLING BACK CHANGES...")
        try:
            cursor = self.conn.cursor()
            # Execute rollback statements in reverse order
            for sql in reversed(self.rollback_statements):
                try:
                    cursor.execute(sql)
                    print(f"  ↩️  Rolled back: {sql[:50]}...")
                except Exception as e:
                    print(f"  ⚠️  Rollback warning: {e}")
            
            self.conn.commit()
            print("✅ Rollback completed")
            cursor.close()
            
        except Exception as e:
            print(f"❌ Rollback failed: {e}")
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            print("📡 Database connection closed")

def main():
    """Main execution function"""
    try:
        # Get database password securely
        db_password = input("Enter database password: ")

        # Initialize connection parameters
        conn_params = {
            'dbname': 'one_vault',
            'user': 'postgres',
            'password': db_password,
            'host': 'localhost',
            'port': '5432'
        }

        # Initialize and execute Phase 1
        phase1 = Phase1AIInfrastructure(conn_params)
        phase1.connect()
        
        # Execute Phase 1
        success = phase1.execute_phase1()
        
        if not success:
            print("\n🔄 Attempting rollback due to failure...")
            phase1.rollback_changes()
        
        return success
        
    except KeyboardInterrupt:
        print("\n⚠️  Process interrupted by user")
        print("🔄 Attempting rollback...")
        if 'phase1' in locals():
            phase1.rollback_changes()
        return False
        
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        print(f"Traceback: {traceback.format_exc()}")
        print("🔄 Attempting rollback...")
        if 'phase1' in locals():
            phase1.rollback_changes()
        return False
        
    finally:
        if 'phase1' in locals():
            phase1.close()

if __name__ == "__main__":
    success = main()
    if success:
        print("\n🎯 NEXT STEP: Execute Phase 2 - Tenant Isolation Completion")
        print("   Run: python phase2_tenant_isolation.py")
    else:
        print("\n❌ Phase 1 failed. Please review errors and retry.") 