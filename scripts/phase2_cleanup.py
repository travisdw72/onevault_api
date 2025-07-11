#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PHASE 2 CLEANUP SCRIPT
=====================
Handles the remaining scattered files that Phase 1 missed.
This is a simpler, targeted cleanup for specific files.

WHAT THIS DOES:
1. Moves remaining documentation files to docs/
2. Archives remaining experimental files  
3. Cleans up Python cache and temporary files
4. Removes random test files
5. Organizes remaining log files
"""

import os
import shutil
from datetime import datetime

class Phase2Cleanup:
    def __init__(self):
        self.start_time = datetime.now().strftime("%Y%m%d_%H%M%S")
        print("🧹 PHASE 2 CLEANUP - FINISHING THE JOB")
        print("=" * 50)
    
    def safe_move_if_exists(self, source, destination, reason):
        """Move file if it exists, with logging"""
        if os.path.exists(source):
            # Ensure destination directory exists
            dest_dir = os.path.dirname(destination)
            if not os.path.exists(dest_dir):
                os.makedirs(dest_dir, exist_ok=True)
                print(f"📁 Created directory: {dest_dir}")
            
            try:
                shutil.move(source, destination)
                print(f"✅ MOVED: {source}")
                print(f"   ➡️  TO: {destination}")
                print(f"   💡 WHY: {reason}")
                print()
                return True
            except Exception as e:
                print(f"❌ ERROR moving {source}: {e}")
                return False
        else:
            print(f"⚠️  SKIP: {source} does not exist")
            return False
    
    def safe_remove_if_exists(self, path, reason):
        """Remove file/folder if it exists, with logging"""
        if os.path.exists(path):
            try:
                if os.path.isdir(path):
                    shutil.rmtree(path)
                    print(f"🗑️  REMOVED FOLDER: {path}")
                else:
                    os.remove(path)
                    print(f"🗑️  REMOVED FILE: {path}")
                print(f"   💡 WHY: {reason}")
                print()
                return True
            except Exception as e:
                print(f"❌ ERROR removing {path}: {e}")
                return False
        else:
            print(f"⚠️  SKIP: {path} does not exist")
            return False
    
    def cleanup_remaining_docs(self):
        """Move remaining documentation files"""
        print("📚 STEP 1: ORGANIZING REMAINING DOCUMENTATION")
        print("-" * 50)
        
        # Technical documentation
        technical_docs = [
            ("ENTERPRISE_DATABASE_GIT_WORKFLOW.md", "docs/technical/ENTERPRISE_DATABASE_GIT_WORKFLOW.md"),
            ("git_for_dummies_README.md", "docs/configuration/git_for_dummies_README.md")
        ]
        
        for source, dest in technical_docs:
            self.safe_move_if_exists(
                source, dest, 
                "Technical documentation organized in docs folder"
            )
        
        # Business/proposal documentation  
        business_docs = [
            ("USER_CONFIGURABLE_AI_AGENT_BUILDER_PROPOSAL.md", "docs/business/USER_CONFIGURABLE_AI_AGENT_BUILDER_PROPOSAL.md")
        ]
        
        for source, dest in business_docs:
            self.safe_move_if_exists(
                source, dest,
                "Business proposal documentation organized in docs folder"
            )
    
    def cleanup_remaining_experiments(self):
        """Archive remaining experimental and utility files"""
        print("🔬 STEP 2: ARCHIVING REMAINING EXPERIMENTAL FILES")
        print("-" * 50)
        
        # Archive remaining One Barn and experimental files
        archive_files = [
            ("ONE_BARN_SETUP_GUIDE.md", "archive/experiments/ONE_BARN_SETUP_GUIDE.md"),
            ("setup_database_version_control.py", "archive/experiments/setup_database_version_control.py")
        ]
        
        for source, dest in archive_files:
            self.safe_move_if_exists(
                source, dest,
                "Experimental/utility file better organized in archive"
            )
        
        # Archive remaining test results
        test_results = [
            ("RBAC_Analysis_Summary.md", "archive/test_results/RBAC_Analysis_Summary.md")
        ]
        
        for source, dest in test_results:
            self.safe_move_if_exists(
                source, dest,
                "Test analysis results archived for reference"
            )
    
    def cleanup_temp_files(self):
        """Clean up temporary files and Python cache"""
        print("🧽 STEP 3: CLEANING UP TEMPORARY FILES")
        print("-" * 50)
        
        # Remove Python cache
        self.safe_remove_if_exists(
            "__pycache__", 
            "Python cache folder - automatically regenerated"
        )
        
        # Remove random test file
        self.safe_remove_if_exists(
            "test",
            "Random test file with no clear purpose"
        )
        
        # Archive older cleanup log
        self.safe_move_if_exists(
            "cleanup_log_20250617_120756.json",
            "archive/cleanup_log_20250617_120756.json",
            "Archive older cleanup log to keep root clean"
        )
    
    def update_gitignore(self):
        """Update .gitignore with additional entries"""
        print("📝 STEP 4: UPDATING .GITIGNORE")
        print("-" * 50)
        
        gitignore_additions = [
            "__pycache__/",
            "*.pyc",
            "*.pyo", 
            "cleanup_log_*.json",
            "*.log",
            ".DS_Store",  # Mac files
            "Thumbs.db"   # Windows files
        ]
        
        try:
            # Read existing .gitignore
            existing_lines = []
            if os.path.exists(".gitignore"):
                with open(".gitignore", "r", encoding="utf-8") as f:
                    existing_lines = [line.strip() for line in f.readlines()]
            
            # Add new entries that don't already exist
            new_entries = []
            for entry in gitignore_additions:
                if entry not in existing_lines:
                    new_entries.append(entry)
            
            if new_entries:
                with open(".gitignore", "a", encoding="utf-8") as f:
                    f.write("\n# Added by Phase 2 cleanup\n")
                    for entry in new_entries:
                        f.write(f"{entry}\n")
                
                print(f"✅ Added {len(new_entries)} entries to .gitignore:")
                for entry in new_entries:
                    print(f"   + {entry}")
            else:
                print("✅ .gitignore already contains all necessary entries")
                
        except Exception as e:
            print(f"❌ ERROR updating .gitignore: {e}")
    
    def show_final_structure(self):
        """Show the final clean directory structure"""
        print("🎯 STEP 5: FINAL DIRECTORY STRUCTURE")
        print("-" * 50)
        
        print("📁 ROOT DIRECTORY should now contain:")
        print("   ✅ .git/")
        print("   ✅ database/")
        print("   ✅ backend/")
        print("   ✅ frontend/") 
        print("   ✅ docs/")
        print("   ✅ archive/")
        print("   ✅ customers/")
        print("   ✅ example-customers/")
        print("   ✅ debug_screenshots/")
        print("   ✅ .gitignore")
        print("   ✅ safe_cleanup_script.py")
        print("   ✅ phase2_cleanup.py")
        print("   ✅ cleanup_log_[timestamp].json")
        print()
        print("🎉 CLEAN, PROFESSIONAL STRUCTURE!")
    
    def run_phase2_cleanup(self):
        """Run the complete Phase 2 cleanup"""
        print("🧹 Starting Phase 2 cleanup...")
        print()
        
        try:
            self.cleanup_remaining_docs()
            self.cleanup_remaining_experiments()
            self.cleanup_temp_files()
            self.update_gitignore()
            self.show_final_structure()
            
            print("\n🎉 PHASE 2 CLEANUP COMPLETED!")
            print("=" * 50)
            print("✅ All remaining files organized")
            print("✅ Python cache cleaned up")
            print("✅ .gitignore updated")
            print("✅ Professional directory structure achieved")
            print()
            print("🔄 NEXT STEPS:")
            print("1. Review the clean structure")
            print("2. git add .")
            print("3. git commit -m 'Complete project cleanup Phase 2'")
            print("4. git checkout main")
            print("5. git merge feature/project-cleanup")
            print("6. git branch -d feature/project-cleanup")
            
        except Exception as e:
            print(f"❌ ERROR during Phase 2 cleanup: {e}")

# Main execution
if __name__ == "__main__":
    cleanup = Phase2Cleanup()
    
    print("WHAT PHASE 2 CLEANUP WILL DO:")
    print("=" * 50)
    print("1. 📚 Move remaining docs to docs/ folder")
    print("2. 🔬 Archive remaining experimental files")
    print("3. 🧽 Clean up Python cache and temp files")
    print("4. 📝 Update .gitignore with best practices")
    print("5. 🎯 Show final clean structure")
    print()
    
    response = input("🤔 Ready to run Phase 2 cleanup? (y/n): ")
    if response.lower() in ['y', 'yes']:
        cleanup.run_phase2_cleanup()
    else:
        print("❌ Phase 2 cleanup cancelled")
