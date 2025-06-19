#!/usr/bin/env python3
"""
Investigate Existing Database Objects
=====================================
Proper investigation of existing tracking-related objects to determine
if we can integrate with them instead of avoiding conflicts.
"""

import psycopg2
import getpass
import json
from datetime import datetime

def investigate_existing_objects():
    """Investigate existing objects to understand their purpose"""
    
    print("🔍 INVESTIGATING EXISTING TRACKING OBJECTS")
    print("=" * 60)
    print("Purpose: Understand existing objects to determine integration strategy")
    print(f"Investigation started: {datetime.now()}")
    print()
    
    # Get password securely
    password = getpass.getpass('Enter PostgreSQL password: ')
    
    try:
        # Connect to database
        conn = psycopg2.connect(
            host='localhost',
            port=5432,
            database='one_vault',
            user='postgres',
            password=password
        )
        cursor = conn.cursor()
        
        investigation_results = {}
        
        # 1. Investigate auth.ip_tracking_s
        print("1. 🔐 AUTH.IP_TRACKING_S ANALYSIS:")
        print("-" * 40)
        
        # Get table structure
        cursor.execute("""
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns 
            WHERE table_schema = 'auth' AND table_name = 'ip_tracking_s'
            ORDER BY ordinal_position
        """)
        columns = cursor.fetchall()
        
        if columns:
            print("   Table Structure:")
            for col in columns:
                nullable = "nullable" if col[2] == "YES" else "not null"
                default = f" (default: {col[3]})" if col[3] else ""
                print(f"     - {col[0]}: {col[1]} ({nullable}){default}")
            
            # Check usage
            cursor.execute('SELECT COUNT(*) FROM auth.ip_tracking_s')
            count = cursor.fetchone()[0]
            print(f"   Records in table: {count}")
            
            # Check table comment
            cursor.execute("""
                SELECT obj_description(oid) 
                FROM pg_class 
                WHERE relname = 'ip_tracking_s' AND relnamespace = (
                    SELECT oid FROM pg_namespace WHERE nspname = 'auth'
                )
            """)
            comment = cursor.fetchone()
            if comment and comment[0]:
                print(f"   Purpose: {comment[0]}")
            
            investigation_results['auth.ip_tracking_s'] = {
                'exists': True,
                'purpose': 'Security IP tracking - monitors IP addresses for suspicious activity',
                'records': count,
                'integration_potential': 'HIGH - Could integrate for bot detection and rate limiting'
            }
        else:
            investigation_results['auth.ip_tracking_s'] = {'exists': False}
        
        print()
        
        # 2. Investigate auth.security_tracking_h
        print("2. 🛡️ AUTH.SECURITY_TRACKING_H ANALYSIS:")
        print("-" * 40)
        
        cursor.execute("""
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_schema = 'auth' AND table_name = 'security_tracking_h'
            ORDER BY ordinal_position
        """)
        columns = cursor.fetchall()
        
        if columns:
            print("   Table Structure:")
            for col in columns:
                nullable = "nullable" if col[2] == "YES" else "not null"
                print(f"     - {col[0]}: {col[1]} ({nullable})")
            
            cursor.execute('SELECT COUNT(*) FROM auth.security_tracking_h')
            count = cursor.fetchone()[0]
            print(f"   Records in table: {count}")
            
            # Check table comment
            cursor.execute("""
                SELECT obj_description(oid) 
                FROM pg_class 
                WHERE relname = 'security_tracking_h' AND relnamespace = (
                    SELECT oid FROM pg_namespace WHERE nspname = 'auth'
                )
            """)
            comment = cursor.fetchone()
            if comment and comment[0]:
                print(f"   Purpose: {comment[0]}")
            
            investigation_results['auth.security_tracking_h'] = {
                'exists': True,
                'purpose': 'Security tracking hub - likely for auth security events',
                'records': count,
                'integration_potential': 'MEDIUM - Could use for security event correlation'
            }
        else:
            investigation_results['auth.security_tracking_h'] = {'exists': False}
        
        print()
        
        # 3. Investigate automation.entity_tracking
        print("3. 🤖 AUTOMATION.ENTITY_TRACKING ANALYSIS:")
        print("-" * 40)
        
        cursor.execute("""
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_schema = 'automation' AND table_name = 'entity_tracking'
            ORDER BY ordinal_position
        """)
        columns = cursor.fetchall()
        
        if columns:
            print("   Table Structure:")
            for col in columns:
                nullable = "nullable" if col[2] == "YES" else "not null"
                print(f"     - {col[0]}: {col[1]} ({nullable})")
            
            cursor.execute('SELECT COUNT(*) FROM automation.entity_tracking')
            count = cursor.fetchone()[0]
            print(f"   Records in table: {count}")
            
            investigation_results['automation.entity_tracking'] = {
                'exists': True,
                'purpose': 'Business entity automation tracking',
                'records': count,
                'integration_potential': 'LOW - Different domain (automation vs web tracking)'
            }
        else:
            print("   Table does not exist")
            investigation_results['automation.entity_tracking'] = {'exists': False}
        
        print()
        
        # 4. Investigate util.audit_track_* functions
        print("4. 📊 UTIL.AUDIT_TRACK_* FUNCTIONS ANALYSIS:")
        print("-" * 40)
        
        cursor.execute("""
            SELECT routine_name, routine_type, external_language
            FROM information_schema.routines 
            WHERE routine_schema = 'util' AND routine_name LIKE 'audit_track_%'
            ORDER BY routine_name
        """)
        functions = cursor.fetchall()
        
        if functions:
            print("   Functions Found:")
            function_analysis = {}
            
            for func in functions:
                print(f"     - {func[0]} ({func[1]})")
                
                # Get function purpose from definition
                try:
                    cursor.execute("""
                        SELECT pg_get_functiondef(oid) 
                        FROM pg_proc 
                        WHERE proname = %s AND pronamespace = (
                            SELECT oid FROM pg_namespace WHERE nspname = 'util'
                        )
                    """, (func[0],))
                    definition = cursor.fetchone()
                    
                    if definition:
                        def_lines = definition[0].split('\n')
                        # Look for comment lines to understand purpose
                        purpose = "Data Vault 2.0 audit tracking function"
                        for line in def_lines[:15]:  # Check first 15 lines
                            if '--' in line and ('audit' in line.lower() or 'track' in line.lower()):
                                purpose = line.strip()
                                break
                        
                        function_analysis[func[0]] = {
                            'type': func[1],
                            'purpose': purpose,
                            'integration_potential': 'HIGH - Data Vault 2.0 audit functions'
                        }
                        print(f"       Purpose: {purpose}")
                        
                except Exception as e:
                    print(f"       Could not analyze: {e}")
            
            investigation_results['util.audit_track_functions'] = {
                'exists': True,
                'count': len(functions),
                'functions': function_analysis,
                'integration_potential': 'HIGH - These are Data Vault 2.0 audit functions we should use'
            }
        else:
            print("   No audit_track_* functions found")
            investigation_results['util.audit_track_functions'] = {'exists': False}
        
        print()
        
        # 5. Integration Analysis
        print("5. 💡 INTEGRATION ANALYSIS & RECOMMENDATIONS:")
        print("-" * 50)
        
        recommendations = []
        
        # Analyze auth.ip_tracking_s integration
        if investigation_results.get('auth.ip_tracking_s', {}).get('exists'):
            print("   ✅ AUTH.IP_TRACKING_S:")
            print("     - Purpose: Security IP monitoring (bot detection, rate limiting)")
            print("     - Integration: SHOULD INTEGRATE - Perfect for web tracking security")
            print("     - Action: Use existing table for IP-based security in our API layer")
            recommendations.append("INTEGRATE: Use auth.ip_tracking_s for web tracking security")
        
        # Analyze security_tracking_h
        if investigation_results.get('auth.security_tracking_h', {}).get('exists'):
            print("   ✅ AUTH.SECURITY_TRACKING_H:")
            print("     - Purpose: Security event hub")
            print("     - Integration: SHOULD INTEGRATE - Use for security events")
            print("     - Action: Reference this hub for security-related tracking events")
            recommendations.append("INTEGRATE: Use auth.security_tracking_h for security events")
        
        # Analyze util.audit_track_* functions
        if investigation_results.get('util.audit_track_functions', {}).get('exists'):
            print("   ✅ UTIL.AUDIT_TRACK_* FUNCTIONS:")
            print("     - Purpose: Data Vault 2.0 standardized audit functions")
            print("     - Integration: MUST USE - These are our audit standards")
            print("     - Action: Use these functions in our tracking implementation")
            recommendations.append("USE: util.audit_track_* functions are our audit standards")
        
        # Analyze automation.entity_tracking
        if investigation_results.get('automation.entity_tracking', {}).get('exists'):
            print("   ⚠️ AUTOMATION.ENTITY_TRACKING:")
            print("     - Purpose: Business automation tracking (different domain)")
            print("     - Integration: AVOID CONFLICT - Different purpose")
            print("     - Action: Keep our web tracking separate")
            recommendations.append("SEPARATE: automation.entity_tracking is different domain")
        
        print()
        print("📋 FINAL RECOMMENDATIONS:")
        print("-" * 30)
        for i, rec in enumerate(recommendations, 1):
            print(f"   {i}. {rec}")
        
        # Save investigation results
        investigation_results['recommendations'] = recommendations
        investigation_results['investigation_date'] = datetime.now().isoformat()
        
        with open('existing_objects_investigation.json', 'w') as f:
            json.dump(investigation_results, f, indent=2, default=str)
        
        print()
        print("📁 Investigation results saved to: existing_objects_investigation.json")
        
        cursor.close()
        conn.close()
        
        return investigation_results
        
    except Exception as e:
        print(f"❌ Error during investigation: {e}")
        return None

if __name__ == "__main__":
    results = investigate_existing_objects()
    if results:
        print()
        print("🎯 INVESTIGATION COMPLETE!")
        print("Next step: Update scripts based on integration recommendations")
    else:
        print("❌ Investigation failed - check database connection") 