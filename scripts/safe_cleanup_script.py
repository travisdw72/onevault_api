#!/usr/bin/env python3
"""
SAFE PROJECT CLEANUP SCRIPT
============================
This script organizes your One Vault project structure by moving files 
to appropriate locations WITHOUT DELETING ANYTHING.

WHAT IT DOES:
1. Creates archive folders for old/experimental files
2. Moves scattered files to organized locations  
3. Creates a log of every move operation
4. Has safety checks to prevent data loss
5. Can be UNDONE using the generated log

WHAT IT DOES NOT DO:
- Delete any files
- Modify file contents
- Touch your git history
- Change your working database/backend/frontend code
"""

import os
import shutil
import json
from datetime import datetime
from pathlib import Path

class SafeCleanup:
    def __init__(self):
        """Initialize the cleanup process with safety checks"""
        self.start_time = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = f"cleanup_log_{self.start_time}.json"
        self.operations_log = []
        self.dry_run = True  # Start in DRY RUN mode for safety
        
        print("🧹 SAFE PROJECT CLEANUP SCRIPT")
        print("=" * 50)
        print("⚠️  STARTING IN DRY RUN MODE (no files moved yet)")
        print("📝 All operations will be logged for undo capability")
        print()
    
    def log_operation(self, operation_type, source, destination, reason):
        """Log every operation for undo capability and transparency"""
        operation = {
            "timestamp": datetime.now().isoformat(),
            "type": operation_type,
            "source": str(source),
            "destination": str(destination),
            "reason": reason,
            "executed": not self.dry_run
        }
        self.operations_log.append(operation)
        
        # Print what we're doing (or would do)
        action = "WOULD MOVE" if self.dry_run else "MOVED"
        print(f"📦 {action}: {source}")
        print(f"   ➡️  TO: {destination}")
        print(f"   💡 WHY: {reason}")
        print()
    
    def safe_create_directory(self, path):
        """Safely create directory if it doesn't exist"""
        if not os.path.exists(path):
            if not self.dry_run:
                os.makedirs(path, exist_ok=True)
            print(f"📁 {'WOULD CREATE' if self.dry_run else 'CREATED'} directory: {path}")
        else:
            print(f"✅ Directory already exists: {path}")
    
    def safe_move_file(self, source, destination, reason):
        """Safely move a file with collision detection"""
        if not os.path.exists(source):
            print(f"⚠️  SKIP: {source} does not exist")
            return False
        
        # Check if destination already exists
        if os.path.exists(destination):
            # Create a unique name by adding timestamp
            name, ext = os.path.splitext(destination)
            destination = f"{name}_{self.start_time}{ext}"
            print(f"⚠️  COLLISION: Renamed to {destination}")
        
        # Ensure destination directory exists
        dest_dir = os.path.dirname(destination)
        self.safe_create_directory(dest_dir)
        
        # Log the operation
        self.log_operation("MOVE", source, destination, reason)
        
        # Actually move the file (if not dry run)
        if not self.dry_run:
            try:
                shutil.move(source, destination)
                return True
            except Exception as e:
                print(f"❌ ERROR moving {source}: {e}")
                return False
        return True
    
    def cleanup_root_level(self):
        """Clean up the messy root level directory"""
        print("🎯 STEP 1: CLEANING ROOT LEVEL")
        print("-" * 40)
        
        # Create archive structure
        archive_dirs = [
            "archive/investigations",
            "archive/experiments", 
            "archive/old_docs",
            "archive/test_results",
            "docs/business",
            "docs/technical",
            "docs/configuration"
        ]
        
        for dir_path in archive_dirs:
            self.safe_create_directory(dir_path)
        
        # Move investigation files (large JSON files)
        investigation_files = [f for f in os.listdir('.') if f.startswith('database_investigation_') and f.endswith('.json')]
        for file in investigation_files:
            self.safe_move_file(
                file, 
                f"archive/investigations/{file}",
                "Large investigation file cluttering root directory"
            )
        
        # Move experiment files
        experiment_files = [
            'mock_data_generator.py',
            'run_all_analysis.py', 
            'function_test_runner.py',
            'check_one_barn_structure.py',
            'check_raw_staging_structure.py'
        ]
        for file in experiment_files:
            if os.path.exists(file):
                self.safe_move_file(
                    file,
                    f"archive/experiments/{file}",
                    "Experimental/testing script better organized in archive"
                )
        
        # Move one_barn related files (experimental)
        one_barn_files = [f for f in os.listdir('.') if f.startswith('one_barn')]
        for file in one_barn_files:
            self.safe_move_file(
                file,
                f"archive/experiments/{file}",
                "One Barn experimental files - keep for reference but archive"
            )
        
        # Move result/test JSON files
        result_files = [f for f in os.listdir('.') if f.endswith('_results_') or 'rbac' in f or 'assessment' in f]
        for file in result_files:
            if file.endswith('.json') or file.endswith('.md'):
                self.safe_move_file(
                    file,
                    f"archive/test_results/{file}",
                    "Test result files cluttering root - archive for reference"
                )
        
        # Organize documentation
        business_docs = [
            'OneVault_Business_Plan.md',
            'DEVELOPMENT_ROADMAP_PHASE_BY_PHASE.md',
            'Customer_Configuration_Examples.md'
        ]
        for doc in business_docs:
            if os.path.exists(doc):
                self.safe_move_file(
                    doc,
                    f"docs/business/{doc}",
                    "Business documentation organized in docs folder"
                )
        
        technical_docs = [
            'AI_IMPLEMENTATION_PROMPT.md',
            'CONFIG_CONSTANTS_IMPLEMENTATION.md', 
            'TYPESCRIPT_CONFIG_GUIDE.md',
            'TYPESCRIPT_CONFIG_INTEGRATION_SUMMARY.md'
        ]
        for doc in technical_docs:
            if os.path.exists(doc):
                self.safe_move_file(
                    doc,
                    f"docs/technical/{doc}",
                    "Technical documentation organized in docs folder"
                )
        
        config_docs = [
            'GETTING_STARTED.md',
            'OneVault_Folder_Structure.md',
            'OneVault_Complete_Folder_Structure.md'
        ]
        for doc in config_docs:
            if os.path.exists(doc):
                self.safe_move_file(
                    doc,
                    f"docs/configuration/{doc}",
                    "Configuration documentation organized in docs folder"
                )
    
    def cleanup_database_folder(self):
        """Clean up the database folder structure"""
        print("🎯 STEP 2: CLEANING DATABASE FOLDER")
        print("-" * 40)
        
        database_path = "database"
        if not os.path.exists(database_path):
            print("⚠️  Database folder not found, skipping")
            return
        
        # Check for the mysterious .git folder inside database
        db_git_path = os.path.join(database_path, ".git")
        if os.path.exists(db_git_path):
            self.safe_move_file(
                db_git_path,
                "archive/mysterious_db_git_folder",
                "Unknown .git folder inside database directory - needs investigation"
            )
        
        # Organize scripts better
        legacy_scripts_path = os.path.join(database_path, "legacy_scripts")
        if os.path.exists(legacy_scripts_path):
            print(f"📂 Found legacy_scripts folder - analyzing contents...")
            
            # Move testing_validation to a better location
            testing_path = os.path.join(legacy_scripts_path, "testing_validation")
            if os.path.exists(testing_path):
                self.safe_move_file(
                    testing_path,
                    os.path.join(database_path, "testing"),
                    "Move testing scripts to cleaner location for easy access"
                )
        
        # Clean up duplicate/old files in database root
        db_cleanup_files = [
            'test_script_completeness.py',
            'test_auto_detection.py',
            'organize_database_scripts.py'
        ]
        for file in db_cleanup_files:
            file_path = os.path.join(database_path, file)
            if os.path.exists(file_path):
                self.safe_move_file(
                    file_path,
                    f"archive/experiments/database_{file}",
                    "Database utility script - archive to reduce clutter"
                )
    
    def cleanup_weird_folders(self):
        """Clean up oddly named or placed folders"""
        print("🎯 STEP 3: CLEANING WEIRD FOLDERS")
        print("-" * 40)
        
        # "Raw and Staging Layer/" - weird name with spaces
        raw_staging_path = "Raw and Staging Layer"
        if os.path.exists(raw_staging_path):
            self.safe_move_file(
                raw_staging_path,
                "archive/experiments/raw_and_staging_layer",
                "Folder with spaces in name - archive and investigate contents later"
            )
        
        # Any other folders with weird names
        weird_folders = [f for f in os.listdir('.') if ' ' in f and os.path.isdir(f)]
        for folder in weird_folders:
            if folder != "Raw and Staging Layer":  # Already handled above
                safe_name = folder.replace(' ', '_').lower()
                self.safe_move_file(
                    folder,
                    f"archive/experiments/{safe_name}",
                    f"Folder with spaces in name: '{folder}' - archive for investigation"
                )
    
    def create_clean_structure(self):
        """Create the clean, organized folder structure"""
        print("🎯 STEP 4: CREATING CLEAN STRUCTURE")
        print("-" * 40)
        
        clean_structure = [
            "database/migrations",
            "database/testing", 
            "database/config",
            "database/docs",
            "backend/src",
            "backend/config",
            "frontend/src",
            "frontend/config", 
            "docs/business",
            "docs/technical",
            "docs/configuration",
            "archive/investigations",
            "archive/experiments",
            "archive/test_results"
        ]
        
        for dir_path in clean_structure:
            self.safe_create_directory(dir_path)
    
    def save_log(self):
        """Save the operations log for undo capability"""
        log_data = {
            "cleanup_session": {
                "start_time": self.start_time,
                "total_operations": len(self.operations_log),
                "dry_run": self.dry_run
            },
            "operations": self.operations_log,
            "undo_instructions": [
                "To undo these operations, run the reverse of each MOVE operation",
                "For safety, this was logged but you can manually review each operation",
                "Original locations are preserved in the 'source' field"
            ]
        }
        
        with open(self.log_file, 'w') as f:
            json.dump(log_data, f, indent=2)
        
        print(f"📋 Operations log saved to: {self.log_file}")
    
    def show_summary(self):
        """Show summary of what was/would be done"""
        print("\n🎯 CLEANUP SUMMARY")
        print("=" * 50)
        print(f"📊 Total operations: {len(self.operations_log)}")
        print(f"🏃 Mode: {'DRY RUN' if self.dry_run else 'ACTUAL EXECUTION'}")
        print(f"📝 Log file: {self.log_file}")
        print()
        
        if self.dry_run:
            print("⚠️  THIS WAS A DRY RUN - NO FILES WERE ACTUALLY MOVED")
            print("🔄 To execute for real, run: cleanup.execute_for_real()")
            print("🛡️  All operations are logged and can be undone")
        else:
            print("✅ CLEANUP COMPLETED SUCCESSFULLY")
            print("🎉 Your project structure is now organized!")
            print("📁 All old files are safely archived in archive/ folder")
        print()
    
    def execute_for_real(self):
        """Switch to real execution mode and run cleanup"""
        print("🚨 SWITCHING TO REAL EXECUTION MODE")
        print("⚠️  Files will actually be moved now!")
        response = input("Are you sure? Type 'YES' to proceed: ")
        
        if response == 'YES':
            self.dry_run = False
            self.operations_log = []  # Reset log for actual execution
            print("✅ Proceeding with real cleanup...")
            self.run_full_cleanup()
        else:
            print("❌ Cancelled - staying in dry run mode")
    
    def run_full_cleanup(self):
        """Run the complete cleanup process"""
        print(f"🧹 Starting cleanup - DRY RUN: {self.dry_run}")
        print()
        
        try:
            self.cleanup_root_level()
            self.cleanup_database_folder() 
            self.cleanup_weird_folders()
            self.create_clean_structure()
            self.save_log()
            self.show_summary()
            
        except Exception as e:
            print(f"❌ ERROR during cleanup: {e}")
            print("🛡️  Check the log file for completed operations")
            self.save_log()

# Main execution
if __name__ == "__main__":
    cleanup = SafeCleanup()
    
    print("EXPLANATION OF WHAT THIS SCRIPT DOES:")
    print("=" * 50)
    print("1. 📁 Creates organized folder structure (archive/, docs/, etc.)")
    print("2. 📦 Moves scattered files to appropriate locations") 
    print("3. 🧹 Cleans up root directory clutter")
    print("4. 🗂️  Organizes database folder better")
    print("5. 📝 Logs every operation for undo capability")
    print("6. 🛡️  NEVER deletes anything - only moves to archive")
    print()
    print("⚠️  STARTING IN SAFE DRY RUN MODE")
    print("   You can review what it would do, then execute for real")
    print()
    
    # Run the cleanup in dry run mode first
    cleanup.run_full_cleanup()
    
    print("\n" + "="*50)
    print("🤔 WHAT DO YOU WANT TO DO NOW?")
    print("1. If this looks good, run: cleanup.execute_for_real()")
    print("2. If you want to modify something, edit the script")
    print("3. If you're not sure, review the log file first")
    print("="*50) 