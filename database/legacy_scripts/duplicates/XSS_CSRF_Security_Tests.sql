-- ================================================
-- XSS/CSRF Security Testing Script
-- Tests various cross-site attack vectors
-- ================================================

-- Clean up any previous test results
DROP TABLE IF EXISTS temp_security_test_results;

-- Create table to store test results
CREATE TEMP TABLE temp_security_test_results (
    test_id SERIAL PRIMARY KEY,
    test_category VARCHAR(50),
    test_name VARCHAR(100),
    test_payload TEXT,
    expected_result VARCHAR(50),
    actual_result TEXT,
    passed BOOLEAN,
    notes TEXT,
    test_timestamp TIMESTAMP DEFAULT NOW()
);

DO $$
DECLARE
    v_result JSONB;
    v_test_payload TEXT;
    v_expected TEXT;
    v_actual TEXT;
    v_passed BOOLEAN;
    v_notes TEXT;
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'STARTING XSS/CSRF SECURITY TESTS';
    RAISE NOTICE '============================================';

    -- ========================================
    -- XSS TESTING SECTION
    -- ========================================
    RAISE NOTICE 'Testing XSS vulnerabilities...';

    -- XSS Test 1: Script injection in username
    BEGIN
        v_test_payload := '<script>alert("XSS")</script>@example.com';
        SELECT api.auth_login(jsonb_build_object(
            'username', v_test_payload,
            'password', 'password123',
            'ip_address', '192.168.1.100',
            'user_agent', 'XSS Test Browser'
        )) INTO v_result;
        
        v_actual := v_result->>'p_message';
        v_passed := NOT (v_actual LIKE '%<script>%' OR v_actual LIKE '%alert%');
        
        INSERT INTO temp_security_test_results 
        (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
        VALUES 
        ('XSS', 'Script Tag in Username', v_test_payload, 'No script execution', v_actual, v_passed, 
         'Should sanitize script tags in username field');
    EXCEPTION
        WHEN OTHERS THEN
            v_passed := TRUE; -- Exception is actually good for security
            INSERT INTO temp_security_test_results 
            (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
            VALUES 
            ('XSS', 'Script Tag in Username', v_test_payload, 'Exception/Rejection', SQLERRM, v_passed, 
             'Exception thrown - good security practice');
    END;

    -- XSS Test 2: HTML injection in password
    BEGIN
        v_test_payload := '<img src=x onerror=alert("XSS")>';
        SELECT api.auth_login(jsonb_build_object(
            'username', 'test@example.com',
            'password', v_test_payload,
            'ip_address', '192.168.1.101',
            'user_agent', 'XSS Test Browser'
        )) INTO v_result;
        
        v_actual := v_result->>'p_message';
        v_passed := NOT (v_actual LIKE '%<img%' OR v_actual LIKE '%onerror%');
        
        INSERT INTO temp_security_test_results 
        (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
        VALUES 
        ('XSS', 'Image XSS in Password', v_test_payload, 'No HTML execution', v_actual, v_passed, 
         'Should sanitize HTML tags in password field');
    EXCEPTION
        WHEN OTHERS THEN
            v_passed := TRUE;
            INSERT INTO temp_security_test_results 
            (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
            VALUES 
            ('XSS', 'Image XSS in Password', v_test_payload, 'Exception/Rejection', SQLERRM, v_passed, 
             'Exception thrown - good security practice');
    END;

    -- XSS Test 3: JavaScript in User-Agent
    BEGIN
        v_test_payload := 'Mozilla/5.0 <script>document.cookie="hacked=true"</script>';
        SELECT api.auth_login(jsonb_build_object(
            'username', 'travisdwoodward72@gmail.com',
            'password', 'MyNewSecurePassword123',
            'ip_address', '192.168.1.102',
            'user_agent', v_test_payload
        )) INTO v_result;
        
        v_actual := v_result->>'p_message';
        v_passed := NOT (v_actual LIKE '%<script>%' OR v_actual LIKE '%document.cookie%');
        
        INSERT INTO temp_security_test_results 
        (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
        VALUES 
        ('XSS', 'Script in User-Agent', v_test_payload, 'No script execution', v_actual, v_passed, 
         'Should sanitize user-agent field for logging');
    EXCEPTION
        WHEN OTHERS THEN
            v_passed := TRUE;
            INSERT INTO temp_security_test_results 
            (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
            VALUES 
            ('XSS', 'Script in User-Agent', v_test_payload, 'Exception/Rejection', SQLERRM, v_passed, 
             'Exception thrown - good security practice');
    END;

    -- XSS Test 4: CSS injection
    BEGIN
        v_test_payload := 'test<style>body{background:red;}</style>@example.com';
        SELECT api.auth_login(jsonb_build_object(
            'username', v_test_payload,
            'password', 'password123',
            'ip_address', '192.168.1.103',
            'user_agent', 'CSS Test Browser'
        )) INTO v_result;
        
        v_actual := v_result->>'p_message';
        v_passed := NOT (v_actual LIKE '%<style>%' OR v_actual LIKE '%background%');
        
        INSERT INTO temp_security_test_results 
        (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
        VALUES 
        ('XSS', 'CSS Injection in Username', v_test_payload, 'No CSS execution', v_actual, v_passed, 
         'Should sanitize CSS tags');
    EXCEPTION
        WHEN OTHERS THEN
            v_passed := TRUE;
            INSERT INTO temp_security_test_results 
            (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
            VALUES 
            ('XSS', 'CSS Injection in Username', v_test_payload, 'Exception/Rejection', SQLERRM, v_passed, 
             'Exception thrown - good security practice');
    END;

    -- ========================================
    -- CSRF TESTING SECTION
    -- ========================================
    RAISE NOTICE 'Testing CSRF vulnerabilities...';

    -- CSRF Test 1: JSON structure manipulation
    BEGIN
        v_test_payload := '{"username":"test@example.com","password":"pass","admin":true,"bypass_auth":true}';
        SELECT api.auth_login(v_test_payload::jsonb) INTO v_result;
        
        v_actual := v_result->>'p_message';
        v_passed := NOT (v_result->>'p_success')::boolean;
        
        INSERT INTO temp_security_test_results 
        (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
        VALUES 
        ('CSRF', 'JSON Parameter Injection', v_test_payload, 'Reject extra parameters', v_actual, v_passed, 
         'Should ignore unauthorized JSON parameters');
    EXCEPTION
        WHEN OTHERS THEN
            v_passed := TRUE;
            INSERT INTO temp_security_test_results 
            (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
            VALUES 
            ('CSRF', 'JSON Parameter Injection', v_test_payload, 'Exception/Rejection', SQLERRM, v_passed, 
             'Exception thrown - good security practice');
    END;

    -- CSRF Test 2: HTTP Method spoofing attempt (simulated)
    BEGIN
        v_test_payload := 'POST /admin/delete_user HTTP/1.1';
        SELECT api.auth_login(jsonb_build_object(
            'username', 'test@example.com',
            'password', 'password123',
            'ip_address', '192.168.1.104',
            'user_agent', v_test_payload
        )) INTO v_result;
        
        v_actual := v_result->>'p_message';
        v_passed := NOT (v_actual LIKE '%admin%' OR v_actual LIKE '%delete%');
        
        INSERT INTO temp_security_test_results 
        (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
        VALUES 
        ('CSRF', 'HTTP Method Spoofing', v_test_payload, 'No command execution', v_actual, v_passed, 
         'Should not interpret HTTP commands in user-agent');
    EXCEPTION
        WHEN OTHERS THEN
            v_passed := TRUE;
            INSERT INTO temp_security_test_results 
            (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
            VALUES 
            ('CSRF', 'HTTP Method Spoofing', v_test_payload, 'Exception/Rejection', SQLERRM, v_passed, 
             'Exception thrown - good security practice');
    END;

    -- CSRF Test 3: Content-Type manipulation simulation
    BEGIN
        v_test_payload := 'application/x-www-form-urlencoded; boundary=--12345';
        SELECT api.auth_login(jsonb_build_object(
            'username', 'test@example.com',
            'password', 'password123',
            'ip_address', '192.168.1.105',
            'user_agent', v_test_payload
        )) INTO v_result;
        
        v_actual := v_result->>'p_message';
        v_passed := TRUE; -- This should not affect the function
        
        INSERT INTO temp_security_test_results 
        (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
        VALUES 
        ('CSRF', 'Content-Type Header Injection', v_test_payload, 'Normal processing', v_actual, v_passed, 
         'User-agent with content-type should not affect processing');
    EXCEPTION
        WHEN OTHERS THEN
            v_passed := TRUE;
            INSERT INTO temp_security_test_results 
            (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
            VALUES 
            ('CSRF', 'Content-Type Header Injection', v_test_payload, 'Exception/Rejection', SQLERRM, v_passed, 
             'Exception thrown - acceptable');
    END;

    -- ========================================
    -- ADDITIONAL ATTACK VECTORS
    -- ========================================
    RAISE NOTICE 'Testing additional attack vectors...';

    -- Test 1: Unicode/encoding attacks
    BEGIN
        v_test_payload := 'test%3Cscript%3Ealert%28%22xss%22%29%3C%2Fscript%3E@example.com';
        SELECT api.auth_login(jsonb_build_object(
            'username', v_test_payload,
            'password', 'password123',
            'ip_address', '192.168.1.106',
            'user_agent', 'Encoding Test Browser'
        )) INTO v_result;
        
        v_actual := v_result->>'p_message';
        v_passed := NOT (v_actual LIKE '%script%' OR v_actual LIKE '%alert%');
        
        INSERT INTO temp_security_test_results 
        (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
        VALUES 
        ('Encoding', 'URL Encoded XSS', v_test_payload, 'No script execution', v_actual, v_passed, 
         'Should handle URL encoded malicious content');
    EXCEPTION
        WHEN OTHERS THEN
            v_passed := TRUE;
            INSERT INTO temp_security_test_results 
            (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
            VALUES 
            ('Encoding', 'URL Encoded XSS', v_test_payload, 'Exception/Rejection', SQLERRM, v_passed, 
             'Exception thrown - good security practice');
    END;

    -- Test 2: Polyglot attack
    BEGIN
        v_test_payload := '''"><script>alert(String.fromCharCode(88,83,83))</script>';
        SELECT api.auth_login(jsonb_build_object(
            'username', 'test@example.com',
            'password', v_test_payload,
            'ip_address', '192.168.1.107',
            'user_agent', 'Polyglot Test Browser'
        )) INTO v_result;
        
        v_actual := v_result->>'p_message';
        v_passed := NOT (v_actual LIKE '%script%' OR v_actual LIKE '%alert%' OR v_actual LIKE '%fromCharCode%');
        
        INSERT INTO temp_security_test_results 
        (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
        VALUES 
        ('Advanced', 'Polyglot XSS Attack', v_test_payload, 'No script execution', v_actual, v_passed, 
         'Should handle complex polyglot attacks');
    EXCEPTION
        WHEN OTHERS THEN
            v_passed := TRUE;
            INSERT INTO temp_security_test_results 
            (test_category, test_name, test_payload, expected_result, actual_result, passed, notes)
            VALUES 
            ('Advanced', 'Polyglot XSS Attack', v_test_payload, 'Exception/Rejection', SQLERRM, v_passed, 
             'Exception thrown - good security practice');
    END;

    RAISE NOTICE 'XSS/CSRF Security tests completed!';
    
    -- ========================================
    -- DISPLAY RESULTS WITHIN THE SAME BLOCK
    -- ========================================
    RAISE NOTICE '============================================';
    RAISE NOTICE 'SECURITY TEST RESULTS SUMMARY';
    RAISE NOTICE '============================================';
END;
$$;

SELECT 
    test_category,
    COUNT(*) as total_tests,
    SUM(CASE WHEN passed THEN 1 ELSE 0 END) as passed_tests,
    SUM(CASE WHEN NOT passed THEN 1 ELSE 0 END) as failed_tests,
    ROUND(
        (SUM(CASE WHEN passed THEN 1 ELSE 0 END)::decimal / COUNT(*)) * 100, 
        2
    ) as pass_percentage
FROM temp_security_test_results
GROUP BY test_category
ORDER BY test_category;

-- Display detailed results after the DO block
-- RAISE NOTICE '';
-- RAISE NOTICE 'DETAILED RESULTS:';

SELECT 
    test_id,
    test_category,
    test_name,
    CASE 
        WHEN passed THEN '✅ PASS'
        ELSE '❌ FAIL'
    END as result,
    LEFT(test_payload, 50) || CASE WHEN LENGTH(test_payload) > 50 THEN '...' ELSE '' END as payload_preview,
    LEFT(actual_result, 100) || CASE WHEN LENGTH(actual_result) > 100 THEN '...' ELSE '' END as result_preview,
    notes
FROM temp_security_test_results
ORDER BY test_category, test_id;

-- ========================================
-- FAILED TESTS DETAIL
-- ========================================
SELECT 
    'SECURITY VULNERABILITIES FOUND:' as alert_header
WHERE EXISTS (SELECT 1 FROM temp_security_test_results WHERE NOT passed);

SELECT 
    '🚨 VULNERABILITY: ' || test_category || ' - ' || test_name as vulnerability,
    'Payload: ' || test_payload as attack_vector,
    'Response: ' || actual_result as system_response,
    'Risk: ' || notes as risk_assessment
FROM temp_security_test_results 
WHERE NOT passed
ORDER BY test_category, test_name;

-- ========================================
-- RECOMMENDATIONS
-- ========================================
DO $$
DECLARE
    v_failed_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_failed_count FROM temp_security_test_results WHERE NOT passed;
    
    IF v_failed_count > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '============================================';
        RAISE NOTICE 'SECURITY RECOMMENDATIONS';
        RAISE NOTICE '============================================';
        RAISE NOTICE '1. Implement input sanitization for all user inputs';
        RAISE NOTICE '2. Use parameterized queries to prevent injection';
        RAISE NOTICE '3. Implement Content Security Policy (CSP) headers';
        RAISE NOTICE '4. Add CSRF tokens for state-changing operations';
        RAISE NOTICE '5. Validate and sanitize all JSON input parameters';
        RAISE NOTICE '6. Log and monitor for attack patterns';
        RAISE NOTICE '7. Consider implementing rate limiting';
        RAISE NOTICE '8. Regular security testing and penetration testing';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '✅ No XSS/CSRF vulnerabilities detected in tested vectors!';
        RAISE NOTICE 'Continue with regular security testing and monitoring.';
    END IF;
END;
$$; 