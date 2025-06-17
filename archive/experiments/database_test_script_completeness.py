#!/usr/bin/env python3
"""
Quick Test Runner for Script Completeness Validator
==================================================

Easy way to test if our 662+ organized scripts represent the complete database structure.
"""

import os
import sys
from pathlib import Path

# Add scripts directory to path
scripts_dir = Path(__file__).parent / "scripts"
sys.path.insert(0, str(scripts_dir))

def setup_environment():
    """Setup database connection environment variables if not already set"""
    
    # Default connection parameters (modify as needed)
    defaults = {
        'DB_HOST': 'localhost',
        'DB_PORT': '5432',
        'DB_NAME': 'one_vault',
        'DB_USER': 'postgres',
        'DB_PASSWORD': 'password'  # Change this to your actual password
    }
    
    print("🔧 Setting up database connection...")
    
    for key, default_value in defaults.items():
        if key not in os.environ:
            if key == 'DB_PASSWORD':
                # For password, try to get from user input if not set
                import getpass
                try:
                    password = getpass.getpass(f"Enter database password (default: {default_value}): ")
                    os.environ[key] = password if password.strip() else default_value
                except KeyboardInterrupt:
                    print("\n❌ Cancelled by user")
                    sys.exit(1)
            else:
                os.environ[key] = default_value
            
            print(f"   ✅ {key}: {os.environ[key] if key != 'DB_PASSWORD' else '*' * len(os.environ[key])}")
        else:
            print(f"   📋 {key}: Using existing environment variable")

def main():
    """Main runner function"""
    print("🧪 SCRIPT COMPLETENESS TEST RUNNER")
    print("=" * 50)
    print("Testing if our organized scripts match the current database structure...")
    print()
    
    # Setup database connection
    setup_environment()
    
    try:
        # Import and run the validator
        from validate_script_completeness import main as run_validator
        
        print("\n🚀 Starting validation...")
        success = run_validator()
        
        if success:
            print("\n🎉 SUCCESS! Your script collection is comprehensive!")
        else:
            print("\n⚠️  Some gaps detected - see report for details.")
            
        return success
        
    except ImportError:
        print("❌ Could not import validator. Make sure validate_script_completeness.py exists in scripts/")
        return False
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False

if __name__ == "__main__":
    success = main()
    
    print("\n" + "="*50)
    if success:
        print("🏆 VERDICT: Your database scripts are comprehensive! 🏆")
    else:
        print("🔍 VERDICT: Review the gaps and determine their importance.")
    
    print("="*50)
    
    sys.exit(0 if success else 1) 