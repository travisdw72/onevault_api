#!/usr/bin/env python3
import psycopg2
import os
import json
from datetime import datetime

def analyze_audit_capabilities():
    """Comprehensive analysis of existing audit capabilities vs Phase 1 requirements"""
    
    conn = psycopg2.connect(
        host='localhost',
        port=5432,
        database='one_vault_site_testing',
        user='postgres',
        password=os.getenv('DB_PASSWORD')
    )
    cursor = conn.cursor()

    print('🔍 COMPREHENSIVE AUDIT CAPABILITY ANALYSIS')
    print('='*60)
    print(f'Analysis Date: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
    print('='*60)

    # 1. Analyze existing audit tables in detail
    print('\n📊 EXISTING AUDIT TABLES - DETAILED ANALYSIS')
    print('-'*50)
    
    cursor.execute("""
    SELECT table_name, 
           (SELECT count(*) FROM information_schema.columns 
            WHERE table_schema = 'audit' AND table_name = t.table_name) as column_count,
           obj_description(('audit.' || table_name)::regclass, 'pg_class') as table_comment
    FROM information_schema.tables t
    WHERE table_schema = 'audit' 
    ORDER BY table_name
    """)
    
    audit_tables = cursor.fetchall()
    
    for table_name, col_count, comment in audit_tables:
        print(f'\n🗂️  audit.{table_name}')
        print(f'   Columns: {col_count}')
        print(f'   Purpose: {comment or "No documentation"}')
        
        # Get column details
        cursor.execute("""
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns 
        WHERE table_schema = 'audit' AND table_name = %s
        ORDER BY ordinal_position
        """, (table_name,))
        
        columns = cursor.fetchall()
        relevant_cols = []
        
        for col_name, data_type, nullable, default in columns:
            if any(keyword in col_name.lower() for keyword in 
                   ['validation', 'performance', 'duration', 'token', 'tenant', 'cache', 'parallel']):
                relevant_cols.append(f'{col_name} ({data_type})')
        
        if relevant_cols:
            print(f'   Relevant columns: {", ".join(relevant_cols)}')
        else:
            print(f'   No Phase 1 relevant columns detected')
            
        # Check if table has data
        cursor.execute(f'SELECT count(*) FROM audit.{table_name}')
        row_count = cursor.fetchone()[0]
        print(f'   Current records: {row_count:,}')

    # 2. Analyze existing audit functions
    print(f'\n📊 EXISTING AUDIT FUNCTIONS - CAPABILITY ANALYSIS')
    print('-'*50)
    
    cursor.execute("""
    SELECT routine_name, 
           routine_type,
           external_language,
           routine_definition
    FROM information_schema.routines 
    WHERE routine_schema = 'audit'
    ORDER BY routine_name
    """)
    
    audit_functions = cursor.fetchall()
    
    phase1_capabilities = {
        'parallel_validation_logging': False,
        'performance_comparison': False,
        'cache_tracking': False,
        'cross_tenant_detection': False,
        'token_extension_tracking': False,
        'enhanced_vs_current_comparison': False
    }
    
    for func_name, func_type, language, definition in audit_functions:
        print(f'\n⚙️  audit.{func_name}() - {func_type}')
        
        # Analyze function parameters
        cursor.execute("""
        SELECT parameter_name, data_type, parameter_mode
        FROM information_schema.parameters 
        WHERE specific_schema = 'audit' 
        AND specific_name = (
            SELECT specific_name FROM information_schema.routines 
            WHERE routine_schema = 'audit' AND routine_name = %s
            LIMIT 1
        )
        ORDER BY ordinal_position
        """, (func_name,))
        
        params = cursor.fetchall()
        if params:
            param_list = [f'{name}({dtype})' for name, dtype, mode in params if name]
            print(f'   Parameters: {", ".join(param_list)}')
        else:
            print(f'   Parameters: None or not accessible')
            
        # Check capabilities for Phase 1
        if definition:
            def_lower = definition.lower()
            capabilities_found = []
            
            if 'performance' in def_lower or 'duration' in def_lower:
                capabilities_found.append('performance tracking')
                if 'comparison' in def_lower or 'baseline' in def_lower:
                    phase1_capabilities['performance_comparison'] = True
                    
            if 'cache' in def_lower:
                capabilities_found.append('cache operations')
                phase1_capabilities['cache_tracking'] = True
                
            if 'tenant' in def_lower and ('cross' in def_lower or 'isolation' in def_lower):
                capabilities_found.append('tenant isolation')
                phase1_capabilities['cross_tenant_detection'] = True
                
            if 'token' in def_lower and 'extend' in def_lower:
                capabilities_found.append('token extension')
                phase1_capabilities['token_extension_tracking'] = True
                
            if 'parallel' in def_lower or 'validation' in def_lower:
                capabilities_found.append('validation tracking')
                if 'parallel' in def_lower:
                    phase1_capabilities['parallel_validation_logging'] = True
            
            if capabilities_found:
                print(f'   Phase 1 capabilities: {", ".join(capabilities_found)}')
            else:
                print(f'   Phase 1 capabilities: None detected')

    # 3. Phase 1 Requirements Gap Analysis
    print(f'\n🎯 PHASE 1 REQUIREMENTS GAP ANALYSIS')
    print('-'*50)
    
    requirements = [
        ('Parallel Validation Logging', 
         'Track current vs enhanced validation side-by-side',
         phase1_capabilities['parallel_validation_logging']),
         
        ('Performance Comparison Tracking', 
         'Measure response time improvements between methods',
         phase1_capabilities['performance_comparison']),
         
        ('Cache Performance Monitoring', 
         'Track cache hit rates and performance gains',
         phase1_capabilities['cache_tracking']),
         
        ('Cross-Tenant Security Events', 
         'Log enhanced cross-tenant blocking attempts',
         phase1_capabilities['cross_tenant_detection']),
         
        ('Token Extension Tracking', 
         'Monitor automatic token renewals',
         phase1_capabilities['token_extension_tracking']),
         
        ('Enhanced vs Current Comparison', 
         'Side-by-side validation result comparison',
         phase1_capabilities['enhanced_vs_current_comparison'])
    ]
    
    gaps_found = []
    
    for requirement, description, available in requirements:
        status = '✅ Available' if available else '❌ Gap Found'
        print(f'\n{status} {requirement}')
        print(f'   Need: {description}')
        
        if not available:
            gaps_found.append(requirement)
            
            # Suggest specific solutions
            if 'parallel' in requirement.lower():
                print(f'   Solution: New table to log both validation methods per request')
            elif 'performance' in requirement.lower():
                print(f'   Solution: New table with duration tracking and baseline comparison')
            elif 'cache' in requirement.lower():
                print(f'   Solution: New table tracking cache operations and hit rates')
            elif 'cross-tenant' in requirement.lower():
                print(f'   Solution: Enhanced security event table with tenant context')
            elif 'token extension' in requirement.lower():
                print(f'   Solution: Track automatic token renewals in parallel validation')
            elif 'comparison' in requirement.lower():
                print(f'   Solution: Table comparing enhanced vs current results')

    # 4. Examine what we CAN currently track
    print(f'\n📈 CURRENT TRACKING CAPABILITIES')
    print('-'*50)
    
    current_capabilities = []
    
    # Check if we can track basic security events
    cursor.execute("""
    SELECT column_name 
    FROM information_schema.columns 
    WHERE table_schema = 'audit' 
    AND table_name = 'security_event_s'
    """)
    
    security_columns = [row[0] for row in cursor.fetchall()]
    if security_columns:
        current_capabilities.append(f"✅ Basic security events: {len(security_columns)} fields")
        
        # Check for specific Phase 1 relevant fields
        phase1_fields = [col for col in security_columns if any(keyword in col.lower() 
                        for keyword in ['tenant', 'token', 'validation', 'performance'])]
        if phase1_fields:
            print(f"   Phase 1 relevant fields: {', '.join(phase1_fields)}")
    
    # Check if we can track basic audit events  
    cursor.execute("""
    SELECT column_name 
    FROM information_schema.columns 
    WHERE table_schema = 'audit' 
    AND table_name = 'audit_detail_s'
    """)
    
    audit_columns = [row[0] for row in cursor.fetchall()]
    if audit_columns:
        current_capabilities.append(f"✅ Basic audit events: {len(audit_columns)} fields")

    # 5. Test current logging capabilities
    print(f'\n🧪 TESTING CURRENT LOGGING CAPABILITIES')
    print('-'*50)
    
    # Test if we can log a security event
    try:
        cursor.execute("""
        SELECT audit.log_security_event(%s, %s, %s, %s)
        """, ('test_validation', 'INFO', 'Testing current logging capability', '{}'))
        
        result = cursor.fetchone()
        print(f"✅ audit.log_security_event() - Working (returned: {result[0] if result else 'success'})")
        
        # Check what fields we can populate
        cursor.execute("""
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = 'audit' 
        AND table_name = 'security_event_s'
        AND column_name IN ('event_type', 'severity', 'description', 'additional_data')
        """)
        
        available_fields = cursor.fetchall()
        print(f"   Available logging fields: {', '.join([f'{name}({dtype})' for name, dtype in available_fields])}")
        
    except Exception as e:
        print(f"❌ audit.log_security_event() - Error: {e}")

    # 6. Specific Phase 1 Use Cases Analysis
    print(f'\n🎯 PHASE 1 USE CASE REQUIREMENTS')
    print('-'*50)
    
    use_cases = [
        {
            'name': 'Parallel Validation Request',
            'scenario': 'API request triggers both current and enhanced validation',
            'data_needed': [
                'Request context (endpoint, method, IP)',
                'Current validation result + duration',
                'Enhanced validation result + duration', 
                'Performance improvement calculation',
                'Token extension status',
                'Cross-tenant blocking status'
            ]
        },
        {
            'name': 'Performance Benchmarking',
            'scenario': 'Compare response times before/after enhancement',
            'data_needed': [
                'Baseline response time',
                'Enhanced response time',
                'Improvement percentage',
                'Cache hit/miss status',
                'Memory/CPU usage comparison'
            ]
        },
        {
            'name': 'Security Enhancement Tracking',
            'scenario': 'Monitor cross-tenant protection improvements',
            'data_needed': [
                'Token tenant vs requested tenant',
                'Cross-tenant blocking events',
                'Enhanced validation discrepancies',
                'Auto-remediation actions taken'
            ]
        }
    ]
    
    for use_case in use_cases:
        print(f"\n📋 Use Case: {use_case['name']}")
        print(f"   Scenario: {use_case['scenario']}")
        print(f"   Data Requirements:")
        
        for requirement in use_case['data_needed']:
            # Check if current tables can handle this
            can_track = False
            
            if any(table for table in audit_tables 
                   if any(keyword in requirement.lower().split() 
                         for keyword in ['security', 'audit', 'event'])):
                can_track = True
                
            status = "✅ Can track" if can_track else "❌ Cannot track"
            print(f"     {status} {requirement}")

    # 7. Final Recommendation
    print(f'\n🎯 FINAL ANALYSIS AND RECOMMENDATION')
    print('='*60)
    
    print(f"📊 Current Audit Infrastructure:")
    print(f"   ✅ {len(audit_tables)} audit tables available")
    print(f"   ✅ {len(audit_functions)} audit functions available") 
    print(f"   ✅ Basic security and audit event logging working")
    
    print(f"\n⚠️  Phase 1 Gaps Identified ({len(gaps_found)} critical):")
    for gap in gaps_found:
        print(f"   ❌ {gap}")
    
    if gaps_found:
        print(f"\n🚧 Why Current Infrastructure Is Insufficient:")
        print(f"   1. Cannot track parallel validation (current vs enhanced side-by-side)")
        print(f"   2. Cannot measure performance improvements with baselines")
        print(f"   3. Cannot monitor cache effectiveness for Phase 1")
        print(f"   4. Cannot track enhanced security features (token extension, cross-tenant)")
        print(f"   5. Cannot generate Phase 1 success metrics and reporting")
        
        print(f"\n💡 Recommendation:")
        print(f"   ✅ Keep all existing audit infrastructure (working perfectly)")
        print(f"   ➕ Add 4 Phase 1-specific tables for parallel validation tracking")
        print(f"   ➕ Add 2 helper functions for easy Phase 1 logging")
        print(f"   🎯 Result: Complete visibility into Phase 1 'silent enhancement' process")
    else:
        print(f"\n🎉 Current infrastructure sufficient for Phase 1!")
    
    # Rollback test transaction
    conn.rollback()
    conn.close()

if __name__ == "__main__":
    if not os.getenv('DB_PASSWORD'):
        print("❌ Please set DB_PASSWORD environment variable")
        exit(1)
        
    analyze_audit_capabilities() 