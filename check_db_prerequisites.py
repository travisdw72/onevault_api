import psycopg2
import json
from urllib.parse import urlparse

def check_ai_agents_prerequisites():
    """Check if required database components exist for USER_AGENT_BUILDER_SCHEMA.sql"""
    
    # Database connection parameters
    db_url = 'postgresql://postgres:F00tball@localhost:5432/one_vault'
    
    results = {
        "ai_agents_schema_exists": False,
        "agents_schema_exists": False,
        "util_functions": [],
        "auth_tenant_h_exists": False,
        "required_functions_missing": [],
        "recommendations": []
    }
    
    try:
        # Parse URL to get connection parameters
        parsed = urlparse(db_url)
        conn = psycopg2.connect(
            host=parsed.hostname,
            port=parsed.port,
            database=parsed.path[1:],  # Remove leading slash
            user=parsed.username,
            password=parsed.password
        )
        cursor = conn.cursor()
        
        # Check if ai_agents schema exists
        cursor.execute("""
            SELECT schema_name 
            FROM information_schema.schemata 
            WHERE schema_name = 'ai_agents'
        """)
        ai_agents_exists = cursor.fetchone()
        results["ai_agents_schema_exists"] = bool(ai_agents_exists)
        
        # Check for agents schema (alternative)
        cursor.execute("""
            SELECT schema_name 
            FROM information_schema.schemata 
            WHERE schema_name = 'agents'
        """)
        agents_exists = cursor.fetchone()
        results["agents_schema_exists"] = bool(agents_exists)
        
        # Check utility functions
        required_functions = ['current_load_date', 'hash_binary', 'get_record_source']
        cursor.execute("""
            SELECT routine_name 
            FROM information_schema.routines 
            WHERE routine_schema = 'util'
            AND routine_name IN %s
            ORDER BY routine_name
        """, (tuple(required_functions),))
        
        util_functions = [f[0] for f in cursor.fetchall()]
        results["util_functions"] = util_functions
        
        # Find missing functions
        missing_functions = [f for f in required_functions if f not in util_functions]
        results["required_functions_missing"] = missing_functions
        
        # Check auth.tenant_h table
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'auth' 
            AND table_name = 'tenant_h'
        """)
        tenant_h_exists = cursor.fetchone()
        results["auth_tenant_h_exists"] = bool(tenant_h_exists)
        
        # Generate recommendations
        if not results["ai_agents_schema_exists"]:
            results["recommendations"].append("Need to create 'ai_agents' schema first")
            
        if missing_functions:
            results["recommendations"].append(f"Missing utility functions: {', '.join(missing_functions)}")
            
        if not results["auth_tenant_h_exists"]:
            results["recommendations"].append("Missing auth.tenant_h table - core authentication needs setup")
            
        # Overall assessment
        if not missing_functions and results["auth_tenant_h_exists"]:
            results["recommendations"].append("✅ Core prerequisites met - can proceed with ai_agents schema creation")
        else:
            results["recommendations"].append("❌ Prerequisites missing - need to run foundation scripts first")
        
    except Exception as e:
        results["error"] = str(e)
        results["recommendations"].append(f"Database connection error: {e}")
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()
    
    return results

if __name__ == "__main__":
    results = check_ai_agents_prerequisites()
    print(json.dumps(results, indent=2)) 