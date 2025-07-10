# Zero Trust Gateway Local API Testing Script (PowerShell)
# Tests all endpoints with curl commands

param(
    [string]$TestType = "all",
    [string]$ApiToken = "",
    [string]$BaseUrl = "http://localhost:8000"
)

# Colors for output
$Colors = @{
    Red = "Red"
    Green = "Green" 
    Yellow = "Yellow"
    Blue = "Blue"
}

function Write-TestHeader {
    param([string]$TestName)
    Write-Host "`n🧪 Testing: $TestName" -ForegroundColor $Colors.Blue
    Write-Host "----------------------------------------"
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor $Colors.Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor $Colors.Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor $Colors.Yellow
}

# Function to check if server is running
function Test-Server {
    Write-TestHeader "Server Health Check"
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/health" -Method Get -TimeoutSec 10
        Write-Success "Server is running"
        $response | ConvertTo-Json -Depth 10
        return $true
    }
    catch {
        Write-Error "Server not responding: $($_.Exception.Message)"
        Write-Host "Make sure to run: python local_api_test.py"
        return $false
    }
}

# Function to get API token from user
function Get-ApiToken {
    if ([string]::IsNullOrEmpty($script:ApiToken)) {
        Write-Host ""
        Write-Host "🔑 API Token Required"
        Write-Host "You need a valid API token from your database."
        Write-Host ""
        Write-Host "To get one, run this SQL query:"
        Write-Host "SELECT ats.token_hash, ath.api_token_bk"
        Write-Host "FROM auth.api_token_s ats"
        Write-Host "JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk"
        Write-Host "WHERE ats.is_revoked = false"
        Write-Host "AND ats.expires_at > CURRENT_TIMESTAMP"
        Write-Host "AND ats.load_end_date IS NULL"
        Write-Host "LIMIT 1;"
        Write-Host ""
        
        $script:ApiToken = Read-Host "Enter your API token (ovt_prod_...)"
        
        if ([string]::IsNullOrEmpty($script:ApiToken)) {
            Write-Error "No API token provided. Skipping authenticated tests."
            return $false
        }
    }
    return $true
}

# Function to test basic authentication
function Test-BasicAuth {
    Write-TestHeader "Basic Authentication"
    
    if (-not (Get-ApiToken)) {
        return $false
    }
    
    try {
        $headers = @{
            "Authorization" = "Bearer $script:ApiToken"
        }
        
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/test/basic" -Method Get -Headers $headers
        Write-Success "Authentication successful"
        $response | ConvertTo-Json -Depth 10
        
        # Extract tenant info for later tests
        $script:TenantBk = $response.tenant_name
        return $true
    }
    catch {
        Write-Error "Authentication failed: $($_.Exception.Message)"
        if ($_.Exception.Response.StatusCode) {
            Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)"
        }
        return $false
    }
}

# Function to test tenant access
function Test-TenantAccess {
    Write-TestHeader "Tenant Access Control"
    
    if ([string]::IsNullOrEmpty($script:TenantBk)) {
        Write-Warning "No tenant info available. Run basic auth test first."
        return $false
    }
    
    try {
        $headers = @{
            "Authorization" = "Bearer $script:ApiToken"
        }
        
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/test/tenant/$script:TenantBk" -Method Get -Headers $headers
        Write-Success "Own tenant access granted"
        $response | ConvertTo-Json -Depth 10
        return $true
    }
    catch {
        Write-Error "Own tenant access failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to test cross-tenant blocking
function Test-CrossTenantBlocking {
    Write-TestHeader "Cross-Tenant Access Blocking"
    
    try {
        $headers = @{
            "Authorization" = "Bearer $script:ApiToken"
        }
        
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/test/cross-tenant/TENANT_OTHER_123" -Method Get -Headers $headers
        Write-Warning "Cross-tenant access allowed (Admin user?)"
        $response | ConvertTo-Json -Depth 10
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 403) {
            Write-Success "Cross-tenant access properly blocked"
            try {
                $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
                $errorResponse | ConvertTo-Json -Depth 10
            }
            catch {
                Write-Host $_.ErrorDetails.Message
            }
        }
        else {
            Write-Error "Unexpected response: $($_.Exception.Message)"
        }
    }
}

# Function to test admin access
function Test-AdminAccess {
    Write-TestHeader "Admin Access Control"
    
    try {
        $headers = @{
            "Authorization" = "Bearer $script:ApiToken"
        }
        
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/test/admin" -Method Get -Headers $headers
        Write-Success "Admin access granted"
        $response | ConvertTo-Json -Depth 10
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 403) {
            Write-Warning "Admin access denied (expected for non-admin users)"
            try {
                $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
                $errorResponse | ConvertTo-Json -Depth 10
            }
            catch {
                Write-Host $_.ErrorDetails.Message
            }
        }
        else {
            Write-Error "Unexpected admin response: $($_.Exception.Message)"
        }
    }
}

# Function to test business resource access
function Test-BusinessResources {
    Write-TestHeader "Business Resource Access"
    
    $resources = @("users", "entities", "assets", "transactions")
    
    foreach ($resource in $resources) {
        Write-Host "Testing $resource access..."
        
        try {
            $headers = @{
                "Authorization" = "Bearer $script:ApiToken"
            }
            
            $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/test/business/$resource" -Method Get -Headers $headers
            Write-Success "$resource access granted"
            Write-Host "Query: $($response.simulated_query)"
        }
        catch {
            Write-Error "$resource access failed: $($_.Exception.Message)"
        }
        Write-Host ""
    }
}

# Function to test performance
function Test-Performance {
    Write-TestHeader "Performance Benchmarking"
    
    Write-Host "Running 5 performance tests..."
    $totalTime = 0
    $successCount = 0
    
    for ($i = 1; $i -le 5; $i++) {
        $startTime = Get-Date
        
        try {
            $headers = @{
                "Authorization" = "Bearer $script:ApiToken"
            }
            
            $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/test/performance" -Method Get -Headers $headers
            $endTime = Get-Date
            $requestTime = ($endTime - $startTime).TotalMilliseconds
            $totalTime += $requestTime
            $successCount++
            
            Write-Host "Request $i`: $([math]::Round($requestTime, 2))ms"
        }
        catch {
            Write-Error "Performance test $i failed: $($_.Exception.Message)"
        }
    }
    
    if ($successCount -gt 0) {
        $avgTime = $totalTime / $successCount
        Write-Host ""
        Write-Host "Average response time: $([math]::Round($avgTime, 2))ms"
        
        if ($avgTime -lt 200) {
            Write-Success "Performance target met (<200ms)"
        }
        else {
            Write-Warning "Performance target missed ($([math]::Round($avgTime, 2))ms > 200ms)"
        }
    }
    
    # Get detailed metrics
    Write-Host ""
    Write-Host "Detailed middleware metrics:"
    try {
        $metrics = Invoke-RestMethod -Uri "$BaseUrl/metrics" -Method Get
        $metrics | ConvertTo-Json -Depth 10
    }
    catch {
        Write-Error "Failed to get metrics: $($_.Exception.Message)"
    }
}

# Function to test without authentication (should fail)
function Test-NoAuth {
    Write-TestHeader "No Authentication (Should Fail)"
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/test/basic" -Method Get
        Write-Error "Expected 401, but request succeeded"
        $response | ConvertTo-Json -Depth 10
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            Write-Success "Unauthenticated access properly blocked"
            try {
                $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
                $errorResponse | ConvertTo-Json -Depth 10
            }
            catch {
                Write-Host $_.ErrorDetails.Message
            }
        }
        else {
            Write-Error "Expected 401, got $($_.Exception.Response.StatusCode.value__)"
        }
    }
}

# Main test execution
function Start-AllTests {
    Write-Host "🛡️  Zero Trust Gateway - Local API Testing (PowerShell)" -ForegroundColor $Colors.Blue
    Write-Host "=========================================="
    Write-Host "Starting local API tests..."
    Write-Host "Make sure the server is running: python local_api_test.py"
    Write-Host ""
    
    # Run tests
    if (Test-Server) {
        Test-NoAuth
        Test-BasicAuth
        Test-TenantAccess
        Test-CrossTenantBlocking
        Test-AdminAccess
        Test-BusinessResources
        Test-Performance
        
        Write-Host ""
        Write-Host "=========================================="
        Write-Success "Local API testing complete!"
        Write-Host "🚀 Ready to deploy to production if all tests passed"
        Write-Host "📊 Check the server logs for detailed middleware metrics"
    }
    else {
        Write-Error "Server not available. Start with: python local_api_test.py"
        exit 1
    }
}

# Script entry point
Write-Host "🛡️  OneVault Zero Trust Gateway - PowerShell Testing" -ForegroundColor $Colors.Blue
Write-Host ""

# Set API token if provided as parameter
if (-not [string]::IsNullOrEmpty($ApiToken)) {
    $script:ApiToken = $ApiToken
}

# Handle command line arguments
switch ($TestType.ToLower()) {
    "quick" {
        if (Test-Server) { Test-BasicAuth }
    }
    "performance" {
        if (Test-Server) { Test-Performance }
    }
    "security" {
        if (Test-Server) { 
            Test-NoAuth
            Test-CrossTenantBlocking 
        }
    }
    "help" {
        Write-Host "Usage: .\test_api_locally.ps1 [TestType] [-ApiToken <token>]"
        Write-Host "  TestType:"
        Write-Host "    quick      - Run basic connectivity and auth test"
        Write-Host "    performance - Run performance benchmark only"
        Write-Host "    security   - Run security-focused tests"
        Write-Host "    all        - Run all tests (default)"
        Write-Host "    help       - Show this help"
        Write-Host ""
        Write-Host "  Examples:"
        Write-Host "    .\test_api_locally.ps1"
        Write-Host "    .\test_api_locally.ps1 quick"
        Write-Host "    .\test_api_locally.ps1 performance -ApiToken 'ovt_prod_abc123'"
    }
    default {
        Start-AllTests
    }
} 