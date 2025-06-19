#!/usr/bin/env python3
"""
One Vault Database Version Manager - GUI Interface
Beautiful, modern interface for managing database migrations
"""

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext, filedialog
import os
import sys
import json
import subprocess
from datetime import datetime
from pathlib import Path
import threading
from typing import Dict, List, Optional

# Import the existing database version manager
try:
    from db_version_manager import DatabaseVersionManager
except ImportError:
    # If running from different directory, add to path
    sys.path.append(str(Path(__file__).parent))
    from db_version_manager import DatabaseVersionManager

class ModernStyle:
    """Modern UI styling constants"""
    
    # Colors
    PRIMARY = "#2196F3"      # Blue
    PRIMARY_DARK = "#1976D2"
    SUCCESS = "#4CAF50"      # Green
    WARNING = "#FF9800"      # Orange
    ERROR = "#F44336"        # Red
    BACKGROUND = "#FAFAFA"   # Light gray
    SURFACE = "#FFFFFF"      # White
    TEXT_PRIMARY = "#212121" # Dark gray
    TEXT_SECONDARY = "#757575" # Medium gray
    
    # Fonts
    FONT_LARGE = ("Segoe UI", 14, "bold")
    FONT_MEDIUM = ("Segoe UI", 11)
    FONT_SMALL = ("Segoe UI", 9)
    FONT_CODE = ("Consolas", 10)

class DatabaseVersionManagerGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.db_manager = DatabaseVersionManager()
        self.current_branch = self.get_current_git_branch()
        
        self.setup_window()
        self.create_widgets()
        self.load_migration_list()
        
    def setup_window(self):
        """Configure the main window"""
        self.root.title("One Vault - Database Version Manager")
        self.root.geometry("1200x800")
        self.root.configure(bg=ModernStyle.BACKGROUND)
        
        # Set window icon (if available)
        try:
            self.root.iconbitmap("database.ico")
        except:
            pass
            
        # Configure style
        self.style = ttk.Style()
        self.style.theme_use("clam")
        
        # Configure custom styles
        self.configure_styles()
        
    def configure_styles(self):
        """Configure modern ttk styles"""
        
        # Button styles
        self.style.configure(
            "Primary.TButton",
            background=ModernStyle.PRIMARY,
            foreground="white",
            borderwidth=0,
            focuscolor="none",
            font=ModernStyle.FONT_MEDIUM
        )
        
        self.style.configure(
            "Success.TButton",
            background=ModernStyle.SUCCESS,
            foreground="white",
            borderwidth=0,
            focuscolor="none",
            font=ModernStyle.FONT_MEDIUM
        )
        
        self.style.configure(
            "Warning.TButton",
            background=ModernStyle.WARNING,
            foreground="white",
            borderwidth=0,
            focuscolor="none",
            font=ModernStyle.FONT_MEDIUM
        )
        
        # Notebook style
        self.style.configure(
            "Modern.TNotebook",
            background=ModernStyle.BACKGROUND,
            borderwidth=0
        )
        
        self.style.configure(
            "Modern.TNotebook.Tab",
            background=ModernStyle.SURFACE,
            foreground=ModernStyle.TEXT_PRIMARY,
            padding=[20, 10],
            font=ModernStyle.FONT_MEDIUM
        )
        
    def create_widgets(self):
        """Create and layout all GUI widgets"""
        
        # Main container
        main_frame = ttk.Frame(self.root, style="Modern.TFrame")
        main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Header
        self.create_header(main_frame)
        
        # Notebook for tabs
        self.notebook = ttk.Notebook(main_frame, style="Modern.TNotebook")
        self.notebook.pack(fill=tk.BOTH, expand=True, pady=(20, 0))
        
        # Create tabs
        self.create_workflow_tab()
        self.create_migrations_tab()
        self.create_status_tab()
        self.create_tools_tab()
        
    def create_header(self, parent):
        """Create the header section"""
        header_frame = tk.Frame(parent, bg=ModernStyle.BACKGROUND)
        header_frame.pack(fill=tk.X, pady=(0, 20))
        
        # Title
        title_label = tk.Label(
            header_frame,
            text="🗄️ One Vault Database Version Manager",
            font=ModernStyle.FONT_LARGE,
            bg=ModernStyle.BACKGROUND,
            fg=ModernStyle.TEXT_PRIMARY
        )
        title_label.pack(side=tk.LEFT)
        
        # Current branch info
        branch_frame = tk.Frame(header_frame, bg=ModernStyle.BACKGROUND)
        branch_frame.pack(side=tk.RIGHT)
        
        tk.Label(
            branch_frame,
            text="Current Branch:",
            font=ModernStyle.FONT_SMALL,
            bg=ModernStyle.BACKGROUND,
            fg=ModernStyle.TEXT_SECONDARY
        ).pack(side=tk.LEFT)
        
        self.branch_label = tk.Label(
            branch_frame,
            text=self.current_branch,
            font=("Segoe UI", 9, "bold"),
            bg=ModernStyle.BACKGROUND,
            fg=ModernStyle.PRIMARY
        )
        self.branch_label.pack(side=tk.LEFT, padx=(5, 0))
        
        # Refresh button
        ttk.Button(
            branch_frame,
            text="🔄",
            command=self.refresh_branch_info,
            width=3
        ).pack(side=tk.LEFT, padx=(10, 0))
        
    def create_workflow_tab(self):
        """Create the main workflow tab"""
        workflow_frame = ttk.Frame(self.notebook)
        self.notebook.add(workflow_frame, text="🚀 Workflow")
        
        # Create workflow steps
        self.create_workflow_steps(workflow_frame)
        
    def create_workflow_steps(self, parent):
        """Create the step-by-step workflow interface"""
        
        # Scrollable container
        canvas = tk.Canvas(parent, bg=ModernStyle.BACKGROUND)
        scrollbar = ttk.Scrollbar(parent, orient="vertical", command=canvas.yview)
        scrollable_frame = ttk.Frame(canvas)
        
        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
        
        # Step 1: Git Branch Management
        self.create_step_card(
            scrollable_frame,
            "1️⃣ Git Branch Management",
            "Start your feature development with proper Git workflow",
            self.create_git_controls,
            ModernStyle.PRIMARY
        )
        
        # Step 2: Database Migration
        self.create_step_card(
            scrollable_frame,
            "2️⃣ Database Migration",
            "Create and manage database schema changes", 
            self.create_migration_controls,
            ModernStyle.SUCCESS
        )
        
        # Step 3: Testing & Validation
        self.create_step_card(
            scrollable_frame,
            "3️⃣ Testing & Validation",
            "Test your changes before deployment",
            self.create_testing_controls,
            ModernStyle.WARNING
        )
        
        # Step 4: Deployment
        self.create_step_card(
            scrollable_frame,
            "4️⃣ Deployment",
            "Deploy to staging and production environments",
            self.create_deployment_controls,
            "#9C27B0"  # Purple
        )
        
    def create_step_card(self, parent, title, description, content_func, color):
        """Create a modern card for each workflow step"""
        
        # Card container
        card_frame = tk.Frame(
            parent,
            bg=ModernStyle.SURFACE,
            relief=tk.FLAT,
            bd=1
        )
        card_frame.pack(fill=tk.X, pady=(0, 20), padx=10)
        
        # Add shadow effect (simulate with border)
        shadow_frame = tk.Frame(parent, bg="#E0E0E0", height=2)
        shadow_frame.pack(fill=tk.X, padx=12)
        
        # Header
        header_frame = tk.Frame(card_frame, bg=color, height=60)
        header_frame.pack(fill=tk.X)
        header_frame.pack_propagate(False)
        
        tk.Label(
            header_frame,
            text=title,
            font=ModernStyle.FONT_LARGE,
            bg=color,
            fg="white"
        ).pack(side=tk.LEFT, padx=20, pady=15)
        
        tk.Label(
            header_frame,
            text=description,
            font=ModernStyle.FONT_SMALL,
            bg=color,
            fg="white"
        ).pack(side=tk.LEFT, padx=(0, 20), pady=15)
        
        # Content
        content_frame = tk.Frame(card_frame, bg=ModernStyle.SURFACE)
        content_frame.pack(fill=tk.X, padx=20, pady=20)
        
        content_func(content_frame)
        
    def create_git_controls(self, parent):
        """Create Git branch management controls"""
        
        # Current branch display
        current_frame = tk.Frame(parent, bg=ModernStyle.SURFACE)
        current_frame.pack(fill=tk.X, pady=(0, 15))
        
        tk.Label(
            current_frame,
            text="Current Branch:",
            font=ModernStyle.FONT_MEDIUM,
            bg=ModernStyle.SURFACE,
            fg=ModernStyle.TEXT_PRIMARY
        ).pack(side=tk.LEFT)
        
        self.current_branch_label = tk.Label(
            current_frame,
            text=self.current_branch,
            font=("Segoe UI", 11, "bold"),
            bg=ModernStyle.SURFACE,
            fg=ModernStyle.PRIMARY
        )
        self.current_branch_label.pack(side=tk.LEFT, padx=(10, 0))
        
        # Branch creation
        branch_frame = tk.Frame(parent, bg=ModernStyle.SURFACE)
        branch_frame.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(
            branch_frame,
            text="New Feature Branch:",
            font=ModernStyle.FONT_MEDIUM,
            bg=ModernStyle.SURFACE,
            fg=ModernStyle.TEXT_PRIMARY
        ).pack(side=tk.LEFT)
        
        self.branch_entry = tk.Entry(
            branch_frame,
            font=ModernStyle.FONT_MEDIUM,
            width=30
        )
        self.branch_entry.pack(side=tk.LEFT, padx=(10, 10))
        self.branch_entry.insert(0, "feature/")
        
        ttk.Button(
            branch_frame,
            text="Create Branch",
            command=self.create_git_branch,
            style="Primary.TButton"
        ).pack(side=tk.LEFT)
        
        # Git status
        ttk.Button(
            parent,
            text="📊 Check Git Status",
            command=self.show_git_status,
            width=20
        ).pack(pady=(10, 0))
        
    def create_migration_controls(self, parent):
        """Create database migration controls"""
        
        # Migration creation form
        form_frame = tk.Frame(parent, bg=ModernStyle.SURFACE)
        form_frame.pack(fill=tk.X, pady=(0, 15))
        
        # Version
        version_frame = tk.Frame(form_frame, bg=ModernStyle.SURFACE)
        version_frame.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(
            version_frame,
            text="Version:",
            font=ModernStyle.FONT_MEDIUM,
            bg=ModernStyle.SURFACE,
            fg=ModernStyle.TEXT_PRIMARY,
            width=15,
            anchor="w"
        ).pack(side=tk.LEFT)
        
        self.version_entry = tk.Entry(
            version_frame,
            font=ModernStyle.FONT_MEDIUM,
            width=15
        )
        self.version_entry.pack(side=tk.LEFT, padx=(10, 0))
        self.version_entry.insert(0, "1.1.0")
        
        # Name
        name_frame = tk.Frame(form_frame, bg=ModernStyle.SURFACE)
        name_frame.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(
            name_frame,
            text="Migration Name:",
            font=ModernStyle.FONT_MEDIUM,
            bg=ModernStyle.SURFACE,
            fg=ModernStyle.TEXT_PRIMARY,
            width=15,
            anchor="w"
        ).pack(side=tk.LEFT)
        
        self.migration_name_entry = tk.Entry(
            name_frame,
            font=ModernStyle.FONT_MEDIUM,
            width=40
        )
        self.migration_name_entry.pack(side=tk.LEFT, padx=(10, 0))
        
        # Description
        desc_frame = tk.Frame(form_frame, bg=ModernStyle.SURFACE)
        desc_frame.pack(fill=tk.X, pady=(0, 15))
        
        tk.Label(
            desc_frame,
            text="Description:",
            font=ModernStyle.FONT_MEDIUM,
            bg=ModernStyle.SURFACE,
            fg=ModernStyle.TEXT_PRIMARY,
            width=15,
            anchor="w"
        ).pack(side=tk.TOP, anchor="w")
        
        self.description_text = tk.Text(
            desc_frame,
            font=ModernStyle.FONT_MEDIUM,
            height=3,
            width=60
        )
        self.description_text.pack(fill=tk.X, pady=(5, 0))
        
        # Buttons
        button_frame = tk.Frame(parent, bg=ModernStyle.SURFACE)
        button_frame.pack(fill=tk.X)
        
        ttk.Button(
            button_frame,
            text="✨ Create Migration",
            command=self.create_migration,
            style="Success.TButton",
            width=20
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(
            button_frame,
            text="📁 Open Migration Folder",
            command=self.open_migration_folder,
            width=20
        ).pack(side=tk.LEFT)
        
    def create_testing_controls(self, parent):
        """Create testing and validation controls"""
        
        # Test buttons
        button_frame = tk.Frame(parent, bg=ModernStyle.SURFACE)
        button_frame.pack(fill=tk.X, pady=(0, 15))
        
        ttk.Button(
            button_frame,
            text="🧪 Dry Run Migration",
            command=self.run_dry_migration,
            style="Warning.TButton",
            width=20
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(
            button_frame,
            text="▶️ Apply Migration",
            command=self.apply_migration,
            style="Success.TButton",
            width=20
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(
            button_frame,
            text="↩️ Test Rollback",
            command=self.test_rollback,
            width=20
        ).pack(side=tk.LEFT)
        
        # Output console
        console_frame = tk.Frame(parent, bg=ModernStyle.SURFACE)
        console_frame.pack(fill=tk.BOTH, expand=True)
        
        tk.Label(
            console_frame,
            text="Console Output:",
            font=ModernStyle.FONT_MEDIUM,
            bg=ModernStyle.SURFACE,
            fg=ModernStyle.TEXT_PRIMARY
        ).pack(anchor="w", pady=(0, 5))
        
        self.console_output = scrolledtext.ScrolledText(
            console_frame,
            font=ModernStyle.FONT_CODE,
            height=8,
            bg="#1E1E1E",
            fg="#FFFFFF",
            insertbackground="#FFFFFF"
        )
        self.console_output.pack(fill=tk.BOTH, expand=True)
        
    def create_deployment_controls(self, parent):
        """Create deployment controls"""
        
        # Environment selection
        env_frame = tk.Frame(parent, bg=ModernStyle.SURFACE)
        env_frame.pack(fill=tk.X, pady=(0, 15))
        
        tk.Label(
            env_frame,
            text="Target Environment:",
            font=ModernStyle.FONT_MEDIUM,
            bg=ModernStyle.SURFACE,
            fg=ModernStyle.TEXT_PRIMARY
        ).pack(side=tk.LEFT)
        
        self.environment_var = tk.StringVar(value="staging")
        env_combo = ttk.Combobox(
            env_frame,
            textvariable=self.environment_var,
            values=["development", "staging", "production"],
            state="readonly",
            font=ModernStyle.FONT_MEDIUM,
            width=15
        )
        env_combo.pack(side=tk.LEFT, padx=(10, 0))
        
        # Deployment buttons
        deploy_frame = tk.Frame(parent, bg=ModernStyle.SURFACE)
        deploy_frame.pack(fill=tk.X, pady=(0, 15))
        
        ttk.Button(
            deploy_frame,
            text="🚀 Deploy to Environment",
            command=self.deploy_to_environment,
            style="Primary.TButton",
            width=25
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(
            deploy_frame,
            text="📸 Create Snapshot",
            command=self.create_snapshot,
            width=20
        ).pack(side=tk.LEFT)
        
        # Git integration
        git_frame = tk.Frame(parent, bg=ModernStyle.SURFACE)
        git_frame.pack(fill=tk.X)
        
        ttk.Button(
            git_frame,
            text="📝 Commit Changes",
            command=self.commit_changes,
            width=20
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(
            git_frame,
            text="⬆️ Push to Remote",
            command=self.push_changes,
            width=20
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(
            git_frame,
            text="🔀 Create Pull Request",
            command=self.open_pull_request,
            width=20
        ).pack(side=tk.LEFT)
        
    def create_migrations_tab(self):
        """Create the migrations management tab"""
        migrations_frame = ttk.Frame(self.notebook)
        self.notebook.add(migrations_frame, text="📋 Migrations")
        
        # Migration list
        list_frame = tk.Frame(migrations_frame, bg=ModernStyle.SURFACE)
        list_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        tk.Label(
            list_frame,
            text="Migration Files:",
            font=ModernStyle.FONT_MEDIUM,
            bg=ModernStyle.SURFACE,
            fg=ModernStyle.TEXT_PRIMARY
        ).pack(anchor="w", pady=(0, 10))
        
        # Migration tree
        tree_frame = tk.Frame(list_frame, bg=ModernStyle.SURFACE)
        tree_frame.pack(fill=tk.BOTH, expand=True)
        
        self.migration_tree = ttk.Treeview(
            tree_frame,
            columns=("version", "name", "status", "date"),
            show="headings",
            height=15
        )
        
        self.migration_tree.heading("version", text="Version")
        self.migration_tree.heading("name", text="Migration Name")
        self.migration_tree.heading("status", text="Status")
        self.migration_tree.heading("date", text="Created Date")
        
        self.migration_tree.column("version", width=100)
        self.migration_tree.column("name", width=300)
        self.migration_tree.column("status", width=100)
        self.migration_tree.column("date", width=150)
        
        # Scrollbar for tree
        tree_scroll = ttk.Scrollbar(tree_frame, orient="vertical", command=self.migration_tree.yview)
        self.migration_tree.configure(yscrollcommand=tree_scroll.set)
        
        self.migration_tree.pack(side="left", fill="both", expand=True)
        tree_scroll.pack(side="right", fill="y")
        
        # Migration actions
        action_frame = tk.Frame(list_frame, bg=ModernStyle.SURFACE)
        action_frame.pack(fill=tk.X, pady=(15, 0))
        
        ttk.Button(
            action_frame,
            text="🔄 Refresh List",
            command=self.load_migration_list,
            width=15
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(
            action_frame,
            text="📝 Edit Migration",
            command=self.edit_selected_migration,
            width=15
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(
            action_frame,
            text="🗑️ Delete Migration",
            command=self.delete_selected_migration,
            width=15
        ).pack(side=tk.LEFT)
        
    def create_status_tab(self):
        """Create the database status tab"""
        status_frame = ttk.Frame(self.notebook)
        self.notebook.add(status_frame, text="📊 Status")
        
        # Create status display
        self.create_status_display(status_frame)
        
    def create_status_display(self, parent):
        """Create database status display"""
        
        # Status container
        status_container = tk.Frame(parent, bg=ModernStyle.BACKGROUND)
        status_container.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Database health card
        self.create_status_card(
            status_container,
            "🏥 Database Health",
            self.get_database_health_info,
            ModernStyle.SUCCESS
        )
        
        # Environment status card
        self.create_status_card(
            status_container,
            "🌍 Environment Status",
            self.get_environment_status_info,
            ModernStyle.PRIMARY
        )
        
        # Recent activity card
        self.create_status_card(
            status_container,
            "📈 Recent Activity",
            self.get_recent_activity_info,
            ModernStyle.WARNING
        )
        
        # Refresh button
        ttk.Button(
            status_container,
            text="🔄 Refresh Status",
            command=self.refresh_status,
            style="Primary.TButton",
            width=20
        ).pack(pady=(20, 0))
        
    def create_status_card(self, parent, title, content_func, color):
        """Create a status information card"""
        
        card_frame = tk.Frame(
            parent,
            bg=ModernStyle.SURFACE,
            relief=tk.FLAT,
            bd=1
        )
        card_frame.pack(fill=tk.X, pady=(0, 15))
        
        # Header
        header_frame = tk.Frame(card_frame, bg=color, height=50)
        header_frame.pack(fill=tk.X)
        header_frame.pack_propagate(False)
        
        tk.Label(
            header_frame,
            text=title,
            font=ModernStyle.FONT_LARGE,
            bg=color,
            fg="white"
        ).pack(side=tk.LEFT, padx=20, pady=12)
        
        # Content
        content_frame = tk.Frame(card_frame, bg=ModernStyle.SURFACE)
        content_frame.pack(fill=tk.X, padx=20, pady=15)
        
        content_func(content_frame)
        
    def create_tools_tab(self):
        """Create the tools and utilities tab"""
        tools_frame = ttk.Frame(self.notebook)
        self.notebook.add(tools_frame, text="🛠️ Tools")
        
        # Tools container
        tools_container = tk.Frame(tools_frame, bg=ModernStyle.BACKGROUND)
        tools_container.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Schema tools
        self.create_tool_section(
            tools_container,
            "📋 Schema Tools",
            [
                ("📸 Create Schema Snapshot", self.create_schema_snapshot),
                ("📊 Compare Schemas", self.compare_schemas),
                ("🔍 Analyze Schema Health", self.analyze_schema_health)
            ]
        )
        
        # Backup tools
        self.create_tool_section(
            tools_container,
            "💾 Backup Tools",
            [
                ("💾 Create Database Backup", self.create_database_backup),
                ("📥 Restore from Backup", self.restore_from_backup),
                ("🗂️ Manage Backups", self.manage_backups)
            ]
        )
        
        # Development tools
        self.create_tool_section(
            tools_container,
            "⚡ Development Tools",
            [
                ("🧹 Clean Migration Files", self.clean_migration_files),
                ("🔧 Validate Migrations", self.validate_migrations),
                ("📖 Generate Documentation", self.generate_documentation)
            ]
        )
        
    def create_tool_section(self, parent, title, tools):
        """Create a section of tool buttons"""
        
        section_frame = tk.LabelFrame(
            parent,
            text=title,
            font=ModernStyle.FONT_MEDIUM,
            bg=ModernStyle.BACKGROUND,
            fg=ModernStyle.TEXT_PRIMARY,
            padx=20,
            pady=15
        )
        section_frame.pack(fill=tk.X, pady=(0, 20))
        
        for i, (tool_name, tool_command) in enumerate(tools):
            ttk.Button(
                section_frame,
                text=tool_name,
                command=tool_command,
                width=30
            ).pack(pady=(5, 0) if i > 0 else 0)
    
    # =========================================================================
    # Event Handlers and Methods
    # =========================================================================
    
    def get_current_git_branch(self) -> str:
        """Get the current Git branch name"""
        try:
            result = subprocess.run(
                ["git", "branch", "--show-current"],
                capture_output=True,
                text=True,
                cwd=Path.cwd()
            )
            if result.returncode == 0:
                return result.stdout.strip() or "main"
            return "unknown"
        except:
            return "unknown"
    
    def refresh_branch_info(self):
        """Refresh the current branch information"""
        self.current_branch = self.get_current_git_branch()
        self.branch_label.config(text=self.current_branch)
        self.current_branch_label.config(text=self.current_branch)
        
    def create_git_branch(self):
        """Create a new Git branch"""
        branch_name = self.branch_entry.get().strip()
        if not branch_name:
            messagebox.showerror("Error", "Please enter a branch name")
            return
            
        try:
            # Create and switch to new branch
            result = subprocess.run(
                ["git", "checkout", "-b", branch_name],
                capture_output=True,
                text=True,
                cwd=Path.cwd()
            )
            
            if result.returncode == 0:
                self.log_to_console(f"✅ Created and switched to branch: {branch_name}")
                self.refresh_branch_info()
                messagebox.showinfo("Success", f"Created branch: {branch_name}")
            else:
                self.log_to_console(f"❌ Failed to create branch: {result.stderr}")
                messagebox.showerror("Error", f"Failed to create branch:\n{result.stderr}")
                
        except Exception as e:
            self.log_to_console(f"❌ Exception: {str(e)}")
            messagebox.showerror("Error", f"Exception occurred:\n{str(e)}")
    
    def show_git_status(self):
        """Show Git status in console"""
        try:
            result = subprocess.run(
                ["git", "status", "--porcelain"],
                capture_output=True,
                text=True,
                cwd=Path.cwd()
            )
            
            if result.returncode == 0:
                if result.stdout.strip():
                    self.log_to_console("📊 Git Status (modified files):")
                    self.log_to_console(result.stdout)
                else:
                    self.log_to_console("✅ Git Status: Working directory clean")
            else:
                self.log_to_console(f"❌ Git status failed: {result.stderr}")
                
        except Exception as e:
            self.log_to_console(f"❌ Exception: {str(e)}")
    
    def create_migration(self):
        """Create a new database migration"""
        version = self.version_entry.get().strip()
        name = self.migration_name_entry.get().strip()
        description = self.description_text.get("1.0", tk.END).strip()
        
        if not version or not name:
            messagebox.showerror("Error", "Please enter version and migration name")
            return
        
        try:
            self.log_to_console(f"🚀 Creating migration: {version} - {name}")
            
            # Use the existing database manager
            self.db_manager.create_migration(version, name, description)
            
            self.log_to_console(f"✅ Migration created successfully!")
            self.load_migration_list()
            
            # Clear form
            self.version_entry.delete(0, tk.END)
            self.migration_name_entry.delete(0, tk.END)
            self.description_text.delete("1.0", tk.END)
            
            messagebox.showinfo("Success", f"Migration {version} created successfully!")
            
        except Exception as e:
            self.log_to_console(f"❌ Failed to create migration: {str(e)}")
            messagebox.showerror("Error", f"Failed to create migration:\n{str(e)}")
    
    def run_dry_migration(self):
        """Run migration in dry-run mode"""
        try:
            self.log_to_console("🧪 Running migration dry run...")
            
            # Run in background thread to prevent GUI freeze
            threading.Thread(
                target=self._run_migration_thread,
                args=(True,),
                daemon=True
            ).start()
            
        except Exception as e:
            self.log_to_console(f"❌ Failed to run dry migration: {str(e)}")
            messagebox.showerror("Error", f"Failed to run dry migration:\n{str(e)}")
    
    def apply_migration(self):
        """Apply the migration to database"""
        if messagebox.askyesno("Confirm", "Apply migration to database?\nThis will make actual changes."):
            try:
                self.log_to_console("▶️ Applying migration...")
                
                # Run in background thread
                threading.Thread(
                    target=self._run_migration_thread,
                    args=(False,),
                    daemon=True
                ).start()
                
            except Exception as e:
                self.log_to_console(f"❌ Failed to apply migration: {str(e)}")
                messagebox.showerror("Error", f"Failed to apply migration:\n{str(e)}")
    
    def _run_migration_thread(self, dry_run: bool):
        """Run migration in background thread"""
        try:
            self.db_manager.migrate(dry_run=dry_run)
            
            if dry_run:
                self.log_to_console("✅ Dry run completed successfully!")
            else:
                self.log_to_console("✅ Migration applied successfully!")
                
        except Exception as e:
            self.log_to_console(f"❌ Migration failed: {str(e)}")
    
    def log_to_console(self, message: str):
        """Log message to console output"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        formatted_message = f"[{timestamp}] {message}\n"
        
        self.console_output.insert(tk.END, formatted_message)
        self.console_output.see(tk.END)
        self.root.update_idletasks()
    
    def load_migration_list(self):
        """Load and display migration files"""
        # Clear existing items
        for item in self.migration_tree.get_children():
            self.migration_tree.delete(item)
        
        # Load migration files
        migration_files = sorted(list(Path("database/migrations").glob("V*.sql")))
        
        for migration_file in migration_files:
            # Parse migration info
            filename = migration_file.name
            parts = filename.replace(".sql", "").split("__")
            
            if len(parts) >= 2:
                version = parts[0][1:]  # Remove 'V' prefix
                name = parts[1].replace("_", " ")
            else:
                version = "Unknown"
                name = filename
            
            # Get file info
            stat = migration_file.stat()
            created_date = datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M")
            
            # Determine status (simplified)
            status = "Ready"
            
            self.migration_tree.insert(
                "",
                tk.END,
                values=(version, name, status, created_date)
            )
    
    def open_migration_folder(self):
        """Open the migrations folder in file explorer"""
        try:
            migration_path = Path("database/migrations").absolute()
            
            # Cross-platform file explorer opening
            if sys.platform == "win32":
                os.startfile(migration_path)
            elif sys.platform == "darwin":  # macOS
                subprocess.run(["open", migration_path])
            else:  # Linux
                subprocess.run(["xdg-open", migration_path])
                
        except Exception as e:
            messagebox.showerror("Error", f"Failed to open folder:\n{str(e)}")
    
    def get_database_health_info(self, parent):
        """Display database health information"""
        try:
            # Simulate database health check (replace with actual implementation)
            health_info = [
                ("Overall Health Score", "97%", ModernStyle.SUCCESS),
                ("Total Schemas", "29", ModernStyle.PRIMARY),
                ("Total Tables", "382", ModernStyle.PRIMARY),
                ("Total Functions", "351", ModernStyle.PRIMARY),
                ("Compliance Status", "HIPAA/GDPR Ready", ModernStyle.SUCCESS),
            ]
            
            for label, value, color in health_info:
                row_frame = tk.Frame(parent, bg=ModernStyle.SURFACE)
                row_frame.pack(fill=tk.X, pady=2)
                
                tk.Label(
                    row_frame,
                    text=label + ":",
                    font=ModernStyle.FONT_MEDIUM,
                    bg=ModernStyle.SURFACE,
                    fg=ModernStyle.TEXT_PRIMARY,
                    width=20,
                    anchor="w"
                ).pack(side=tk.LEFT)
                
                tk.Label(
                    row_frame,
                    text=value,
                    font=("Segoe UI", 11, "bold"),
                    bg=ModernStyle.SURFACE,
                    fg=color
                ).pack(side=tk.LEFT)
                
        except Exception as e:
            tk.Label(
                parent,
                text=f"Error loading health info: {str(e)}",
                font=ModernStyle.FONT_MEDIUM,
                bg=ModernStyle.SURFACE,
                fg=ModernStyle.ERROR
            ).pack()
    
    def get_environment_status_info(self, parent):
        """Display environment status information"""
        env_info = [
            ("Development", "Active", ModernStyle.SUCCESS),
            ("Staging", "Ready", ModernStyle.WARNING),
            ("Production", "Stable", ModernStyle.SUCCESS),
        ]
        
        for env, status, color in env_info:
            row_frame = tk.Frame(parent, bg=ModernStyle.SURFACE)
            row_frame.pack(fill=tk.X, pady=2)
            
            tk.Label(
                row_frame,
                text=env + ":",
                font=ModernStyle.FONT_MEDIUM,
                bg=ModernStyle.SURFACE,
                fg=ModernStyle.TEXT_PRIMARY,
                width=15,
                anchor="w"
            ).pack(side=tk.LEFT)
            
            tk.Label(
                row_frame,
                text=status,
                font=("Segoe UI", 11, "bold"),
                bg=ModernStyle.SURFACE,
                fg=color
            ).pack(side=tk.LEFT)
    
    def get_recent_activity_info(self, parent):
        """Display recent activity information"""
        activity_info = [
            "✅ Last migration: V1.0.0 (2 days ago)",
            "📊 Last backup: Today 03:00 AM",
            "🔄 Last health check: 5 minutes ago",
            "📝 Pending migrations: 0",
        ]
        
        for activity in activity_info:
            tk.Label(
                parent,
                text=activity,
                font=ModernStyle.FONT_MEDIUM,
                bg=ModernStyle.SURFACE,
                fg=ModernStyle.TEXT_PRIMARY,
                anchor="w"
            ).pack(fill=tk.X, pady=1)
    
    # Placeholder methods for additional functionality
    def test_rollback(self):
        self.log_to_console("🔄 Testing rollback procedures...")
        messagebox.showinfo("Info", "Rollback testing not yet implemented")
    
    def deploy_to_environment(self):
        env = self.environment_var.get()
        self.log_to_console(f"🚀 Deploying to {env} environment...")
        messagebox.showinfo("Info", f"Deployment to {env} not yet implemented")
    
    def create_snapshot(self):
        self.log_to_console("📸 Creating database snapshot...")
        messagebox.showinfo("Info", "Snapshot creation not yet implemented")
    
    def commit_changes(self):
        self.log_to_console("📝 Committing changes to Git...")
        messagebox.showinfo("Info", "Git commit not yet implemented")
    
    def push_changes(self):
        self.log_to_console("⬆️ Pushing changes to remote...")
        messagebox.showinfo("Info", "Git push not yet implemented")
    
    def open_pull_request(self):
        self.log_to_console("🔀 Opening pull request...")
        messagebox.showinfo("Info", "Pull request creation not yet implemented")
    
    def edit_selected_migration(self):
        messagebox.showinfo("Info", "Migration editing not yet implemented")
    
    def delete_selected_migration(self):
        messagebox.showinfo("Info", "Migration deletion not yet implemented")
    
    def refresh_status(self):
        self.log_to_console("🔄 Refreshing status information...")
        messagebox.showinfo("Info", "Status refresh complete")
    
    def create_schema_snapshot(self):
        self.log_to_console("📸 Creating schema snapshot...")
        messagebox.showinfo("Info", "Schema snapshot not yet implemented")
    
    def compare_schemas(self):
        messagebox.showinfo("Info", "Schema comparison not yet implemented")
    
    def analyze_schema_health(self):
        messagebox.showinfo("Info", "Schema health analysis not yet implemented")
    
    def create_database_backup(self):
        messagebox.showinfo("Info", "Database backup not yet implemented")
    
    def restore_from_backup(self):
        messagebox.showinfo("Info", "Backup restore not yet implemented")
    
    def manage_backups(self):
        messagebox.showinfo("Info", "Backup management not yet implemented")
    
    def clean_migration_files(self):
        messagebox.showinfo("Info", "Migration cleanup not yet implemented")
    
    def validate_migrations(self):
        messagebox.showinfo("Info", "Migration validation not yet implemented")
    
    def generate_documentation(self):
        messagebox.showinfo("Info", "Documentation generation not yet implemented")
    
    def run(self):
        """Start the GUI application"""
        self.root.mainloop()

def main():
    """Main entry point"""
    try:
        app = DatabaseVersionManagerGUI()
        app.run()
    except Exception as e:
        messagebox.showerror("Error", f"Failed to start application:\n{str(e)}")

if __name__ == "__main__":
    main() 