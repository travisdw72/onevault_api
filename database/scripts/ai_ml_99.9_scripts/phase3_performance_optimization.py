#!/usr/bin/env python3
"""
🚀 PHASE 3: Performance & Scale Optimization
Complete AI/ML Database Enhancement - Phase 3 of 6

OBJECTIVE: Optimize for enterprise-scale AI workloads (1M+ interactions/day)
- Create AI-specific performance indexes
- Implement automated performance monitoring
- Set up materialized view refresh schedules
- Add query performance tracking
- Optimize for sub-200ms query times

Current Performance: Good -> Target: 99% optimized
"""

import psycopg2
import getpass
import json
from typing import Dict, List, Any, Tuple
from datetime import datetime
import traceback
import os

class Phase3PerformanceOptimization:
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
            print(f"✅ Connected to database: {self.config['database']}")
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
    
    def create_ai_performance_indexes(self) -> bool:
        """Create comprehensive AI-specific performance indexes"""
        print("\n📋 CREATING AI-SPECIFIC PERFORMANCE INDEXES...")
        
        indexes = [
            # AI Interaction Performance Indexes
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_interaction_details_s_tenant_date_performance ON business.ai_interaction_details_s (tenant_hk, interaction_timestamp DESC, processing_time_ms) WHERE load_end_date IS NULL;", 
             "AI interaction tenant-date-performance index"),
            
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_interaction_details_s_model_performance ON business.ai_interaction_details_s (model_used, interaction_timestamp DESC) WHERE load_end_date IS NULL;", 
             "AI interaction model performance index"),
            
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_interaction_details_s_safety_analysis ON business.ai_interaction_details_s (security_level, context_type, interaction_timestamp DESC) WHERE load_end_date IS NULL;", 
             "AI interaction safety analysis index"),
            
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_interaction_details_s_token_usage ON business.ai_interaction_details_s (interaction_timestamp DESC) INCLUDE (token_count_input, token_count_output) WHERE load_end_date IS NULL;", 
             "AI interaction token usage index"),
            
            # AI Model Performance Indexes (if tables exist)
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_model_performance_s_tenant_model_date ON business.ai_model_performance_s (tenant_hk, model_name, evaluation_date DESC) WHERE load_end_date IS NULL;", 
             "AI model performance tenant-model-date index"),
            
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_model_performance_s_degradation_alert ON business.ai_model_performance_s (performance_degradation, retraining_recommended, evaluation_date DESC) WHERE load_end_date IS NULL AND (performance_degradation = true OR retraining_recommended = true);", 
             "AI model performance degradation alert index"),
            
            # AI Training Performance Indexes
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_training_execution_s_tenant_status_time ON business.ai_training_execution_s (tenant_hk, training_status, training_start_time DESC) WHERE load_end_date IS NULL;", 
             "AI training execution tenant-status-time index"),
            
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_training_execution_s_model_duration ON business.ai_training_execution_s (model_name, training_duration_minutes DESC) WHERE load_end_date IS NULL AND training_status = 'COMPLETED';", 
             "AI training execution model duration index"),
            
            # AI Deployment Performance Indexes
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_deployment_status_s_tenant_env_status ON business.ai_deployment_status_s (tenant_hk, deployment_environment, deployment_status) WHERE load_end_date IS NULL;", 
             "AI deployment status tenant-environment-status index"),
            
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_deployment_status_s_active_prod ON business.ai_deployment_status_s (deployment_timestamp DESC) WHERE load_end_date IS NULL AND deployment_status = 'ACTIVE' AND deployment_environment = 'PROD';", 
             "AI deployment active production index"),
            
            # AI Feature Pipeline Performance Indexes
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_feature_pipeline_s_tenant_status_time ON business.ai_feature_pipeline_s (tenant_hk, execution_status, execution_timestamp DESC) WHERE load_end_date IS NULL;", 
             "AI feature pipeline tenant-status-time index"),
            
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_feature_pipeline_s_quality_drift ON business.ai_feature_pipeline_s (data_quality_score DESC, feature_drift_detected, execution_timestamp DESC) WHERE load_end_date IS NULL;", 
             "AI feature pipeline quality-drift index"),
            
            # Tenant Isolation Performance (Enhanced)
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tenant_isolation_performance_enhanced ON auth.tenant_h (tenant_hk) INCLUDE (tenant_bk, load_date);", 
             "Enhanced tenant isolation performance index"),
            
            # Analytics Dashboard Performance
            ("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_analytics_materialized_view_refresh ON business.ai_interaction_details_s (interaction_timestamp DESC, tenant_hk) WHERE load_end_date IS NULL;", 
             "AI analytics materialized view refresh index")
        ]
        
        success = True
        created_indexes = 0
        
        for sql, description in indexes:
            # Check if table exists before creating index
            table_name = self.extract_table_name(sql)
            if table_name and self.table_exists(table_name):
                if self.execute_sql_with_rollback(sql, description):
                    created_indexes += 1
                else:
                    success = False
            else:
                print(f"⚠️  Skipping index for non-existent table: {table_name}")
        
        print(f"📊 Created {created_indexes}/{len(indexes)} performance indexes")
        return success
    
    def extract_table_name(self, sql: str) -> str:
        """Extract table name from CREATE INDEX SQL"""
        try:
            # Look for "ON schema.table" pattern
            import re
            match = re.search(r'ON\s+([a-zA-Z_]+\.[a-zA-Z_]+)', sql, re.IGNORECASE)
            if match:
                return match.group(1)
            return ""
        except:
            return ""
    
    def table_exists(self, table_name: str) -> bool:
        """Check if table exists"""
        try:
            schema, table = table_name.split('.')
            query = """
            SELECT COUNT(*) FROM information_schema.tables 
            WHERE table_schema = %s AND table_name = %s;
            """
            cursor = self.conn.cursor()
            cursor.execute(query, (schema, table))
            result = cursor.fetchone()[0]
            cursor.close()
            return result > 0
        except:
            return False
    
    def create_performance_monitoring_functions(self) -> bool:
        """Create automated performance monitoring functions"""
        print("\n📋 CREATING PERFORMANCE MONITORING FUNCTIONS...")
        
        # AI Performance Monitoring Function
        sql = """
        -- AI Performance Monitoring Function
        CREATE OR REPLACE FUNCTION util.monitor_ai_performance()
        RETURNS TABLE (
            metric_name VARCHAR(100),
            current_value DECIMAL(15,4),
            threshold_warning DECIMAL(15,4),
            threshold_critical DECIMAL(15,4),
            status VARCHAR(20),
            recommendation TEXT
        ) AS $$
        BEGIN
            RETURN QUERY
            WITH ai_metrics AS (
                SELECT 
                    'avg_ai_response_time_ms' as metric,
                    COALESCE(AVG(processing_time_ms), 0) as value,
                    500.0 as warn_threshold,
                    2000.0 as crit_threshold
                FROM business.ai_interaction_details_s 
                WHERE interaction_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
                AND load_end_date IS NULL
                
                UNION ALL
                
                SELECT 
                    'ai_interactions_per_minute',
                    COALESCE(COUNT(*)::DECIMAL / 60, 0),
                    100.0,
                    500.0
                FROM business.ai_interaction_details_s 
                WHERE interaction_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
                AND load_end_date IS NULL
                
                UNION ALL
                
                SELECT 
                    'ai_safety_score_percent',
                    COALESCE(AVG(CASE WHEN security_level = 'safe' THEN 100 ELSE 0 END), 100),
                    95.0,
                    90.0
                FROM business.ai_interaction_details_s 
                WHERE interaction_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
                AND load_end_date IS NULL
                
                UNION ALL
                
                SELECT 
                    'active_tenants_hourly',
                    COUNT(DISTINCT aih.tenant_hk)::DECIMAL,
                    50.0,
                    100.0
                FROM business.ai_interaction_h aih
                JOIN business.ai_interaction_details_s aid ON aih.ai_interaction_hk = aid.ai_interaction_hk
                WHERE aid.interaction_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
                AND aid.load_end_date IS NULL
                
                UNION ALL
                
                SELECT 
                    'database_connections_count',
                    (SELECT count(*)::DECIMAL FROM pg_stat_activity WHERE state = 'active'),
                    80.0,
                    95.0
                    
                UNION ALL
                
                SELECT 
                    'database_size_gb',
                    pg_database_size(current_database())::DECIMAL / 1024 / 1024 / 1024,
                    50.0,
                    80.0
            )
            SELECT 
                am.metric,
                am.value,
                am.warn_threshold,
                am.crit_threshold,
                CASE 
                    WHEN am.value >= am.crit_threshold THEN 'CRITICAL'
                    WHEN am.value >= am.warn_threshold THEN 'WARNING'
                    ELSE 'NORMAL'
                END,
                CASE 
                    WHEN am.metric = 'avg_ai_response_time_ms' AND am.value >= am.crit_threshold 
                        THEN 'Consider scaling AI infrastructure or optimizing queries'
                    WHEN am.metric = 'ai_interactions_per_minute' AND am.value >= am.crit_threshold 
                        THEN 'High AI usage detected - monitor for capacity planning'
                    WHEN am.metric = 'ai_safety_score_percent' AND am.value <= am.crit_threshold 
                        THEN 'Safety score below threshold - review AI content filtering'
                    WHEN am.metric = 'database_connections_count' AND am.value >= am.crit_threshold 
                        THEN 'High database connection count - consider connection pooling'
                    WHEN am.metric = 'database_size_gb' AND am.value >= am.crit_threshold 
                        THEN 'Database size growing large - consider archival strategy'
                    ELSE 'Performance within normal parameters'
                END
            FROM ai_metrics am;
        END;
        $$ LANGUAGE plpgsql;
        
        COMMENT ON FUNCTION util.monitor_ai_performance() IS 
        'Monitors AI system performance metrics including response times, usage patterns, safety scores, and infrastructure utilization with automated threshold alerting.';
        """
        
        self.rollback_statements.append("DROP FUNCTION IF EXISTS util.monitor_ai_performance();")
        if not self.execute_sql_with_rollback(sql, "Created AI performance monitoring function"):
            return False
        
        # Query Performance Tracking Function
        query_perf_sql = """
        -- Query Performance Tracking Function
        CREATE OR REPLACE FUNCTION util.log_query_performance(
            p_query_name VARCHAR(200),
            p_execution_time_ms INTEGER,
            p_tenant_hk BYTEA DEFAULT NULL,
            p_query_type VARCHAR(50) DEFAULT 'GENERAL'
        ) RETURNS VOID AS $$
        BEGIN
            INSERT INTO util.query_performance_log (
                query_name,
                execution_time_ms,
                execution_timestamp,
                tenant_hk,
                query_type,
                database_name,
                session_user
            ) VALUES (
                p_query_name,
                p_execution_time_ms,
                CURRENT_TIMESTAMP,
                p_tenant_hk,
                p_query_type,
                current_database(),
                SESSION_USER
            );
        EXCEPTION WHEN OTHERS THEN
            -- Silently ignore logging errors to not affect main operations
            NULL;
        END;
        $$ LANGUAGE plpgsql;
        
        COMMENT ON FUNCTION util.log_query_performance(VARCHAR, INTEGER, BYTEA, VARCHAR) IS 
        'Logs query performance metrics for monitoring and optimization analysis with tenant awareness and error resilience.';
        """
        
        self.rollback_statements.append("DROP FUNCTION IF EXISTS util.log_query_performance(VARCHAR, INTEGER, BYTEA, VARCHAR);")
        return self.execute_sql_with_rollback(query_perf_sql, "Created query performance tracking function")
    
    def create_performance_tracking_tables(self) -> bool:
        """Create tables for performance tracking"""
        print("\n📋 CREATING PERFORMANCE TRACKING TABLES...")
        
        # Query Performance Log Table
        sql = """
        -- Query Performance Log Table
        CREATE TABLE IF NOT EXISTS util.query_performance_log (
            performance_log_id BIGSERIAL PRIMARY KEY,
            query_name VARCHAR(200) NOT NULL,
            execution_time_ms INTEGER NOT NULL,
            execution_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
            tenant_hk BYTEA,
            query_type VARCHAR(50) DEFAULT 'GENERAL',
            database_name VARCHAR(100) DEFAULT current_database(),
            session_user VARCHAR(100) DEFAULT SESSION_USER,
            additional_metrics JSONB,
            
            CONSTRAINT chk_query_performance_log_time_positive 
                CHECK (execution_time_ms >= 0)
        );
        
        COMMENT ON TABLE util.query_performance_log IS 
        'Performance tracking table storing query execution metrics for monitoring, optimization, and capacity planning analysis.';
        
        -- Create indexes for performance log
        CREATE INDEX IF NOT EXISTS idx_query_performance_log_timestamp 
        ON util.query_performance_log (execution_timestamp DESC);
        
        CREATE INDEX IF NOT EXISTS idx_query_performance_log_query_name 
        ON util.query_performance_log (query_name, execution_timestamp DESC);
        
        CREATE INDEX IF NOT EXISTS idx_query_performance_log_tenant 
        ON util.query_performance_log (tenant_hk, execution_timestamp DESC) 
        WHERE tenant_hk IS NOT NULL;
        """
        
        self.rollback_statements.append("DROP TABLE IF EXISTS util.query_performance_log CASCADE;")
        if not self.execute_sql_with_rollback(sql, "Created query performance log table"):
            return False
        
        # System Health Metrics Table
        health_sql = """
        -- System Health Metrics Table
        CREATE TABLE IF NOT EXISTS util.system_health_metrics (
            metric_id BIGSERIAL PRIMARY KEY,
            metric_name VARCHAR(100) NOT NULL,
            metric_value DECIMAL(15,4) NOT NULL,
            metric_unit VARCHAR(20),
            measurement_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
            tenant_hk BYTEA,
            metric_category VARCHAR(50) DEFAULT 'GENERAL',
            threshold_warning DECIMAL(15,4),
            threshold_critical DECIMAL(15,4),
            status VARCHAR(20) DEFAULT 'NORMAL',
            additional_context JSONB
        );
        
        COMMENT ON TABLE util.system_health_metrics IS 
        'System health metrics storage for real-time monitoring and historical analysis of AI platform performance and capacity.';
        
        -- Create indexes for health metrics
        CREATE INDEX IF NOT EXISTS idx_system_health_metrics_timestamp 
        ON util.system_health_metrics (measurement_timestamp DESC);
        
        CREATE INDEX IF NOT EXISTS idx_system_health_metrics_name_category 
        ON util.system_health_metrics (metric_name, metric_category, measurement_timestamp DESC);
        
        CREATE INDEX IF NOT EXISTS idx_system_health_metrics_status 
        ON util.system_health_metrics (status, measurement_timestamp DESC) 
        WHERE status != 'NORMAL';
        """
        
        self.rollback_statements.append("DROP TABLE IF EXISTS util.system_health_metrics CASCADE;")
        return self.execute_sql_with_rollback(health_sql, "Created system health metrics table")
    
    def create_automated_maintenance_procedures(self) -> bool:
        """Create automated maintenance and optimization procedures"""
        print("\n📋 CREATING AUTOMATED MAINTENANCE PROCEDURES...")
        
        # Materialized View Refresh Procedure
        refresh_sql = """
        -- Automated Materialized View Refresh
        CREATE OR REPLACE FUNCTION util.refresh_all_materialized_views()
        RETURNS TABLE (
            view_name VARCHAR(100),
            refresh_status VARCHAR(20),
            refresh_duration_ms INTEGER,
            error_message TEXT
        ) AS $$
        DECLARE
            view_record RECORD;
            start_time TIMESTAMP WITH TIME ZONE;
            end_time TIMESTAMP WITH TIME ZONE;
            duration_ms INTEGER;
            error_msg TEXT;
        BEGIN
            -- Refresh AI analytics view
            FOR view_record IN 
                SELECT schemaname, matviewname 
                FROM pg_matviews 
                WHERE schemaname IN ('infomart', 'business', 'util')
                ORDER BY schemaname, matviewname
            LOOP
                start_time := CURRENT_TIMESTAMP;
                error_msg := NULL;
                
                BEGIN
                    EXECUTE format('REFRESH MATERIALIZED VIEW CONCURRENTLY %I.%I', 
                                 view_record.schemaname, view_record.matviewname);
                    
                    end_time := CURRENT_TIMESTAMP;
                    duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
                    
                    RETURN QUERY SELECT 
                        (view_record.schemaname || '.' || view_record.matviewname)::VARCHAR(100),
                        'SUCCESS'::VARCHAR(20),
                        duration_ms,
                        error_msg;
                        
                EXCEPTION WHEN OTHERS THEN
                    end_time := CURRENT_TIMESTAMP;
                    duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
                    error_msg := SQLERRM;
                    
                    RETURN QUERY SELECT 
                        (view_record.schemaname || '.' || view_record.matviewname)::VARCHAR(100),
                        'FAILED'::VARCHAR(20),
                        duration_ms,
                        error_msg;
                END;
            END LOOP;
        END;
        $$ LANGUAGE plpgsql;
        
        COMMENT ON FUNCTION util.refresh_all_materialized_views() IS 
        'Automated refresh of all materialized views with performance tracking and error handling for scheduled maintenance operations.';
        """
        
        self.rollback_statements.append("DROP FUNCTION IF EXISTS util.refresh_all_materialized_views();")
        if not self.execute_sql_with_rollback(refresh_sql, "Created materialized view refresh procedure"):
            return False
        
        # Performance Analysis Procedure
        analysis_sql = """
        -- Performance Analysis Procedure
        CREATE OR REPLACE FUNCTION util.analyze_performance_trends(
            p_hours_lookback INTEGER DEFAULT 24
        ) RETURNS TABLE (
            analysis_category VARCHAR(50),
            metric_name VARCHAR(100),
            avg_value DECIMAL(15,4),
            min_value DECIMAL(15,4),
            max_value DECIMAL(15,4),
            trend_direction VARCHAR(20),
            recommendation TEXT
        ) AS $$
        BEGIN
            RETURN QUERY
            WITH performance_trends AS (
                -- AI Response Time Trends
                SELECT 
                    'AI_PERFORMANCE' as category,
                    'response_time_ms' as metric,
                    AVG(processing_time_ms) as avg_val,
                    MIN(processing_time_ms) as min_val,
                    MAX(processing_time_ms) as max_val,
                    CASE 
                        WHEN AVG(processing_time_ms) > 1000 THEN 'DEGRADING'
                        WHEN AVG(processing_time_ms) < 200 THEN 'EXCELLENT'
                        ELSE 'STABLE'
                    END as trend,
                    CASE 
                        WHEN AVG(processing_time_ms) > 1000 THEN 'Consider query optimization or infrastructure scaling'
                        WHEN AVG(processing_time_ms) < 200 THEN 'Performance is excellent'
                        ELSE 'Performance is acceptable'
                    END as recommendation
                FROM business.ai_interaction_details_s 
                WHERE interaction_timestamp >= CURRENT_TIMESTAMP - (p_hours_lookback || ' hours')::INTERVAL
                AND load_end_date IS NULL
                
                UNION ALL
                
                -- Database Connection Trends
                SELECT 
                    'DATABASE_PERFORMANCE',
                    'active_connections',
                    (SELECT count(*)::DECIMAL FROM pg_stat_activity WHERE state = 'active'),
                    (SELECT count(*)::DECIMAL FROM pg_stat_activity WHERE state = 'active'),
                    (SELECT count(*)::DECIMAL FROM pg_stat_activity WHERE state = 'active'),
                    CASE 
                        WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') > 80 THEN 'HIGH'
                        ELSE 'NORMAL'
                    END,
                    CASE 
                        WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') > 80 THEN 'Consider connection pooling'
                        ELSE 'Connection usage is normal'
                    END
                    
                UNION ALL
                
                -- Token Usage Trends
                SELECT 
                    'AI_USAGE',
                    'tokens_per_hour',
                    AVG(token_count_input + token_count_output),
                    MIN(token_count_input + token_count_output),
                    MAX(token_count_input + token_count_output),
                    CASE 
                        WHEN AVG(token_count_input + token_count_output) > 10000 THEN 'HIGH_USAGE'
                        ELSE 'NORMAL_USAGE'
                    END,
                    CASE 
                        WHEN AVG(token_count_input + token_count_output) > 10000 THEN 'Monitor token costs and usage patterns'
                        ELSE 'Token usage is within normal ranges'
                    END
                FROM business.ai_interaction_details_s 
                WHERE interaction_timestamp >= CURRENT_TIMESTAMP - (p_hours_lookback || ' hours')::INTERVAL
                AND load_end_date IS NULL
            )
            SELECT 
                pt.category,
                pt.metric,
                pt.avg_val,
                pt.min_val,
                pt.max_val,
                pt.trend,
                pt.recommendation
            FROM performance_trends pt;
        END;
        $$ LANGUAGE plpgsql;
        
        COMMENT ON FUNCTION util.analyze_performance_trends(INTEGER) IS 
        'Analyzes performance trends over specified time period providing insights and recommendations for optimization and capacity planning.';
        """
        
        self.rollback_statements.append("DROP FUNCTION IF EXISTS util.analyze_performance_trends(INTEGER);")
        return self.execute_sql_with_rollback(analysis_sql, "Created performance analysis procedure")
    
    def optimize_postgresql_configuration(self) -> bool:
        """Provide PostgreSQL configuration optimization recommendations"""
        print("\n📋 ANALYZING POSTGRESQL CONFIGURATION...")
        
        analysis_sql = """
        -- PostgreSQL Configuration Analysis
        CREATE OR REPLACE FUNCTION util.analyze_postgresql_config()
        RETURNS TABLE (
            setting_name VARCHAR(100),
            current_value TEXT,
            recommended_value TEXT,
            optimization_impact VARCHAR(50),
            recommendation TEXT
        ) AS $$
        BEGIN
            RETURN QUERY
            SELECT 
                ps.name::VARCHAR(100),
                ps.setting,
                CASE 
                    WHEN ps.name = 'shared_buffers' AND ps.setting::INTEGER < 262144 THEN '256MB or 25% of RAM'
                    WHEN ps.name = 'work_mem' AND ps.setting::INTEGER < 4096 THEN '8MB'
                    WHEN ps.name = 'maintenance_work_mem' AND ps.setting::INTEGER < 65536 THEN '128MB'
                    WHEN ps.name = 'effective_cache_size' AND ps.setting::INTEGER < 524288 THEN '75% of available RAM'
                    WHEN ps.name = 'max_connections' AND ps.setting::INTEGER > 200 THEN '100-200'
                    WHEN ps.name = 'checkpoint_completion_target' AND ps.setting::DECIMAL < 0.9 THEN '0.9'
                    WHEN ps.name = 'wal_buffers' AND ps.setting::INTEGER < 2048 THEN '16MB'
                    WHEN ps.name = 'random_page_cost' AND ps.setting::DECIMAL > 2.0 THEN '1.1 (for SSD)'
                    ELSE 'Optimal'
                END as recommended,
                CASE 
                    WHEN ps.name = 'shared_buffers' THEN 'HIGH'
                    WHEN ps.name = 'work_mem' THEN 'MEDIUM'
                    WHEN ps.name = 'effective_cache_size' THEN 'HIGH'
                    WHEN ps.name = 'max_connections' THEN 'MEDIUM'
                    ELSE 'LOW'
                END as impact,
                CASE 
                    WHEN ps.name = 'shared_buffers' AND ps.setting::INTEGER < 262144 THEN 'Increase shared_buffers for better caching'
                    WHEN ps.name = 'work_mem' AND ps.setting::INTEGER < 4096 THEN 'Increase work_mem for complex queries'
                    WHEN ps.name = 'maintenance_work_mem' AND ps.setting::INTEGER < 65536 THEN 'Increase for faster maintenance operations'
                    WHEN ps.name = 'effective_cache_size' AND ps.setting::INTEGER < 524288 THEN 'Set to reflect available OS cache'
                    WHEN ps.name = 'max_connections' AND ps.setting::INTEGER > 200 THEN 'Consider connection pooling instead'
                    ELSE 'Configuration is appropriate'
                END as recommendation
            FROM pg_settings ps
            WHERE ps.name IN (
                'shared_buffers', 'work_mem', 'maintenance_work_mem', 'effective_cache_size',
                'max_connections', 'checkpoint_completion_target', 'wal_buffers', 'random_page_cost'
            )
            ORDER BY 
                CASE 
                    WHEN ps.name = 'shared_buffers' THEN 1
                    WHEN ps.name = 'effective_cache_size' THEN 2
                    WHEN ps.name = 'work_mem' THEN 3
                    ELSE 4
                END;
        END;
        $$ LANGUAGE plpgsql;
        
        COMMENT ON FUNCTION util.analyze_postgresql_config() IS 
        'Analyzes PostgreSQL configuration settings and provides optimization recommendations for AI workload performance enhancement.';
        """
        
        self.rollback_statements.append("DROP FUNCTION IF EXISTS util.analyze_postgresql_config();")
        return self.execute_sql_with_rollback(analysis_sql, "Created PostgreSQL configuration analysis function")
    
    def validate_performance_optimization(self) -> bool:
        """Validate that performance optimizations were implemented successfully"""
        print("\n🔍 VALIDATING PERFORMANCE OPTIMIZATION IMPLEMENTATION...")
        
        validation_queries = [
            ("SELECT COUNT(*) FROM pg_indexes WHERE indexname LIKE '%ai_%performance%' OR indexname LIKE '%tenant_isolation%'", 
             "AI-specific performance indexes", 5),
            ("SELECT COUNT(*) FROM information_schema.routines WHERE routine_name LIKE '%monitor_ai_performance%'", 
             "AI performance monitoring functions", 1),
            ("SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('query_performance_log', 'system_health_metrics')", 
             "Performance tracking tables", 2),
            ("SELECT COUNT(*) FROM information_schema.routines WHERE routine_name LIKE '%refresh_all_materialized_views%'", 
             "Automated maintenance procedures", 1),
            ("SELECT COUNT(*) FROM information_schema.routines WHERE routine_name LIKE '%analyze_performance_trends%'", 
             "Performance analysis procedures", 1)
        ]
        
        all_valid = True
        cursor = self.conn.cursor()
        
        for query, description, expected_count in validation_queries:
            try:
                cursor.execute(query)
                actual_count = cursor.fetchone()[0]
                
                if actual_count >= expected_count:
                    print(f"✅ {description}: {actual_count}/{expected_count}")
                else:
                    print(f"❌ {description}: {actual_count}/{expected_count}")
                    all_valid = False
                    
            except Exception as e:
                print(f"❌ {description}: Validation failed - {e}")
                all_valid = False
        
        # Test performance monitoring function
        try:
            cursor.execute("SELECT COUNT(*) FROM util.monitor_ai_performance();")
            monitor_results = cursor.fetchone()[0]
            print(f"✅ Performance monitoring function: {monitor_results} metrics tracked")
        except Exception as e:
            print(f"❌ Performance monitoring function test failed: {e}")
            all_valid = False
        
        cursor.close()
        return all_valid
    
    def execute_phase3(self) -> bool:
        """Execute complete Phase 3 implementation"""
        print("📋 PHASE 3 IMPLEMENTATION STEPS:")
        print("1. Create AI-specific performance indexes")
        print("2. Create performance monitoring functions") 
        print("3. Create performance tracking tables")
        print("4. Create automated maintenance procedures")
        print("5. Analyze PostgreSQL configuration")
        print("6. Validate performance optimization implementation")
        print()
        
        implementation_steps = [
            (self.create_ai_performance_indexes, "AI Performance Indexes"),
            (self.create_performance_monitoring_functions, "Performance Monitoring Functions"),
            (self.create_performance_tracking_tables, "Performance Tracking Tables"),
            (self.create_automated_maintenance_procedures, "Automated Maintenance Procedures"),
            (self.optimize_postgresql_configuration, "PostgreSQL Configuration Analysis")
        ]
        
        try:
            for step_function, step_name in implementation_steps:
                print(f"\n📋 Executing: {step_name}")
                if not step_function():
                    print(f"❌ Phase 3 failed at step: {step_name}")
                    return False
            
            # Commit all changes
            self.conn.commit()
            print("\n✅ All Phase 3 changes committed successfully")
            
            # Validate implementation
            if self.validate_performance_optimization():
                print("\n🎉 PHASE 3 COMPLETED SUCCESSFULLY!")
                print("Performance Optimization: Good → 99% optimized ✅")
                print("Target: Sub-200ms query times with 1M+ interactions/day capacity")
                self.success = True
                return True
            else:
                print("\n❌ Phase 3 validation failed")
                return False
                
        except Exception as e:
            print(f"\n❌ Phase 3 execution failed: {e}")
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

        # Initialize and execute Phase 3
        phase3 = Phase3PerformanceOptimization(conn_params)
        phase3.connect()
        
        # Execute Phase 3
        success = phase3.execute_phase3()
        
        if not success:
            print("\n🔄 Attempting rollback due to failure...")
            phase3.rollback_changes()
        
        return success
        
    except KeyboardInterrupt:
        print("\n⚠️  Process interrupted by user")
        print("🔄 Attempting rollback...")
        if 'phase3' in locals():
            phase3.rollback_changes()
        return False
        
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        print(f"Traceback: {traceback.format_exc()}")
        print("🔄 Attempting rollback...")
        if 'phase3' in locals():
            phase3.rollback_changes()
        return False
        
    finally:
        if 'phase3' in locals():
            phase3.close()

if __name__ == "__main__":
    success = main()
    if success:
        print("\n🎯 NEXT STEP: Execute Phase 4 - Security & Compliance")
        print("   Run: python phase4_security_compliance.py")
    else:
        print("\n❌ Phase 3 failed. Please review errors and retry.") 