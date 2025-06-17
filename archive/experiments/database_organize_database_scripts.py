#!/usr/bin/env python3
"""
Database Script Organization Tool
Organizes scattered SQL scripts into proper migration structure for Git version control
"""

import os
import re
import json
import shutil
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Tuple, Optional
import yaml

class DatabaseScriptOrganizer:
    def __init__(self, database_root: str = "."):
        self.database_root = Path(database_root)
        self.scripts_dir = self.database_root / "scripts"
        self.legacy_dir = self.database_root / "legacy_scripts"
        self.migrations_dir = self.database_root / "migrations"
        self.organized_dir = self.database_root / "organized_migrations"
        
        # Migration patterns to identify script types
        self.script_patterns = {
            'dbCreation': r'dbCreation_(\d+).*\.sql',
            'schema_creation': r'.*schema.*\.sql',
            'table_creation': r'.*(create|table).*\.sql',
            'function_creation': r'.*(function|procedure).*\.sql',
            'index_creation': r'.*index.*\.sql',
            'data_insertion': r'.*(insert|data).*\.sql',
            'migration': r'.*migration.*\.sql',
            'rollback': r'.*rollback.*\.sql',
            'deployment': r'.*deploy.*\.sql',
            'monitoring': r'.*monitoring.*\.sql',
            'ai_related': r'.*ai.*\.sql',
            'backup': r'.*backup.*\.sql',
            'performance': r'.*performance.*\.sql'
        }
        
        self.script_inventory = []
        self.analysis_results = {}
        
    def create_directory_structure(self):
        """Create organized directory structure"""
        print("🗂️ Creating organized directory structure...")
        
        directories = [
            # Main organized structure
            self.legacy_dir,
            self.organized_dir,
            self.organized_dir / "01_foundation",
            self.organized_dir / "02_core_schemas", 
            self.organized_dir / "03_auth_system",
            self.organized_dir / "04_business_logic",
            self.organized_dir / "05_data_vault_tables",
            self.organized_dir / "06_functions_procedures",
            self.organized_dir / "07_indexes_performance",
            self.organized_dir / "08_ai_ml_systems",
            self.organized_dir / "09_monitoring_audit",
            self.organized_dir / "10_reference_data",
            self.organized_dir / "99_production_enhancements",
            
            # Enhanced legacy structure - organized like main structure
            self.legacy_dir / "historical_migrations",
            self.legacy_dir / "historical_migrations" / "01_original_foundation",
            self.legacy_dir / "historical_migrations" / "02_original_schemas",
            self.legacy_dir / "historical_migrations" / "03_original_auth",
            self.legacy_dir / "historical_migrations" / "04_original_business_logic",
            self.legacy_dir / "historical_migrations" / "05_original_data_structures",
            self.legacy_dir / "historical_migrations" / "06_original_functions",
            self.legacy_dir / "historical_migrations" / "07_original_performance",
            self.legacy_dir / "historical_migrations" / "08_original_ai_integration",
            self.legacy_dir / "historical_migrations" / "09_original_monitoring",
            
            # Iteration tracking
            self.legacy_dir / "iterations",
            self.legacy_dir / "iterations" / "first_iteration", 
            self.legacy_dir / "iterations" / "second_iteration",
            self.legacy_dir / "iterations" / "third_iteration",
            
            # Testing and validation 
            self.legacy_dir / "testing_validation",
            self.legacy_dir / "testing_validation" / "authentication_tests",
            self.legacy_dir / "testing_validation" / "security_tests", 
            self.legacy_dir / "testing_validation" / "performance_tests",
            self.legacy_dir / "testing_validation" / "compliance_tests",
            self.legacy_dir / "testing_validation" / "user_management_tests",
            
            # Development artifacts
            self.legacy_dir / "development_artifacts",
            self.legacy_dir / "development_artifacts" / "investigation_results",
            self.legacy_dir / "development_artifacts" / "debugging_scripts",
            self.legacy_dir / "development_artifacts" / "config_experiments",
            
            # Archive for cleanup
            self.legacy_dir / "archive",
            self.legacy_dir / "archive" / "duplicates",
            self.legacy_dir / "archive" / "unorganized",
            self.legacy_dir / "archive" / "deprecated"
        ]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            print(f"  ✅ Created: {directory}")
    
    def scan_all_scripts(self) -> List[Dict]:
        """Scan all SQL scripts and gather metadata"""
        print("🔍 Scanning all SQL scripts...")
        
        scripts = []
        
        # Scan main scripts directory recursively (includes /legacy subfolder!)
        for sql_file in self.scripts_dir.rglob("*.sql"):
            script_info = self.analyze_script(sql_file)
            scripts.append(script_info)
        
        # Also scan other common locations
        other_locations = [
            self.database_root / "migration_scripts",
            self.database_root,  # Root level
        ]
        
        for location in other_locations:
            if location.exists():
                for sql_file in location.rglob("*.sql"):
                    script_info = self.analyze_script(sql_file)
                    scripts.append(script_info)
        
        self.script_inventory = scripts
        print(f"  📊 Found {len(scripts)} SQL scripts")
        return scripts
    
    def analyze_script(self, script_path: Path) -> Dict:
        """Analyze a single script and extract metadata"""
        try:
            with open(script_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
        except Exception as e:
            content = ""
        
        script_info = {
            'path': str(script_path),
            'relative_path': str(script_path.relative_to(self.database_root)),
            'filename': script_path.name,
            'size': script_path.stat().st_size,
            'modified': datetime.fromtimestamp(script_path.stat().st_mtime),
            'content_preview': content[:500] if content else "",
            'line_count': len(content.splitlines()) if content else 0,
            'type': self.classify_script_type(script_path.name, content),
            'priority': self.determine_priority(script_path.name, content),
            'dependencies': self.extract_dependencies(content),
            'schemas_created': self.extract_schemas(content),
            'tables_created': self.extract_tables(content),
            'functions_created': self.extract_functions(content),
            'is_duplicate': False,
            'suggested_location': None
        }
        
        # Determine suggested organization location
        script_info['suggested_location'] = self.suggest_organization_location(script_info)
        
        return script_info
    
    def classify_script_type(self, filename: str, content: str) -> str:
        """Classify script type based on filename and content"""
        filename_lower = filename.lower()
        content_lower = content.lower()
        
        # Check patterns in order of specificity
        if re.search(self.script_patterns['dbCreation'], filename):
            return 'dbCreation_sequence'
        elif 'investigation' in filename_lower or '.json' in filename:
            return 'investigation_result'
        elif 'test' in filename_lower:
            return 'test_script'
        elif 'config' in filename_lower:
            return 'configuration'
        elif re.search(self.script_patterns['ai_related'], filename_lower):
            return 'ai_ml_system'
        elif 'monitoring' in filename_lower:
            return 'monitoring_system'
        elif 'backup' in filename_lower:
            return 'backup_system'
        elif 'performance' in filename_lower:
            return 'performance_optimization'
        elif 'deploy' in filename_lower:
            return 'deployment_script'
        elif 'rollback' in filename_lower:
            return 'rollback_script'
        elif 'schema' in content_lower and 'create schema' in content_lower:
            return 'schema_creation'
        elif 'create table' in content_lower:
            return 'table_creation'
        elif 'create function' in content_lower or 'create or replace function' in content_lower:
            return 'function_creation'
        elif 'create index' in content_lower:
            return 'index_creation'
        else:
            return 'unknown'
    
    def determine_priority(self, filename: str, content: str) -> int:
        """Determine execution priority (1=first, 99=last)"""
        filename_lower = filename.lower()
        
        # Extract dbCreation number if present
        match = re.search(r'dbcreation_(\d+)', filename_lower)
        if match:
            return int(match.group(1))
        
        # Priority based on content type
        if 'create schema' in content.lower():
            return 1
        elif 'util' in filename_lower and 'function' in content.lower():
            return 2
        elif 'auth' in filename_lower:
            return 3
        elif 'business' in filename_lower:
            return 4
        elif 'table' in content.lower() and 'create table' in content.lower():
            return 5
        elif 'function' in content.lower():
            return 6
        elif 'index' in content.lower():
            return 7
        elif 'ai' in filename_lower:
            return 8
        elif 'monitoring' in filename_lower:
            return 9
        elif 'performance' in filename_lower:
            return 10
        else:
            return 50
    
    def extract_dependencies(self, content: str) -> List[str]:
        """Extract script dependencies from content"""
        dependencies = []
        
        # Look for explicit dependency comments
        dep_patterns = [
            r'-- Dependencies?:\s*(.+)',
            r'-- Requires?:\s*(.+)',
            r'-- Must run after:\s*(.+)'
        ]
        
        for pattern in dep_patterns:
            matches = re.findall(pattern, content, re.IGNORECASE)
            dependencies.extend(matches)
        
        return dependencies
    
    def extract_schemas(self, content: str) -> List[str]:
        """Extract schema names from CREATE SCHEMA statements"""
        pattern = r'CREATE SCHEMA(?:\s+IF NOT EXISTS)?\s+(\w+)'
        return re.findall(pattern, content, re.IGNORECASE)
    
    def extract_tables(self, content: str) -> List[str]:
        """Extract table names from CREATE TABLE statements"""
        pattern = r'CREATE TABLE(?:\s+IF NOT EXISTS)?\s+(?:(\w+)\.)?(\w+)'
        matches = re.findall(pattern, content, re.IGNORECASE)
        return [f"{schema}.{table}" if schema else table for schema, table in matches]
    
    def extract_functions(self, content: str) -> List[str]:
        """Extract function names from CREATE FUNCTION statements"""
        pattern = r'CREATE(?:\s+OR\s+REPLACE)?\s+FUNCTION\s+(?:(\w+)\.)?(\w+)'
        matches = re.findall(pattern, content, re.IGNORECASE)
        return [f"{schema}.{func}" if schema else func for schema, func in matches]
    
    def suggest_organization_location(self, script_info: Dict) -> str:
        """Suggest where to organize this script"""
        script_type = script_info['type']
        filename = script_info['filename'].lower()
        relative_path = script_info['relative_path'].lower()
        priority = script_info['priority']
        
        # Handle legacy folder scripts with special logic
        if 'scripts/legacy' in relative_path or 'scripts\\legacy' in relative_path:
            return self.categorize_legacy_script(script_info, relative_path)
        
        # Standard categorization for current scripts
        if script_type == 'investigation_result':
            return 'legacy_scripts/development_artifacts/investigation_results'
        elif script_type == 'test_script':
            return 'legacy_scripts/testing_validation/authentication_tests'
        elif script_type == 'configuration':
            return 'legacy_scripts/development_artifacts/config_experiments'
        elif script_type == 'dbCreation_sequence':
            if priority <= 5:
                return 'organized_migrations/01_foundation'
            elif priority <= 10:
                return 'organized_migrations/02_core_schemas'
            elif priority <= 15:
                return 'organized_migrations/03_auth_system'
            elif priority <= 20:
                return 'organized_migrations/04_business_logic'
            else:
                return 'organized_migrations/05_data_vault_tables'
        elif script_type == 'schema_creation':
            return 'organized_migrations/02_core_schemas'
        elif script_type == 'ai_ml_system':
            return 'organized_migrations/08_ai_ml_systems'
        elif script_type == 'monitoring_system':
            return 'organized_migrations/09_monitoring_audit'
        elif script_type == 'performance_optimization':
            return 'organized_migrations/07_indexes_performance'
        elif script_type == 'backup_system':
            return 'organized_migrations/99_production_enhancements'
        elif script_type == 'function_creation':
            return 'organized_migrations/06_functions_procedures'
        else:
            return 'legacy_scripts/archive/unorganized'
    
    def categorize_legacy_script(self, script_info: Dict, relative_path: str) -> str:
        """Categorize scripts from the legacy folder structure"""
        filename = script_info['filename'].lower()
        script_type = script_info['type']
        priority = script_info['priority']
        
        # Original DB Creation scripts - these are the FOUNDATION!
        if 'original db creation' in relative_path:
            if script_type == 'dbCreation_sequence':
                if priority <= 5:
                    return 'legacy_scripts/historical_migrations/01_original_foundation'
                elif priority <= 10:
                    return 'legacy_scripts/historical_migrations/02_original_schemas'
                elif priority <= 15:
                    return 'legacy_scripts/historical_migrations/03_original_auth'
                elif priority <= 25:
                    return 'legacy_scripts/historical_migrations/04_original_business_logic'
                elif priority <= 35:
                    return 'legacy_scripts/historical_migrations/05_original_data_structures'
                else:
                    return 'legacy_scripts/historical_migrations/06_original_functions'
            else:
                return 'legacy_scripts/historical_migrations/01_original_foundation'
        
        # Second Iteration scripts
        elif 'second iteration' in relative_path:
            return 'legacy_scripts/iterations/second_iteration'
        
        # Initial AI Integration scripts
        elif 'initial ai integration' in relative_path:
            return 'legacy_scripts/historical_migrations/08_original_ai_integration'
        
        # Testing scripts - categorize by function
        elif 'testing' in relative_path or 'test' in filename:
            if 'auth' in filename or 'login' in filename or 'password' in filename:
                return 'legacy_scripts/testing_validation/authentication_tests'
            elif 'security' in filename or 'sox' in filename or 'xss' in filename:
                return 'legacy_scripts/testing_validation/security_tests'
            elif 'performance' in filename or 'database_performance' in filename:
                return 'legacy_scripts/testing_validation/performance_tests'
            elif 'compliance' in filename or 'sox_compliance' in filename:
                return 'legacy_scripts/testing_validation/compliance_tests'
            elif 'user' in filename or 'readonly' in filename or 'implementation' in filename:
                return 'legacy_scripts/testing_validation/user_management_tests'
            else:
                return 'legacy_scripts/testing_validation/authentication_tests'
        
        # Debug/investigation scripts
        elif 'debug' in filename or 'investigate' in filename or 'diagnose' in filename:
            return 'legacy_scripts/development_artifacts/debugging_scripts'
        
        # Default for other legacy scripts
        else:
            return 'legacy_scripts/iterations/first_iteration'
    
    def detect_duplicates(self):
        """Detect potential duplicate scripts"""
        print("🔍 Detecting duplicate scripts...")
        
        # Group by filename
        filename_groups = {}
        for script in self.script_inventory:
            filename = script['filename']
            if filename not in filename_groups:
                filename_groups[filename] = []
            filename_groups[filename].append(script)
        
        duplicates_found = 0
        for filename, scripts in filename_groups.items():
            if len(scripts) > 1:
                duplicates_found += 1
                print(f"  ⚠️ Duplicate filename: {filename} ({len(scripts)} copies)")
                
                # Mark all but the newest as duplicates
                scripts.sort(key=lambda x: x['modified'], reverse=True)
                for i, script in enumerate(scripts):
                    if i > 0:  # Keep the newest, mark others as duplicate
                        script['is_duplicate'] = True
                        script['suggested_location'] = 'legacy_scripts/duplicates'
        
        print(f"  📊 Found {duplicates_found} sets of duplicate filenames")
    
    def organize_scripts(self):
        """Organize scripts into proper structure"""
        print("📁 Organizing scripts...")
        
        organized_count = 0
        for script in self.script_inventory:
            source_path = Path(script['path'])
            suggested_location = script['suggested_location']
            
            if suggested_location:
                dest_dir = self.database_root / suggested_location
                dest_path = dest_dir / script['filename']
                
                # Handle filename conflicts
                if dest_path.exists():
                    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                    name, ext = os.path.splitext(script['filename'])
                    dest_path = dest_dir / f"{name}_{timestamp}{ext}"
                
                try:
                    shutil.copy2(source_path, dest_path)
                    organized_count += 1
                    print(f"  ✅ Moved: {script['relative_path']} → {suggested_location}")
                except Exception as e:
                    print(f"  ❌ Error moving {script['filename']}: {e}")
        
        print(f"  📊 Organized {organized_count} scripts")
    
    def run_full_organization(self):
        """Run the complete organization process"""
        print("🚀 Starting Database Script Organization...")
        print("=" * 60)
        
        # Step 1: Create directory structure
        self.create_directory_structure()
        print()
        
        # Step 2: Scan all scripts
        self.scan_all_scripts()
        print()
        
        # Step 3: Detect duplicates
        self.detect_duplicates()
        print()
        
        # Step 4: Organize scripts
        self.organize_scripts()
        print()
        
        print("✅ Database Script Organization Complete!")
        print("=" * 60)
        print("📋 Next steps:")
        print("   1. Review organized_migrations/ for proper migration order")
        print("   2. Review legacy_scripts/ for anything important")
        print("   3. Use Git version control GUI for proper migrations")

def main():
    organizer = DatabaseScriptOrganizer()
    organizer.run_full_organization()

if __name__ == "__main__":
    main() 