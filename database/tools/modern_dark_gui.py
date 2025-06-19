#!/usr/bin/env python3
"""
One Vault Database Version Manager - Modern Dark GUI
Beautiful dark theme with Git initialization and database password input
"""

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext, simpledialog
import subprocess
import os
import sys
from pathlib import Path
from datetime import datetime
import threading
import json
import platform

# Windows dark title bar support
if platform.system() == "Windows":
    try:
        import ctypes
        from ctypes import wintypes
        
        # Windows API constants for dark mode
        DWMWA_USE_IMMERSIVE_DARK_MODE = 20
        DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1 = 19
        
        def set_dark_title_bar(hwnd):
            """Set dark mode for Windows title bar"""
            try:
                # Try the newer constant first
                ctypes.windll.dwmapi.DwmSetWindowAttribute(
                    hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, 
                    ctypes.byref(ctypes.c_int(1)), ctypes.sizeof(ctypes.c_int)
                )
            except:
                try:
                    # Fall back to older constant for older Windows versions
                    ctypes.windll.dwmapi.DwmSetWindowAttribute(
                        hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1, 
                        ctypes.byref(ctypes.c_int(1)), ctypes.sizeof(ctypes.c_int)
                    )
                except:
                    pass  # Dark title bar not supported
    except ImportError:
        def set_dark_title_bar(hwnd):
            pass  # No Windows API available
else:
    def set_dark_title_bar(hwnd):
        pass  # Not Windows

# Try to import the existing manager
try:
    from db_version_manager import DatabaseVersionManager
except ImportError:
    DatabaseVersionManager = None

class DarkTheme:
    """Modern dark theme colors"""
    # Main colors
    BG_DARK = "#1a1a1a"        # Main background
    BG_CARD = "#2d2d2d"        # Card backgrounds
    BG_HEADER = "#3d3d3d"      # Header backgrounds
    BG_ACCENT = "#404040"      # Accent elements
    
    # Text colors
    TEXT_PRIMARY = "#ffffff"    # Main text
    TEXT_SECONDARY = "#b0b0b0"  # Secondary text
    TEXT_MUTED = "#808080"      # Muted text
    
    # Accent colors
    ACCENT_BLUE = "#00d4aa"     # Primary accent (teal)
    ACCENT_GREEN = "#4caf50"    # Success
    ACCENT_ORANGE = "#ff9800"   # Warning
    ACCENT_RED = "#f44336"      # Error
    ACCENT_PURPLE = "#9c27b0"   # Special
    
    # Gradients (simulated)
    GRADIENT_START = "#1e88e5"
    GRADIENT_END = "#00d4aa"

class ModernDarkGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.setup_window()
        self.setup_dark_theme()
        self.db_manager = None
        self.db_password = ""
        
        # Git state
        self.current_branch = None
        self.is_git_repo = False
        self.git_command = "git"  # Default Git command
        
        self.create_widgets()
        self.check_git_status()
        
    def setup_window(self):
        """Setup the main window with modern styling"""
        self.root.title("⚡ One Vault Database Manager")
        self.root.geometry("1600x1000")  # Increased size for better proportions
        self.root.configure(bg=DarkTheme.BG_DARK)
        self.root.resizable(True, True)
        
        # Set minimum window size
        self.root.minsize(1200, 800)
        
        # Apply dark title bar (Windows only)
        self.root.update()  # Ensure window is created
        try:
            hwnd = self.root.winfo_id()
            set_dark_title_bar(hwnd)
        except:
            pass  # If it fails, continue without dark title bar
        
        # Center window
        self.center_window()
        
    def center_window(self):
        """Center the window on screen"""
        self.root.update_idletasks()
        width = self.root.winfo_width()
        height = self.root.winfo_height()
        x = (self.root.winfo_screenwidth() // 2) - (width // 2)
        y = (self.root.winfo_screenheight() // 2) - (height // 2)
        self.root.geometry(f'{width}x{height}+{x}+{y}')
        
    def setup_dark_theme(self):
        """Configure modern dark theme"""
        style = ttk.Style()
        
        # Configure dark theme
        style.theme_use('clam')
        
        # Button styles
        style.configure("Dark.TButton",
                       background=DarkTheme.BG_CARD,
                       foreground=DarkTheme.TEXT_PRIMARY,
                       borderwidth=1,
                       focuscolor='none',
                       font=('Segoe UI', 10))
        
        style.configure("Accent.TButton",
                       background=DarkTheme.ACCENT_BLUE,
                       foreground=DarkTheme.TEXT_PRIMARY,
                       borderwidth=0,
                       focuscolor='none',
                       font=('Segoe UI', 10, 'bold'))
        
        style.configure("Success.TButton",
                       background=DarkTheme.ACCENT_GREEN,
                       foreground=DarkTheme.TEXT_PRIMARY,
                       borderwidth=0,
                       focuscolor='none',
                       font=('Segoe UI', 10, 'bold'))
        
        # Entry styles
        style.configure("Dark.TEntry",
                       fieldbackground=DarkTheme.BG_ACCENT,
                       foreground=DarkTheme.TEXT_PRIMARY,
                       borderwidth=1,
                       insertcolor=DarkTheme.TEXT_PRIMARY)
        
        # Frame styles
        style.configure("Dark.TFrame",
                       background=DarkTheme.BG_DARK,
                       borderwidth=0)
        
        style.configure("Card.TFrame",
                       background=DarkTheme.BG_CARD,
                       borderwidth=1,
                       relief='flat')
    
    def create_widgets(self):
        """Create the modern interface"""
        
        # Main container
        main_container = tk.Frame(self.root, bg=DarkTheme.BG_DARK)
        main_container.pack(fill=tk.BOTH, expand=True)
        
        # Create header
        self.create_modern_header(main_container)
        
        # Create main content area
        content_frame = tk.Frame(main_container, bg=DarkTheme.BG_DARK)
        content_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=10)
        
        # Create left panel (workflow) and right panel (console)
        self.create_main_layout(content_frame)
        
    def create_modern_header(self, parent):
        """Create modern gradient-style header"""
        header_frame = tk.Frame(parent, bg=DarkTheme.GRADIENT_START, height=100)
        header_frame.pack(fill=tk.X)
        header_frame.pack_propagate(False)
        
        # Header content
        header_content = tk.Frame(header_frame, bg=DarkTheme.GRADIENT_START)
        header_content.pack(expand=True, fill=tk.BOTH, padx=30, pady=20)
        
        # Title section
        title_frame = tk.Frame(header_content, bg=DarkTheme.GRADIENT_START)
        title_frame.pack(side=tk.LEFT, expand=True, fill=tk.BOTH)
        
        tk.Label(
            title_frame,
            text="⚡ One Vault",
            font=('Segoe UI', 24, 'bold'),
            bg=DarkTheme.GRADIENT_START,
            fg=DarkTheme.TEXT_PRIMARY
        ).pack(anchor='w')
        
        tk.Label(
            title_frame,
            text="Database Version Manager",
            font=('Segoe UI', 12),
            bg=DarkTheme.GRADIENT_START,
            fg=DarkTheme.TEXT_SECONDARY
        ).pack(anchor='w', pady=(5, 0))
        
        # Status section
        status_frame = tk.Frame(header_content, bg=DarkTheme.GRADIENT_START)
        status_frame.pack(side=tk.RIGHT)
        
        # Git status
        self.git_status_label = tk.Label(
            status_frame,
            text="🔍 Checking Git...",
            font=('Segoe UI', 10),
            bg=DarkTheme.GRADIENT_START,
            fg=DarkTheme.TEXT_PRIMARY
        )
        self.git_status_label.pack(anchor='e')
        
        # Database status
        self.db_status_label = tk.Label(
            status_frame,
            text="🗄️ Database: Not Connected",
            font=('Segoe UI', 10),
            bg=DarkTheme.GRADIENT_START,
            fg=DarkTheme.TEXT_SECONDARY
        )
        self.db_status_label.pack(anchor='e', pady=(5, 0))
        
    def create_main_layout(self, parent):
        """Create the main two-panel layout"""
        
        # Create paned window for resizable panels
        paned = tk.PanedWindow(parent, orient=tk.HORIZONTAL, bg=DarkTheme.BG_DARK,
                              sashwidth=8, sashrelief=tk.FLAT, sashpad=0)
        paned.pack(fill=tk.BOTH, expand=True)
        
        # Left panel - Workflow (larger for better visibility)
        left_panel = self.create_workflow_panel()
        paned.add(left_panel, width=950, minsize=700)
        
        # Right panel - Console and tools
        right_panel = self.create_console_panel()
        paned.add(right_panel, width=650, minsize=400)
        
    def create_workflow_panel(self):
        """Create the workflow panel"""
        panel = tk.Frame(bg=DarkTheme.BG_DARK)
        
        # Panel header
        header = tk.Frame(panel, bg=DarkTheme.BG_CARD, height=50)
        header.pack(fill=tk.X, pady=(0, 10))
        header.pack_propagate(False)
        
        tk.Label(
            header,
            text="🚀 Development Workflow",
            font=('Segoe UI', 14, 'bold'),
            bg=DarkTheme.BG_CARD,
            fg=DarkTheme.TEXT_PRIMARY
        ).pack(side=tk.LEFT, padx=20, pady=15)
        
        # Database connection button
        ttk.Button(
            header,
            text="🔐 Configure Database",
            command=self.configure_database,
            style="Accent.TButton"
        ).pack(side=tk.RIGHT, padx=20, pady=10)
        
        # Create scrollable frame for workflow steps
        canvas_frame = tk.Frame(panel, bg=DarkTheme.BG_DARK)
        canvas_frame.pack(fill=tk.BOTH, expand=True)
        
        canvas = tk.Canvas(canvas_frame, bg=DarkTheme.BG_DARK, highlightthickness=0)
        scrollbar = ttk.Scrollbar(canvas_frame, orient="vertical", command=canvas.yview)
        self.scrollable_frame = tk.Frame(canvas, bg=DarkTheme.BG_DARK)
        
        # Configure scrolling
        def configure_scroll_region(event=None):
            canvas.configure(scrollregion=canvas.bbox("all"))
        
        def configure_canvas_width(event=None):
            canvas.configure(width=event.width - scrollbar.winfo_reqwidth())
        
        self.scrollable_frame.bind("<Configure>", configure_scroll_region)
        canvas_frame.bind("<Configure>", configure_canvas_width)
        
        canvas.create_window((0, 0), window=self.scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Pack scrollable components
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
        
        # Bind mousewheel to canvas for scrolling
        def _on_mousewheel(event):
            canvas.yview_scroll(int(-1*(event.delta/120)), "units")
        
        def bind_mousewheel(event):
            canvas.bind_all("<MouseWheel>", _on_mousewheel)
        
        def unbind_mousewheel(event):
            canvas.unbind_all("<MouseWheel>")
        
        canvas.bind('<Enter>', bind_mousewheel)
        canvas.bind('<Leave>', unbind_mousewheel)
        
        # Create workflow steps in scrollable frame
        self.create_workflow_steps(self.scrollable_frame)
        
        # Force initial scroll region update
        panel.after(100, lambda: canvas.configure(scrollregion=canvas.bbox("all")))
        
        return panel
        
    def create_workflow_steps(self, parent):
        """Create the workflow steps"""
        
        # Step 1: Git Setup
        self.create_workflow_card(
            parent,
            "1️⃣ Git Repository Setup",
            "Initialize or manage your Git repository",
            self.create_git_setup_section,
            DarkTheme.ACCENT_BLUE,
            "git_card"
        )
        
        # Step 2: Branch Management  
        self.create_workflow_card(
            parent,
            "2️⃣ Branch Management",
            "Create and manage feature branches",
            self.create_branch_section,
            DarkTheme.ACCENT_GREEN,
            "branch_card"
        )
        
        # Step 3: Migration Creation
        self.create_workflow_card(
            parent,
            "3️⃣ Database Migration",
            "Create and manage database changes",
            self.create_migration_section,
            DarkTheme.ACCENT_ORANGE,
            "migration_card"
        )
        
        # Step 4: Testing & Deployment
        self.create_workflow_card(
            parent,
            "4️⃣ Testing & Deployment",
            "Test and deploy your changes",
            self.create_testing_section,
            DarkTheme.ACCENT_PURPLE,
            "testing_card"
        )
    
    def create_workflow_card(self, parent, title, subtitle, content_func, accent_color, card_id):
        """Create a modern workflow card"""
        
        # Card container with shadow effect
        card_container = tk.Frame(parent, bg=DarkTheme.BG_DARK)
        card_container.pack(fill=tk.X, pady=(0, 15))
        
        # Main card
        card = tk.Frame(card_container, bg=DarkTheme.BG_CARD, relief=tk.FLAT, bd=0)
        card.pack(fill=tk.X, padx=2, pady=2)
        
        # Header with accent border
        header_frame = tk.Frame(card, bg=accent_color, height=4)
        header_frame.pack(fill=tk.X)
        
        # Title section - moved left by reducing left padding
        title_frame = tk.Frame(card, bg=DarkTheme.BG_CARD)
        title_frame.pack(fill=tk.X, padx=(5, 20), pady=(15, 10))  # Changed from padx=20 to padx=(5, 20)
        
        tk.Label(
            title_frame,
            text=title,
            font=('Segoe UI', 12, 'bold'),
            bg=DarkTheme.BG_CARD,
            fg=DarkTheme.TEXT_PRIMARY
        ).pack(side=tk.LEFT)
        
        tk.Label(
            title_frame,
            text=subtitle,
            font=('Segoe UI', 9),
            bg=DarkTheme.BG_CARD,
            fg=DarkTheme.TEXT_SECONDARY
        ).pack(side=tk.LEFT, padx=(15, 0))
        
        # Content section - also adjusted padding for consistency
        content_frame = tk.Frame(card, bg=DarkTheme.BG_CARD)
        content_frame.pack(fill=tk.X, padx=(5, 20), pady=(0, 20))  # Changed from padx=20 to padx=(5, 20)
        
        content_func(content_frame, accent_color)
        
        # Store card reference
        setattr(self, card_id, card)
        
    def create_git_setup_section(self, parent, accent_color):
        """Create Git setup section"""
        
        # Git status display
        status_frame = tk.Frame(parent, bg=DarkTheme.BG_CARD)
        status_frame.pack(fill=tk.X, pady=(0, 10))
        
        self.git_repo_status = tk.Label(
            status_frame,
            text="🔍 Checking Git repository...",
            font=('Segoe UI', 10),
            bg=DarkTheme.BG_CARD,
            fg=DarkTheme.TEXT_SECONDARY
        )
        self.git_repo_status.pack(side=tk.LEFT)
        
        # Git actions
        button_frame = tk.Frame(parent, bg=DarkTheme.BG_CARD)
        button_frame.pack(fill=tk.X)
        
        ttk.Button(
            button_frame,
            text="🎯 Initialize Git Repo",
            command=self.initialize_git,
            style="Accent.TButton"
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(
            button_frame,
            text="🔄 Refresh Status",
            command=self.check_git_status,
            style="Dark.TButton"
        ).pack(side=tk.LEFT)
        
    def create_branch_section(self, parent, accent_color):
        """Create branch management section"""
        
        # Current branch display
        current_frame = tk.Frame(parent, bg=DarkTheme.BG_CARD)
        current_frame.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(
            current_frame,
            text="Current Branch:",
            font=('Segoe UI', 10),
            bg=DarkTheme.BG_CARD,
            fg=DarkTheme.TEXT_SECONDARY
        ).pack(side=tk.LEFT)
        
        self.current_branch_label = tk.Label(
            current_frame,
            text="No branch",
            font=('Segoe UI', 10, 'bold'),
            bg=DarkTheme.BG_CARD,
            fg=accent_color
        )
        self.current_branch_label.pack(side=tk.LEFT, padx=(10, 0))
        
        # New branch creation
        new_branch_frame = tk.Frame(parent, bg=DarkTheme.BG_CARD)
        new_branch_frame.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(
            new_branch_frame,
            text="New Branch:",
            font=('Segoe UI', 10),
            bg=DarkTheme.BG_CARD,
            fg=DarkTheme.TEXT_SECONDARY
        ).pack(side=tk.LEFT)
        
        self.branch_entry = tk.Entry(
            new_branch_frame,
            font=('Segoe UI', 10),
            bg=DarkTheme.BG_ACCENT,
            fg=DarkTheme.TEXT_PRIMARY,
            insertbackground=DarkTheme.TEXT_PRIMARY,
            bd=0,
            width=25
        )
        self.branch_entry.pack(side=tk.LEFT, padx=(10, 10), ipady=5)
        self.branch_entry.insert(0, "feature/")
        
        ttk.Button(
            new_branch_frame,
            text="Create Branch",
            command=self.create_branch,
            style="Success.TButton"
        ).pack(side=tk.LEFT)
        
    def create_migration_section(self, parent, accent_color):
        """Create migration section"""
        
        # Migration form in grid
        form_frame = tk.Frame(parent, bg=DarkTheme.BG_CARD)
        form_frame.pack(fill=tk.X, pady=(0, 10))
        
        # Version and name row
        row1 = tk.Frame(form_frame, bg=DarkTheme.BG_CARD)
        row1.pack(fill=tk.X, pady=(0, 8))
        
        tk.Label(row1, text="Version:", font=('Segoe UI', 10), 
                bg=DarkTheme.BG_CARD, fg=DarkTheme.TEXT_SECONDARY, width=10, anchor='w').pack(side=tk.LEFT)
        
        self.version_entry = tk.Entry(
            row1, font=('Segoe UI', 10), bg=DarkTheme.BG_ACCENT, fg=DarkTheme.TEXT_PRIMARY,
            insertbackground=DarkTheme.TEXT_PRIMARY, bd=0, width=12
        )
        self.version_entry.pack(side=tk.LEFT, padx=(5, 20), ipady=3)
        self.version_entry.insert(0, "1.1.0")
        
        tk.Label(row1, text="Name:", font=('Segoe UI', 10),
                bg=DarkTheme.BG_CARD, fg=DarkTheme.TEXT_SECONDARY, width=8, anchor='w').pack(side=tk.LEFT)
        
        self.name_entry = tk.Entry(
            row1, font=('Segoe UI', 10), bg=DarkTheme.BG_ACCENT, fg=DarkTheme.TEXT_PRIMARY,
            insertbackground=DarkTheme.TEXT_PRIMARY, bd=0, width=30
        )
        self.name_entry.pack(side=tk.LEFT, padx=(5, 0), ipady=3)
        
        # Description
        desc_row = tk.Frame(form_frame, bg=DarkTheme.BG_CARD)
        desc_row.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(desc_row, text="Description:", font=('Segoe UI', 10),
                bg=DarkTheme.BG_CARD, fg=DarkTheme.TEXT_SECONDARY).pack(anchor='w')
        
        self.desc_text = tk.Text(
            desc_row, height=3, font=('Segoe UI', 9),
            bg=DarkTheme.BG_ACCENT, fg=DarkTheme.TEXT_PRIMARY,
            insertbackground=DarkTheme.TEXT_PRIMARY, bd=0
        )
        self.desc_text.pack(fill=tk.X, pady=(5, 0))
        
        # Buttons
        button_frame = tk.Frame(parent, bg=DarkTheme.BG_CARD)
        button_frame.pack(fill=tk.X)
        
        ttk.Button(
            button_frame,
            text="✨ Create Migration",
            command=self.create_migration,
            style="Accent.TButton"
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(
            button_frame,
            text="📁 Open Folder",
            command=self.open_migrations_folder,
            style="Dark.TButton"
        ).pack(side=tk.LEFT)
        
    def create_testing_section(self, parent, accent_color):
        """Create testing section"""
        
        # Status display
        status_frame = tk.Frame(parent, bg=DarkTheme.BG_CARD)
        status_frame.pack(fill=tk.X, pady=(0, 15))
        
        tk.Label(
            status_frame,
            text="🚀 Deploy your changes to the database",
            font=('Segoe UI', 10),
            bg=DarkTheme.BG_CARD,
            fg=DarkTheme.TEXT_SECONDARY
        ).pack(side=tk.LEFT)
        
        # Testing actions row 1
        test_frame = tk.Frame(parent, bg=DarkTheme.BG_CARD)
        test_frame.pack(fill=tk.X, pady=(0, 10))
        
        ttk.Button(
            test_frame,
            text="🧪 Dry Run",
            command=self.dry_run_migration,
            style="Dark.TButton"
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(
            test_frame,
            text="▶️ Apply Migration",
            command=self.apply_migration,
            style="Success.TButton"
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        # Management actions row 2
        manage_frame = tk.Frame(parent, bg=DarkTheme.BG_CARD)
        manage_frame.pack(fill=tk.X, pady=(0, 10))
        
        ttk.Button(
            manage_frame,
            text="📸 Create Snapshot",
            command=self.create_snapshot,
            style="Dark.TButton"
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(
            manage_frame,
            text="📁 Open Migrations",
            command=self.open_migrations_folder,
            style="Dark.TButton"
        ).pack(side=tk.LEFT, padx=(0, 10))
        
        # Deployment status
        deployment_status_frame = tk.Frame(parent, bg=DarkTheme.BG_CARD)
        deployment_status_frame.pack(fill=tk.X, pady=(0, 15))
        
        tk.Label(
            deployment_status_frame,
            text="Deployment Status:",
            font=('Segoe UI', 10),
            bg=DarkTheme.BG_CARD,
            fg=DarkTheme.TEXT_SECONDARY
        ).pack(side=tk.LEFT)
        
        self.deployment_status_label = tk.Label(
            deployment_status_frame,
            text="Ready for deployment",
            font=('Segoe UI', 10, 'bold'),
            bg=DarkTheme.BG_CARD,
            fg=accent_color
        )
        self.deployment_status_label.pack(side=tk.LEFT, padx=(10, 0))
        
        # Additional info
        info_frame = tk.Frame(parent, bg=DarkTheme.BG_CARD)
        info_frame.pack(fill=tk.X, pady=(0, 20))
        
        info_text = tk.Text(
            info_frame,
            height=3,
            font=('Segoe UI', 9),
            bg=DarkTheme.BG_ACCENT,
            fg=DarkTheme.TEXT_SECONDARY,
            bd=0,
            wrap=tk.WORD,
            padx=10,
            pady=8
        )
        info_text.pack(fill=tk.X)
        info_text.insert("1.0", "💡 Tips:\n• Use Dry Run to test migrations safely\n• Create snapshots before major changes\n• Apply migrations only on feature branches")
        info_text.config(state=tk.DISABLED)
    
    def create_console_panel(self):
        """Create the console panel"""
        panel = tk.Frame(bg=DarkTheme.BG_DARK)
        
        # Console header
        header = tk.Frame(panel, bg=DarkTheme.BG_CARD, height=50)
        header.pack(fill=tk.X, pady=(0, 10))
        header.pack_propagate(False)
        
        tk.Label(
            header,
            text="🖥️ Console Output",
            font=('Segoe UI', 14, 'bold'),
            bg=DarkTheme.BG_CARD,
            fg=DarkTheme.TEXT_PRIMARY
        ).pack(side=tk.LEFT, padx=20, pady=15)
        
        ttk.Button(
            header,
            text="🧹 Clear",
            command=self.clear_console,
            style="Dark.TButton"
        ).pack(side=tk.RIGHT, padx=20, pady=10)
        
        # Console output
        console_frame = tk.Frame(panel, bg=DarkTheme.BG_CARD)
        console_frame.pack(fill=tk.BOTH, expand=True)
        
        self.console = scrolledtext.ScrolledText(
            console_frame,
            font=('Consolas', 10),
            bg="#0a0a0a",
            fg=DarkTheme.ACCENT_BLUE,
            insertbackground=DarkTheme.ACCENT_BLUE,
            selectbackground=DarkTheme.BG_ACCENT,
            bd=0,
            padx=15,
            pady=15
        )
        self.console.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Initial welcome message
        self.log("⚡ One Vault Database Manager", DarkTheme.ACCENT_BLUE)
        self.log("🌙 Dark mode activated", DarkTheme.TEXT_SECONDARY)
        self.log("💡 Start by checking Git status or configuring database", DarkTheme.TEXT_SECONDARY)
        
        return panel
    
    # =========================================================================
    # Event Handlers
    # =========================================================================
    
    def check_git_status(self):
        """Check Git repository status"""
        try:
            # Check if Git is available in different locations
            git_commands = [
                "git", 
                "git.exe",
                r"C:\Program Files\Git\bin\git.exe",
                r"C:\Program Files (x86)\Git\bin\git.exe",
                r"C:\Git\bin\git.exe"
            ]
            git_found = False
            
            for git_cmd in git_commands:
                try:
                    result = subprocess.run([git_cmd, "--version"], 
                                          capture_output=True, text=True, timeout=10)
                    if result.returncode == 0:
                        git_found = True
                        self.git_command = git_cmd
                        version = result.stdout.strip()
                        self.log(f"✅ Found Git: {version}", DarkTheme.ACCENT_GREEN)
                        break
                except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
                    continue
            
            if not git_found:
                self.git_command = None  # Explicitly set to None when not found
                self.update_git_status("❌ Git not found", False)
                self.log("❌ Git not found in PATH or common locations", DarkTheme.ACCENT_RED)
                self.log("💡 Try restarting PowerShell or your computer", DarkTheme.ACCENT_BLUE)
                self.log("💡 Or reinstall Git from: https://git-scm.com/download/windows", DarkTheme.TEXT_SECONDARY)
                return
            
            # Check if in Git repository
            try:
                result = subprocess.run([self.git_command, "status"], 
                                      capture_output=True, text=True, 
                                      cwd=Path.cwd(), timeout=10)
                if result.returncode != 0:
                    self.update_git_status("📁 Not a Git repository", False)
                    self.is_git_repo = False
                    return
            except subprocess.TimeoutExpired:
                self.update_git_status("⏱️ Git command timeout", False)
                return
            
            # Get current branch
            try:
                result = subprocess.run([self.git_command, "branch", "--show-current"], 
                                      capture_output=True, text=True, 
                                      cwd=Path.cwd(), timeout=10)
                if result.returncode == 0:
                    branch = result.stdout.strip()
                    if branch:
                        self.current_branch = branch
                        self.update_git_status(f"🌿 Branch: {branch}", True)
                    else:
                        self.current_branch = None
                        self.update_git_status("🔍 No branch (detached HEAD)", True)
                else:
                    self.current_branch = None
                    self.update_git_status("❓ Cannot determine branch", True)
            except subprocess.TimeoutExpired:
                self.update_git_status("⏱️ Branch check timeout", True)
                
            self.is_git_repo = True
            
        except Exception as e:
            self.git_command = None  # Set to None on any error
            self.update_git_status(f"❌ Git error: {str(e)[:50]}...", False)
            self.is_git_repo = False
    
    def update_git_status(self, status_text, is_repo):
        """Update Git status display"""
        self.git_status_label.config(text=status_text)
        
        if hasattr(self, 'git_repo_status'):
            self.git_repo_status.config(text=status_text)
        
        if hasattr(self, 'current_branch_label'):
            if self.current_branch:
                self.current_branch_label.config(text=self.current_branch)
            else:
                self.current_branch_label.config(text="No branch" if is_repo else "No Git repo")
                
        self.log(f"Git Status: {status_text}", DarkTheme.TEXT_SECONDARY)
    
    def initialize_git(self):
        """Initialize Git repository"""
        # First check if Git is available
        if not hasattr(self, 'git_command') or not self.git_command:
            self.log("❌ Git not found! Please install Git first.", DarkTheme.ACCENT_RED)
            self.log("💡 Download Git from: https://git-scm.com/download/windows", DarkTheme.ACCENT_BLUE)
            messagebox.showerror(
                "Git Not Found", 
                "Git is not installed or not found in your system PATH.\n\n"
                "Please:\n"
                "1. Download Git from: https://git-scm.com/download/windows\n"
                "2. Install Git with default settings\n"
                "3. Restart this application\n\n"
                "Git is required for database version control."
            )
            return
            
        try:
            self.log("🎯 Initializing Git repository...", DarkTheme.ACCENT_BLUE)
            
            result = subprocess.run([self.git_command, "init"], 
                                  capture_output=True, text=True, 
                                  cwd=Path.cwd(), timeout=30)
            if result.returncode == 0:
                self.log("✅ Git repository initialized!", DarkTheme.ACCENT_GREEN)
                
                # Create initial commit
                try:
                    subprocess.run([self.git_command, "add", "."], 
                                 cwd=Path.cwd(), timeout=30)
                    subprocess.run([self.git_command, "commit", "-m", "Initial commit - One Vault Database Foundation"], 
                                 cwd=Path.cwd(), timeout=30)
                    self.log("✅ Initial commit created", DarkTheme.ACCENT_GREEN)
                except subprocess.TimeoutExpired:
                    self.log("⏱️ Initial commit timeout (but repo created)", DarkTheme.ACCENT_ORANGE)
                except Exception as commit_error:
                    self.log(f"⚠️ Initial commit failed: {commit_error}", DarkTheme.ACCENT_ORANGE)
                
                self.check_git_status()
            else:
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                self.log(f"❌ Failed to initialize Git: {error_msg}", DarkTheme.ACCENT_RED)
                
        except subprocess.TimeoutExpired:
            self.log("⏱️ Git initialization timeout", DarkTheme.ACCENT_RED)
        except FileNotFoundError:
            self.log("❌ Git command not found", DarkTheme.ACCENT_RED)
            self.log("💡 Please install Git and restart the application", DarkTheme.ACCENT_BLUE)
        except Exception as e:
            self.log(f"❌ Git initialization error: {str(e)}", DarkTheme.ACCENT_RED)
    
    def create_branch(self):
        """Create new Git branch"""
        if not hasattr(self, 'git_command') or not self.git_command:
            messagebox.showerror(
                "Git Not Found", 
                "Git is not installed.\n\n"
                "Please install Git from:\n"
                "https://git-scm.com/download/windows\n\n"
                "Then restart this application."
            )
            return
            
        if not self.is_git_repo:
            messagebox.showerror("Error", "Not in a Git repository. Initialize Git first.")
            return
            
        branch_name = self.branch_entry.get().strip()
        if not branch_name:
            messagebox.showerror("Error", "Please enter a branch name")
            return
        
        try:
            self.log(f"🌿 Creating branch: {branch_name}", DarkTheme.ACCENT_BLUE)
            
            result = subprocess.run([self.git_command, "checkout", "-b", branch_name], 
                                  capture_output=True, text=True, 
                                  cwd=Path.cwd(), timeout=30)
            
            if result.returncode == 0:
                self.log(f"✅ Created and switched to: {branch_name}", DarkTheme.ACCENT_GREEN)
                self.current_branch = branch_name
                self.current_branch_label.config(text=branch_name)
                self.git_status_label.config(text=f"🌿 Branch: {branch_name}")
                messagebox.showinfo("Success", f"Created branch: {branch_name}")
            else:
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                self.log(f"❌ Failed: {error_msg}", DarkTheme.ACCENT_RED)
                messagebox.showerror("Error", f"Failed to create branch:\n{error_msg}")
                
        except subprocess.TimeoutExpired:
            self.log("⏱️ Branch creation timeout", DarkTheme.ACCENT_RED)
            messagebox.showerror("Error", "Branch creation timed out")
        except FileNotFoundError:
            self.log("❌ Git command not found", DarkTheme.ACCENT_RED)
            messagebox.showerror("Error", "Git is not installed or not in PATH")
        except Exception as e:
            self.log(f"❌ Exception: {str(e)}", DarkTheme.ACCENT_RED)
    
    def configure_database(self):
        """Configure database connection"""
        dialog = DatabaseConfigDialog(self.root)
        if dialog.result:
            self.db_password = dialog.result.get('password', '')
            host = dialog.result.get('host', 'localhost')
            port = dialog.result.get('port', '5432')
            database = dialog.result.get('database', 'one_vault')
            user = dialog.result.get('user', 'postgres')
            
            self.log(f"🔐 Database configured: {user}@{host}:{port}/{database}", DarkTheme.ACCENT_BLUE)
            
            # Test connection
            self.test_database_connection(host, port, database, user, self.db_password)
    
    def test_database_connection(self, host, port, database, user, password):
        """Test database connection"""
        try:
            if DatabaseVersionManager:
                # Update db_manager config
                if not self.db_manager:
                    self.db_manager = DatabaseVersionManager()
                
                self.db_manager.db_config.update({
                    'host': host,
                    'port': int(port),
                    'database': database,
                    'user': user,
                    'password': password
                })
                
                # Test connection
                conn = self.db_manager.connect_db()
                if conn:
                    conn.close()
                    self.log("✅ Database connection successful!", DarkTheme.ACCENT_GREEN)
                    self.db_status_label.config(text="🗄️ Database: Connected")
                else:
                    self.log("❌ Database connection failed", DarkTheme.ACCENT_RED)
            else:
                self.log("⚠️ Database manager not available", DarkTheme.ACCENT_ORANGE)
                
        except Exception as e:
            self.log(f"❌ Database connection error: {str(e)}", DarkTheme.ACCENT_RED)
    
    def create_migration(self):
        """Create new migration"""
        version = self.version_entry.get().strip()
        name = self.name_entry.get().strip()
        description = self.desc_text.get("1.0", tk.END).strip()
        
        if not version or not name:
            messagebox.showerror("Error", "Please enter version and migration name")
            return
        
        try:
            self.log(f"✨ Creating migration: {version} - {name}", DarkTheme.ACCENT_BLUE)
            
            if self.db_manager:
                self.db_manager.create_migration(version, name, description)
            else:
                self._create_migration_manually(version, name, description)
            
            self.log("✅ Migration files created!", DarkTheme.ACCENT_GREEN)
            
            # Clear form
            self.version_entry.delete(0, tk.END)
            self.name_entry.delete(0, tk.END)
            self.desc_text.delete("1.0", tk.END)
            
            messagebox.showinfo("Success", f"Migration {version} created!")
            
        except Exception as e:
            self.log(f"❌ Failed: {str(e)}", DarkTheme.ACCENT_RED)
    
    def _create_migration_manually(self, version, name, description):
        """Create migration manually"""
        clean_name = "".join(c for c in name if c.isalnum() or c in (' ', '-', '_')).replace(' ', '_')
        
        migrations_dir = Path("database/migrations")
        rollback_dir = Path("database/rollback")
        migrations_dir.mkdir(parents=True, exist_ok=True)
        rollback_dir.mkdir(parents=True, exist_ok=True)
        
        migration_file = migrations_dir / f"V{version}__{clean_name}.sql"
        rollback_file = rollback_dir / f"V{version}__{clean_name}_rollback.sql"
        
        # Create migration template
        template = f"""-- Migration: {name}
-- Version: {version}
-- Created: {datetime.now().isoformat()}
-- Description: {description}

-- Add your database changes below
"""
        
        with open(migration_file, 'w') as f:
            f.write(template)
            
        rollback_template = f"""-- Rollback: {name}
-- Version: {version}

-- Add rollback commands below
"""
        
        with open(rollback_file, 'w') as f:
            f.write(rollback_template)
    
    def dry_run_migration(self):
        """Run migration dry run"""
        self.log("🧪 Running migration dry run...", DarkTheme.ACCENT_ORANGE)
        
        if self.db_manager and self.db_password:
            try:
                self.db_manager.migrate(dry_run=True)
                self.log("✅ Dry run completed!", DarkTheme.ACCENT_GREEN)
            except Exception as e:
                self.log(f"❌ Dry run failed: {str(e)}", DarkTheme.ACCENT_RED)
        else:
            self.log("⚠️ Configure database connection first", DarkTheme.ACCENT_ORANGE)
    
    def apply_migration(self):
        """Apply migration"""
        if not self.db_password:
            messagebox.showerror("Error", "Configure database connection first")
            return
            
        if messagebox.askyesno("Confirm", "Apply migration to database?\nThis will make actual changes."):
            self.log("▶️ Applying migration...", DarkTheme.ACCENT_BLUE)
            
            if self.db_manager:
                threading.Thread(target=self._apply_migration_thread, daemon=True).start()
            else:
                self.log("⚠️ Database manager not available", DarkTheme.ACCENT_ORANGE)
    
    def _apply_migration_thread(self):
        """Apply migration in thread"""
        try:
            self.db_manager.migrate(dry_run=False)
            self.log("✅ Migration applied!", DarkTheme.ACCENT_GREEN)
        except Exception as e:
            self.log(f"❌ Migration failed: {str(e)}", DarkTheme.ACCENT_RED)
    
    def create_snapshot(self):
        """Create database snapshot"""
        self.log("📸 Creating snapshot...", DarkTheme.ACCENT_BLUE)
        if self.db_manager:
            try:
                self.db_manager.snapshot()
                self.log("✅ Snapshot created!", DarkTheme.ACCENT_GREEN)
            except Exception as e:
                self.log(f"❌ Snapshot failed: {str(e)}", DarkTheme.ACCENT_RED)
    
    def open_migrations_folder(self):
        """Open migrations folder"""
        try:
            migrations_path = Path("database/migrations").absolute()
            migrations_path.mkdir(parents=True, exist_ok=True)
            
            if sys.platform == "win32":
                os.startfile(migrations_path)
            elif sys.platform == "darwin":
                subprocess.run(["open", migrations_path])
            else:
                subprocess.run(["xdg-open", migrations_path])
                
            self.log(f"📁 Opened: {migrations_path}", DarkTheme.ACCENT_BLUE)
            
        except Exception as e:
            self.log(f"❌ Failed to open folder: {str(e)}", DarkTheme.ACCENT_RED)
    
    def clear_console(self):
        """Clear console"""
        self.console.delete("1.0", tk.END)
        self.log("🧹 Console cleared", DarkTheme.TEXT_MUTED)
    
    def log(self, message, color=None):
        """Log message to console"""
        if color is None:
            color = DarkTheme.TEXT_PRIMARY
            
        timestamp = datetime.now().strftime("%H:%M:%S")
        
        # Insert timestamp
        self.console.insert(tk.END, f"[{timestamp}] ", DarkTheme.TEXT_MUTED)
        
        # Insert message with color
        self.console.insert(tk.END, f"{message}\n")
        
        # Apply color to the message part
        line_start = self.console.index(tk.END + "-1c linestart")
        message_start = f"{line_start.split('.')[0]}.{len(f'[{timestamp}] ')}"
        self.console.tag_add(f"color_{id(message)}", message_start, tk.END + "-1c")
        self.console.tag_config(f"color_{id(message)}", foreground=color)
        
        self.console.see(tk.END)
        self.root.update_idletasks()
    
    def run(self):
        """Start the GUI"""
        # Apply dark title bar one more time after everything is loaded
        self.root.after(100, self.apply_dark_title_bar)
        self.root.mainloop()
    
    def apply_dark_title_bar(self):
        """Apply dark title bar (separate method for easier calling)"""
        try:
            hwnd = self.root.winfo_id()
            set_dark_title_bar(hwnd)
        except:
            pass  # If it fails, continue without dark title bar

class DatabaseConfigDialog:
    """Database configuration dialog"""
    
    def __init__(self, parent):
        self.result = None
        
        # Create dialog
        self.dialog = tk.Toplevel(parent)
        self.dialog.title("🔐 Database Configuration")
        self.dialog.geometry("450x400")  # Increased size
        self.dialog.configure(bg=DarkTheme.BG_DARK)
        self.dialog.resizable(False, False)
        
        # Apply dark title bar to dialog
        self.dialog.update()
        try:
            hwnd = self.dialog.winfo_id()
            set_dark_title_bar(hwnd)
        except:
            pass  # If it fails, continue without dark title bar
        
        # Center dialog on parent
        self.dialog.transient(parent)
        self.dialog.grab_set()
        
        # Center the dialog
        self.center_dialog(parent)
        
        self.create_dialog_widgets()
        
        # Wait for dialog to close
        self.dialog.wait_window()
    
    def center_dialog(self, parent):
        """Center dialog on parent window"""
        parent.update_idletasks()
        parent_x = parent.winfo_rootx()
        parent_y = parent.winfo_rooty()
        parent_width = parent.winfo_width()
        parent_height = parent.winfo_height()
        
        dialog_width = 450
        dialog_height = 400
        
        x = parent_x + (parent_width - dialog_width) // 2
        y = parent_y + (parent_height - dialog_height) // 2
        
        self.dialog.geometry(f"{dialog_width}x{dialog_height}+{x}+{y}")
    
    def create_dialog_widgets(self):
        """Create dialog widgets"""
        
        # Header
        header = tk.Frame(self.dialog, bg=DarkTheme.ACCENT_BLUE, height=70)
        header.pack(fill=tk.X)
        header.pack_propagate(False)
        
        tk.Label(
            header,
            text="🔐 Database Connection",
            font=('Segoe UI', 16, 'bold'),
            bg=DarkTheme.ACCENT_BLUE,
            fg=DarkTheme.TEXT_PRIMARY
        ).pack(pady=25)
        
        # Form container
        form_container = tk.Frame(self.dialog, bg=DarkTheme.BG_DARK)
        form_container.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Form fields
        fields = [
            ("Host:", "localhost"),
            ("Port:", "5432"),
            ("Database:", "one_vault"),
            ("Username:", "postgres"),
            ("Password:", "")
        ]
        
        self.entries = {}
        
        for i, (label, default) in enumerate(fields):
            row = tk.Frame(form_container, bg=DarkTheme.BG_DARK)
            row.pack(fill=tk.X, pady=(0, 15))
            
            tk.Label(
                row,
                text=label,
                font=('Segoe UI', 11),
                bg=DarkTheme.BG_DARK,
                fg=DarkTheme.TEXT_SECONDARY,
                width=12,
                anchor='w'
            ).pack(side=tk.LEFT)
            
            is_password = "Password" in label
            entry = tk.Entry(
                row,
                font=('Segoe UI', 11),
                bg=DarkTheme.BG_ACCENT,
                fg=DarkTheme.TEXT_PRIMARY,
                insertbackground=DarkTheme.TEXT_PRIMARY,
                bd=1,
                relief=tk.FLAT,
                show="*" if is_password else ""
            )
            entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(10, 0), ipady=8)
            entry.insert(0, default)
            
            field_name = label.lower().replace(":", "")
            self.entries[field_name] = entry
        
        # Connection test info
        info_frame = tk.Frame(form_container, bg=DarkTheme.BG_DARK)
        info_frame.pack(fill=tk.X, pady=(10, 20))
        
        tk.Label(
            info_frame,
            text="💡 Connection will be tested automatically",
            font=('Segoe UI', 9),
            bg=DarkTheme.BG_DARK,
            fg=DarkTheme.TEXT_MUTED
        ).pack()
        
        # Buttons frame
        button_container = tk.Frame(self.dialog, bg=DarkTheme.BG_DARK)
        button_container.pack(fill=tk.X, padx=20, pady=(0, 20))
        
        button_frame = tk.Frame(button_container, bg=DarkTheme.BG_DARK)
        button_frame.pack(anchor='e')
        
        # Cancel button
        cancel_btn = tk.Button(
            button_frame,
            text="✕ Cancel",
            command=self.cancel,
            bg=DarkTheme.BG_ACCENT,
            fg=DarkTheme.TEXT_PRIMARY,
            bd=0,
            padx=25,
            pady=12,
            font=('Segoe UI', 10),
            cursor="hand2"
        )
        cancel_btn.pack(side=tk.RIGHT, padx=(15, 0))
        
        # Connect button
        connect_btn = tk.Button(
            button_frame,
            text="🔗 Connect",
            command=self.save,
            bg=DarkTheme.ACCENT_BLUE,
            fg=DarkTheme.TEXT_PRIMARY,
            bd=0,
            padx=25,
            pady=12,
            font=('Segoe UI', 10, 'bold'),
            cursor="hand2"
        )
        connect_btn.pack(side=tk.RIGHT)
        
        # Focus on first field
        self.entries['host'].focus_set()
        
        # Bind Enter key to connect
        self.dialog.bind('<Return>', lambda e: self.save())
    
    def save(self):
        """Save configuration"""
        self.result = {
            'host': self.entries['host'].get(),
            'port': self.entries['port'].get(),
            'database': self.entries['database'].get(),
            'user': self.entries['username'].get(),
            'password': self.entries['password'].get()
        }
        self.dialog.destroy()
    
    def cancel(self):
        """Cancel dialog"""
        self.result = None
        self.dialog.destroy()

def main():
    """Main entry point"""
    try:
        app = ModernDarkGUI()
        app.run()
    except Exception as e:
        print(f"❌ Failed to start GUI: {e}")
        messagebox.showerror("Error", f"Failed to start GUI:\n{str(e)}")

if __name__ == "__main__":
    main() 