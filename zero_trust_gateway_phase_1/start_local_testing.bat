@echo off
title OneVault Zero Trust Gateway - Local Testing
color 0A

echo.
echo ================================================================================
echo  🛡️  OneVault Zero Trust Gateway - Local Testing Startup
echo ================================================================================
echo.
echo 🏠 This script helps you test the Zero Trust Gateway on localhost
echo 📊 Connects to your local database for safe testing
echo 🚀 No production systems are affected
echo.
echo ================================================================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python not found. Please install Python 3.8+ and try again.
    echo    Download from: https://python.org
    pause
    exit /b 1
)

echo ✅ Python found: 
python --version

REM Check if required files exist
if not exist "local_api_test.py" (
    echo ❌ local_api_test.py not found
    echo    Make sure you're in the zero_trust_gateway_phase_1 directory
    pause
    exit /b 1
)

if not exist "local_config.py" (
    echo ❌ local_config.py not found
    echo    Missing configuration file
    pause
    exit /b 1
)

echo ✅ Required files found

REM Check if DB_PASSWORD is set
if "%DB_PASSWORD%"=="" (
    echo.
    echo ⚠️  Database Password Required
    echo.
    echo Please set your database password:
    set /p DB_PASSWORD="Enter DB_PASSWORD: "
    
    if "!DB_PASSWORD!"=="" (
        echo ❌ No password provided. Exiting.
        pause
        exit /b 1
    )
    
    REM Export for this session
    set DB_PASSWORD=%DB_PASSWORD%
    echo ✅ Password set for this session
    echo.
    echo 💡 For permanent setup, add this to your environment variables:
    echo    DB_PASSWORD=%DB_PASSWORD%
    echo.
)

echo ✅ Database password configured

echo.
echo ================================================================================
echo  📋 Pre-flight Checks
echo ================================================================================
echo.

REM Test database connection
echo 🔌 Testing database connection...
python local_config.py
if errorlevel 1 (
    echo.
    echo ❌ Database connection failed
    echo.
    echo 🔧 Troubleshooting:
    echo    1. Make sure PostgreSQL is running
    echo    2. Check database name: one_vault_site_testing
    echo    3. Verify password is correct
    echo    4. Ensure database has Zero Trust functions
    echo.
    pause
    exit /b 1
)

echo.
echo ✅ Database connection successful!

echo.
echo ================================================================================
echo  🚀 Starting Local API Server
echo ================================================================================
echo.

echo Starting FastAPI server on http://localhost:8000
echo.
echo 📝 API Documentation: http://localhost:8000/docs
echo 🔍 Health Check: http://localhost:8000/health
echo 📈 Metrics: http://localhost:8000/metrics
echo.
echo 🧪 Test Endpoints:
echo    GET /api/v1/test/basic - Basic authentication test
echo    GET /api/v1/test/tenant/{id} - Tenant access control
echo    GET /api/v1/test/admin - Admin access test
echo    GET /api/v1/test/business/{type} - Business resource simulation
echo    GET /api/v1/test/cross-tenant/{id} - Cross-tenant blocking test
echo    GET /api/v1/test/performance - Performance benchmark
echo.
echo 🔑 Authentication: Include header "Authorization: Bearer your_api_token"
echo.
echo ================================================================================
echo.
echo 🎯 Next Steps:
echo    1. Server will start below
echo    2. Open another terminal/command prompt  
echo    3. Run: bash test_api_locally.sh (or use curl commands)
echo    4. Test all endpoints with your API token
echo    5. Verify performance targets are met
echo.
echo 💡 To stop the server: Press Ctrl+C
echo.
echo ================================================================================
echo.

REM Start the API server
python local_api_test.py

echo.
echo ================================================================================
echo  🏁 Server Stopped
echo ================================================================================
echo.
echo 📊 Check the output above for any errors or performance metrics
echo.
echo 🚀 If tests passed, you're ready to deploy to production!
echo.
pause 