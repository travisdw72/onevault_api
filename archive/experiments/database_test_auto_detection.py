#!/usr/bin/env python3
"""Test script to demonstrate auto-detection capabilities"""

from organize_database_scripts import DatabaseScriptOrganizer

def test_detection():
    organizer = DatabaseScriptOrganizer()
    
    # Test different script types
    test_cases = [
        {
            'filename': 'create_multiple_schemas.sql',
            'content': '''
-- Multi-schema setup script
CREATE SCHEMA IF NOT EXISTS finance;
CREATE SCHEMA IF NOT EXISTS inventory; 
CREATE SCHEMA IF NOT EXISTS reporting;
CREATE SCHEMA monitoring;
            '''
        },
        {
            'filename': 'business_tables.sql', 
            'content': '''
CREATE TABLE business.customers (
    customer_id SERIAL PRIMARY KEY,
    name VARCHAR(100)
);
CREATE TABLE business.orders (id SERIAL);
            '''
        },
        {
            'filename': 'ai_monitoring_functions.sql',
            'content': '''
CREATE OR REPLACE FUNCTION ai.monitor_performance()
RETURNS TABLE(metric VARCHAR, value DECIMAL) AS $$
BEGIN
    -- AI monitoring logic
END;
$$ LANGUAGE plpgsql;
            '''
        }
    ]
    
    print("🧠 Auto-Detection Test Results:")
    print("=" * 50)
    
    for test in test_cases:
        script_type = organizer.classify_script_type(test['filename'], test['content'])
        script_info = {
            'type': script_type,
            'filename': test['filename'], 
            'priority': organizer.determine_priority(test['filename'], test['content'])
        }
        location = organizer.suggest_organization_location(script_info)
        schemas = organizer.extract_schemas(test['content'])
        tables = organizer.extract_tables(test['content'])
        functions = organizer.extract_functions(test['content'])
        
        print(f"\n📄 File: {test['filename']}")
        print(f"   Type: {script_type}")
        print(f"   Auto-Location: {location}")
        print(f"   Priority: {script_info['priority']}")
        if schemas:
            print(f"   Schemas Found: {schemas}")
        if tables:
            print(f"   Tables Found: {tables}")
        if functions:
            print(f"   Functions Found: {functions}")

if __name__ == "__main__":
    test_detection() 