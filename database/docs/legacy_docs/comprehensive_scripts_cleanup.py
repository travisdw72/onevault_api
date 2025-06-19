#!/usr/bin/env python3
"""
Comprehensive Scripts Cleanup - Phase 2
Removes duplicates and organizes remaining files in database/scripts/

This script:
1. Identifies duplicates between scripts/ and organized_migrations/
2. Moves remaining files to appropriate organized_migrations/ subdirectories
3. Archives documentation properly
4. Removes cleanup artifacts that were added to scripts/
5. Leaves only essential raw/staging SQL scripts in scripts/
"""

import os
import shutil
import json
from datetime import datetime
from pathlib import Path
import hashlib

# Configuration
SCRIPTS_DIR = Path("database/scripts")
ORGANIZED_MIGRATIONS_DIR = Path("database/organized_migrations") 
ARCHIVE_DIR = Path("archive")
TOOLS_DIR = Path("database/tools")

def calculate_file_hash(file_path):
    """Calculate SHA-256 hash of file content for duplicate detection"""
    try:
        with open(file_path, 'rb') as f:
            return hashlib.sha256(f.read()).hexdigest()
    except Exception:
        return None

def find_duplicates():
    """Find files in scripts/ that already exist in organized_migrations/"""
    duplicates = []
    scripts_files = {}
    
    # Index all files in scripts/ with their hashes
    for file_path in SCRIPTS_DIR.rglob("*"):
        if file_path.is_file() and not file_path.name.startswith('.'):
            file_hash = calculate_file_hash(file_path)
            if file_hash:
                scripts_files[file_path.name] = {
                    'path': file_path,
                    'hash': file_hash,
                    'size': file_path.stat().st_size
                }
    
    # Check organized_migrations for matches
    for file_path in ORGANIZED_MIGRATIONS_DIR.rglob("*"):
        if file_path.is_file() and file_path.name in scripts_files:
            scripts_file = scripts_files[file_path.name]
            org_hash = calculate_file_hash(file_path)
            
            if org_hash and scripts_file['hash'] == org_hash:
                duplicates.append({
                    'scripts_path': scripts_file['path'],
                    'organized_path': file_path,
                    'name': file_path.name,
                    'size': scripts_file['size']
                })
    
    return duplicates

def get_file_destination(file_path):
    """Determine appropriate organized_migrations destination for a file"""
    file_name = file_path.name.lower()
    
    # AI/ML related files
    if any(keyword in file_name for keyword in ['ai_', 'ml_', 'agent', 'llm', 'openai']):
        return ORGANIZED_MIGRATIONS_DIR / "08_ai_ml_systems"
    
    # Schema creation files
    if any(keyword in file_name for keyword in ['schema', 'database', 'create_']):
        return ORGANIZED_MIGRATIONS_DIR / "02_core_schemas"
    
    # Authentication/security files  
    if any(keyword in file_name for keyword in ['auth', 'security', 'password', 'rbac']):
        return ORGANIZED_MIGRATIONS_DIR / "03_auth_system"
    
    # Compliance files
    if any(keyword in file_name for keyword in ['sox', 'compliance', 'hipaa', 'gdpr']):
        return ORGANIZED_MIGRATIONS_DIR / "02_core_schemas"
    
    # Performance/indexes
    if any(keyword in file_name for keyword in ['index', 'performance', 'optimization']):
        return ORGANIZED_MIGRATIONS_DIR / "07_indexes_performance"
    
    # Functions and procedures
    if any(keyword in file_name for keyword in ['function', 'procedure', 'proc_']):
        return ORGANIZED_MIGRATIONS_DIR / "06_functions_procedures"
    
    # Monitoring and audit
    if any(keyword in file_name for keyword in ['monitor', 'audit', 'log']):
        return ORGANIZED_MIGRATIONS_DIR / "09_monitoring_audit"
    
    # Default to core schemas for other SQL files
    if file_path.suffix.lower() == '.sql':
        return ORGANIZED_MIGRATIONS_DIR / "02_core_schemas"
    
    # Documentation to archive
    if file_path.suffix.lower() in ['.md', '.txt']:
        return ARCHIVE_DIR / "documentation"
    
    return None

def cleanup_scripts_directory():
    """Main cleanup function"""
    cleanup_log = {
        'timestamp': datetime.now().isoformat(),
        'actions': [],
        'duplicates_removed': [],
        'files_moved': [],
        'errors': []
    }
    
    print("🧹 Starting Comprehensive Scripts Cleanup - Phase 2")
    print("=" * 60)
    
    # Step 1: Remove duplicates
    print("\n📊 Step 1: Identifying and removing duplicates...")
    duplicates = find_duplicates()
    
    for duplicate in duplicates:
        try:
            scripts_path = duplicate['scripts_path']
            organized_path = duplicate['organized_path']
            
            print(f"  🗑️  Removing duplicate: {scripts_path.relative_to(SCRIPTS_DIR)}")
            print(f"      (Already exists in: {organized_path.relative_to(ORGANIZED_MIGRATIONS_DIR)})")
            
            scripts_path.unlink()
            cleanup_log['duplicates_removed'].append({
                'file': str(scripts_path),
                'duplicate_of': str(organized_path),
                'size_bytes': duplicate['size']
            })
            
        except Exception as e:
            error_msg = f"Error removing duplicate {scripts_path}: {e}"
            print(f"  ❌ {error_msg}")
            cleanup_log['errors'].append(error_msg)
    
    # Step 2: Remove cleanup artifacts that were mistakenly added to scripts/
    print("\n📊 Step 2: Removing cleanup artifacts from scripts/...")
    artifacts_to_remove = [
        'CLEANUP_SUMMARY.md',
        'cleanup_scripts_folder.py'
    ]
    
    for artifact in artifacts_to_remove:
        artifact_path = SCRIPTS_DIR / artifact
        if artifact_path.exists():
            try:
                print(f"  🗑️  Removing artifact: {artifact}")
                artifact_path.unlink()
                cleanup_log['actions'].append(f"Removed artifact: {artifact}")
            except Exception as e:
                error_msg = f"Error removing artifact {artifact}: {e}"
                print(f"  ❌ {error_msg}")
                cleanup_log['errors'].append(error_msg)
    
    # Step 3: Move remaining files to appropriate locations
    print("\n📊 Step 3: Moving remaining files to appropriate locations...")
    
    # Essential files that should stay in scripts/
    essential_files = {
        '01_create_raw_schema.sql',
        '02_create_staging_schema.sql', 
        '03_create_raw_staging_functions.sql',
        '04_create_raw_staging_indexes_fixed.sql',
        'enhanced_database_version_control.sql'
    }
    
    for file_path in SCRIPTS_DIR.iterdir():
        if file_path.is_file() and file_path.name not in essential_files:
            # Skip files in subdirectories we created
            if any(parent.name in ['tools', 'testing', 'demos', 'archive'] for parent in file_path.parents):
                continue
                
            destination = get_file_destination(file_path)
            if destination:
                try:
                    destination.mkdir(parents=True, exist_ok=True)
                    dest_file = destination / file_path.name
                    
                    # Avoid overwriting existing files
                    if dest_file.exists():
                        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                        dest_file = destination / f"{file_path.stem}_{timestamp}{file_path.suffix}"
                    
                    print(f"  📁 Moving: {file_path.name}")
                    print(f"      → {dest_file.relative_to(Path.cwd())}")
                    
                    shutil.move(str(file_path), str(dest_file))
                    cleanup_log['files_moved'].append({
                        'from': str(file_path),
                        'to': str(dest_file)
                    })
                    
                except Exception as e:
                    error_msg = f"Error moving {file_path}: {e}"
                    print(f"  ❌ {error_msg}")
                    cleanup_log['errors'].append(error_msg)
    
    # Step 4: Create summary
    total_duplicates = len(cleanup_log['duplicates_removed'])
    total_moved = len(cleanup_log['files_moved']) 
    total_errors = len(cleanup_log['errors'])
    
    print("\n" + "=" * 60)
    print("🎯 Cleanup Complete!")
    print(f"  📊 Duplicates removed: {total_duplicates}")
    print(f"  📁 Files moved: {total_moved}")
    print(f"  ❌ Errors: {total_errors}")
    
    if total_errors == 0:
        print("  ✅ All operations successful!")
    
    # Step 5: Save cleanup log
    log_file = ARCHIVE_DIR / f"comprehensive_cleanup_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    log_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(log_file, 'w') as f:
        json.dump(cleanup_log, f, indent=2)
    
    print(f"  📋 Cleanup log saved: {log_file}")
    
    # Step 6: Show final structure
    print("\n📁 Final scripts/ directory structure:")
    for item in sorted(SCRIPTS_DIR.iterdir()):
        if item.is_file():
            print(f"  📄 {item.name}")
        elif item.is_dir():
            print(f"  📁 {item.name}/")
            for subitem in sorted(item.iterdir()):
                if subitem.is_file():
                    print(f"    📄 {subitem.name}")
                elif subitem.is_dir():
                    file_count = len(list(subitem.rglob('*')))
                    print(f"    📁 {subitem.name}/ ({file_count} items)")
    
    print("\n🚀 Ready for function testing in clean environment!")
    return cleanup_log

if __name__ == "__main__":
    try:
        cleanup_log = cleanup_scripts_directory()
        
        # Summary message
        if len(cleanup_log['errors']) == 0:
            print("\n✅ SUCCESS: Scripts directory is now professionally organized!")
            print("🔧 Next step: Test database functions in clean environment")
        else:
            print("\n⚠️  COMPLETED WITH WARNINGS: Check error log for details")
            
    except Exception as e:
        print(f"\n❌ FATAL ERROR: {e}")
        print("Please review and run again") 