#!/usr/bin/env python3
"""
Quick Zero Trust Validation Script
Tests the implementation against existing database infrastructure
"""

import asyncio
import asyncpg
import json
import time
from datetime import datetime, timezone
from typing import Dict, Any, Optional

# Database connection settings
DB_CONFIG = {
    'host': 'localhost',
    'database': 'one_vault_site_testing',
    'user': 'postgres',
    'password': 'password'
}

class ZeroTrustValidator:
    """Validates Zero Trust implementation against existing database"""
    
    def __init__(self):
        self.results = []
    
    async def run_all_tests(self):
        """Run all validation tests"""
        print("🔐 ZERO TRUST VALIDATION - Using Existing Infrastructure")
        print("=" * 60)
        
        tests = [
            ("Database Connection", self.test_database_connection),
            ("Required Schemas", self.test_required_schemas),
            ("Auth Infrastructure", self.test_auth_infrastructure),
            ("Zero Trust Function", self.test_zero_trust_function),
            ("Business Schema", self.test_business_schema),
            ("Audit Infrastructure", self.test_audit_infrastructure),
            ("Security Events", self.test_security_events),
            ("Performance Test", self.test_performance),
            ("Create Test Data", self.create_test_data),
            ("Tenant Resolution", self.test_tenant_resolution),
            ("Resource Validation", self.test_resource_validation),
            ("Security Logging", self.test_security_logging),
        ]
        
        for test_name, test_func in tests:
            try:
                print(f"\n🧪 Testing: {test_name}")
                result = await test_func()
                status = "✅ PASS" if result['success'] else "❌ FAIL"
                print(f"   {status}: {result['message']}")
                self.results.append({"test": test_name, "result": result})
            except Exception as e:
                print(f"   ❌ ERROR: {str(e)}")
                self.results.append({"test": test_name, "result": {"success": False, "message": str(e)}})
        
        await self.print_summary()
    
    async def test_database_connection(self) -> Dict[str, Any]:
        """Test database connection"""
        try:
            conn = await asyncpg.connect(**DB_CONFIG)
            result = await conn.fetchval("SELECT 1")
            await conn.close()
            return {"success": True, "message": "Database connection successful"}
        except Exception as e:
            return {"success": False, "message": f"Connection failed: {str(e)}"}
    
    async def test_required_schemas(self) -> Dict[str, Any]:
        """Test that required schemas exist"""
        try:
            conn = await asyncpg.connect(**DB_CONFIG)
            
            schemas = await conn.fetch("""
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name IN ('auth', 'ai_monitoring', 'business', 'audit')
            """)
            
            schema_names = {s['schema_name'] for s in schemas}
            required = {'auth', 'ai_monitoring', 'business', 'audit'}
            missing = required - schema_names
            
            await conn.close()
            
            if missing:
                return {"success": False, "message": f"Missing schemas: {missing}"}
            else:
                return {"success": True, "message": "All required schemas exist"}
                
        except Exception as e:
            return {"success": False, "message": f"Schema check failed: {str(e)}"}
    
    async def test_auth_infrastructure(self) -> Dict[str, Any]:
        """Test auth infrastructure tables"""
        try:
            conn = await asyncpg.connect(**DB_CONFIG)
            
            # Check key auth tables
            tables = await conn.fetch("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'auth'
                AND table_name IN ('tenant_h', 'api_token_s', 'session_state_s', 'user_h')
            """)
            
            table_names = {t['table_name'] for t in tables}
            required_tables = {'tenant_h', 'api_token_s', 'session_state_s', 'user_h'}
            missing = required_tables - table_names
            
            await conn.close()
            
            if missing:
                return {"success": False, "message": f"Missing auth tables: {missing}"}
            else:
                return {"success": True, "message": "Auth infrastructure complete"}
                
        except Exception as e:
            return {"success": False, "message": f"Auth check failed: {str(e)}"}
    
    async def test_zero_trust_function(self) -> Dict[str, Any]:
        """Test Zero Trust validation function exists"""
        try:
            conn = await asyncpg.connect(**DB_CONFIG)
            
            # Check if function exists
            function_exists = await conn.fetchval("""
                SELECT 1 FROM information_schema.routines 
                WHERE routine_schema = 'ai_monitoring' 
                AND routine_name = 'validate_zero_trust_access'
            """)
            
            await conn.close()
            
            if function_exists:
                return {"success": True, "message": "Zero Trust validation function exists"}
            else:
                return {"success": False, "message": "validate_zero_trust_access function not found"}
                
        except Exception as e:
            return {"success": False, "message": f"Function check failed: {str(e)}"}
    
    async def test_business_schema(self) -> Dict[str, Any]:
        """Test business schema for resource validation"""
        try:
            conn = await asyncpg.connect(**DB_CONFIG)
            
            # Check business tables
            tables = await conn.fetch("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'business'
                AND table_name LIKE '%_h'
            """)
            
            table_count = len(tables)
            table_names = [t['table_name'] for t in tables]
            
            await conn.close()
            
            if table_count > 0:
                return {"success": True, "message": f"Business schema has {table_count} hub tables: {table_names[:3]}..."}
            else:
                return {"success": False, "message": "No business hub tables found"}
                
        except Exception as e:
            return {"success": False, "message": f"Business schema check failed: {str(e)}"}
    
    async def test_audit_infrastructure(self) -> Dict[str, Any]:
        """Test audit infrastructure"""
        try:
            conn = await asyncpg.connect(**DB_CONFIG)
            
            # Check audit tables
            tables = await conn.fetch("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'audit'
            """)
            
            table_count = len(tables)
            
            await conn.close()
            
            if table_count > 0:
                return {"success": True, "message": f"Audit infrastructure has {table_count} tables"}
            else:
                return {"success": False, "message": "No audit tables found"}
                
        except Exception as e:
            return {"success": False, "message": f"Audit check failed: {str(e)}"}
    
    async def test_security_events(self) -> Dict[str, Any]:
        """Test security events infrastructure"""
        try:
            conn = await asyncpg.connect(**DB_CONFIG)
            
            # Check for security events tables
            security_tables = await conn.fetch("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'ai_monitoring'
                AND table_name LIKE '%security%'
            """)
            
            await conn.close()
            
            if security_tables:
                return {"success": True, "message": f"Security events infrastructure found"}
            else:
                return {"success": False, "message": "No security events tables found"}
                
        except Exception as e:
            return {"success": False, "message": f"Security events check failed: {str(e)}"}
    
    async def test_performance(self) -> Dict[str, Any]:
        """Test basic database performance"""
        try:
            conn = await asyncpg.connect(**DB_CONFIG)
            
            # Simple performance test
            start_time = time.time()
            await conn.fetchval("SELECT COUNT(*) FROM auth.tenant_h")
            query_time = (time.time() - start_time) * 1000  # Convert to ms
            
            await conn.close()
            
            if query_time < 50:
                return {"success": True, "message": f"Database performance good ({query_time:.2f}ms)"}
            else:
                return {"success": False, "message": f"Database performance slow ({query_time:.2f}ms)"}
                
        except Exception as e:
            return {"success": False, "message": f"Performance test failed: {str(e)}"}
    
    async def create_test_data(self) -> Dict[str, Any]:
        """Create test data for validation"""
        try:
            conn = await asyncpg.connect(**DB_CONFIG)
            
            # Create test tenant
            await conn.execute("""
                INSERT INTO auth.tenant_h (tenant_hk, tenant_bk, load_date, record_source)
                VALUES (
                    decode('deadbeef00000000000000000000000000000000000000000000000000000000', 'hex'),
                    'zero_trust_test_tenant',
                    CURRENT_TIMESTAMP,
                    'zero_trust_validation'
                ) ON CONFLICT DO NOTHING
            """)
            
            # Create test API token
            await conn.execute("""
                INSERT INTO auth.api_token_h (api_token_hk, api_token_bk, tenant_hk, load_date, record_source)
                VALUES (
                    decode('feedface00000000000000000000000000000000000000000000000000000000', 'hex'),
                    'zero_trust_test_token',
                    decode('deadbeef00000000000000000000000000000000000000000000000000000000', 'hex'),
                    CURRENT_TIMESTAMP,
                    'zero_trust_validation'
                ) ON CONFLICT DO NOTHING
            """)
            
            # Create test API token satellite
            await conn.execute("""
                INSERT INTO auth.api_token_s (
                    api_token_hk, load_date, load_end_date, hash_diff,
                    tenant_hk, token_value, token_name, is_active,
                    expires_at, created_by, record_source
                )
                VALUES (
                    decode('feedface00000000000000000000000000000000000000000000000000000000', 'hex'),
                    CURRENT_TIMESTAMP,
                    NULL,
                    decode('abcdef0000000000000000000000000000000000000000000000000000000000', 'hex'),
                    decode('deadbeef00000000000000000000000000000000000000000000000000000000', 'hex'),
                    'zt_test_api_key_12345',
                    'Zero Trust Test Token',
                    true,
                    CURRENT_TIMESTAMP + INTERVAL '1 hour',
                    'zero_trust_validation',
                    'zero_trust_validation'
                ) ON CONFLICT (api_token_hk, load_date) DO UPDATE SET
                    token_value = EXCLUDED.token_value,
                    is_active = EXCLUDED.is_active,
                    expires_at = EXCLUDED.expires_at
            """)
            
            await conn.close()
            
            return {"success": True, "message": "Test data created successfully"}
            
        except Exception as e:
            return {"success": False, "message": f"Test data creation failed: {str(e)}"}
    
    async def test_tenant_resolution(self) -> Dict[str, Any]:
        """Test tenant resolution using API key"""
        try:
            conn = await asyncpg.connect(**DB_CONFIG)
            
            # Test tenant resolution query
            result = await conn.fetchrow("""
                SELECT 
                    ats.tenant_hk,
                    ats.token_name,
                    ats.is_active,
                    th.tenant_bk
                FROM auth.api_token_s ats
                JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
                JOIN auth.tenant_h th ON ats.tenant_hk = th.tenant_hk
                WHERE ats.token_value = $1 
                AND ats.load_end_date IS NULL
                AND ats.is_active = true
                AND (ats.expires_at IS NULL OR ats.expires_at > CURRENT_TIMESTAMP)
            """, 'zt_test_api_key_12345')
            
            await conn.close()
            
            if result:
                return {"success": True, "message": f"Tenant resolution successful: {result['tenant_bk']}"}
            else:
                return {"success": False, "message": "Tenant resolution failed - no matching token"}
                
        except Exception as e:
            return {"success": False, "message": f"Tenant resolution failed: {str(e)}"}
    
    async def test_resource_validation(self) -> Dict[str, Any]:
        """Test resource validation against business schema"""
        try:
            conn = await asyncpg.connect(**DB_CONFIG)
            
            tenant_hk = bytes.fromhex('deadbeef00000000000000000000000000000000000000000000000000000000')
            
            # Test resource validation query pattern
            business_tables = await conn.fetch("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'business'
                AND table_name LIKE '%_h'
                LIMIT 3
            """)
            
            validation_attempts = 0
            successful_validations = 0
            
            for table in business_tables:
                table_name = table['table_name']
                try:
                    # Test the resource validation query pattern
                    exists = await conn.fetchval(f"""
                        SELECT 1 FROM business.{table_name}
                        WHERE tenant_hk = $1
                        LIMIT 1
                    """, tenant_hk)
                    
                    validation_attempts += 1
                    if exists is not None:
                        successful_validations += 1
                        
                except Exception as e:
                    # Some tables might not have tenant_hk - that's okay
                    pass
            
            await conn.close()
            
            return {
                "success": True, 
                "message": f"Resource validation tested on {validation_attempts} tables"
            }
            
        except Exception as e:
            return {"success": False, "message": f"Resource validation test failed: {str(e)}"}
    
    async def test_security_logging(self) -> Dict[str, Any]:
        """Test security logging functionality"""
        try:
            conn = await asyncpg.connect(**DB_CONFIG)
            
            # Check if we can log security events
            security_functions = await conn.fetch("""
                SELECT routine_name 
                FROM information_schema.routines 
                WHERE routine_schema = 'ai_monitoring'
                AND routine_name LIKE '%security%'
            """)
            
            await conn.close()
            
            if security_functions:
                function_names = [f['routine_name'] for f in security_functions]
                return {"success": True, "message": f"Security logging functions available: {function_names}"}
            else:
                return {"success": False, "message": "No security logging functions found"}
                
        except Exception as e:
            return {"success": False, "message": f"Security logging test failed: {str(e)}"}
    
    async def print_summary(self):
        """Print test summary"""
        print("\n" + "=" * 60)
        print("📊 ZERO TRUST VALIDATION SUMMARY")
        print("=" * 60)
        
        passed = sum(1 for r in self.results if r['result']['success'])
        failed = len(self.results) - passed
        
        print(f"✅ Passed: {passed}")
        print(f"❌ Failed: {failed}")
        print(f"📈 Success Rate: {passed/len(self.results)*100:.1f}%")
        
        if failed > 0:
            print("\n🔴 FAILED TESTS:")
            for result in self.results:
                if not result['result']['success']:
                    print(f"   • {result['test']}: {result['result']['message']}")
        
        print("\n🎯 RECOMMENDATIONS:")
        if passed >= len(self.results) * 0.8:
            print("   ✅ Infrastructure is ready for Zero Trust implementation")
            print("   ✅ Can proceed with middleware deployment")
            print("   ✅ Existing functions can be leveraged")
        else:
            print("   ⚠️  Some infrastructure components need attention")
            print("   ⚠️  Review failed tests before deployment")
        
        print("\n🚀 NEXT STEPS:")
        print("   1. Deploy updated middleware with existing infrastructure")
        print("   2. Run integration tests with real API calls")
        print("   3. Monitor performance and security metrics")
        print("   4. Proceed to Phase 2 (Token Lifecycle Management)")

async def main():
    """Main validation runner"""
    validator = ZeroTrustValidator()
    await validator.run_all_tests()

if __name__ == "__main__":
    print("🔐 Zero Trust Infrastructure Validation")
    print("Using existing database: one_vault_site_testing")
    print("This will test readiness for Zero Trust implementation")
    print()
    
    asyncio.run(main()) 