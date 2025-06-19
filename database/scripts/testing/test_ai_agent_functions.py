#!/usr/bin/env python3
"""
AI Agent Database Function Testing Script
=========================================
Tests all AI agent database functions to ensure they work before building APIs.

Usage:
    python test_ai_agent_functions.py
"""

import psycopg2
import json
import os
from datetime import datetime
from pathlib import Path

# Configuration
CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'one_vault',
    'user': 'postgres',
    'password': os.getenv('DB_PASSWORD', 'your_password_here')
}

class AIAgentTester:
    def __init__(self):
        self.conn = None
        self.test_results = []
        
    def connect(self):
        """Establish database connection"""
        try:
            self.conn = psycopg2.connect(**CONFIG)
            self.conn.autocommit = True
            print("✅ Database connection established")
            return True
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return False
    
    def log_test(self, test_name, success, details=None):
        """Log test result"""
        result = {
            'test': test_name,
            'success': success,
            'timestamp': datetime.now().isoformat(),
            'details': details or {}
        }
        self.test_results.append(result)
        
        status = "✅" if success else "❌"
        print(f"{status} {test_name}")
        if details and not success:
            print(f"   Details: {details}")
    
    def test_schema_exists(self):
        """Test if ai_agents schema exists"""
        try:
            cursor = self.conn.cursor()
            cursor.execute("""
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name = 'ai_agents'
            """)
            result = cursor.fetchone()
            
            if result:
                self.log_test("AI Agents Schema Exists", True)
                return True
            else:
                self.log_test("AI Agents Schema Exists", False, "Schema not found")
                return False
        except Exception as e:
            self.log_test("AI Agents Schema Exists", False, str(e))
            return False
    
    def test_core_tables_exist(self):
        """Test if core AI agent tables exist"""
        required_tables = [
            'agent_template_h',
            'agent_template_s', 
            'user_agent_h',
            'user_agent_s',
            'user_agent_execution_h',
            'user_agent_execution_s'
        ]
        
        try:
            cursor = self.conn.cursor()
            for table in required_tables:
                cursor.execute("""
                    SELECT table_name 
                    FROM information_schema.tables 
                    WHERE table_schema = 'ai_agents' 
                    AND table_name = %s
                """, (table,))
                
                if cursor.fetchone():
                    self.log_test(f"Table {table} exists", True)
                else:
                    self.log_test(f"Table {table} exists", False, "Table not found")
                    return False
            
            return True
        except Exception as e:
            self.log_test("Core Tables Exist", False, str(e))
            return False
    
    def test_create_agent_template(self):
        """Test creating an agent template"""
        try:
            cursor = self.conn.cursor()
            
            # Test creating image analysis template
            cursor.execute("""
                SELECT ai_agents.create_agent_template(
                    'Test Image Analysis Template',
                    'IMAGE_AI',
                    'Test template for automated testing',
                    '["image_analysis", "object_detection", "classification"]'::jsonb,
                    '{"image_url": {"type": "string", "required": true}}'::jsonb,
                    '{"analysis_type": {"type": "string", "enum": ["basic", "detailed"]}}'::jsonb,
                    '{"analysis_type": "basic", "confidence_threshold": 0.7}'::jsonb,
                    '["openai_vision", "azure_computer_vision"]'::jsonb,
                    'test-image-template',
                    'BEGINNER',
                    0.05,
                    '{"example": "Image analysis for various use cases"}'::jsonb,
                    true
                )
            """)
            
            result = cursor.fetchone()
            template_hk = result[0] if result else None
            
            if template_hk:
                self.log_test("Create Agent Template", True, {"template_hk": template_hk.hex()})
                return template_hk
            else:
                self.log_test("Create Agent Template", False, "No template_hk returned")
                return None
                
        except Exception as e:
            self.log_test("Create Agent Template", False, str(e))
            return None
    
    def test_create_user_agent(self, template_hk):
        """Test creating a user agent from template"""
        if not template_hk:
            self.log_test("Create User Agent", False, "No template_hk provided")
            return None
            
        try:
            cursor = self.conn.cursor()
            
            # Get a test tenant (create one if needed)
            test_tenant_hk = self.get_or_create_test_tenant()
            
            cursor.execute("""
                SELECT ai_agents.create_user_agent(
                    %s,
                    'Test Horse Health Monitor',
                    %s,
                    '{
                        "industry_focus": "equine_health",
                        "analysis_prompts": {
                            "primary_prompt": "Analyze horse photo for health indicators"
                        },
                        "detection_categories": {
                            "injury_detection": {"threshold": 0.8},
                            "lameness_indicators": {"threshold": 0.7}
                        }
                    }'::jsonb,
                    '{
                        "data_access": "own_horses_only",
                        "retention_days": 365
                    }'::jsonb,
                    '{
                        "injury_detected": {
                            "threshold": 0.8,
                            "notify": ["trainer@test.com"]
                        }
                    }'::jsonb,
                    75.00
                )
            """, (test_tenant_hk, template_hk))
            
            result = cursor.fetchone()
            agent_hk = result[0] if result else None
            
            if agent_hk:
                self.log_test("Create User Agent", True, {"agent_hk": agent_hk.hex()})
                return agent_hk
            else:
                self.log_test("Create User Agent", False, "No agent_hk returned")
                return None
                
        except Exception as e:
            self.log_test("Create User Agent", False, str(e))
            return None
    
    def test_execute_user_agent(self, agent_hk):
        """Test executing a user agent"""
        if not agent_hk:
            self.log_test("Execute User Agent", False, "No agent_hk provided")
            return None
            
        try:
            cursor = self.conn.cursor()
            
            cursor.execute("""
                SELECT ai_agents.execute_user_agent(
                    %s,
                    '{
                        "image_url": "https://example.com/test_horse.jpg",
                        "subject_id": "TEST_HORSE_001",
                        "context": "health_assessment"
                    }'::jsonb,
                    'MANUAL'
                )
            """, (agent_hk,))
            
            result = cursor.fetchone()
            execution_hk = result[0] if result else None
            
            if execution_hk:
                self.log_test("Execute User Agent", True, {"execution_hk": execution_hk.hex()})
                return execution_hk
            else:
                self.log_test("Execute User Agent", False, "No execution_hk returned")
                return None
                
        except Exception as e:
            self.log_test("Execute User Agent", False, str(e))
            return None
    
    def test_get_user_agents(self):
        """Test retrieving user agents"""
        try:
            cursor = self.conn.cursor()
            test_tenant_hk = self.get_or_create_test_tenant()
            
            cursor.execute("""
                SELECT ua.agent_name, uas.configuration, uas.monthly_budget
                FROM ai_agents.user_agent_h ua
                JOIN ai_agents.user_agent_s uas ON ua.user_agent_hk = uas.user_agent_hk
                WHERE ua.tenant_hk = %s
                AND uas.load_end_date IS NULL
                LIMIT 5
            """, (test_tenant_hk,))
            
            results = cursor.fetchall()
            
            if results:
                self.log_test("Get User Agents", True, {"count": len(results)})
                return True
            else:
                self.log_test("Get User Agents", False, "No agents found")
                return False
                
        except Exception as e:
            self.log_test("Get User Agents", False, str(e))
            return False
    
    def test_get_agent_templates(self):
        """Test retrieving agent templates"""
        try:
            cursor = self.conn.cursor()
            
            cursor.execute("""
                SELECT at.template_name, ats.template_category, ats.complexity_level
                FROM ai_agents.agent_template_h at
                JOIN ai_agents.agent_template_s ats ON at.agent_template_hk = ats.agent_template_hk
                WHERE ats.is_active = true
                AND ats.load_end_date IS NULL
                LIMIT 10
            """)
            
            results = cursor.fetchall()
            
            if results:
                self.log_test("Get Agent Templates", True, {"count": len(results)})
                return True
            else:
                self.log_test("Get Agent Templates", False, "No templates found")
                return False
                
        except Exception as e:
            self.log_test("Get Agent Templates", False, str(e))
            return False
    
    def get_or_create_test_tenant(self):
        """Get or create a test tenant for testing"""
        try:
            cursor = self.conn.cursor()
            
            # Try to find existing test tenant
            cursor.execute("""
                SELECT tenant_hk 
                FROM auth.tenant_h 
                WHERE tenant_bk = 'TEST_TENANT_AI_AGENTS'
                LIMIT 1
            """)
            
            result = cursor.fetchone()
            if result:
                return result[0]
            
            # Create test tenant
            cursor.execute("""
                INSERT INTO auth.tenant_h (tenant_hk, tenant_bk, load_date, record_source)
                VALUES (
                    decode(md5('TEST_TENANT_AI_AGENTS'), 'hex'),
                    'TEST_TENANT_AI_AGENTS',
                    CURRENT_TIMESTAMP,
                    'AI_AGENT_TESTING'
                )
                RETURNING tenant_hk
            """)
            
            result = cursor.fetchone()
            return result[0] if result else None
            
        except Exception as e:
            print(f"Error creating test tenant: {e}")
            return None
    
    def run_all_tests(self):
        """Run comprehensive test suite"""
        print("🧪 Starting AI Agent Database Function Tests")
        print("=" * 50)
        
        if not self.connect():
            return False
        
        # Test 1: Schema and tables
        if not self.test_schema_exists():
            print("❌ Schema missing - run AI agent schema creation first")
            return False
            
        if not self.test_core_tables_exist():
            print("❌ Tables missing - run AI agent table creation first")
            return False
        
        # Test 2: Template operations
        template_hk = self.test_create_agent_template()
        self.test_get_agent_templates()
        
        # Test 3: User agent operations
        agent_hk = self.test_create_user_agent(template_hk)
        self.test_get_user_agents()
        
        # Test 4: Execution
        execution_hk = self.test_execute_user_agent(agent_hk)
        
        # Generate report
        self.generate_report()
        
        return True
    
    def generate_report(self):
        """Generate test report"""
        print("\n" + "=" * 50)
        print("🧪 TEST SUMMARY REPORT")
        print("=" * 50)
        
        total_tests = len(self.test_results)
        passed_tests = sum(1 for test in self.test_results if test['success'])
        failed_tests = total_tests - passed_tests
        
        print(f"Total Tests: {total_tests}")
        print(f"✅ Passed: {passed_tests}")
        print(f"❌ Failed: {failed_tests}")
        print(f"Success Rate: {(passed_tests/total_tests*100):.1f}%")
        
        if failed_tests > 0:
            print("\n❌ FAILED TESTS:")
            for test in self.test_results:
                if not test['success']:
                    print(f"  • {test['test']}: {test['details']}")
        
        # Save detailed results
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        results_file = f"ai_agent_test_results_{timestamp}.json"
        
        with open(results_file, 'w') as f:
            json.dump({
                'summary': {
                    'total_tests': total_tests,
                    'passed_tests': passed_tests,
                    'failed_tests': failed_tests,
                    'success_rate': passed_tests/total_tests*100
                },
                'detailed_results': self.test_results
            }, f, indent=2, default=str)
        
        print(f"\n📄 Detailed results saved to: {results_file}")
        
        if passed_tests == total_tests:
            print("\n🎉 ALL TESTS PASSED! Ready to build APIs.")
        else:
            print(f"\n⚠️  {failed_tests} tests failed. Fix these before building APIs.")

def main():
    """Main function"""
    print("AI Agent Database Function Tester")
    print("Make sure your database is running and AI agent schema is deployed!")
    
    input("Press Enter to continue...")
    
    tester = AIAgentTester()
    tester.run_all_tests()

if __name__ == "__main__":
    main() 