#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os

# Add the current directory to the Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Set encoding for Windows
if sys.platform.startswith('win'):
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.detach())

from investigate_database import DatabaseInvestigator

def main():
    print("One Vault Database Investigation Tool v3.0 - ENHANCED")
    print("=" * 60)
    print("Comprehensive analysis including:")
    print("   - Data Vault 2.0 completeness assessment")
    print("   - Tenant isolation verification")
    print("   - Production readiness scoring")
    print("   - Authentication system analysis")
    print("   - AI/ML system analysis")
    print()
    
    # Initialize investigator
    investigator = DatabaseInvestigator()
    
    try:
        # Run investigation
        investigator.run_investigation()
    except Exception as e:
        print(f"Error during investigation: {e}")
        import traceback
        traceback.print_exc()
    finally:
        investigator.close()

if __name__ == "__main__":
    main() 