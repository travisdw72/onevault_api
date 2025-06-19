#!/usr/bin/env python3
"""
Cleanup script to move investigation files to archive
Part of site tracking deployment cleanup
"""

import os
import shutil
import glob
from datetime import datetime

def main():
    """Move investigation files to archive folder"""
    
    # Create archive folder with timestamp
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    archive_folder = f"investigation_archive_{timestamp}"
    
    if not os.path.exists(archive_folder):
        os.makedirs(archive_folder)
        print(f"✅ Created archive folder: {archive_folder}")
    
    # Files to archive (investigation and temporary files)
    files_to_archive = [
        "*.py",
        "*.json", 
        "*SUMMARY.md",
        "*GUIDE.md",
        "*IMPACT*.md",
        "*TESTING*.md",
        "*INTEGRATION*.md",
        "*README*.md",
        "*UPDATED*.md",
        "*DISCOVERY*.md",
        "*AUDIT*.md",
        "*FINAL*.md",
        "*COMPATIBILITY*.md",
        "*IMPLEMENTATION*.md"
    ]
    
    # Keep these core files
    keep_files = [
        "00_integration_strategy.sql",
        "01_create_raw_layer.sql", 
        "02_create_staging_layer.sql",
        "03_create_business_hubs.sql",
        "04_create_business_links.sql", 
        "05_create_business_satellites.sql",
        "06_create_api_layer.sql",
        "DEPLOY_ALL.sql",
        "00_DEPLOYMENT_ORDER.md",
        "cleanup_investigation_files.py"
    ]
    
    files_moved = 0
    
    # Move files to archive
    for pattern in files_to_archive:
        for file_path in glob.glob(pattern):
            if os.path.basename(file_path) not in keep_files:
                try:
                    shutil.move(file_path, os.path.join(archive_folder, os.path.basename(file_path)))
                    print(f"📦 Archived: {file_path}")
                    files_moved += 1
                except Exception as e:
                    print(f"❌ Failed to archive {file_path}: {e}")
    
    # Remove __pycache__ folder if it exists
    if os.path.exists("__pycache__"):
        shutil.rmtree("__pycache__")
        print("🗑️ Removed __pycache__ folder")
    
    print(f"\n✅ Cleanup complete!")
    print(f"📦 {files_moved} files archived to {archive_folder}")
    print(f"🎯 Ready for production deployment!")
    
    # Show remaining files
    print(f"\n📁 REMAINING FILES (ready for deployment):")
    remaining_files = [f for f in os.listdir('.') if os.path.isfile(f) and not f.startswith('.')]
    for file in sorted(remaining_files):
        print(f"   ✅ {file}")

if __name__ == "__main__":
    main() 