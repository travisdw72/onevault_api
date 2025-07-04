#!/usr/bin/env python3
"""
One_Barn_AI Localhost Development Setup
======================================
Date: July 3, 2025
Purpose: Localhost-first API setup for development and testing
API Base: http://localhost:8000 (auto-detected)

This script is optimized for local development workflow:
- Auto-detects localhost API server
- Falls back to staging/production if needed
- Enhanced error messages for development
- Faster timeouts for local testing
"""

import requests
import json
import time
import os
import sys
from typing import Dict, List, Optional, Tuple
from datetime import datetime

# Import the main setup class
from one_barn_ai_api_setup import OneBarnAPISetup

class LocalhostOneBarnSetup(OneBarnAPISetup):
    """Enhanced setup class optimized for localhost development."""
    
    def __init__(self, api_base_url: str = None):
        """Initialize with localhost detection and fallback."""
        # Auto-detect best API endpoint
        if api_base_url is None:
            api_base_url = self._detect_api_endpoint()
        
        super().__init__(api_base_url)
        
        # Enhanced timeouts for local development
        self.session.timeout = 5 if 'localhost' in api_base_url else 10
        
        # Development-specific headers
        self.session.headers.update({
            'X-Development-Mode': 'true',
            'X-Testing-Purpose': 'localhost-development'
        })
        
        print(f"🏠 Localhost Development Mode")
        print(f"📍 API Endpoint: {self.api_base}")
        print(f"⏱️  Timeout: {self.session.timeout}s")
        print()
    
    def _detect_api_endpoint(self) -> str:
        """Auto-detect the best API endpoint for development."""
        # Check environment variable first
        env_url = os.getenv('ONEVAULT_API_URL')
        if env_url:
            print(f"🔧 Using environment variable: {env_url}")
            return env_url
        
        # Test localhost endpoints in order of preference
        localhost_urls = [
            'http://localhost:8000',
            'http://127.0.0.1:8000',
            'http://localhost:3000',  # Common alternative
            'http://localhost:5000',  # Flask default
        ]
        
        print("🔍 Auto-detecting API endpoint...")
        
        for url in localhost_urls:
            if self._test_url_connectivity(url):
                print(f"✅ Found local API at: {url}")
                return url
        
        # Fallback options
        print("⚠️  No localhost API detected")
        print("🔄 Checking fallback options...")
        
        fallback_urls = [
            'https://staging-api.onevault.com',
            'https://onevault-api.onrender.com'
        ]
        
        for url in fallback_urls:
            if self._test_url_connectivity(url):
                print(f"📡 Using fallback: {url}")
                return url
        
        # Last resort - use production and hope for the best
        print("🚨 Using production endpoint (no other options available)")
        return 'https://onevault-api.onrender.com'
    
    def _test_url_connectivity(self, url: str) -> bool:
        """Test if a URL is reachable."""
        try:
            response = requests.get(f"{url}/api/system_health_check", timeout=2)
            return response.status_code == 200
        except:
            return False
    
    def run_complete_setup(self) -> Dict:
        """Run complete setup with development enhancements."""
        print("🏠 One_Barn_AI Localhost Development Setup")
        print("=" * 60)
        print("Optimized for local development and testing")
        print(f"API Base: {self.api_base}")
        print()
        
        # Run the standard setup
        results = super().run_complete_setup()
        
        # Add localhost-specific summary
        print("\n" + "=" * 60)
        print("🏠 LOCALHOST DEVELOPMENT SUMMARY")
        print("=" * 60)
        
        if 'localhost' in self.api_base:
            print("✅ Local development mode successfully used")
            print("🚀 Ready for local Canvas testing")
            print("📝 Check API server logs for detailed information")
            print("\n🔧 Next Development Steps:")
            print("   1. Test Canvas integration with localhost")
            print("   2. Verify all demo scenarios work locally")
            print("   3. Deploy to staging for production testing")
        else:
            print("📡 Using remote API endpoint")
            print("⚠️  Consider setting up local API server for faster development")
        
        return results

def main():
    """Main localhost development setup."""
    print("🏠 OneVault Localhost Development Setup")
    print("Optimized for local API testing and development")
    print()
    
    # Check for command line arguments
    api_url = None
    if len(sys.argv) > 1:
        if sys.argv[1] in ['--help', '-h']:
            print("Usage: python one_barn_ai_localhost_setup.py [API_URL]")
            print("")
            print("Options:")
            print("  API_URL    Custom API endpoint (default: auto-detect localhost)")
            print("  --help     Show this help message")
            print("")
            print("Environment Variables:")
            print("  ONEVAULT_API_URL    Override API endpoint")
            print("")
            print("Examples:")
            print("  python one_barn_ai_localhost_setup.py")
            print("  python one_barn_ai_localhost_setup.py http://localhost:8000")
            print("  ONEVAULT_API_URL=http://localhost:3000 python one_barn_ai_localhost_setup.py")
            return 0
        else:
            api_url = sys.argv[1]
    
    # Create and run setup
    setup = LocalhostOneBarnSetup(api_url)
    
    try:
        # Run complete setup
        results = setup.run_complete_setup()
        
        # Save results with localhost suffix
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        results_file = f"one_barn_localhost_setup_{timestamp}.json"
        setup.save_results(results_file)
        
        # Return appropriate exit code
        return 0 if results['setup_summary']['overall_success'] else 1
        
    except KeyboardInterrupt:
        print("\n⚠️ Setup interrupted by user")
        return 1
    except Exception as e:
        print(f"\n❌ Setup failed with error: {str(e)}")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 