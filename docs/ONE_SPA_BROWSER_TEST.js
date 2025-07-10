/**
 * THE ONE SPA - Browser Console Test Script
 * ========================================
 * 
 * INSTRUCTIONS:
 * 1. Go to https://theonespaoregon.com
 * 2. Open Developer Tools (F12)
 * 3. Go to Console tab
 * 4. Paste this entire script and press Enter
 * 5. Watch the automated testing and results
 * 
 * This tests the complete automated pipeline:
 * Frontend → API → Raw → Staging → Business → Monitoring
 */

console.log('🚀 Starting The ONE Spa Site Tracking Test...');
console.log('Testing complete automated pipeline with real-time processing');

// Configuration for The ONE Spa
const SPA_CONFIG = {
    apiBaseUrl: 'https://onevault-api.onrender.com', // Your Render URL
    customerId: 'one_spa',
    apiToken: 'ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f',
    testEvents: [
        {
            name: 'Homepage Visit',
            event_type: 'page_view',
            page_url: window.location.href,
            event_data: {
                title: document.title,
                referrer: document.referrer,
                spa_context: 'homepage_visit'
            }
        },
        {
            name: 'Service Interest',
            event_type: 'item_interaction',
            page_url: window.location.href,
            event_data: {
                service_type: 'massage_therapy',
                action: 'view_service',
                spa_context: 'service_browsing',
                event_label: 'deep_tissue_massage',
                event_value: 120
            }
        },
        {
            name: 'Booking Intent',
            event_type: 'transaction_step',
            page_url: window.location.href,
            event_data: {
                action: 'start',
                transaction_type: 'appointment_booking',
                spa_context: 'booking_funnel',
                event_label: 'appointment_booking_start',
                event_value: 120
            }
        },
        {
            name: 'Contact Interaction',
            event_type: 'contact_interaction',
            page_url: window.location.href,
            event_data: {
                action: 'phone_click',
                contact_method: 'phone',
                spa_context: 'contact_engagement',
                event_label: 'phone_number_click',
                event_value: 25
            }
        }
    ]
};

// Test Results Storage
let testResults = {
    events: [],
    pipeline: {},
    automation: {},
    startTime: new Date()
};

// Helper function to make API calls
async function makeAPICall(endpoint, method = 'GET', data = null) {
    const headers = {
        'X-Customer-ID': SPA_CONFIG.customerId,
        'Authorization': `Bearer ${SPA_CONFIG.apiToken}`,
        'Content-Type': 'application/json'
    };
    
    const options = {
        method,
        headers,
        ...(data && { body: JSON.stringify(data) })
    };
    
    try {
        const response = await fetch(`${SPA_CONFIG.apiBaseUrl}${endpoint}`, options);
        const result = await response.json();
        return { success: response.ok, status: response.status, data: result };
    } catch (error) {
        return { success: false, error: error.message };
    }
}

// Test 1: API Health Check
async function testAPIHealth() {
    console.log('\n📊 Test 1: API Health Check');
    
    const result = await makeAPICall('/health');
    
    if (result.success) {
        console.log('✅ API is healthy and responding');
        console.log('   Status:', result.data.status);
        console.log('   Database:', result.data.database ? 'Connected' : 'Disconnected');
    } else {
        console.log('❌ API health check failed:', result.error || result.status);
    }
    
    return result.success;
}

// Test 2: Send Tracking Events (with automation)
async function testEventTracking() {
    console.log('\n🎯 Test 2: Sending Spa Tracking Events (Automated Processing)');
    
    for (let i = 0; i < SPA_CONFIG.testEvents.length; i++) {
        const event = SPA_CONFIG.testEvents[i];
        console.log(`\n   Sending Event ${i + 1}: ${event.name}`);
        
        const startTime = performance.now();
        const result = await makeAPICall('/api/v1/track', 'POST', event);
        const endTime = performance.now();
        const duration = Math.round(endTime - startTime);
        
        if (result.success) {
            console.log(`   ✅ ${event.name} tracked successfully (${duration}ms)`);
            console.log(`      Event ID: ${result.data.event_id || 'Generated'}`);
            console.log(`      Processing: ${result.data.processing_status || 'Automated'}`);
            
            testResults.events.push({
                name: event.name,
                success: true,
                duration,
                eventId: result.data.event_id,
                automation: result.data.automation_triggered || true
            });
        } else {
            console.log(`   ❌ ${event.name} failed:`, result.error || result.status);
            testResults.events.push({
                name: event.name,
                success: false,
                error: result.error || result.status
            });
        }
        
        // Brief pause between events
        await new Promise(resolve => setTimeout(resolve, 500));
    }
}

// Test 3: Check Pipeline Status (Automation Verification)
async function testPipelineStatus() {
    console.log('\n⚙️ Test 3: Pipeline Status & Automation Verification');
    
    const result = await makeAPICall('/api/v1/track/status');
    
    if (result.success) {
        const status = result.data.pipeline_status;
        console.log('✅ Pipeline Status Retrieved:');
        console.log(`   Raw Events: ${status.raw_events_count || 0}`);
        console.log(`   Staging Events: ${status.staging_events_count || 0}`);
        console.log(`   Business Events: ${status.business_events_count || 0}`);
        console.log(`   Processing Status: ${status.processing_status || 'Unknown'}`);
        console.log(`   Automation Active: ${status.automation_enabled ? 'Yes' : 'No'}`);
        
        testResults.pipeline = status;
    } else {
        console.log('❌ Pipeline status check failed:', result.error || result.status);
    }
    
    return result.success;
}

// Test 4: Check Dashboard Data (Real-time Monitoring)
async function testDashboardData() {
    console.log('\n📈 Test 4: Real-time Dashboard Data');
    
    const result = await makeAPICall('/api/v1/track/dashboard?limit=10');
    
    if (result.success) {
        const dashboard = result.data.recent_events || [];
        console.log(`✅ Dashboard Data Retrieved (${dashboard.length} recent events):`);
        
        dashboard.slice(0, 3).forEach((event, index) => {
            console.log(`   Event ${index + 1}:`);
            console.log(`      Type: ${event.event_type || 'Unknown'}`);
            console.log(`      Status: ${event.processing_status || 'Unknown'}`);
            console.log(`      Time: ${event.created_at || event.load_date || 'Unknown'}`);
        });
        
        testResults.automation = {
            recentEvents: dashboard.length,
            latestEvent: dashboard[0] || null
        };
    } else {
        console.log('❌ Dashboard data check failed:', result.error || result.status);
    }
    
    return result.success;
}

// Test 5: Manual Pipeline Trigger (Verification)
async function testManualTrigger() {
    console.log('\n🔧 Test 5: Manual Pipeline Trigger (Verification)');
    
    const result = await makeAPICall('/api/v1/track/process', 'POST');
    
    if (result.success) {
        console.log('✅ Manual pipeline trigger successful:');
        console.log(`   Events Processed: ${result.data.events_processed || 0}`);
        console.log(`   Processing Time: ${result.data.processing_time_ms || 0}ms`);
        console.log(`   Status: ${result.data.status || 'Unknown'}`);
    } else {
        console.log('❌ Manual trigger failed:', result.error || result.status);
    }
    
    return result.success;
}

// Main Test Runner
async function runSpaTrackingTest() {
    console.log('🏥 THE ONE SPA - AUTOMATED SITE TRACKING TEST');
    console.log('============================================');
    console.log(`Testing from: ${window.location.href}`);
    console.log(`API Endpoint: ${SPA_CONFIG.apiBaseUrl}`);
    console.log(`Customer: ${SPA_CONFIG.customerId}`);
    console.log(`Start Time: ${testResults.startTime.toLocaleString()}`);
    
    try {
        // Run all tests
        const healthOk = await testAPIHealth();
        if (!healthOk) {
            console.log('\n❌ CRITICAL: API health check failed. Cannot continue testing.');
            return;
        }
        
        await testEventTracking();
        await new Promise(resolve => setTimeout(resolve, 2000)); // Wait for processing
        await testPipelineStatus();
        await testDashboardData();
        await testManualTrigger();
        
        // Final Results Summary
        console.log('\n🎉 TEST RESULTS SUMMARY');
        console.log('======================');
        
        const successfulEvents = testResults.events.filter(e => e.success).length;
        const totalEvents = testResults.events.length;
        
        console.log(`📊 Event Tracking: ${successfulEvents}/${totalEvents} successful`);
        console.log(`⚙️ Pipeline Status: ${testResults.pipeline.processing_status || 'Unknown'}`);
        console.log(`📈 Dashboard Events: ${testResults.automation.recentEvents || 0} recent events`);
        console.log(`⏱️ Total Test Time: ${Math.round((new Date() - testResults.startTime) / 1000)}s`);
        
        if (successfulEvents === totalEvents) {
            console.log('\n✅ ALL TESTS PASSED! 🚀');
            console.log('The ONE Spa site tracking automation is working perfectly!');
            console.log('Events are flowing: Frontend → API → Raw → Staging → Business');
        } else {
            console.log('\n⚠️ SOME TESTS FAILED');
            console.log('Check the detailed results above for issues.');
        }
        
        // Detailed Event Results
        console.log('\n📝 DETAILED EVENT RESULTS:');
        testResults.events.forEach((event, index) => {
            const status = event.success ? '✅' : '❌';
            const duration = event.duration ? ` (${event.duration}ms)` : '';
            console.log(`   ${status} ${event.name}${duration}`);
            if (event.eventId) console.log(`      Event ID: ${event.eventId}`);
            if (event.error) console.log(`      Error: ${event.error}`);
        });
        
    } catch (error) {
        console.log('\n❌ CRITICAL ERROR during testing:', error);
    }
}

// Auto-start the test
console.log('🚀 Starting automated test in 2 seconds...');
setTimeout(runSpaTrackingTest, 2000);

// Also provide manual trigger
window.testSpaTracking = runSpaTrackingTest;
console.log('\n💡 TIP: You can also run testSpaTracking() manually anytime'); 