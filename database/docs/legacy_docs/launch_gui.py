#!/usr/bin/env python3
"""
One Vault Database Version Manager GUI Launcher
Simple launcher for the GUI interface
"""

import sys
import subprocess
from pathlib import Path

def main():
    """Launch the Database Version Manager GUI"""
    
    # Change to the tools directory
    tools_dir = Path(__file__).parent / "tools"
    
    try:
        # Launch the modern dark GUI
        subprocess.run([
            sys.executable, 
            str(tools_dir / "modern_dark_gui.py")
        ], cwd=tools_dir)
        
    except FileNotFoundError:
        print("❌ Error: GUI file not found")
        print("   Expected location: database/tools/modern_dark_gui.py")
        
    except Exception as e:
        print(f"❌ Error launching GUI: {e}")

if __name__ == "__main__":
    main() 