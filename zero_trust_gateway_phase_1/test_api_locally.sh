#!/bin/bash

# Zero Trust Gateway Local API Testing Script
# Tests all endpoints with curl commands

echo "🛡️  Zero Trust Gateway - Local API Testing"
echo "=========================================="

# Configuration
BASE_URL="http://localhost:8000"
API_TOKEN=""  # Will be set by user or auto-detected

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_test() {
    echo -e "\n${BLUE}🧪 Testing: $1${NC}"
    echo "----------------------------------------"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to check if server is running
check_server() {
    print_test "Server Health Check"
    
    response=$(curl -s -w "HTTP_STATUS:%{http_code}" "$BASE_URL/health")
    http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$http_status" = "200" ]; then
        print_success "Server is running"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
        return 0
    else
        print_error "Server not responding (Status: $http_status)"
        echo "Make sure to run: python local_api_test.py"
        return 1
    fi
}

# Function to get API token from user
get_api_token() {
    if [ -z "$API_TOKEN" ]; then
        echo ""
        echo "🔑 API Token Required"
        echo "You need a valid API token from your database."
        echo ""
        echo "To get one, run this SQL query:"
        echo "SELECT ats.token_hash, ath.api_token_bk"
        echo "FROM auth.api_token_s ats"
        echo "JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk"
        echo "WHERE ats.is_revoked = false"
        echo "AND ats.expires_at > CURRENT_TIMESTAMP"
        echo "AND ats.load_end_date IS NULL"
        echo "LIMIT 1;"
        echo ""
        read -p "Enter your API token (ovt_prod_...): " API_TOKEN
        
        if [ -z "$API_TOKEN" ]; then
            print_error "No API token provided. Skipping authenticated tests."
            return 1
        fi
    fi
    return 0
}

# Function to test basic authentication
test_basic_auth() {
    print_test "Basic Authentication"
    
    if ! get_api_token; then
        return 1
    fi
    
    response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -H "Authorization: Bearer $API_TOKEN" \
        "$BASE_URL/api/v1/test/basic")
    
    http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$http_status" = "200" ]; then
        print_success "Authentication successful"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
        
        # Extract tenant info for later tests
        TENANT_BK=$(echo "$body" | jq -r '.tenant_name' 2>/dev/null | head -1)
        export TENANT_BK
        
    else
        print_error "Authentication failed (Status: $http_status)"
        echo "$body"
        return 1
    fi
}

# Function to test tenant access
test_tenant_access() {
    print_test "Tenant Access Control"
    
    if [ -z "$TENANT_BK" ]; then
        print_warning "No tenant info available. Run basic auth test first."
        return 1
    fi
    
    # Test access to own tenant
    response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -H "Authorization: Bearer $API_TOKEN" \
        "$BASE_URL/api/v1/test/tenant/$TENANT_BK")
    
    http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$http_status" = "200" ]; then
        print_success "Own tenant access granted"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        print_error "Own tenant access failed (Status: $http_status)"
        echo "$body"
    fi
}

# Function to test cross-tenant blocking
test_cross_tenant_blocking() {
    print_test "Cross-Tenant Access Blocking"
    
    # Try to access a different tenant (should fail)
    response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -H "Authorization: Bearer $API_TOKEN" \
        "$BASE_URL/api/v1/test/cross-tenant/TENANT_OTHER_123")
    
    http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$http_status" = "403" ]; then
        print_success "Cross-tenant access properly blocked"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    elif [ "$http_status" = "200" ]; then
        print_warning "Cross-tenant access allowed (Admin user?)"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        print_error "Unexpected response (Status: $http_status)"
        echo "$body"
    fi
}

# Function to test admin access
test_admin_access() {
    print_test "Admin Access Control"
    
    response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -H "Authorization: Bearer $API_TOKEN" \
        "$BASE_URL/api/v1/test/admin")
    
    http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$http_status" = "200" ]; then
        print_success "Admin access granted"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    elif [ "$http_status" = "403" ]; then
        print_warning "Admin access denied (expected for non-admin users)"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        print_error "Unexpected admin response (Status: $http_status)"
        echo "$body"
    fi
}

# Function to test business resource access
test_business_resources() {
    print_test "Business Resource Access"
    
    for resource in "users" "entities" "assets" "transactions"; do
        echo "Testing $resource access..."
        
        response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
            -H "Authorization: Bearer $API_TOKEN" \
            "$BASE_URL/api/v1/test/business/$resource")
        
        http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
        
        if [ "$http_status" = "200" ]; then
            print_success "$resource access granted"
            echo "$body" | jq '.simulated_query' 2>/dev/null || echo "Query: $(echo "$body" | grep -o 'SELECT.*')"
        else
            print_error "$resource access failed (Status: $http_status)"
            echo "$body"
        fi
        echo ""
    done
}

# Function to test performance
test_performance() {
    print_test "Performance Benchmarking"
    
    echo "Running 5 performance tests..."
    total_time=0
    
    for i in {1..5}; do
        start_time=$(date +%s%3N)
        
        response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
            -H "Authorization: Bearer $API_TOKEN" \
            "$BASE_URL/api/v1/test/performance")
        
        end_time=$(date +%s%3N)
        request_time=$((end_time - start_time))
        total_time=$((total_time + request_time))
        
        http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        
        if [ "$http_status" = "200" ]; then
            echo "Request $i: ${request_time}ms"
        else
            print_error "Performance test $i failed (Status: $http_status)"
        fi
    done
    
    avg_time=$((total_time / 5))
    echo ""
    echo "Average response time: ${avg_time}ms"
    
    if [ "$avg_time" -lt 200 ]; then
        print_success "Performance target met (<200ms)"
    else
        print_warning "Performance target missed (${avg_time}ms > 200ms)"
    fi
    
    # Get detailed metrics
    echo ""
    echo "Detailed middleware metrics:"
    curl -s "$BASE_URL/metrics" | jq '.' 2>/dev/null || curl -s "$BASE_URL/metrics"
}

# Function to test without authentication (should fail)
test_no_auth() {
    print_test "No Authentication (Should Fail)"
    
    response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        "$BASE_URL/api/v1/test/basic")
    
    http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$http_status" = "401" ]; then
        print_success "Unauthenticated access properly blocked"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        print_error "Expected 401, got $http_status"
        echo "$body"
    fi
}

# Main test execution
main() {
    echo "Starting local API tests..."
    echo "Make sure the server is running: python local_api_test.py"
    echo ""
    
    # Check if jq is available for JSON formatting
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found. JSON output will be unformatted."
        echo "Install jq for better output: sudo apt-get install jq"
        echo ""
    fi
    
    # Run tests
    if check_server; then
        test_no_auth
        test_basic_auth
        test_tenant_access
        test_cross_tenant_blocking
        test_admin_access
        test_business_resources
        test_performance
        
        echo ""
        echo "=========================================="
        print_success "Local API testing complete!"
        echo "🚀 Ready to deploy to production if all tests passed"
        echo "📊 Check the server logs for detailed middleware metrics"
    else
        print_error "Server not available. Start with: python local_api_test.py"
        exit 1
    fi
}

# Handle command line arguments
case "$1" in
    "quick")
        check_server && test_basic_auth
        ;;
    "performance")
        check_server && test_performance
        ;;
    "security")
        check_server && test_no_auth && test_cross_tenant_blocking
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [quick|performance|security|help]"
        echo "  quick      - Run basic connectivity and auth test"
        echo "  performance - Run performance benchmark only"
        echo "  security   - Run security-focused tests"
        echo "  help       - Show this help"
        echo "  (no args)  - Run all tests"
        ;;
    *)
        main
        ;;
esac 