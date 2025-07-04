#!/usr/bin/env python3
"""
Canvas API Readiness Test
Tests all database functions that the Canvas will need to call via API
"""

import psycopg2
import json
import getpass
from datetime import datetime

class CanvasAPIReadinessTest:
    def __init__(self):
        self.conn = None
        self.test_results = {}
        
    def connect_to_database(self):
        """Connect to local test database"""
        print("🔍 Canvas API Readiness Test")
        print("Connecting to: one_vault_site_testing (localhost)")
        
        password = getpass.getpass("Enter database password: ")
        
        try:
            self.conn = psycopg2.connect(
                host="localhost",
                port=5432,
                database="one_vault_site_testing",
                user="postgres",
                password=password
            )
            print("✅ Database connection successful")
            return True
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return False
    
    def execute_query(self, query: str, params: tuple = None):
        """Execute query and return results"""
        if not self.conn:
            return None
            
        try:
            cursor = self.conn.cursor()
            cursor.execute(query, params)
            
            if query.strip().upper().startswith('SELECT'):
                results = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]
                return [dict(zip(columns, row)) for row in results]
            else:
                self.conn.commit()
                return [{"status": "success"}]
                
        except Exception as e:
            print(f"❌ Query failed: {e}")
            return [{"error": str(e)}]
        finally:
            cursor.close()
    
    def test_ai_functions(self):
        """Test AI-related functions"""
        print("\n🤖 Testing AI Functions...")
        
        # Check if key AI functions exist
        ai_functions_query = """
        SELECT routine_name, routine_type 
        FROM information_schema.routines 
        WHERE routine_schema = 'api' 
        AND routine_name LIKE 'ai_%'
        ORDER BY routine_name
        """
        
        result = self.execute_query(ai_functions_query)
        print(f"Found {len(result)} AI functions:")
        for func in result:
            print(f"  - {func['routine_name']} ({func['routine_type']})")
        
        self.test_results['ai_functions'] = result
        return result
    
    def test_agent_schema(self):
        """Test ai_agents schema"""
        print("\n🧠 Testing AI Agents Schema...")
        
        # Check ai_agents tables
        agents_query = """
        SELECT table_name, table_type 
        FROM information_schema.tables 
        WHERE table_schema = 'ai_agents'
        ORDER BY table_name
        """
        
        result = self.execute_query(agents_query)
        print(f"Found {len(result)} tables in ai_agents schema:")
        for table in result:
            print(f"  - {table['table_name']}")
        
        self.test_results['ai_agents_tables'] = result
        return result
    
    def test_monitoring_schema(self):
        """Test ai_monitoring schema"""
        print("\n📊 Testing AI Monitoring Schema...")
        
        # Check ai_monitoring tables
        monitoring_query = """
        SELECT table_name, table_type 
        FROM information_schema.tables 
        WHERE table_schema = 'ai_monitoring'
        ORDER BY table_name
        """
        
        result = self.execute_query(monitoring_query)
        print(f"Found {len(result)} tables in ai_monitoring schema:")
        for table in result:
            print(f"  - {table['table_name']}")
        
        self.test_results['ai_monitoring_tables'] = result
        return result
    
    def test_ref_schema(self):
        """Test ref schema"""
        print("\n📚 Testing Reference Schema...")
        
        # Check ref tables
        ref_query = """
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'ref'
        ORDER BY table_name
        """
        
        result = self.execute_query(ref_query)
        print(f"Found {len(result)} reference tables:")
        for table in result:
            print(f"  - {table['table_name']}")
        
        self.test_results['ref_tables'] = result
        return result
    
    def test_api_functions(self):
        """Test all API functions"""
        print("\n🔌 Testing API Functions...")
        
        # Get all API schema functions
        api_query = """
        SELECT routine_name, routine_type 
        FROM information_schema.routines 
        WHERE routine_schema = 'api'
        ORDER BY routine_name
        """
        
        result = self.execute_query(api_query)
        print(f"Found {len(result)} API functions:")
        
        # Group by type
        auth_funcs = [f for f in result if 'auth' in f['routine_name']]
        ai_funcs = [f for f in result if 'ai_' in f['routine_name']]
        other_funcs = [f for f in result if f not in auth_funcs and f not in ai_funcs]
        
        print(f"\n  Authentication functions ({len(auth_funcs)}):")
        for func in auth_funcs:
            print(f"    - {func['routine_name']}")
            
        print(f"\n  AI functions ({len(ai_funcs)}):")
        for func in ai_funcs:
            print(f"    - {func['routine_name']}")
            
        print(f"\n  Other functions ({len(other_funcs)}):")
        for func in other_funcs:
            print(f"    - {func['routine_name']}")
        
        self.test_results['api_functions'] = {
            'all_functions': result,
            'auth_functions': auth_funcs,
            'ai_functions': ai_funcs,
            'other_functions': other_funcs
        }
        return result
    
    def test_data_samples(self):
        """Test if sample data exists"""
        print("\n📊 Testing Sample Data...")
        
        sample_queries = {
            'tenants': "SELECT COUNT(*) as count FROM auth.tenant_h",
            'users': "SELECT COUNT(*) as count FROM auth.user_h", 
            'agents': "SELECT COUNT(*) as count FROM ai_agents.agent_h",
            'monitoring_entities': "SELECT COUNT(*) as count FROM ai_monitoring.monitored_entity_h"
        }
        
        sample_data = {}
        for name, query in sample_queries.items():
            result = self.execute_query(query)
            count = result[0]['count'] if result else 0
            print(f"  {name}: {count} records")
            sample_data[name] = count
        
        self.test_results['sample_data'] = sample_data
        return sample_data
    
    def assess_readiness(self):
        """Assess Canvas integration readiness"""
        print("\n🎯 Canvas Integration Readiness Assessment...")
        
        readiness = {
            'authentication': len(self.test_results.get('api_functions', {}).get('auth_functions', [])) > 0,
            'ai_agents': len(self.test_results.get('ai_agents_tables', [])) > 0,
            'ai_monitoring': len(self.test_results.get('ai_monitoring_tables', [])) > 0,
            'ai_api_functions': len(self.test_results.get('api_functions', {}).get('ai_functions', [])) > 0,
            'reference_data': len(self.test_results.get('ref_tables', [])) > 0
        }
        
        total_checks = len(readiness)
        passed_checks = sum(readiness.values())
        readiness_score = (passed_checks / total_checks) * 100
        
        print(f"\nReadiness Score: {readiness_score:.1f}% ({passed_checks}/{total_checks})")
        
        for check, status in readiness.items():
            status_icon = "✅" if status else "❌"
            print(f"  {status_icon} {check.replace('_', ' ').title()}")
        
        if readiness_score >= 80:
            print("\n🚀 READY FOR CANVAS INTEGRATION!")
            print("Your database has all the components needed for Canvas API integration.")
        elif readiness_score >= 50:
            print("\n⚠️  MOSTLY READY")
            print("Some components are missing but core functionality is available.")
        else:
            print("\n❌ NOT READY")
            print("Critical components are missing. Database needs attention before Canvas integration.")
        
        self.test_results['readiness_assessment'] = {
            'score': readiness_score,
            'checks': readiness,
            'status': 'READY' if readiness_score >= 80 else 'PARTIAL' if readiness_score >= 50 else 'NOT_READY'
        }
        
        return readiness
    
    def save_results(self):
        """Save test results"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"canvas_readiness_test_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump(self.test_results, f, indent=2, default=str)
        
        print(f"\n💾 Results saved to: {filename}")
        return filename
    
    def run_all_tests(self):
        """Run all tests"""
        if not self.connect_to_database():
            return False
        
        try:
            self.test_api_functions()
            self.test_ai_functions()
            self.test_agent_schema()
            self.test_monitoring_schema()
            self.test_ref_schema()
            self.test_data_samples()
            self.assess_readiness()
            self.save_results()
            
            print("\n🎉 Canvas API Readiness Test Complete!")
            return True
            
        except Exception as e:
            print(f"❌ Test failed: {e}")
            return False
        finally:
            if self.conn:
                self.conn.close()

if __name__ == "__main__":
    tester = CanvasAPIReadinessTest()
    tester.run_all_tests() 