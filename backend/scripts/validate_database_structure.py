#!/usr/bin/env python3
"""
OneVault Database Structure Validation Script
============================================

This script validates your existing database structure against OneVault's
Data Vault 2.0 requirements and provides a comprehensive report of what's
ready and what needs to be built.

Usage:
    python validate_database_structure.py --customer one_spa
    python validate_database_structure.py --all-customers
    python validate_database_structure.py --system-only
"""

import sys
import json
import logging
from datetime import datetime
from typing import Dict, List, Optional, Any
from pathlib import Path

# Add the app directory to the path so we can import our modules
sys.path.append(str(Path(__file__).parent.parent))

from app.core.config import settings, get_customer_config
from app.core.database import db_manager, DataVaultUtils

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DatabaseValidator:
    """Validates OneVault database structure and compliance"""
    
    def __init__(self):
        self.validation_results = {
            "validation_timestamp": datetime.utcnow().isoformat(),
            "system_database": {},
            "customer_databases": {},
            "overall_status": "unknown",
            "recommendations": []
        }
    
    def validate_system_database(self) -> Dict[str, Any]:
        """Validate the system database structure"""
        logger.info("Validating system database...")
        
        try:
            session = db_manager.get_system_session()
            
            # Check database connectivity
            result = session.execute("SELECT 1 as test")
            connectivity_ok = result.fetchone()[0] == 1
            
            if not connectivity_ok:
                return {
                    "status": "failed",
                    "error": "System database connectivity test failed"
                }
            
            # Check for required schemas in system database
            schema_result = session.execute("""
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name IN ('platform', 'monitoring', 'audit')
            """)
            
            existing_schemas = [row[0] for row in schema_result]
            required_schemas = ['platform', 'monitoring', 'audit']
            missing_schemas = set(required_schemas) - set(existing_schemas)
            
            # Check for platform management tables
            table_result = session.execute("""
                SELECT table_schema, table_name 
                FROM information_schema.tables 
                WHERE table_schema IN ('platform', 'monitoring', 'audit')
                AND table_type = 'BASE TABLE'
            """)
            
            existing_tables = [(row[0], row[1]) for row in table_result]
            
            session.close()
            
            validation_result = {
                "status": "healthy" if len(missing_schemas) == 0 else "needs_setup",
                "connectivity": "ok",
                "schemas": {
                    "existing": existing_schemas,
                    "missing": list(missing_schemas),
                    "required": required_schemas
                },
                "tables": {
                    "total": len(existing_tables),
                    "by_schema": {}
                }
            }
            
            # Group tables by schema
            for schema, table in existing_tables:
                if schema not in validation_result["tables"]["by_schema"]:
                    validation_result["tables"]["by_schema"][schema] = []
                validation_result["tables"]["by_schema"][schema].append(table)
            
            logger.info("System database validation completed")
            return validation_result
            
        except Exception as e:
            logger.error(f"System database validation failed: {e}")
            return {
                "status": "failed",
                "error": str(e),
                "connectivity": "failed"
            }
    
    def validate_customer_database(self, customer_id: str) -> Dict[str, Any]:
        """Validate a specific customer database"""
        logger.info(f"Validating customer database: {customer_id}")
        
        try:
            # Get customer configuration
            customer_config = get_customer_config(customer_id)
            
            # Use the database manager to validate
            validation_result = db_manager.validate_customer_database(customer_id)
            
            # Add additional Data Vault 2.0 specific validations
            if validation_result.get("database_valid"):
                dv_validation = self._validate_data_vault_compliance(customer_id)
                validation_result["data_vault_compliance"] = dv_validation
            
            # Add customer configuration validation
            config_validation = self._validate_customer_config(customer_config)
            validation_result["configuration"] = config_validation
            
            logger.info(f"Customer database validation completed: {customer_id}")
            return validation_result
            
        except Exception as e:
            logger.error(f"Customer database validation failed for {customer_id}: {e}")
            return {
                "customer_id": customer_id,
                "status": "failed",
                "error": str(e),
                "database_valid": False
            }
    
    def _validate_data_vault_compliance(self, customer_id: str) -> Dict[str, Any]:
        """Validate Data Vault 2.0 compliance for customer database"""
        try:
            engine = db_manager.get_customer_engine(customer_id)
            
            with engine.connect() as conn:
                # Check for required Data Vault 2.0 patterns
                
                # 1. Check hub tables have proper structure
                hub_check = conn.execute("""
                    SELECT table_name, column_name, data_type
                    FROM information_schema.columns
                    WHERE table_schema IN ('auth', 'business')
                    AND table_name LIKE '%_h'
                    AND column_name IN ('load_date', 'record_source')
                    ORDER BY table_name, column_name
                """)
                
                hub_compliance = list(hub_check)
                
                # 2. Check satellite tables have proper structure
                satellite_check = conn.execute("""
                    SELECT table_name, column_name, data_type
                    FROM information_schema.columns
                    WHERE table_schema IN ('auth', 'business')
                    AND table_name LIKE '%_s'
                    AND column_name IN ('load_date', 'load_end_date', 'hash_diff', 'record_source')
                    ORDER BY table_name, column_name
                """)
                
                satellite_compliance = list(satellite_check)
                
                # 3. Check for proper indexes
                index_check = conn.execute("""
                    SELECT schemaname, tablename, indexname
                    FROM pg_indexes
                    WHERE schemaname IN ('auth', 'business', 'audit')
                    AND (indexname LIKE '%_hk%' OR indexname LIKE '%load_date%')
                """)
                
                index_compliance = list(index_check)
                
                # 4. Check for audit functions
                function_check = conn.execute("""
                    SELECT routine_name, routine_type
                    FROM information_schema.routines
                    WHERE routine_schema IN ('util', 'audit')
                    AND routine_name IN ('hash_binary', 'current_load_date', 'get_record_source')
                """)
                
                function_compliance = list(function_check)
                
                return {
                    "status": "compliant" if all([
                        len(hub_compliance) > 0,
                        len(satellite_compliance) > 0,
                        len(function_compliance) >= 2
                    ]) else "partial",
                    "hub_tables_compliant": len(hub_compliance) > 0,
                    "satellite_tables_compliant": len(satellite_compliance) > 0,
                    "indexes_present": len(index_compliance),
                    "utility_functions_present": len(function_compliance),
                    "details": {
                        "hubs": len(set(row[0] for row in hub_compliance)),
                        "satellites": len(set(row[0] for row in satellite_compliance)),
                        "indexes": len(index_compliance),
                        "functions": [row[0] for row in function_compliance]
                    }
                }
                
        except Exception as e:
            return {
                "status": "failed",
                "error": str(e)
            }
    
    def _validate_customer_config(self, customer_config) -> Dict[str, Any]:
        """Validate customer configuration completeness"""
        try:
            config_dict = customer_config.config
            
            required_sections = [
                'customer', 'database', 'features', 'compliance', 
                'branding', 'security'
            ]
            
            missing_sections = []
            present_sections = []
            
            for section in required_sections:
                if section in config_dict:
                    present_sections.append(section)
                else:
                    missing_sections.append(section)
            
            # Check industry-specific requirements
            industry_validation = {
                "industry_type": config_dict.get('customer', {}).get('industry', {}).get('type'),
                "compliance_frameworks": config_dict.get('compliance', {}).get('frameworks', []),
                "enabled_features": config_dict.get('features', {}).get('enabled', [])
            }
            
            return {
                "status": "complete" if len(missing_sections) == 0 else "incomplete",
                "required_sections": required_sections,
                "present_sections": present_sections,
                "missing_sections": missing_sections,
                "industry_specific": industry_validation,
                "database_url_configured": bool(customer_config.database_url),
                "branding_configured": bool(config_dict.get('branding')),
                "tenants_configured": len(config_dict.get('tenants', []))
            }
            
        except Exception as e:
            return {
                "status": "failed",
                "error": str(e)
            }
    
    def generate_recommendations(self) -> List[str]:
        """Generate recommendations based on validation results"""
        recommendations = []
        
        # System database recommendations
        system_status = self.validation_results.get("system_database", {})
        if system_status.get("status") == "needs_setup":
            recommendations.append(
                "🔧 System database needs setup - create platform management schemas"
            )
        elif system_status.get("status") == "failed":
            recommendations.append(
                "❌ System database connectivity failed - check connection settings"
            )
        
        # Customer database recommendations
        for customer_id, customer_data in self.validation_results.get("customer_databases", {}).items():
            if not customer_data.get("database_valid"):
                recommendations.append(
                    f"🏗️ Customer '{customer_id}' database needs Data Vault 2.0 setup"
                )
            
            dv_compliance = customer_data.get("data_vault_compliance", {})
            if dv_compliance.get("status") == "partial":
                recommendations.append(
                    f"⚠️ Customer '{customer_id}' has incomplete Data Vault 2.0 structure"
                )
            
            config_status = customer_data.get("configuration", {})
            if config_status.get("status") == "incomplete":
                missing = config_status.get("missing_sections", [])
                recommendations.append(
                    f"📝 Customer '{customer_id}' configuration missing: {', '.join(missing)}"
                )
        
        # General recommendations
        if not recommendations:
            recommendations.append("✅ All validations passed! Ready to start development.")
        else:
            recommendations.insert(0, "🚀 Next steps to get OneVault ready:")
        
        return recommendations
    
    def run_full_validation(self, customer_ids: Optional[List[str]] = None) -> Dict[str, Any]:
        """Run complete validation suite"""
        logger.info("Starting OneVault database validation...")
        
        # Validate system database
        self.validation_results["system_database"] = self.validate_system_database()
        
        # Validate customer databases
        if customer_ids:
            for customer_id in customer_ids:
                try:
                    result = self.validate_customer_database(customer_id)
                    self.validation_results["customer_databases"][customer_id] = result
                except Exception as e:
                    logger.error(f"Failed to validate customer {customer_id}: {e}")
                    self.validation_results["customer_databases"][customer_id] = {
                        "status": "failed",
                        "error": str(e)
                    }
        
        # Generate recommendations
        self.validation_results["recommendations"] = self.generate_recommendations()
        
        # Determine overall status
        system_ok = self.validation_results["system_database"].get("status") in ["healthy", "needs_setup"]
        customer_results = self.validation_results["customer_databases"].values()
        customers_ok = all(c.get("database_valid", False) for c in customer_results) if customer_results else True
        
        if system_ok and customers_ok:
            self.validation_results["overall_status"] = "ready"
        elif system_ok or any(c.get("database_valid", False) for c in customer_results):
            self.validation_results["overall_status"] = "partial"
        else:
            self.validation_results["overall_status"] = "needs_setup"
        
        logger.info("OneVault database validation completed")
        return self.validation_results

def print_validation_report(results: Dict[str, Any]):
    """Print a formatted validation report"""
    print("\n" + "="*60)
    print("🏗️  ONEVAULT DATABASE VALIDATION REPORT")
    print("="*60)
    
    print(f"\n📅 Validation Time: {results['validation_timestamp']}")
    print(f"🎯 Overall Status: {results['overall_status'].upper()}")
    
    # System database section
    print(f"\n🖥️  SYSTEM DATABASE")
    print("-" * 30)
    system = results.get("system_database", {})
    print(f"Status: {system.get('status', 'unknown')}")
    print(f"Connectivity: {system.get('connectivity', 'unknown')}")
    
    if system.get("schemas"):
        print(f"Schemas Present: {', '.join(system['schemas'].get('existing', []))}")
        if system['schemas'].get('missing'):
            print(f"Schemas Missing: {', '.join(system['schemas']['missing'])}")
    
    # Customer databases section
    print(f"\n👥 CUSTOMER DATABASES")
    print("-" * 30)
    
    customers = results.get("customer_databases", {})
    if not customers:
        print("No customer databases validated")
    else:
        for customer_id, data in customers.items():
            print(f"\n📊 Customer: {customer_id}")
            print(f"   Database Valid: {'✅' if data.get('database_valid') else '❌'}")
            
            if data.get("data_vault_structure"):
                dv = data["data_vault_structure"]
                print(f"   Data Vault Tables: {dv.get('total_tables', 0)} total")
                print(f"   - Hubs: {dv.get('hub_tables', 0)}")
                print(f"   - Satellites: {dv.get('satellite_tables', 0)}")
                print(f"   - Links: {dv.get('link_tables', 0)}")
            
            if data.get("configuration"):
                config = data["configuration"]
                print(f"   Configuration: {'✅' if config.get('status') == 'complete' else '⚠️'}")
                if config.get("missing_sections"):
                    print(f"   Missing Config: {', '.join(config['missing_sections'])}")
    
    # Recommendations section
    print(f"\n💡 RECOMMENDATIONS")
    print("-" * 30)
    for recommendation in results.get("recommendations", []):
        print(f"{recommendation}")
    
    print("\n" + "="*60)

def main():
    """Main function for command line usage"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Validate OneVault database structure")
    parser.add_argument("--customer", help="Validate specific customer database")
    parser.add_argument("--all-customers", action="store_true", help="Validate all customer databases")
    parser.add_argument("--system-only", action="store_true", help="Validate only system database")
    parser.add_argument("--output", help="Save results to JSON file")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose logging")
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    validator = DatabaseValidator()
    
    # Determine which customers to validate
    customer_ids = []
    if args.customer:
        customer_ids = [args.customer]
    elif args.all_customers:
        # In a real implementation, you'd scan the customers directory
        customer_ids = ["one_spa"]  # For now, just the example customer
    elif not args.system_only:
        # Default: validate one_spa if it exists
        customer_ids = ["one_spa"]
    
    # Run validation
    results = validator.run_full_validation(customer_ids if not args.system_only else None)
    
    # Print report
    print_validation_report(results)
    
    # Save to file if requested
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        print(f"\n💾 Results saved to: {args.output}")
    
    # Exit with appropriate code
    if results["overall_status"] == "ready":
        sys.exit(0)
    elif results["overall_status"] == "partial":
        sys.exit(1)
    else:
        sys.exit(2)

if __name__ == "__main__":
    main() 