#!/usr/bin/env python3
"""
Mock Data Generator for One Vault Data Platform
Generates realistic test data for all Data Vault 2.0 structures
"""

import psycopg2
import yaml
import json
import random
import hashlib
import uuid
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import sys
import logging
from faker import Faker
from faker.providers import company, person, address, internet, phone_number
import argparse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

class MockDataGenerator:
    """Comprehensive mock data generator for One Vault platform"""
    
    def __init__(self, config_file: str = "config.yaml"):
        """Initialize the mock data generator"""
        self.config = self._load_config(config_file)
        self.connection = None
        self.fake = Faker()
        
        # Add providers
        self.fake.add_provider(company)
        self.fake.add_provider(person)
        self.fake.add_provider(address)
        self.fake.add_provider(internet)
        self.fake.add_provider(phone_number)
        
        # Data generation settings
        self.generation_stats = {
            'tenants_created': 0,
            'users_created': 0,
            'sessions_created': 0,
            'entities_created': 0,
            'assets_created': 0,
            'transactions_created': 0,
            'audit_records_created': 0
        }
        
        # Pre-defined data sets
        self.entity_types = ['LLC', 'Corporation', 'Partnership', 'Sole Proprietorship', 'S-Corp', 'C-Corp']
        self.asset_types = ['Equipment', 'Intellectual Property', 'Real Estate', 'Vehicle', 'Software', 'Inventory']
        self.transaction_types = ['Sale', 'Purchase', 'Lease', 'License', 'Service', 'Investment']
        self.compliance_frameworks = ['HIPAA', 'GDPR', 'SOX', 'PCI-DSS', 'GLBA']
        
    def _load_config(self, config_file: str) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        try:
            with open(config_file, 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            return {
                'database': {
                    'host': 'localhost',
                    'port': 5432,
                    'database': 'one_vault_test',  # Use test database
                    'user': 'postgres',
                    'password': None
                },
                'mock_data': {
                    'num_tenants': 5,
                    'users_per_tenant': 10,
                    'entities_per_tenant': 20,
                    'assets_per_entity': 5,
                    'transactions_per_entity': 25,
                    'time_range_days': 365,
                    'create_test_database': True
                }
            }
    
    def connect(self, create_test_db: bool = False) -> None:
        """Establish database connection"""
        try:
            db_config = self.config['database']
            
            if create_test_db:
                # Connect to postgres database to create test database
                conn = psycopg2.connect(
                    host=db_config['host'],
                    port=db_config['port'],
                    database='postgres',
                    user=db_config['user'],
                    password=db_config.get('password') or ''
                )
                conn.autocommit = True
                
                with conn.cursor() as cursor:
                    # Create test database if it doesn't exist
                    cursor.execute(f"SELECT 1 FROM pg_database WHERE datname = '{db_config['database']}'")
                    if not cursor.fetchone():
                        cursor.execute(f"CREATE DATABASE {db_config['database']}")
                        logging.info(f"Created test database: {db_config['database']}")
                
                conn.close()
            
            # Connect to target database
            self.connection = psycopg2.connect(
                host=db_config['host'],
                port=db_config['port'],
                database=db_config['database'],
                user=db_config['user'],
                password=db_config.get('password') or ''
            )
            self.connection.autocommit = True
            logging.info(f"Connected to database: {db_config['database']}")
            
        except Exception as e:
            logging.error(f"Failed to connect to database: {e}")
            raise
    
    def generate_hash_key(self, business_key: str) -> bytes:
        """Generate SHA-256 hash key from business key"""
        return hashlib.sha256(business_key.encode()).digest()
    
    def generate_hash_diff(self, *values) -> bytes:
        """Generate hash diff for satellite records"""
        combined = '||'.join(str(v) for v in values)
        return hashlib.sha256(combined.encode()).digest()
    
    def get_current_load_date(self) -> datetime:
        """Get current load date"""
        return datetime.now()
    
    def create_schema_structure(self) -> None:
        """Create the basic schema structure if it doesn't exist"""
        schemas = ['auth', 'business', 'audit', 'util', 'ref']
        
        with self.connection.cursor() as cursor:
            for schema in schemas:
                cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {schema}")
                logging.info(f"Ensured schema exists: {schema}")
    
    def create_basic_tables(self) -> None:
        """Create basic table structures for testing"""
        
        table_definitions = """
        -- Utility functions
        CREATE OR REPLACE FUNCTION util.current_load_date()
        RETURNS TIMESTAMP WITH TIME ZONE AS $$
        BEGIN
            RETURN CURRENT_TIMESTAMP;
        END;
        $$ LANGUAGE plpgsql;
        
        CREATE OR REPLACE FUNCTION util.get_record_source()
        RETURNS VARCHAR(100) AS $$
        BEGIN
            RETURN 'MOCK_DATA_GENERATOR';
        END;
        $$ LANGUAGE plpgsql;
        
        -- Tenant Hub
        CREATE TABLE IF NOT EXISTS auth.tenant_h (
            tenant_hk BYTEA PRIMARY KEY,
            tenant_bk VARCHAR(255) NOT NULL UNIQUE,
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            record_source VARCHAR(100) NOT NULL DEFAULT 'MOCK_DATA'
        );
        
        -- Tenant Profile Satellite
        CREATE TABLE IF NOT EXISTS auth.tenant_profile_s (
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            load_end_date TIMESTAMP WITH TIME ZONE,
            hash_diff BYTEA NOT NULL,
            tenant_name VARCHAR(255) NOT NULL,
            domain_name VARCHAR(255),
            subscription_tier VARCHAR(50),
            is_active BOOLEAN DEFAULT true,
            created_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
            contact_email VARCHAR(255),
            phone VARCHAR(50),
            address_line1 VARCHAR(255),
            city VARCHAR(100),
            state VARCHAR(50),
            postal_code VARCHAR(20),
            country VARCHAR(100),
            record_source VARCHAR(100) NOT NULL DEFAULT 'MOCK_DATA',
            PRIMARY KEY (tenant_hk, load_date)
        );
        
        -- User Hub
        CREATE TABLE IF NOT EXISTS auth.user_h (
            user_hk BYTEA PRIMARY KEY,
            user_bk VARCHAR(255) NOT NULL,
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            record_source VARCHAR(100) NOT NULL DEFAULT 'MOCK_DATA',
            UNIQUE(user_bk, tenant_hk)
        );
        
        -- User Profile Satellite
        CREATE TABLE IF NOT EXISTS auth.user_profile_s (
            user_hk BYTEA NOT NULL REFERENCES auth.user_h(user_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            load_end_date TIMESTAMP WITH TIME ZONE,
            hash_diff BYTEA NOT NULL,
            first_name VARCHAR(100),
            last_name VARCHAR(100),
            email VARCHAR(255),
            phone VARCHAR(50),
            job_title VARCHAR(100),
            department VARCHAR(100),
            is_active BOOLEAN DEFAULT true,
            created_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
            last_login_date TIMESTAMP WITH TIME ZONE,
            record_source VARCHAR(100) NOT NULL DEFAULT 'MOCK_DATA',
            PRIMARY KEY (user_hk, load_date)
        );
        
        -- Business Entity Hub
        CREATE TABLE IF NOT EXISTS business.entity_h (
            entity_hk BYTEA PRIMARY KEY,
            entity_bk VARCHAR(255) NOT NULL,
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            record_source VARCHAR(100) NOT NULL DEFAULT 'MOCK_DATA',
            UNIQUE(entity_bk, tenant_hk)
        );
        
        -- Entity Details Satellite
        CREATE TABLE IF NOT EXISTS business.entity_details_s (
            entity_hk BYTEA NOT NULL REFERENCES business.entity_h(entity_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            load_end_date TIMESTAMP WITH TIME ZONE,
            hash_diff BYTEA NOT NULL,
            entity_name VARCHAR(255) NOT NULL,
            entity_type VARCHAR(50),
            tax_id VARCHAR(50),
            formation_date DATE,
            status VARCHAR(20) DEFAULT 'Active',
            description TEXT,
            annual_revenue DECIMAL(15,2),
            employee_count INTEGER,
            record_source VARCHAR(100) NOT NULL DEFAULT 'MOCK_DATA',
            PRIMARY KEY (entity_hk, load_date)
        );
        
        -- Asset Hub
        CREATE TABLE IF NOT EXISTS business.asset_h (
            asset_hk BYTEA PRIMARY KEY,
            asset_bk VARCHAR(255) NOT NULL,
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            record_source VARCHAR(100) NOT NULL DEFAULT 'MOCK_DATA',
            UNIQUE(asset_bk, tenant_hk)
        );
        
        -- Asset Details Satellite
        CREATE TABLE IF NOT EXISTS business.asset_details_s (
            asset_hk BYTEA NOT NULL REFERENCES business.asset_h(asset_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            load_end_date TIMESTAMP WITH TIME ZONE,
            hash_diff BYTEA NOT NULL,
            asset_name VARCHAR(255) NOT NULL,
            asset_type VARCHAR(50),
            purchase_price DECIMAL(15,2),
            current_value DECIMAL(15,2),
            purchase_date DATE,
            depreciation_method VARCHAR(50),
            useful_life_years INTEGER,
            description TEXT,
            record_source VARCHAR(100) NOT NULL DEFAULT 'MOCK_DATA',
            PRIMARY KEY (asset_hk, load_date)
        );
        
        -- Transaction Hub
        CREATE TABLE IF NOT EXISTS business.transaction_h (
            transaction_hk BYTEA PRIMARY KEY,
            transaction_bk VARCHAR(255) NOT NULL,
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            record_source VARCHAR(100) NOT NULL DEFAULT 'MOCK_DATA',
            UNIQUE(transaction_bk, tenant_hk)
        );
        
        -- Transaction Details Satellite
        CREATE TABLE IF NOT EXISTS business.transaction_details_s (
            transaction_hk BYTEA NOT NULL REFERENCES business.transaction_h(transaction_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            load_end_date TIMESTAMP WITH TIME ZONE,
            hash_diff BYTEA NOT NULL,
            transaction_type VARCHAR(50),
            amount DECIMAL(15,2),
            transaction_date DATE,
            description TEXT,
            counterparty VARCHAR(255),
            payment_method VARCHAR(50),
            status VARCHAR(20) DEFAULT 'Completed',
            record_source VARCHAR(100) NOT NULL DEFAULT 'MOCK_DATA',
            PRIMARY KEY (transaction_hk, load_date)
        );
        
        -- Audit Event Hub
        CREATE TABLE IF NOT EXISTS audit.audit_event_h (
            audit_event_hk BYTEA PRIMARY KEY,
            audit_event_bk VARCHAR(255) NOT NULL,
            tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            record_source VARCHAR(100) NOT NULL DEFAULT 'MOCK_DATA'
        );
        
        -- Audit Detail Satellite
        CREATE TABLE IF NOT EXISTS audit.audit_detail_s (
            audit_event_hk BYTEA NOT NULL REFERENCES audit.audit_event_h(audit_event_hk),
            load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
            load_end_date TIMESTAMP WITH TIME ZONE,
            hash_diff BYTEA NOT NULL,
            event_type VARCHAR(100),
            table_name VARCHAR(100),
            operation VARCHAR(20),
            user_id VARCHAR(255),
            ip_address INET,
            user_agent TEXT,
            event_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
            old_values JSONB,
            new_values JSONB,
            record_source VARCHAR(100) NOT NULL DEFAULT 'MOCK_DATA',
            PRIMARY KEY (audit_event_hk, load_date)
        );
        """
        
        with self.connection.cursor() as cursor:
            cursor.execute(table_definitions)
            logging.info("Created basic table structures")
    
    def generate_tenants(self, num_tenants: int) -> List[bytes]:
        """Generate mock tenant data"""
        tenant_hks = []
        
        with self.connection.cursor() as cursor:
            for i in range(num_tenants):
                # Generate tenant data
                company_name = self.fake.company()
                tenant_bk = f"TENANT_{company_name.replace(' ', '_').upper()}_{i+1}"
                tenant_hk = self.generate_hash_key(tenant_bk)
                
                # Insert tenant hub
                cursor.execute("""
                    INSERT INTO auth.tenant_h (tenant_hk, tenant_bk, load_date, record_source)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (tenant_bk) DO NOTHING
                """, (tenant_hk, tenant_bk, self.get_current_load_date(), 'MOCK_DATA_GENERATOR'))
                
                # Generate tenant profile data
                domain_name = f"{company_name.lower().replace(' ', '')}.com"
                subscription_tiers = ['Basic', 'Professional', 'Enterprise']
                
                hash_diff = self.generate_hash_diff(
                    company_name, domain_name, random.choice(subscription_tiers)
                )
                
                cursor.execute("""
                    INSERT INTO auth.tenant_profile_s (
                        tenant_hk, load_date, hash_diff, tenant_name, domain_name,
                        subscription_tier, is_active, contact_email, phone,
                        address_line1, city, state, postal_code, country, record_source
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    tenant_hk, self.get_current_load_date(), hash_diff,
                    company_name, domain_name, random.choice(subscription_tiers),
                    True, self.fake.company_email(), self.fake.phone_number(),
                    self.fake.street_address(), self.fake.city(), self.fake.state(),
                    self.fake.postcode(), self.fake.country(), 'MOCK_DATA_GENERATOR'
                ))
                
                tenant_hks.append(tenant_hk)
                self.generation_stats['tenants_created'] += 1
        
        logging.info(f"Generated {num_tenants} tenants")
        return tenant_hks
    
    def generate_users(self, tenant_hks: List[bytes], users_per_tenant: int) -> List[bytes]:
        """Generate mock user data"""
        user_hks = []
        
        with self.connection.cursor() as cursor:
            for tenant_hk in tenant_hks:
                for i in range(users_per_tenant):
                    # Generate user data
                    first_name = self.fake.first_name()
                    last_name = self.fake.last_name()
                    email = f"{first_name.lower()}.{last_name.lower()}{i}@example.com"
                    user_bk = f"USER_{email}"
                    user_hk = self.generate_hash_key(user_bk + tenant_hk.hex())
                    
                    # Insert user hub
                    cursor.execute("""
                        INSERT INTO auth.user_h (user_hk, user_bk, tenant_hk, load_date, record_source)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (user_bk, tenant_hk) DO NOTHING
                    """, (user_hk, user_bk, tenant_hk, self.get_current_load_date(), 'MOCK_DATA_GENERATOR'))
                    
                    # Generate user profile
                    job_titles = ['Manager', 'Analyst', 'Director', 'Specialist', 'Coordinator', 'Executive']
                    departments = ['Finance', 'Operations', 'IT', 'HR', 'Sales', 'Marketing']
                    
                    hash_diff = self.generate_hash_diff(
                        first_name, last_name, email, random.choice(job_titles)
                    )
                    
                    last_login = self.fake.date_time_between(start_date='-30d', end_date='now')
                    
                    cursor.execute("""
                        INSERT INTO auth.user_profile_s (
                            user_hk, load_date, hash_diff, first_name, last_name, email,
                            phone, job_title, department, is_active, last_login_date, record_source
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        user_hk, self.get_current_load_date(), hash_diff,
                        first_name, last_name, email, self.fake.phone_number(),
                        random.choice(job_titles), random.choice(departments),
                        True, last_login, 'MOCK_DATA_GENERATOR'
                    ))
                    
                    user_hks.append(user_hk)
                    self.generation_stats['users_created'] += 1
        
        logging.info(f"Generated {len(user_hks)} users")
        return user_hks
    
    def generate_entities(self, tenant_hks: List[bytes], entities_per_tenant: int) -> List[bytes]:
        """Generate mock business entity data"""
        entity_hks = []
        
        with self.connection.cursor() as cursor:
            for tenant_hk in tenant_hks:
                for i in range(entities_per_tenant):
                    # Generate entity data
                    company_name = self.fake.company()
                    entity_bk = f"ENTITY_{company_name.replace(' ', '_').upper()}_{i+1}"
                    entity_hk = self.generate_hash_key(entity_bk + tenant_hk.hex())
                    
                    # Insert entity hub
                    cursor.execute("""
                        INSERT INTO business.entity_h (entity_hk, entity_bk, tenant_hk, load_date, record_source)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (entity_bk, tenant_hk) DO NOTHING
                    """, (entity_hk, entity_bk, tenant_hk, self.get_current_load_date(), 'MOCK_DATA_GENERATOR'))
                    
                    # Generate entity details
                    entity_type = random.choice(self.entity_types)
                    tax_id = f"{random.randint(10, 99)}-{random.randint(1000000, 9999999)}"
                    formation_date = self.fake.date_between(start_date='-10y', end_date='-1y')
                    annual_revenue = random.randint(100000, 50000000)
                    employee_count = random.randint(1, 500)
                    
                    hash_diff = self.generate_hash_diff(
                        company_name, entity_type, tax_id, str(annual_revenue)
                    )
                    
                    cursor.execute("""
                        INSERT INTO business.entity_details_s (
                            entity_hk, load_date, hash_diff, entity_name, entity_type,
                            tax_id, formation_date, status, description, annual_revenue,
                            employee_count, record_source
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        entity_hk, self.get_current_load_date(), hash_diff,
                        company_name, entity_type, tax_id, formation_date,
                        'Active', self.fake.catch_phrase(), annual_revenue,
                        employee_count, 'MOCK_DATA_GENERATOR'
                    ))
                    
                    entity_hks.append(entity_hk)
                    self.generation_stats['entities_created'] += 1
        
        logging.info(f"Generated {len(entity_hks)} business entities")
        return entity_hks
    
    def generate_assets(self, entity_hks: List[bytes], tenant_hks: List[bytes], assets_per_entity: int) -> List[bytes]:
        """Generate mock asset data"""
        asset_hks = []
        
        with self.connection.cursor() as cursor:
            for entity_hk in entity_hks:
                # Get corresponding tenant_hk
                tenant_hk = random.choice(tenant_hks)  # Simplified assignment
                
                for i in range(assets_per_entity):
                    # Generate asset data
                    asset_type = random.choice(self.asset_types)
                    asset_name = f"{asset_type} {self.fake.word().title()} {i+1}"
                    asset_bk = f"ASSET_{asset_name.replace(' ', '_').upper()}_{entity_hk.hex()[:8]}"
                    asset_hk = self.generate_hash_key(asset_bk + tenant_hk.hex())
                    
                    # Insert asset hub
                    cursor.execute("""
                        INSERT INTO business.asset_h (asset_hk, asset_bk, tenant_hk, load_date, record_source)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (asset_bk, tenant_hk) DO NOTHING
                    """, (asset_hk, asset_bk, tenant_hk, self.get_current_load_date(), 'MOCK_DATA_GENERATOR'))
                    
                    # Generate asset details
                    purchase_price = random.randint(1000, 500000)
                    current_value = purchase_price * random.uniform(0.3, 1.2)  # Depreciation/appreciation
                    purchase_date = self.fake.date_between(start_date='-5y', end_date='now')
                    useful_life = random.randint(3, 20)
                    
                    depreciation_methods = ['Straight-line', 'Double-declining', 'Sum-of-years', 'Units-of-production']
                    
                    hash_diff = self.generate_hash_diff(
                        asset_name, asset_type, str(purchase_price), str(current_value)
                    )
                    
                    cursor.execute("""
                        INSERT INTO business.asset_details_s (
                            asset_hk, load_date, hash_diff, asset_name, asset_type,
                            purchase_price, current_value, purchase_date, depreciation_method,
                            useful_life_years, description, record_source
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        asset_hk, self.get_current_load_date(), hash_diff,
                        asset_name, asset_type, purchase_price, current_value,
                        purchase_date, random.choice(depreciation_methods),
                        useful_life, self.fake.text(max_nb_chars=200), 'MOCK_DATA_GENERATOR'
                    ))
                    
                    asset_hks.append(asset_hk)
                    self.generation_stats['assets_created'] += 1
        
        logging.info(f"Generated {len(asset_hks)} assets")
        return asset_hks
    
    def generate_transactions(self, entity_hks: List[bytes], tenant_hks: List[bytes], transactions_per_entity: int) -> List[bytes]:
        """Generate mock transaction data"""
        transaction_hks = []
        
        with self.connection.cursor() as cursor:
            for entity_hk in entity_hks:
                # Get corresponding tenant_hk
                tenant_hk = random.choice(tenant_hks)  # Simplified assignment
                
                for i in range(transactions_per_entity):
                    # Generate transaction data
                    transaction_type = random.choice(self.transaction_types)
                    transaction_id = f"TXN_{random.randint(100000, 999999)}"
                    transaction_bk = f"TRANSACTION_{transaction_id}_{entity_hk.hex()[:8]}"
                    transaction_hk = self.generate_hash_key(transaction_bk + tenant_hk.hex())
                    
                    # Insert transaction hub
                    cursor.execute("""
                        INSERT INTO business.transaction_h (transaction_hk, transaction_bk, tenant_hk, load_date, record_source)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (transaction_bk, tenant_hk) DO NOTHING
                    """, (transaction_hk, transaction_bk, tenant_hk, self.get_current_load_date(), 'MOCK_DATA_GENERATOR'))
                    
                    # Generate transaction details
                    amount = random.uniform(100, 100000)
                    transaction_date = self.fake.date_between(start_date='-1y', end_date='now')
                    counterparty = self.fake.company()
                    payment_methods = ['Cash', 'Check', 'Credit Card', 'Bank Transfer', 'ACH']
                    statuses = ['Completed', 'Pending', 'Failed', 'Cancelled']
                    
                    hash_diff = self.generate_hash_diff(
                        transaction_type, str(amount), str(transaction_date), counterparty
                    )
                    
                    cursor.execute("""
                        INSERT INTO business.transaction_details_s (
                            transaction_hk, load_date, hash_diff, transaction_type, amount,
                            transaction_date, description, counterparty, payment_method,
                            status, record_source
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        transaction_hk, self.get_current_load_date(), hash_diff,
                        transaction_type, amount, transaction_date,
                        f"{transaction_type} transaction with {counterparty}",
                        counterparty, random.choice(payment_methods),
                        random.choice(statuses), 'MOCK_DATA_GENERATOR'
                    ))
                    
                    transaction_hks.append(transaction_hk)
                    self.generation_stats['transactions_created'] += 1
        
        logging.info(f"Generated {len(transaction_hks)} transactions")
        return transaction_hks
    
    def generate_audit_records(self, tenant_hks: List[bytes], num_audit_records: int = 1000) -> None:
        """Generate mock audit records"""
        
        with self.connection.cursor() as cursor:
            for i in range(num_audit_records):
                tenant_hk = random.choice(tenant_hks)
                
                # Generate audit event data
                event_types = ['USER_LOGIN', 'DATA_ACCESS', 'DATA_MODIFICATION', 'REPORT_GENERATION', 'SYSTEM_ACCESS']
                table_names = ['auth.user_profile_s', 'business.entity_details_s', 'business.transaction_details_s']
                operations = ['SELECT', 'INSERT', 'UPDATE', 'DELETE']
                
                audit_bk = f"AUDIT_{random.randint(100000, 999999)}_{i}"
                audit_hk = self.generate_hash_key(audit_bk + tenant_hk.hex())
                
                # Insert audit event hub
                cursor.execute("""
                    INSERT INTO audit.audit_event_h (audit_event_hk, audit_event_bk, tenant_hk, load_date, record_source)
                    VALUES (%s, %s, %s, %s, %s)
                """, (audit_hk, audit_bk, tenant_hk, self.get_current_load_date(), 'MOCK_DATA_GENERATOR'))
                
                # Generate audit details
                event_type = random.choice(event_types)
                table_name = random.choice(table_names)
                operation = random.choice(operations)
                user_id = f"user_{random.randint(1, 100)}"
                
                hash_diff = self.generate_hash_diff(
                    event_type, table_name, operation, user_id
                )
                
                old_values = {"field1": "old_value", "field2": random.randint(1, 100)}
                new_values = {"field1": "new_value", "field2": random.randint(1, 100)}
                
                cursor.execute("""
                    INSERT INTO audit.audit_detail_s (
                        audit_event_hk, load_date, hash_diff, event_type, table_name,
                        operation, user_id, ip_address, user_agent, event_timestamp,
                        old_values, new_values, record_source
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    audit_hk, self.get_current_load_date(), hash_diff,
                    event_type, table_name, operation, user_id,
                    self.fake.ipv4(), self.fake.user_agent(),
                    self.fake.date_time_between(start_date='-30d', end_date='now'),
                    json.dumps(old_values), json.dumps(new_values), 'MOCK_DATA_GENERATOR'
                ))
                
                self.generation_stats['audit_records_created'] += 1
        
        logging.info(f"Generated {num_audit_records} audit records")
    
    def generate_all_mock_data(self) -> Dict[str, Any]:
        """Generate complete mock dataset"""
        config = self.config['mock_data']
        
        logging.info("🏗️  Starting mock data generation...")
        
        # Step 1: Create schema and tables
        self.create_schema_structure()
        self.create_basic_tables()
        
        # Step 2: Generate tenants
        tenant_hks = self.generate_tenants(config['num_tenants'])
        
        # Step 3: Generate users
        user_hks = self.generate_users(tenant_hks, config['users_per_tenant'])
        
        # Step 4: Generate business entities
        entity_hks = self.generate_entities(tenant_hks, config['entities_per_tenant'])
        
        # Step 5: Generate assets
        asset_hks = self.generate_assets(entity_hks, tenant_hks, config['assets_per_entity'])
        
        # Step 6: Generate transactions
        transaction_hks = self.generate_transactions(entity_hks, tenant_hks, config['transactions_per_entity'])
        
        # Step 7: Generate audit records
        self.generate_audit_records(tenant_hks, 1000)
        
        # Generate summary report
        summary = {
            'generation_timestamp': datetime.now().isoformat(),
            'database': self.config['database']['database'],
            'statistics': self.generation_stats,
            'configuration_used': config,
            'total_records_created': sum(self.generation_stats.values())
        }
        
        return summary
    
    def save_report(self, summary: Dict[str, Any]) -> None:
        """Save generation report"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"mock_data_generation_report_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump(summary, f, indent=2, default=str)
        
        logging.info(f"Generation report saved to: {filename}")
    
    def close(self) -> None:
        """Close database connection"""
        if self.connection:
            self.connection.close()
            logging.info("Database connection closed")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Generate mock data for One Vault platform')
    parser.add_argument('--config', default='config.yaml', help='Configuration file path')
    parser.add_argument('--create-db', action='store_true', help='Create test database if it doesn\'t exist')
    
    args = parser.parse_args()
    
    print("🎭 One Vault Mock Data Generator")
    print("===============================")
    
    generator = MockDataGenerator(args.config)
    
    try:
        # Connect to database
        generator.connect(create_test_db=args.create_db)
        
        # Generate all mock data
        summary = generator.generate_all_mock_data()
        
        # Display summary
        print(f"\n📊 MOCK DATA GENERATION COMPLETE")
        print(f"=================================")
        print(f"Database: {generator.config['database']['database']}")
        print(f"Tenants: {summary['statistics']['tenants_created']}")
        print(f"Users: {summary['statistics']['users_created']}")
        print(f"Entities: {summary['statistics']['entities_created']}")
        print(f"Assets: {summary['statistics']['assets_created']}")
        print(f"Transactions: {summary['statistics']['transactions_created']}")
        print(f"Audit Records: {summary['statistics']['audit_records_created']}")
        print(f"Total Records: {summary['total_records_created']}")
        
        # Save report
        generator.save_report(summary)
        
        print(f"\n🎉 Mock data generation completed successfully!")
        
    except Exception as e:
        logging.error(f"Mock data generation failed: {e}")
        return 1
    
    finally:
        generator.close()
    
    return 0


if __name__ == "__main__":
    sys.exit(main()) 