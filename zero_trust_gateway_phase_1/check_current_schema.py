#!/usr/bin/env python3
"""
Check current schema structure of auth.api_token_s table
"""
import os
import psycopg2
from local_config import get_local_config

def check_current_schema():
    """Check what columns currently exist in auth.api_token_s"""
    print("🔍 Current Schema Analysis")
    print("=" * 40)
    
    try:
        config = get_local_config()
        # Use psycopg2 directly with the config
        conn = psycopg2.connect(**config.database.to_dict())
        cursor = conn.cursor()
        
        # Check current table structure
        schema_query = """
        SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default,
            character_maximum_length
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
        AND table_name = 'api_token_s'
        ORDER BY ordinal_position;
        """
        
        cursor.execute(schema_query)
        current_columns = cursor.fetchall()
        
        print("📋 Current auth.api_token_s columns:")
        print("-" * 60)
        for col in current_columns:
            col_name, data_type, nullable, default, max_length = col
            length_info = f"({max_length})" if max_length else ""
            nullable_info = "NULL" if nullable == "YES" else "NOT NULL"
            default_info = f" DEFAULT {default}" if default else ""
            print(f"  {col_name:<25} {data_type}{length_info:<15} {nullable_info}{default_info}")
        
        # Check for required columns from refresh function
        required_columns = [
            'api_token_hk', 'load_date', 'load_end_date', 'hash_diff',
            'token_hash', 'token_type', 'scope', 'expires_at', 'is_revoked',
            'record_source'
        ]
        
        additional_columns = [
            'created_at', 'last_used_at', 'usage_count', 'rate_limit_per_hour',
            'security_level', 'refresh_reason', 'predecessor_token_hk'
        ]
        
        existing_column_names = [col[0] for col in current_columns]
        
        print(f"\n✅ REQUIRED COLUMNS (for basic refresh):")
        print("-" * 50)
        missing_required = []
        for col in required_columns:
            if col in existing_column_names:
                print(f"  ✅ {col}")
            else:
                print(f"  ❌ {col} - MISSING")
                missing_required.append(col)
        
        print(f"\n🔧 ADDITIONAL COLUMNS (for enhanced features):")
        print("-" * 50)
        missing_additional = []
        for col in additional_columns:
            if col in existing_column_names:
                print(f"  ✅ {col}")
            else:
                print(f"  ⚠️  {col} - MISSING")
                missing_additional.append(col)
        
        # Check current token structure
        print(f"\n🔑 CURRENT TOKEN ANALYSIS:")
        print("-" * 30)
        
        token_query = """
        SELECT 
            token_type,
            COUNT(*) as count,
            MIN(expires_at) as earliest_expiry,
            MAX(expires_at) as latest_expiry,
            COUNT(*) FILTER (WHERE expires_at > CURRENT_TIMESTAMP) as active_count
        FROM auth.api_token_s 
        WHERE load_end_date IS NULL
        GROUP BY token_type;
        """
        
        cursor.execute(token_query)
        token_stats = cursor.fetchall()
        
        for stat in token_stats:
            token_type, count, earliest, latest, active = stat
            print(f"  {token_type}: {count} total, {active} active")
            print(f"    Expiry range: {earliest} to {latest}")
        
        # Generate recommendations
        print(f"\n🎯 RECOMMENDATIONS:")
        print("-" * 25)
        
        if missing_required:
            print("  ❌ CRITICAL: Missing required columns for basic refresh!")
            print("     Cannot deploy refresh function without these columns")
            for col in missing_required:
                print(f"     - {col}")
        else:
            print("  ✅ GOOD: All required columns exist for basic refresh")
        
        if missing_additional:
            print("  🔧 OPTIONAL: Missing enhanced feature columns")
            print("     Refresh function will work but with limited features")
            for col in missing_additional:
                print(f"     - {col}")
        else:
            print("  🎉 PERFECT: All enhanced columns exist!")
        
        # Check if we can create a sample token lookup
        print(f"\n🧪 TOKEN LOOKUP TEST:")
        print("-" * 25)
        
        sample_token = 'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e'
        lookup_query = """
        SELECT 
            ath.api_token_hk,
            ats.token_type,
            ats.expires_at,
            EXTRACT(DAY FROM (ats.expires_at - CURRENT_TIMESTAMP)) as days_remaining,
            ats.is_revoked
        FROM auth.api_token_s ats
        JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
        WHERE ats.token_hash = sha256(%s::bytea)
        AND ats.load_end_date IS NULL;
        """
        
        cursor.execute(lookup_query, (sample_token,))
        token_result = cursor.fetchone()
        
        if token_result:
            token_hk, token_type, expires_at, days_remaining, is_revoked = token_result
            print(f"  ✅ Found token: {token_type}")
            print(f"     Expires: {expires_at}")
            print(f"     Days remaining: {days_remaining}")
            print(f"     Revoked: {is_revoked}")
            
            if days_remaining and days_remaining <= 7:
                print(f"  🔄 REFRESH NEEDED: Token expires in {days_remaining} days")
            elif days_remaining:
                print(f"  ✅ TOKEN FRESH: {days_remaining} days remaining")
        else:
            print("  ⚠️  Sample token not found (expected if testing with different token)")
        
        cursor.close()
        conn.close()
        
        return {
            'existing_columns': existing_column_names,
            'missing_required': missing_required,
            'missing_additional': missing_additional,
            'can_do_basic_refresh': len(missing_required) == 0
        }
        
    except Exception as e:
        print(f"❌ Error checking schema: {e}")
        return None

if __name__ == "__main__":
    result = check_current_schema()
    
    if result:
        print(f"\n📊 SUMMARY:")
        print(f"  Current columns: {len(result['existing_columns'])}")
        print(f"  Missing required: {len(result['missing_required'])}")
        print(f"  Missing additional: {len(result['missing_additional'])}")
        print(f"  Basic refresh ready: {'✅ YES' if result['can_do_basic_refresh'] else '❌ NO'}") 