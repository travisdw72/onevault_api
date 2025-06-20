#!/usr/bin/env python3
"""
Enhanced Features Check Script
Checks for step 6a (zero trust templates) and step 7a (augmented learning) implementations
"""

import psycopg2
import psycopg2.extras
import getpass
import json

def check_enhanced_features():
    try:
        print("🔍 Enhanced Features Analysis")
        print("="*50)
        
        # Connect to database
        password = getpass.getpass("Enter PostgreSQL password: ")
        conn = psycopg2.connect(
            host="localhost",
            port=5432,
            database="one_vault",
            user="postgres",
            password=password
        )
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        # Check for Step 6a - Zero Trust Agent Templates
        print("\n📋 STEP 6A: Zero Trust Agent Templates")
        print("-" * 40)
        
        template_tables = [
            'agent_template_h', 'agent_template_s', 
            'zero_trust_execution_log'
        ]
        
        template_functions = [
            'deploy_zero_trust_agent_from_template',
            'execute_zero_trust_agent'
        ]
        
        for table in template_tables:
            cursor.execute(f"""
                SELECT COUNT(*) as count 
                FROM information_schema.tables 
                WHERE table_schema = 'ai_agents' AND table_name = '{table}'
            """)
            result = cursor.fetchone()
            status = "✅ EXISTS" if result['count'] > 0 else "❌ MISSING"
            print(f"  {table}: {status}")
        
        for func in template_functions:
            cursor.execute(f"""
                SELECT COUNT(*) as count 
                FROM information_schema.routines 
                WHERE routine_schema = 'ai_agents' AND routine_name = '{func}'
            """)
            result = cursor.fetchone()
            status = "✅ EXISTS" if result['count'] > 0 else "❌ MISSING"
            print(f"  {func}: {status}")
        
        # Check for Step 7a - Augmented Learning Integration
        print("\n🧠 STEP 7A: Augmented Learning Integration")
        print("-" * 40)
        
        learning_tables = [
            'agent_learning_session_h', 'agent_learning_session_s'
        ]
        
        learning_functions = [
            'execute_agent_with_learning',
            'process_agent_feedback',
            'apply_cross_domain_learning',
            'validate_learning_integration'
        ]
        
        for table in learning_tables:
            cursor.execute(f"""
                SELECT COUNT(*) as count 
                FROM information_schema.tables 
                WHERE table_schema = 'ai_agents' AND table_name = '{table}'
            """)
            result = cursor.fetchone()
            status = "✅ EXISTS" if result['count'] > 0 else "❌ MISSING"
            print(f"  {table}: {status}")
        
        for func in learning_functions:
            cursor.execute(f"""
                SELECT COUNT(*) as count 
                FROM information_schema.routines 
                WHERE routine_schema = 'ai_agents' AND routine_name = '{func}'
            """)
            result = cursor.fetchone()
            status = "✅ EXISTS" if result['count'] > 0 else "❌ MISSING"
            print(f"  {func}: {status}")
        
        # Check USER_AGENT_BUILDER functions 
        print("\n👤 USER AGENT BUILDER SYSTEM")
        print("-" * 40)
        
        builder_functions = [
            'create_user_agent', 'create_agent_identity', 
            'assign_agent_to_domain', 'validate_agent_identity'
        ]
        
        for func in builder_functions:
            cursor.execute(f"""
                SELECT COUNT(*) as count 
                FROM information_schema.routines 
                WHERE routine_schema = 'ai_agents' AND routine_name = '{func}'
            """)
            result = cursor.fetchone()
            status = "✅ EXISTS" if result['count'] > 0 else "❌ MISSING"
            print(f"  {func}: {status}")
        
        # Summary
        print("\n📊 SUMMARY")
        print("="*50)
        
        # Test one function to see if it actually works
        try:
            cursor.execute("SELECT ai_agents.medical_diagnosis_reasoning('test input')")
            print("✅ Core AI functions are WORKING")
        except Exception as e:
            print(f"⚠️ Core AI functions test failed: {str(e)[:100]}...")
        
        conn.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    check_enhanced_features() 