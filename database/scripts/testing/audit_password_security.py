#!/usr/bin/env python3
"""
Password Security Audit Script
Scans database for potential plain text password storage violations
"""

import psycopg2
import getpass
import re
import json
from datetime import datetime

class PasswordSecurityAuditor:
    def __init__(self):
        self.findings = []
        self.conn = None
        self.cur = None
        
    def connect_to_database(self):
        """Establish database connection"""
        try:
            password = getpass.getpass("Enter PostgreSQL password: ")
            self.conn = psycopg2.connect(
                host='localhost',
                database='one_vault',
                user='postgres',
                password=password
            )
            self.conn.autocommit = True
            self.cur = self.conn.cursor()
            print("✅ Connected to database successfully")
            return True
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return False
    
    def audit_password_columns(self):
        """Audit all columns that might contain passwords"""
        print("\n🔍 Auditing password-related columns...")
        
        # Find all columns with password-related names
        password_column_query = """
        SELECT 
            table_schema,
            table_name,
            column_name,
            data_type,
            character_maximum_length,
            is_nullable
        FROM information_schema.columns 
        WHERE LOWER(column_name) LIKE '%password%'
           OR LOWER(column_name) LIKE '%pwd%'
           OR LOWER(column_name) LIKE '%pass%'
        ORDER BY table_schema, table_name, column_name;
        """
        
        self.cur.execute(password_column_query)
        password_columns = self.cur.fetchall()
        
        print(f"Found {len(password_columns)} password-related columns:")
        
        for schema, table, column, data_type, max_length, nullable in password_columns:
            full_column = f"{schema}.{table}.{column}"
            
            # Check if this looks like a proper hash column
            is_hash_column = self._is_hash_column(column, data_type, max_length)
            
            print(f"  📋 {full_column}")
            print(f"     Type: {data_type}, Length: {max_length}, Nullable: {nullable}")
            print(f"     Assessment: {'✅ HASH COLUMN' if is_hash_column else '⚠️  NEEDS REVIEW'}")
            
            # Sample data from this column (safely)
            self._audit_column_data(schema, table, column, is_hash_column)
            print()
    
    def _is_hash_column(self, column_name, data_type, max_length):
        """Determine if a column appears to store password hashes properly"""
        column_lower = column_name.lower()
        
        # Proper hash columns should be:
        # 1. Named with 'hash' or 'hashed'
        # 2. BYTEA type (binary) or fixed-length text
        # 3. Appropriate length for hash algorithms
        
        if 'hash' in column_lower:
            return True
            
        if data_type == 'bytea':
            return True
            
        # bcrypt hashes are typically 60 characters
        # SHA-256 hex is 64 characters
        # SHA-512 hex is 128 characters
        if data_type in ['character varying', 'text'] and max_length in [60, 64, 128]:
            return True
            
        return False
    
    def _audit_column_data(self, schema, table, column, is_expected_hash):
        """Safely audit actual data in password columns"""
        try:
            # Get sample of data (first 5 non-null values)
            sample_query = f"""
            SELECT 
                {column},
                LENGTH({column}::text) as length,
                CASE 
                    WHEN {column} IS NULL THEN 'NULL'
                    WHEN LENGTH({column}::text) = 0 THEN 'EMPTY'
                    ELSE 'HAS_DATA'
                END as status
            FROM {schema}.{table} 
            WHERE {column} IS NOT NULL 
            AND LENGTH({column}::text) > 0
            LIMIT 5;
            """
            
            self.cur.execute(sample_query)
            samples = self.cur.fetchall()
            
            if not samples:
                print(f"     📊 No data found in column")
                return
            
            print(f"     📊 Sample analysis ({len(samples)} records):")
            
            for i, (value, length, status) in enumerate(samples, 1):
                # Analyze the value for security issues
                security_assessment = self._analyze_password_value(value, is_expected_hash)
                
                print(f"       Sample {i}: Length={length}, Status={status}")
                print(f"                Security: {security_assessment['status']} - {security_assessment['reason']}")
                
                # Log findings
                if security_assessment['risk_level'] == 'HIGH':
                    self.findings.append({
                        'type': 'POTENTIAL_PLAINTEXT_PASSWORD',
                        'location': f"{schema}.{table}.{column}",
                        'risk_level': 'HIGH',
                        'description': security_assessment['reason'],
                        'sample_length': length,
                        'recommendation': 'Immediate review required - possible plaintext password'
                    })
                elif security_assessment['risk_level'] == 'MEDIUM':
                    self.findings.append({
                        'type': 'SUSPICIOUS_PASSWORD_STORAGE',
                        'location': f"{schema}.{table}.{column}",
                        'risk_level': 'MEDIUM',
                        'description': security_assessment['reason'],
                        'sample_length': length,
                        'recommendation': 'Review password storage implementation'
                    })
                    
        except Exception as e:
            print(f"     ❌ Error auditing column data: {e}")
    
    def _analyze_password_value(self, value, is_expected_hash):
        """Analyze a password value for security issues"""
        if value is None:
            return {'status': '✅ SAFE', 'reason': 'NULL value', 'risk_level': 'NONE'}
        
        value_str = str(value)
        length = len(value_str)
        
        # Check for obvious plaintext passwords
        if self._looks_like_plaintext_password(value_str):
            return {
                'status': '🚨 CRITICAL', 
                'reason': 'Appears to be plaintext password', 
                'risk_level': 'HIGH'
            }
        
        # Check for proper hash characteristics
        if is_expected_hash:
            if self._looks_like_proper_hash(value_str):
                return {
                    'status': '✅ SAFE', 
                    'reason': 'Appears to be proper password hash', 
                    'risk_level': 'NONE'
                }
            else:
                return {
                    'status': '⚠️  SUSPICIOUS', 
                    'reason': 'Expected hash but format is unusual', 
                    'risk_level': 'MEDIUM'
                }
        else:
            # Column not expected to be hash but contains password-like data
            return {
                'status': '⚠️  REVIEW', 
                'reason': 'Password-named column with unexpected format', 
                'risk_level': 'MEDIUM'
            }
    
    def _looks_like_plaintext_password(self, value):
        """Check if value looks like a plaintext password"""
        # Common plaintext password patterns
        plaintext_indicators = [
            r'^[a-zA-Z0-9!@#$%^&*()_+\-=\[\]{};\':"\\|,.<>\/?]{6,20}$',  # Common password format
            r'password',  # Contains word "password"
            r'123456',    # Common weak passwords
            r'admin',     # Common admin passwords
            r'test',      # Test passwords
        ]
        
        value_lower = value.lower()
        
        for pattern in plaintext_indicators:
            if re.search(pattern, value_lower):
                return True
        
        # Check for dictionary words (simplified check)
        common_words = ['password', 'admin', 'test', 'user', 'login', 'secret']
        if any(word in value_lower for word in common_words):
            return True
            
        return False
    
    def _looks_like_proper_hash(self, value):
        """Check if value looks like a proper password hash"""
        # bcrypt hash pattern: $2a$10$... or $2b$12$...
        if re.match(r'^\$2[ab]\$\d{2}\$[A-Za-z0-9./]{53}$', value):
            return True
        
        # SHA-256 hex (64 chars)
        if re.match(r'^[a-fA-F0-9]{64}$', value):
            return True
        
        # SHA-512 hex (128 chars)
        if re.match(r'^[a-fA-F0-9]{128}$', value):
            return True
        
        # Binary data (starts with \x)
        if value.startswith('\\x') and len(value) > 10:
            return True
        
        # Base64-like patterns
        if re.match(r'^[A-Za-z0-9+/=]{20,}$', value) and len(value) % 4 == 0:
            return True
            
        return False
    
    def audit_authentication_functions(self):
        """Audit authentication functions for password handling"""
        print("\n🔍 Auditing authentication functions...")
        
        # Get all authentication-related functions
        auth_functions_query = """
        SELECT 
            routine_schema,
            routine_name,
            routine_definition
        FROM information_schema.routines 
        WHERE routine_schema IN ('auth', 'api', 'raw', 'staging')
        AND (
            LOWER(routine_name) LIKE '%password%'
            OR LOWER(routine_name) LIKE '%login%'
            OR LOWER(routine_name) LIKE '%auth%'
        )
        ORDER BY routine_schema, routine_name;
        """
        
        self.cur.execute(auth_functions_query)
        functions = self.cur.fetchall()
        
        print(f"Found {len(functions)} authentication-related functions:")
        
        for schema, name, definition in functions:
            print(f"  🔧 {schema}.{name}")
            
            # Analyze function for password security
            security_issues = self._analyze_function_security(definition)
            
            if security_issues:
                print(f"     ⚠️  Security concerns found:")
                for issue in security_issues:
                    print(f"       - {issue}")
                    
                    self.findings.append({
                        'type': 'FUNCTION_SECURITY_ISSUE',
                        'location': f"{schema}.{name}",
                        'risk_level': 'MEDIUM',
                        'description': issue,
                        'recommendation': 'Review function implementation for security best practices'
                    })
            else:
                print(f"     ✅ No obvious security issues detected")
    
    def _analyze_function_security(self, definition):
        """Analyze function definition for password security issues"""
        if not definition:
            return []
        
        issues = []
        definition_lower = definition.lower()
        
        # Check for potential plaintext password handling
        if 'password' in definition_lower and 'hash' not in definition_lower:
            if any(keyword in definition_lower for keyword in ['insert', 'update', 'select']):
                issues.append("Function handles passwords but may not be using hashing")
        
        # Check for logging of sensitive data
        if any(log_func in definition_lower for log_func in ['raise notice', 'raise info', 'raise log']):
            if 'password' in definition_lower:
                issues.append("Function may log password-related information")
        
        # Check for direct password comparisons
        if re.search(r'password\s*=\s*[\'"]', definition_lower):
            issues.append("Function may contain hardcoded password comparison")
        
        return issues
    
    def generate_report(self):
        """Generate comprehensive security audit report"""
        print("\n" + "="*80)
        print("🔒 PASSWORD SECURITY AUDIT REPORT")
        print("="*80)
        
        if not self.findings:
            print("✅ NO SECURITY ISSUES FOUND!")
            print("   All password storage appears to follow security best practices.")
        else:
            print(f"⚠️  FOUND {len(self.findings)} POTENTIAL SECURITY ISSUES:")
            print()
            
            # Group findings by risk level
            high_risk = [f for f in self.findings if f['risk_level'] == 'HIGH']
            medium_risk = [f for f in self.findings if f['risk_level'] == 'MEDIUM']
            
            if high_risk:
                print("🚨 HIGH RISK ISSUES (IMMEDIATE ACTION REQUIRED):")
                for i, finding in enumerate(high_risk, 1):
                    print(f"   {i}. {finding['type']}")
                    print(f"      Location: {finding['location']}")
                    print(f"      Issue: {finding['description']}")
                    print(f"      Action: {finding['recommendation']}")
                    print()
            
            if medium_risk:
                print("⚠️  MEDIUM RISK ISSUES (REVIEW RECOMMENDED):")
                for i, finding in enumerate(medium_risk, 1):
                    print(f"   {i}. {finding['type']}")
                    print(f"      Location: {finding['location']}")
                    print(f"      Issue: {finding['description']}")
                    print(f"      Action: {finding['recommendation']}")
                    print()
        
        # Save detailed report to file
        report_filename = f"password_security_audit_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_filename, 'w') as f:
            json.dump({
                'audit_timestamp': datetime.now().isoformat(),
                'total_findings': len(self.findings),
                'high_risk_count': len([f for f in self.findings if f['risk_level'] == 'HIGH']),
                'medium_risk_count': len([f for f in self.findings if f['risk_level'] == 'MEDIUM']),
                'findings': self.findings
            }, f, indent=2)
        
        print(f"📄 Detailed report saved to: {report_filename}")
        
        return len([f for f in self.findings if f['risk_level'] == 'HIGH']) == 0
    
    def run_audit(self):
        """Run complete password security audit"""
        print("🔒 Starting Password Security Audit...")
        print("="*50)
        
        if not self.connect_to_database():
            return False
        
        try:
            # Run all audit checks
            self.audit_password_columns()
            self.audit_authentication_functions()
            
            # Generate final report
            is_secure = self.generate_report()
            
            return is_secure
            
        except Exception as e:
            print(f"❌ Audit failed: {e}")
            return False
        finally:
            if self.cur:
                self.cur.close()
            if self.conn:
                self.conn.close()

def main():
    auditor = PasswordSecurityAuditor()
    is_secure = auditor.run_audit()
    
    if is_secure:
        print("\n🎉 AUDIT PASSED: No critical password security issues found!")
        exit(0)
    else:
        print("\n⚠️  AUDIT FAILED: Critical security issues require immediate attention!")
        exit(1)

if __name__ == "__main__":
    main() 