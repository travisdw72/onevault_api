#!/bin/bash

# OneVault API Quick Test Script
# =============================
# Quick cURL tests for the OneVault API on Render

API_BASE="https://onevault-api.onrender.com"
API_TOKEN="ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f"
CUSTOMER_ID="one_spa"

echo "🧪 OneVault API Quick Test Suite"
echo "================================="
echo "API Base: $API_BASE"
echo "Customer: $CUSTOMER_ID"
echo "Time: $(date)"
echo "================================="
echo

# Test 1: Basic Health Check
echo "1️⃣  Testing Basic Health Check..."
echo "curl -s $API_BASE/health"
curl -s "$API_BASE/health" | jq '.' 2>/dev/null || curl -s "$API_BASE/health"
echo
echo "================================="
echo

# Test 2: Detailed Health Check
echo "2️⃣  Testing Detailed Health Check..."
echo "curl -s $API_BASE/health/detailed"
curl -s "$API_BASE/health/detailed" | jq '.' 2>/dev/null || curl -s "$API_BASE/health/detailed"
echo
echo "================================="
echo

# Test 3: Customer Health Check
echo "3️⃣  Testing Customer Health Check..."
echo "curl -s $API_BASE/health/customer/$CUSTOMER_ID"
curl -s "$API_BASE/health/customer/$CUSTOMER_ID" | jq '.' 2>/dev/null || curl -s "$API_BASE/health/customer/$CUSTOMER_ID"
echo
echo "================================="
echo

# Test 4: Platform Info
echo "4️⃣  Testing Platform Info..."
echo "curl -s $API_BASE/api/v1/platform/info"
curl -s "$API_BASE/api/v1/platform/info" | jq '.' 2>/dev/null || curl -s "$API_BASE/api/v1/platform/info"
echo
echo "================================="
echo

# Test 5: Site Tracking (The main test!)
echo "5️⃣  Testing Site Tracking with Authentication..."
echo "This is the main endpoint your website will use!"
echo

# Create test payload
TEST_PAYLOAD=$(cat <<EOF
{
  "session_id": "test_$(date +%s)",
  "page_url": "https://theonespaoregon.com/test-connection",
  "event_type": "connection_test", 
  "event_data": {
    "test_run": true,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "source": "curl_connection_test"
  },
  "referrer_url": "https://theonespaoregon.com"
}
EOF
)

echo "Headers:"
echo "  Authorization: Bearer [TOKEN]"
echo "  X-Customer-ID: $CUSTOMER_ID" 
echo "  Content-Type: application/json"
echo
echo "Payload:"
echo "$TEST_PAYLOAD" | jq '.' 2>/dev/null || echo "$TEST_PAYLOAD"
echo
echo "Response:"

curl -s -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "X-Customer-ID: $CUSTOMER_ID" \
  -H "Content-Type: application/json" \
  -H "User-Agent: OneVault-cURL-Test/1.0" \
  -d "$TEST_PAYLOAD" \
  "$API_BASE/api/v1/track" | jq '.' 2>/dev/null || curl -s -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "X-Customer-ID: $CUSTOMER_ID" \
  -H "Content-Type: application/json" \
  -H "User-Agent: OneVault-cURL-Test/1.0" \
  -d "$TEST_PAYLOAD" \
  "$API_BASE/api/v1/track"

echo
echo "================================="
echo

# Test 6: Invalid Authentication Test
echo "6️⃣  Testing Invalid Authentication (Should Fail)..."
echo "curl with invalid token - should return 401/403"

curl -s -X POST \
  -H "Authorization: Bearer invalid_test_token" \
  -H "X-Customer-ID: $CUSTOMER_ID" \
  -H "Content-Type: application/json" \
  -d '{"session_id":"test","page_url":"https://test.com","event_type":"test"}' \
  "$API_BASE/api/v1/track" | jq '.' 2>/dev/null || curl -s -X POST \
  -H "Authorization: Bearer invalid_test_token" \
  -H "X-Customer-ID: $CUSTOMER_ID" \
  -H "Content-Type: application/json" \
  -d '{"session_id":"test","page_url":"https://test.com","event_type":"test"}' \
  "$API_BASE/api/v1/track"

echo
echo "================================="
echo

# Test 7: Missing Customer Header Test
echo "7️⃣  Testing Missing Customer Header (Should Fail)..."
echo "curl without X-Customer-ID header - should return 400"

curl -s -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"session_id":"test","page_url":"https://test.com","event_type":"test"}' \
  "$API_BASE/api/v1/track" | jq '.' 2>/dev/null || curl -s -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"session_id":"test","page_url":"https://test.com","event_type":"test"}' \
  "$API_BASE/api/v1/track"

echo
echo "================================="
echo "🎯 Quick Test Complete!"
echo
echo "✅ If Test 5 (Site Tracking) shows success: true - YOUR API IS WORKING!"
echo "❌ If Test 5 fails - check the error message for debugging info"
echo 
echo "Next steps:"
echo "1. Update your PHP code with the new configuration"
echo "2. Test from your website"
echo "3. Monitor the tracking data in your dashboard"
echo "=================================" 