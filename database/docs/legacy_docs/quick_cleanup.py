#!/usr/bin/env python3
"""
Quick Scripts Cleanup
Moves remaining clutter from scripts/ to organized_migrations/
"""

import os
import shutil
from pathlib import Path

# Configuration
SCRIPTS_DIR = Path("database/scripts")
ORGANIZED_MIGRATIONS_DIR = Path("database/organized_migrations")
ARCHIVE_DIR = Path("archive")

def quick_cleanup():
    """Move remaining files to appropriate locations"""
    
    print("🧹 Quick Scripts Cleanup")
    print("=" * 40)
    
    # Files to move to different locations
    moves = {
        # AI/ML files → 08_ai_ml_systems
        'complete_ai_ml_enhancement.md': '08_ai_ml_systems',
        'AI_MONITORING_README.md': '08_ai_ml_systems',
        'test_ai_api_contracts.sql': '08_ai_ml_systems',
        'test_ai_api_contracts_enhanced.sql': '08_ai_ml_systems',
        
        # Documentation → archive
        'config_summary.md': 'archive/documentation',
        'CONFIGURATION_SUMMARY.md': 'archive/documentation',
        'audit_trail_validation_summary.md': 'archive/documentation',
        'migration_summary.md': 'archive/documentation',
        'ai_migration_analysis.md': 'archive/documentation',
        'one_barn_gap_analysis.md': 'archive/documentation',
        'investigation_summary.md': 'archive/documentation',
        'one_barn_db_investigation_results.md': 'archive/documentation',
        'TESTING_STATUS_SUMMARY.md': 'archive/documentation',
        'DEPLOYMENT_ORDER.md': 'archive/documentation',
        'DEPLOYMENT_SUMMARY.md': 'archive/documentation',
        
        # Security/compliance → 02_core_schemas
        'sox_assessment.sql': '02_core_schemas',
        'password_audit_dashboard.sql': '02_core_schemas',
        'fix_text_password_security.sql': '02_core_schemas',
        
        # Deployment scripts → 99_production_enhancements
        'deploy_critical_schemas.sql': '99_production_enhancements',
        'deploy_template_foundation.sql': '99_production_enhancements',
        'deploy_missing_schemas.sql': '99_production_enhancements',
        'cleanup_barn_user.sql': '99_production_enhancements',
        'customize_application_users.sql': '99_production_enhancements',
        
        # Core infrastructure → 02_core_schemas (already has these)
        'enhanced_database_version_control.sql': '02_core_schemas',
        
        # Cleanup artifacts → archive
        'cleanup_report.json': 'archive',
    }
    
    moved_count = 0
    
    for file_name, dest_folder in moves.items():
        source_path = SCRIPTS_DIR / file_name
        
        if source_path.exists():
            # Determine destination directory
            if dest_folder.startswith('archive'):
                dest_dir = Path(dest_folder)
            else:
                dest_dir = ORGANIZED_MIGRATIONS_DIR / dest_folder
            
            dest_dir.mkdir(parents=True, exist_ok=True)
            dest_path = dest_dir / file_name
            
            # Handle existing files
            if dest_path.exists():
                print(f"  ⚠️  Skipping {file_name} (already exists in {dest_folder})")
                continue
            
            try:
                shutil.move(str(source_path), str(dest_path))
                print(f"  📁 Moved: {file_name} → {dest_folder}/")
                moved_count += 1
            except Exception as e:
                print(f"  ❌ Error moving {file_name}: {e}")
    
    print(f"\n✅ Moved {moved_count} files")
    
    # Show what's left
    print("\n📁 Remaining in scripts/:")
    remaining = list(SCRIPTS_DIR.iterdir())
    for item in sorted(remaining):
        if item.is_file():
            print(f"  📄 {item.name}")
        elif item.is_dir():
            print(f"  📁 {item.name}/")
    
    print(f"\n🎯 Scripts directory now has {len([f for f in remaining if f.is_file()])} files")

if __name__ == "__main__":
    quick_cleanup() 