#!/usr/bin/env python3
"""
One Vault Database Version Manager - Simple GUI
Beautiful interface for the workflow you discovered
"""

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import subprocess
import os
import sys
from pathlib import Path
from datetime import datetime
import threading

# Try to import the existing manager
try:
    from db_version_manager import DatabaseVersionManager
except ImportError:
    DatabaseVersionManager = None

class SimpleDBGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.setup_window()
        self.create_widgets()
        
        # Try to initialize database manager
        if DatabaseVersionManager:
            try:
                self.db_manager = DatabaseVersionManager()
            except:
                self.db_manager = None
        else:
            self.db_manager = None
        
        self.current_branch = self.get_git_branch()
        self.update_branch_display()
        
    def setup_window(self):
        """Setup the main window"""
        self.root.title("🗄️ One Vault Database Manager")
        self.root.geometry("1000x700")
        self.root.configure(bg="#f5f5f5")
        
        # Try to set icon
        try:
            self.root.iconbitmap("database.ico")
        except:
            pass
    
    def create_widgets(self):
        """Create the main interface"""
        
        # Header
        header_frame = tk.Frame(self.root, bg="#2196F3", height=80)
        header_frame.pack(fill=tk.X)
        header_frame.pack_propagate(False)
        
        tk.Label(
            header_frame,
            text="🗄️ One Vault Database Version Manager",
            font=("Arial", 16, "bold"),
            bg="#2196F3",
            fg="white"
        ).pack(pady=20)
        
        # Main container
        main_frame = tk.Frame(self.root, bg="#f5f5f5")
        main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Create the workflow sections
        self.create_workflow_section(main_frame)
        
    def create_workflow_section(self, parent):
        """Create the main workflow interface"""
        
        # Workflow container
        workflow_frame = tk.Frame(parent, bg="#f5f5f5")
        workflow_frame.pack(fill=tk.BOTH, expand=True)
        
        # Step 1: Git Branch Management
        self.create_step_card(
            workflow_frame,
            "1️⃣ Git Branch Management",
            "Start with the correct workflow order!",
            self.create_git_section,
            "#4CAF50"
        )
        
        # Step 2: Database Migration
        self.create_step_card(
            workflow_frame,
            "2️⃣ Database Migration", 
            "Create your database changes",
            self.create_migration_section,
            "#2196F3"
        )
        
        # Step 3: Testing
        self.create_step_card(
            workflow_frame,
            "3️⃣ Testing & Application",
            "Test and apply your changes",
            self.create_testing_section,
            "#FF9800"
        )
        
        # Console output
        self.create_console_section(workflow_frame)
    
    def create_step_card(self, parent, title, subtitle, content_func, color):
        """Create a workflow step card"""
        
        # Card frame
        card_frame = tk.Frame(parent, bg="white", relief=tk.RAISED, bd=1)
        card_frame.pack(fill=tk.X, pady=(0, 15), padx=5)
        
        # Header
        header_frame = tk.Frame(card_frame, bg=color, height=60)
        header_frame.pack(fill=tk.X)
        header_frame.pack_propagate(False)
        
        tk.Label(
            header_frame,
            text=title,
            font=("Arial", 12, "bold"),
            bg=color,
            fg="white"
        ).pack(side=tk.LEFT, padx=15, pady=15)
        
        tk.Label(
            header_frame,
            text=subtitle,
            font=("Arial", 9),
            bg=color,
            fg="white"
        ).pack(side=tk.LEFT, padx=(0, 15), pady=15)
        
        # Content
        content_frame = tk.Frame(card_frame, bg="white")
        content_frame.pack(fill=tk.X, padx=15, pady=15)
        
        content_func(content_frame)
    
    def create_git_section(self, parent):
        """Create Git branch management section"""
        
        # Current branch display
        branch_frame = tk.Frame(parent, bg="white")
        branch_frame.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(
            branch_frame,
            text="Current Branch:",
            font=("Arial", 10, "bold"),
            bg="white"
        ).pack(side=tk.LEFT)
        
        self.branch_label = tk.Label(
            branch_frame,
            text=self.current_branch,
            font=("Arial", 10),
            bg="white",
            fg="#2196F3"
        )
        self.branch_label.pack(side=tk.LEFT, padx=(10, 0))
        
        ttk.Button(
            branch_frame,
            text="🔄 Refresh",
            command=self.refresh_branch,
            width=10
        ).pack(side=tk.RIGHT)
        
        # New branch creation
        new_branch_frame = tk.Frame(parent, bg="white")
        new_branch_frame.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(
            new_branch_frame,
            text="New Branch:",
            font=("Arial", 10),
            bg="white"
        ).pack(side=tk.LEFT)
        
        self.branch_entry = tk.Entry(new_branch_frame, font=("Arial", 10), width=30)
        self.branch_entry.pack(side=tk.LEFT, padx=(10, 10))
        self.branch_entry.insert(0, "feature/")
        
        ttk.Button(
            new_branch_frame,
            text="Create Branch",
            command=self.create_branch,
            width=15
        ).pack(side=tk.LEFT)
        
        # Git status
        ttk.Button(
            parent,
            text="📊 Check Git Status",
            command=self.check_git_status,
            width=20
        ).pack(pady=(5, 0))
    
    def create_migration_section(self, parent):
        """Create migration management section"""
        
        # Migration form
        form_frame = tk.Frame(parent, bg="white")
        form_frame.pack(fill=tk.X, pady=(0, 10))
        
        # Version
        version_frame = tk.Frame(form_frame, bg="white")
        version_frame.pack(fill=tk.X, pady=(0, 5))
        
        tk.Label(
            version_frame,
            text="Version:",
            font=("Arial", 10),
            bg="white",
            width=12,
            anchor="w"
        ).pack(side=tk.LEFT)
        
        self.version_entry = tk.Entry(version_frame, font=("Arial", 10), width=12)
        self.version_entry.pack(side=tk.LEFT, padx=(5, 0))
        self.version_entry.insert(0, "1.1.0")
        
        # Name
        name_frame = tk.Frame(form_frame, bg="white")
        name_frame.pack(fill=tk.X, pady=(0, 5))
        
        tk.Label(
            name_frame,
            text="Name:",
            font=("Arial", 10),
            bg="white",
            width=12,
            anchor="w"
        ).pack(side=tk.LEFT)
        
        self.name_entry = tk.Entry(name_frame, font=("Arial", 10), width=40)
        self.name_entry.pack(side=tk.LEFT, padx=(5, 0))
        
        # Description
        desc_frame = tk.Frame(form_frame, bg="white")
        desc_frame.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(
            desc_frame,
            text="Description:",
            font=("Arial", 10),
            bg="white",
            width=12,
            anchor="w"
        ).pack(side=tk.TOP, anchor="w")
        
        self.desc_text = tk.Text(desc_frame, height=3, width=50, font=("Arial", 9))
        self.desc_text.pack(fill=tk.X, pady=(2, 0))
        
        # Buttons
        button_frame = tk.Frame(parent, bg="white")
        button_frame.pack(fill=tk.X)
        
        ttk.Button(
            button_frame,
            text="✨ Create Migration",
            command=self.create_migration,
            width=18
        ).pack(side=tk.LEFT, padx=(0, 5))
        
        ttk.Button(
            button_frame,
            text="📁 Open Folder",
            command=self.open_migrations_folder,
            width=15
        ).pack(side=tk.LEFT, padx=(0, 5))
        
        ttk.Button(
            button_frame,
            text="📋 Status",
            command=self.check_db_status,
            width=12
        ).pack(side=tk.LEFT)
    
    def create_testing_section(self, parent):
        """Create testing and application section"""
        
        button_frame = tk.Frame(parent, bg="white")
        button_frame.pack(fill=tk.X, pady=(0, 10))
        
        ttk.Button(
            button_frame,
            text="🧪 Dry Run",
            command=self.dry_run_migration,
            width=15
        ).pack(side=tk.LEFT, padx=(0, 5))
        
        ttk.Button(
            button_frame,
            text="▶️ Apply Migration",
            command=self.apply_migration,
            width=18
        ).pack(side=tk.LEFT, padx=(0, 5))
        
        ttk.Button(
            button_frame,
            text="📸 Snapshot",
            command=self.create_snapshot,
            width=15
        ).pack(side=tk.LEFT)
    
    def create_console_section(self, parent):
        """Create console output section"""
        
        # Console frame
        console_frame = tk.Frame(parent, bg="white", relief=tk.RAISED, bd=1)
        console_frame.pack(fill=tk.BOTH, expand=True, pady=(15, 0), padx=5)
        
        # Console header
        header_frame = tk.Frame(console_frame, bg="#424242", height=40)
        header_frame.pack(fill=tk.X)
        header_frame.pack_propagate(False)
        
        tk.Label(
            header_frame,
            text="🖥️ Console Output",
            font=("Arial", 10, "bold"),
            bg="#424242",
            fg="white"
        ).pack(side=tk.LEFT, padx=15, pady=10)
        
        ttk.Button(
            header_frame,
            text="Clear",
            command=self.clear_console,
            width=8
        ).pack(side=tk.RIGHT, padx=15, pady=5)
        
        # Console text
        self.console = scrolledtext.ScrolledText(
            console_frame,
            height=12,
            font=("Consolas", 9),
            bg="#1e1e1e",
            fg="#ffffff",
            insertbackground="#ffffff"
        )
        self.console.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        # Initial message
        self.log("🚀 One Vault Database Manager Ready!")
        self.log("💡 Start by creating a Git branch, then create your migration.")
    
    def get_git_branch(self):
        """Get current Git branch"""
        try:
            result = subprocess.run(
                ["git", "branch", "--show-current"],
                capture_output=True,
                text=True,
                cwd=Path.cwd()
            )
            if result.returncode == 0:
                return result.stdout.strip() or "main"
            return "not-git-repo"
        except:
            return "git-not-found"
    
    def update_branch_display(self):
        """Update the branch display"""
        self.branch_label.config(text=self.current_branch)
    
    def refresh_branch(self):
        """Refresh the current branch"""
        self.current_branch = self.get_git_branch()
        self.update_branch_display()
        self.log(f"🔄 Current branch: {self.current_branch}")
    
    def create_branch(self):
        """Create a new Git branch"""
        branch_name = self.branch_entry.get().strip()
        if not branch_name:
            messagebox.showerror("Error", "Please enter a branch name")
            return
        
        try:
            self.log(f"🌿 Creating branch: {branch_name}")
            
            result = subprocess.run(
                ["git", "checkout", "-b", branch_name],
                capture_output=True,
                text=True,
                cwd=Path.cwd()
            )
            
            if result.returncode == 0:
                self.log(f"✅ Created and switched to: {branch_name}")
                self.current_branch = branch_name
                self.update_branch_display()
                messagebox.showinfo("Success", f"Created branch: {branch_name}")
            else:
                self.log(f"❌ Failed: {result.stderr}")
                messagebox.showerror("Error", f"Failed to create branch:\\n{result.stderr}")
                
        except Exception as e:
            self.log(f"❌ Exception: {str(e)}")
            messagebox.showerror("Error", f"Exception: {str(e)}")
    
    def check_git_status(self):
        """Check Git status"""
        try:
            result = subprocess.run(
                ["git", "status", "--short"],
                capture_output=True,
                text=True,
                cwd=Path.cwd()
            )
            
            if result.returncode == 0:
                if result.stdout.strip():
                    self.log("📊 Git Status (changed files):")
                    for line in result.stdout.strip().split('\\n'):
                        self.log(f"   {line}")
                else:
                    self.log("✅ Git Status: Working directory clean")
            else:
                self.log(f"❌ Git status failed: {result.stderr}")
                
        except Exception as e:
            self.log(f"❌ Git status error: {str(e)}")
    
    def create_migration(self):
        """Create a new migration"""
        version = self.version_entry.get().strip()
        name = self.name_entry.get().strip()
        description = self.desc_text.get("1.0", tk.END).strip()
        
        if not version or not name:
            messagebox.showerror("Error", "Please enter version and migration name")
            return
        
        try:
            self.log(f"✨ Creating migration: {version} - {name}")
            
            if self.db_manager:
                self.db_manager.create_migration(version, name, description)
                self.log("✅ Migration files created successfully!")
            else:
                # Fallback: create manually
                self._create_migration_manually(version, name, description)
                self.log("✅ Migration files created (manual mode)!")
            
            # Clear form
            self.version_entry.delete(0, tk.END)
            self.name_entry.delete(0, tk.END)
            self.desc_text.delete("1.0", tk.END)
            
            messagebox.showinfo("Success", f"Migration {version} created!")
            
        except Exception as e:
            self.log(f"❌ Failed to create migration: {str(e)}")
            messagebox.showerror("Error", f"Failed to create migration:\\n{str(e)}")
    
    def _create_migration_manually(self, version, name, description):
        """Create migration files manually if manager not available"""
        clean_name = "".join(c for c in name if c.isalnum() or c in (' ', '-', '_')).replace(' ', '_')
        
        # Ensure directories exist
        migrations_dir = Path("database/migrations")
        rollback_dir = Path("database/rollback")
        migrations_dir.mkdir(parents=True, exist_ok=True)
        rollback_dir.mkdir(parents=True, exist_ok=True)
        
        # Create migration file
        migration_file = migrations_dir / f"V{version}__{clean_name}.sql"
        template = f"""-- Migration: {name}
-- Version: {version}
-- Created: {datetime.now().isoformat()}
-- Description: {description}

-- Add your database changes below
-- Example:
-- CREATE TABLE business.new_table_h (
--     id SERIAL PRIMARY KEY,
--     name VARCHAR(255) NOT NULL
-- );
"""
        
        with open(migration_file, 'w') as f:
            f.write(template)
        
        # Create rollback file
        rollback_file = rollback_dir / f"V{version}__{clean_name}_rollback.sql"
        rollback_template = f"""-- Rollback: {name}
-- Version: {version}

-- Add rollback commands below
-- DROP TABLE IF EXISTS business.new_table_h CASCADE;
"""
        
        with open(rollback_file, 'w') as f:
            f.write(rollback_template)
    
    def dry_run_migration(self):
        """Run migration in dry-run mode"""
        self.log("🧪 Running migration dry run...")
        
        if self.db_manager:
            try:
                self.db_manager.migrate(dry_run=True)
                self.log("✅ Dry run completed!")
            except Exception as e:
                self.log(f"❌ Dry run failed: {str(e)}")
        else:
            self.log("⚠️ Database manager not available - check migration files manually")
    
    def apply_migration(self):
        """Apply migration to database"""
        if messagebox.askyesno("Confirm", "Apply migration to database?\\nThis will make actual changes."):
            self.log("▶️ Applying migration...")
            
            if self.db_manager:
                try:
                    # Run in thread to prevent GUI freeze
                    threading.Thread(target=self._apply_migration_thread, daemon=True).start()
                except Exception as e:
                    self.log(f"❌ Migration failed: {str(e)}")
            else:
                self.log("⚠️ Database manager not available")
    
    def _apply_migration_thread(self):
        """Apply migration in background thread"""
        try:
            self.db_manager.migrate(dry_run=False)
            self.log("✅ Migration applied successfully!")
        except Exception as e:
            self.log(f"❌ Migration failed: {str(e)}")
    
    def create_snapshot(self):
        """Create database snapshot"""
        self.log("📸 Creating database snapshot...")
        
        if self.db_manager:
            try:
                self.db_manager.snapshot()
                self.log("✅ Snapshot created!")
            except Exception as e:
                self.log(f"❌ Snapshot failed: {str(e)}")
        else:
            self.log("⚠️ Database manager not available")
    
    def check_db_status(self):
        """Check database status"""
        self.log("📋 Checking database status...")
        
        if self.db_manager:
            try:
                # This will print to stdout, we'd need to capture it
                self.log("ℹ️ Check console for database status...")
                self.db_manager.status()
            except Exception as e:
                self.log(f"❌ Status check failed: {str(e)}")
        else:
            self.log("⚠️ Database manager not available")
    
    def open_migrations_folder(self):
        """Open migrations folder"""
        try:
            migrations_path = Path("database/migrations").absolute()
            
            # Cross-platform folder opening
            if sys.platform == "win32":
                os.startfile(migrations_path)
            elif sys.platform == "darwin":
                subprocess.run(["open", migrations_path])
            else:
                subprocess.run(["xdg-open", migrations_path])
                
            self.log(f"📁 Opened: {migrations_path}")
            
        except Exception as e:
            self.log(f"❌ Failed to open folder: {str(e)}")
    
    def clear_console(self):
        """Clear console output"""
        self.console.delete("1.0", tk.END)
        self.log("🧹 Console cleared")
    
    def log(self, message):
        """Log message to console"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        formatted_message = f"[{timestamp}] {message}\\n"
        
        self.console.insert(tk.END, formatted_message)
        self.console.see(tk.END)
        self.root.update_idletasks()
    
    def run(self):
        """Start the GUI"""
        self.root.mainloop()

def main():
    """Main entry point"""
    try:
        app = SimpleDBGUI()
        app.run()
    except Exception as e:
        print(f"❌ Failed to start GUI: {e}")
        messagebox.showerror("Error", f"Failed to start GUI:\\n{str(e)}")

if __name__ == "__main__":
    main() 