<?php
/**
 * OneVault API Configuration - Updated for Render Deployment
 * ==========================================================
 * 
 * Updated configuration for The One Spa Oregon (one_spa)
 * New API deployed on Render: https://onevault-api.onrender.com
 * 
 * Last Updated: 2024-12-28
 */

// ========================================================================
// UPDATED CONFIGURATION - Use these new values
// ========================================================================

// NEW: OneVault API Endpoint (Updated from old Neon endpoint)
define('ONEVAULT_API_ENDPOINT', 'https://onevault-api.onrender.com/api/v1/track');

// UNCHANGED: Your existing API token
define('ONEVAULT_API_TOKEN', 'ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f');

// NEW: Customer ID (Required for new API)
define('ONEVAULT_CUSTOMER_ID', 'one_spa');

// UNCHANGED: Your existing tenant hash key  
define('ONEVAULT_TENANT_HK', '\x6cd30f42d1ccfb4fa6a571db8c2fb43b3fb9dd80b0b4b092ece55b06c3c7b6f5');

// NEW: Additional configuration options
define('ONEVAULT_API_TIMEOUT', 10);  // Timeout in seconds
define('ONEVAULT_API_VERSION', 'v1');
define('ONEVAULT_DEBUG_MODE', false);  // Set to true for debugging

// ========================================================================
// UPDATED TRACKING FUNCTION
// ========================================================================

/**
 * Track site event using new OneVault API
 * 
 * @param string $session_id - User session identifier
 * @param string $page_url - Current page URL
 * @param string $event_type - Type of event (page_view, click, etc.)
 * @param array $event_data - Additional event data
 * @param string $referrer_url - Referring URL (optional)
 * @return array - API response
 */
function track_onevault_event($session_id, $page_url, $event_type = 'page_view', $event_data = [], $referrer_url = null) {
    
    // Prepare headers for new API format
    $headers = [
        'Authorization: Bearer ' . ONEVAULT_API_TOKEN,
        'X-Customer-ID: ' . ONEVAULT_CUSTOMER_ID,
        'Content-Type: application/json',
        'User-Agent: TheOneSpaOregon/1.0 PHP/' . PHP_VERSION
    ];
    
    // Prepare payload for new API format
    $payload = [
        'session_id' => $session_id,
        'page_url' => $page_url,
        'event_type' => $event_type,
        'event_data' => $event_data
    ];
    
    // Add referrer if provided
    if ($referrer_url) {
        $payload['referrer_url'] = $referrer_url;
    }
    
    // Initialize cURL
    $ch = curl_init();
    
    // Set cURL options
    curl_setopt_array($ch, [
        CURLOPT_URL => ONEVAULT_API_ENDPOINT,
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_POSTFIELDS => json_encode($payload),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => ONEVAULT_API_TIMEOUT,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_MAXREDIRS => 3
    ]);
    
    // Execute request
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curl_error = curl_error($ch);
    
    curl_close($ch);
    
    // Handle cURL errors
    if ($curl_error) {
        if (ONEVAULT_DEBUG_MODE) {
            error_log("OneVault API cURL Error: " . $curl_error);
        }
        return [
            'success' => false,
            'error' => 'Connection error: ' . $curl_error,
            'http_code' => 0
        ];
    }
    
    // Handle HTTP errors
    if ($http_code !== 200) {
        if (ONEVAULT_DEBUG_MODE) {
            error_log("OneVault API HTTP Error: " . $http_code . " - " . $response);
        }
        return [
            'success' => false,
            'error' => 'HTTP error: ' . $http_code,
            'http_code' => $http_code,
            'response' => $response
        ];
    }
    
    // Parse JSON response
    $data = json_decode($response, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        if (ONEVAULT_DEBUG_MODE) {
            error_log("OneVault API JSON Error: " . json_last_error_msg());
        }
        return [
            'success' => false,
            'error' => 'Invalid JSON response',
            'http_code' => $http_code,
            'response' => $response
        ];
    }
    
    // Return successful response
    return [
        'success' => true,
        'data' => $data,
        'http_code' => $http_code
    ];
}

// ========================================================================
// HELPER FUNCTIONS
// ========================================================================

/**
 * Generate session ID if not provided
 */
function generate_onevault_session_id() {
    if (session_status() == PHP_SESSION_NONE) {
        session_start();
    }
    return session_id() ?: 'guest_' . uniqid();
}

/**
 * Get current page URL
 */
function get_current_page_url() {
    $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https://' : 'http://';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    $uri = $_SERVER['REQUEST_URI'] ?? '/';
    return $protocol . $host . $uri;
}

/**
 * Get referrer URL
 */
function get_referrer_url() {
    return $_SERVER['HTTP_REFERER'] ?? null;
}

/**
 * Test OneVault API connection
 */
function test_onevault_connection() {
    $test_result = track_onevault_event(
        'test_' . time(),
        get_current_page_url(),
        'connection_test',
        [
            'test' => true,
            'timestamp' => date('c'),
            'source' => 'php_connection_test'
        ],
        get_referrer_url()
    );
    
    return $test_result;
}

// ========================================================================
// USAGE EXAMPLES
// ========================================================================

/**
 * Example 1: Basic page view tracking
 */
function track_page_view() {
    return track_onevault_event(
        generate_onevault_session_id(),
        get_current_page_url(),
        'page_view',
        [
            'page_title' => $_POST['page_title'] ?? 'Unknown',
            'load_time' => $_POST['load_time'] ?? null
        ],
        get_referrer_url()
    );
}

/**
 * Example 2: Track spa booking
 */
function track_spa_booking($booking_data) {
    return track_onevault_event(
        generate_onevault_session_id(),
        get_current_page_url(),
        'spa_booking',
        [
            'service_type' => $booking_data['service_type'] ?? 'unknown',
            'appointment_date' => $booking_data['appointment_date'] ?? null,
            'duration' => $booking_data['duration'] ?? null,
            'total_amount' => $booking_data['total_amount'] ?? null
        ],
        get_referrer_url()
    );
}

/**
 * Example 3: Track contact form submission
 */
function track_contact_form($form_data) {
    return track_onevault_event(
        generate_onevault_session_id(),
        get_current_page_url(),
        'contact_form_submit',
        [
            'form_type' => $form_data['form_type'] ?? 'contact',
            'inquiry_type' => $form_data['inquiry_type'] ?? 'general'
        ],
        get_referrer_url()
    );
}

// ========================================================================
// MIGRATION NOTES
// ========================================================================

/*
KEY CHANGES FROM OLD TO NEW API:

1. ENDPOINT CHANGE:
   OLD: https://app-wild-glade-78480567.dpl.myneon.app/rpc/track_site_event
   NEW: https://onevault-api.onrender.com/api/v1/track

2. NEW REQUIRED HEADER:
   - Must include: X-Customer-ID: one_spa

3. NEW REQUEST FORMAT:
   - Uses JSON payload instead of direct function parameters
   - More structured event data

4. AUTHENTICATION:
   - Same Bearer token, but now in Authorization header
   - Customer ID required in separate header

5. RESPONSE FORMAT:
   - Returns JSON with success/error status
   - Includes event_id for successful tracking

TESTING:
   Run test_onevault_connection() to verify the new setup works.
*/

?> 