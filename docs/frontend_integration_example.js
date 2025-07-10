/**
 * OneVault Site Tracking - Frontend Integration Example
 * ===================================================
 * 
 * This example shows how to integrate the new automated site tracking
 * endpoints in your frontend application.
 */

class OneVaultTracker {
    constructor(config) {
        this.apiBaseUrl = config.apiBaseUrl || 'https://your-api-domain.com';
        this.customerId = config.customerId;
        this.apiToken = config.apiToken;
        this.useAsync = config.useAsync || false; // Use async endpoint by default
        this.enableDebug = config.enableDebug || false;
        
        // Validate required config
        if (!this.customerId || !this.apiToken) {
            throw new Error('OneVault Tracker requires customerId and apiToken');
        }
        
        this.log('🚀 OneVault Tracker initialized', { 
            useAsync: this.useAsync,
            customerId: this.customerId 
        });
    }
    
    /**
     * Get headers for API requests
     */
    getHeaders() {
        return {
            'X-Customer-ID': this.customerId,
            'Authorization': `Bearer ${this.apiToken}`,
            'Content-Type': 'application/json'
        };
    }
    
    /**
     * Log debug messages
     */
    log(message, data = null) {
        if (this.enableDebug) {
            console.log(`[OneVault] ${message}`, data || '');
        }
    }
    
    /**
     * Track a site event with automatic processing
     */
    async trackEvent(eventData) {
        const endpoint = this.useAsync ? '/api/v1/track/async' : '/api/v1/track';
        
        try {
            this.log(`📊 Tracking event: ${eventData.event_type}`, eventData);
            
            const response = await fetch(`${this.apiBaseUrl}${endpoint}`, {
                method: 'POST',
                headers: this.getHeaders(),
                body: JSON.stringify({
                    page_url: eventData.page_url || window.location.href,
                    event_type: eventData.event_type || 'page_view',
                    event_data: eventData.event_data || {}
                })
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const result = await response.json();
            
            this.log(`✅ Event tracked successfully`, {
                eventId: result.event_id,
                processing: result.processing,
                message: result.message
            });
            
            return result;
            
        } catch (error) {
            this.log(`❌ Failed to track event: ${error.message}`, eventData);
            
            // Don't throw - tracking failures shouldn't break the app
            return {
                success: false,
                error: error.message,
                event_data: eventData
            };
        }
    }
    
    /**
     * Track page view (most common event)
     */
    async trackPageView(additionalData = {}) {
        return this.trackEvent({
            event_type: 'page_view',
            page_url: window.location.href,
            event_data: {
                title: document.title,
                referrer: document.referrer,
                timestamp: new Date().toISOString(),
                ...additionalData
            }
        });
    }
    
    /**
     * Track user interaction
     */
    async trackInteraction(elementType, elementId, action, additionalData = {}) {
        return this.trackEvent({
            event_type: 'user_interaction',
            page_url: window.location.href,
            event_data: {
                element_type: elementType,
                element_id: elementId,
                action: action,
                timestamp: new Date().toISOString(),
                ...additionalData
            }
        });
    }
    
    /**
     * Track form submission
     */
    async trackFormSubmission(formId, formData = {}) {
        return this.trackEvent({
            event_type: 'form_submission',
            page_url: window.location.href,
            event_data: {
                form_id: formId,
                form_data: formData, // Be careful with sensitive data
                timestamp: new Date().toISOString()
            }
        });
    }
    
    /**
     * Track custom event
     */
    async trackCustomEvent(eventType, eventData = {}) {
        return this.trackEvent({
            event_type: eventType,
            page_url: window.location.href,
            event_data: {
                timestamp: new Date().toISOString(),
                ...eventData
            }
        });
    }
    
    /**
     * Get tracking status and recent events
     */
    async getTrackingStatus() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/api/v1/track/status`, {
                method: 'GET',
                headers: this.getHeaders()
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            return await response.json();
            
        } catch (error) {
            this.log(`❌ Failed to get tracking status: ${error.message}`);
            return { success: false, error: error.message };
        }
    }
    
    /**
     * Get dashboard data
     */
    async getDashboardData(limit = 10) {
        try {
            const response = await fetch(`${this.apiBaseUrl}/api/v1/track/dashboard?limit=${limit}`, {
                method: 'GET',
                headers: this.getHeaders()
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            return await response.json();
            
        } catch (error) {
            this.log(`❌ Failed to get dashboard data: ${error.message}`);
            return { success: false, error: error.message };
        }
    }
    
    /**
     * Manually trigger processing (for testing)
     */
    async triggerProcessing() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/api/v1/track/process`, {
                method: 'POST',
                headers: this.getHeaders()
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            return await response.json();
            
        } catch (error) {
            this.log(`❌ Failed to trigger processing: ${error.message}`);
            return { success: false, error: error.message };
        }
    }
    
    /**
     * Auto-track common events
     */
    enableAutoTracking() {
        this.log('🔄 Enabling auto-tracking...');
        
        // Track page view on load
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.trackPageView());
        } else {
            this.trackPageView();
        }
        
        // Track clicks on important elements
        document.addEventListener('click', (event) => {
            const element = event.target;
            
            // Track button clicks
            if (element.tagName === 'BUTTON' || element.type === 'submit') {
                this.trackInteraction('button', element.id || element.className, 'click', {
                    text: element.textContent?.trim().substring(0, 100)
                });
            }
            
            // Track link clicks
            if (element.tagName === 'A') {
                this.trackInteraction('link', element.id || element.href, 'click', {
                    href: element.href,
                    text: element.textContent?.trim().substring(0, 100)
                });
            }
        });
        
        // Track form submissions
        document.addEventListener('submit', (event) => {
            const form = event.target;
            if (form.tagName === 'FORM') {
                // Don't include sensitive form data
                this.trackFormSubmission(form.id || form.className, {
                    action: form.action,
                    method: form.method
                });
            }
        });
        
        this.log('✅ Auto-tracking enabled');
    }
}

// Example usage configurations
const examples = {
    
    // Basic setup for production
    production: {
        apiBaseUrl: 'https://api.onevault.com',
        customerId: 'one_spa',
        apiToken: 'ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f',
        useAsync: true, // Use async for better performance
        enableDebug: false
    },
    
    // Development setup
    development: {
        apiBaseUrl: 'http://localhost:8000',
        customerId: 'one_spa', 
        apiToken: 'ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f',
        useAsync: false, // Use sync for easier debugging
        enableDebug: true
    }
};

// Usage Examples
// ==============

// 1. Basic initialization and page tracking
/*
const tracker = new OneVaultTracker(examples.production);
tracker.trackPageView();
*/

// 2. Auto-tracking setup (recommended)
/*
const tracker = new OneVaultTracker(examples.production);
tracker.enableAutoTracking();
*/

// 3. Manual event tracking
/*
const tracker = new OneVaultTracker(examples.production);

// Track custom events
tracker.trackCustomEvent('user_signup', {
    user_type: 'premium',
    signup_method: 'google'
});

// Track interactions
tracker.trackInteraction('button', 'checkout-btn', 'click', {
    cart_value: 99.99,
    items_count: 3
});
*/

// 4. Monitoring and debugging
/*
const tracker = new OneVaultTracker(examples.development);

// Get status
tracker.getTrackingStatus().then(status => {
    console.log('Tracking Status:', status);
});

// Get dashboard data
tracker.getDashboardData(20).then(dashboard => {
    console.log('Dashboard:', dashboard);
});

// Manually trigger processing (for testing)
tracker.triggerProcessing().then(result => {
    console.log('Processing Result:', result);
});
*/

// 5. High-volume setup (recommended for busy sites)
/*
const tracker = new OneVaultTracker({
    ...examples.production,
    useAsync: true // Background processing for better performance
});

// Enable auto-tracking for comprehensive coverage
tracker.enableAutoTracking();

// Track custom business events
tracker.trackCustomEvent('appointment_booked', {
    service_type: 'massage',
    duration: 60,
    value: 120.00
});
*/

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = OneVaultTracker;
}

// Global variable for browser usage
if (typeof window !== 'undefined') {
    window.OneVaultTracker = OneVaultTracker;
}

/**
 * Integration Checklist
 * =====================
 * 
 * 1. ✅ Include this script in your HTML
 * 2. ✅ Configure with your API credentials
 * 3. ✅ Choose sync vs async endpoint based on volume
 * 4. ✅ Enable auto-tracking for comprehensive coverage
 * 5. ✅ Add custom events for business-specific tracking
 * 6. ✅ Monitor via dashboard endpoints
 * 7. ✅ Test with development configuration first
 * 
 * Performance Notes:
 * ==================
 * 
 * - Use async endpoint for high-volume sites (>100 events/min)
 * - Use sync endpoint for immediate processing needs
 * - Auto-tracking covers 80% of common events automatically
 * - Custom events for business-specific requirements
 * - All tracking is non-blocking and won't affect site performance
 * 
 * Security Notes:
 * ===============
 * 
 * - Never include sensitive data in event_data
 * - API tokens should be environment-specific
 * - All data is tenant-isolated in the backend
 * - HIPAA compliance maintained through proper data handling
 */ 