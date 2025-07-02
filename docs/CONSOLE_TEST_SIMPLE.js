// ========================================
// THE ONE SPA - QUICK CONSOLE TEST
// ========================================
// 
// COPY AND PASTE THIS INTO BROWSER CONSOLE:
// 1. Go to theonespaoregon.com
// 2. Press F12 → Console tab
// 3. Paste the line below and press Enter

fetch('https://onevault-api.onrender.com/api/v1/track', {method: 'POST', headers: {'X-Customer-ID': 'one_spa', 'Authorization': 'Bearer ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f', 'Content-Type': 'application/json'}, body: JSON.stringify({event_type: 'page_view', page_url: window.location.href, event_data: {title: document.title, test: 'console_test', spa_context: 'browser_console_test'}})}).then(r => r.json()).then(d => console.log('✅ Test Result:', d)).catch(e => console.log('❌ Test Failed:', e));

// ========================================
// EXPECTED RESULT:
// ✅ Test Result: {
//   "success": true,
//   "message": "Event tracked successfully",
//   "event_id": "evt_staging_XX",
//   "processing_status": "automated"
// }
// ======================================== 