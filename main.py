"""
OneVault API - Enterprise Redirect
==================================
This file redirects to the full enterprise API when Render ignores Procfile
"""

# Import the enterprise API application
from app.main import app

# Export the app for uvicorn to find
__all__ = ['app'] 