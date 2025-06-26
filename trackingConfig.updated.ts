/**
 * Site Tracking Configuration for The ONE Spa Website
 * Universal Multi-Tenant Site Tracking System Configuration
 * API Version: 2.0.0
 * Compliance: HIPAA, GDPR, CCPA compliant
 */

export interface ITrackingConfig {
  // API Configuration
  cfg_tracking_api_base_url: string;
  cfg_tracking_api_version: string;
  cfg_tracking_endpoint: string;
  cfg_tracking_status_endpoint: string;
  
  // Rate Limiting
  cfg_tracking_rate_limit_per_minute: number;
  cfg_tracking_burst_limit: number;
  cfg_tracking_retry_attempts: number;
  cfg_tracking_retry_delay_ms: number;
  
  // Event Configuration
  cfg_tracking_default_event_type: string;
  cfg_tracking_supported_event_types: string[];
  
  // Data Privacy & Compliance
  cfg_tracking_ip_anonymization: boolean;
  cfg_tracking_pii_detection: boolean;
  cfg_tracking_consent_required: boolean;
  cfg_tracking_data_retention_days: number;
  
  // Security
  cfg_tracking_security_score_threshold: number;
  cfg_tracking_auto_block_suspicious: boolean;
  
  // Performance
  cfg_tracking_timeout_ms: number;
  cfg_tracking_batch_enabled: boolean;
  cfg_tracking_batch_size: number;
  cfg_tracking_batch_interval_ms: number;
  
  // Debug & Monitoring
  cfg_tracking_debug_mode: boolean;
  cfg_tracking_console_logging: boolean;
  cfg_tracking_error_reporting: boolean;
}

export const trackingConfig: ITrackingConfig = {
  // API Configuration - Updated to use Vite proxy during development
  cfg_tracking_api_base_url: import.meta.env.DEV 
    ? '/tracking/rpc/track_site_event'  // Use Vite proxy in development
    : import.meta.env.VITE_ONEVAULT_API_ENDPOINT || 'https://app-wild-glade-78480567.dpl.myneon.app/rpc/track_site_event', // Direct URL in production
  cfg_tracking_api_version: '2.0.0',
  cfg_tracking_endpoint: '', // Empty since the full endpoint is in base_url
  cfg_tracking_status_endpoint: '/status', // Will be appended to base URL for status checks
  
  // Rate Limiting
  cfg_tracking_rate_limit_per_minute: 100,
  cfg_tracking_burst_limit: 150,
  cfg_tracking_retry_attempts: 3,
  cfg_tracking_retry_delay_ms: 1000,
  
  // Event Configuration
  cfg_tracking_default_event_type: 'page_view',
  cfg_tracking_supported_event_types: [
    'page_view',
    'item_interaction',
    'transaction_step',
    'contact_interaction',
    'content_engagement',
    'search',
    'download'
  ],
  
  // Data Privacy & Compliance
  cfg_tracking_ip_anonymization: true,
  cfg_tracking_pii_detection: true,
  cfg_tracking_consent_required: true,
  cfg_tracking_data_retention_days: 90,
  
  // Security
  cfg_tracking_security_score_threshold: 0.7,
  cfg_tracking_auto_block_suspicious: false, // Monitor but don't block
  
  // Performance
  cfg_tracking_timeout_ms: 10000,
  cfg_tracking_batch_enabled: false, // Disabled for real-time tracking
  cfg_tracking_batch_size: 10,
  cfg_tracking_batch_interval_ms: 5000,
  
  // Debug & Monitoring
  cfg_tracking_debug_mode: import.meta.env.DEV || false,
  cfg_tracking_console_logging: import.meta.env.DEV || false,
  cfg_tracking_error_reporting: true
};

// Event Type Configurations for The ONE Spa Business
export interface IEventTypeConfig {
  event_type: string;
  description: string;
  required_fields: string[];
  optional_fields: string[];
  business_context: string;
  examples: Record<string, any>[];
}

export const spaEventTypes: IEventTypeConfig[] = [
  {
    event_type: 'page_view',
    description: 'Basic page view tracking',
    required_fields: ['page_url'],
    optional_fields: ['referrer', 'utm_source', 'utm_medium', 'utm_campaign'],
    business_context: 'Website analytics and user journey tracking',
    examples: [
      {
        page_url: 'https://theonespaoregon.com/services',
        referrer: 'https://google.com',
        utm_source: 'google',
        utm_medium: 'organic'
      }
    ]
  },
  {
    event_type: 'item_interaction',
    description: 'Service viewing and interaction tracking',
    required_fields: ['action'],
    optional_fields: [
      'service_id', 'service_name', 'service_category', 'service_price',
      'service_duration', 'action_details', 'session_id', 'user_journey_step'
    ],
    business_context: 'Service popularity and customer interest tracking',
    examples: [
      {
        action: 'view_service',
        service_id: 'hot_stone_massage',
        service_name: 'Hot Stone Massage',
        service_category: 'Massage Therapy',
        service_price: 150,
        service_duration: 90
      },
      {
        action: 'book_service',
        service_id: 'facial_treatment',
        service_name: 'Rejuvenating Facial',
        service_category: 'Facial Treatments'
      }
    ]
  },
  {
    event_type: 'transaction_step',
    description: 'Booking and purchase funnel tracking',
    required_fields: ['funnel_step', 'step_number'],
    optional_fields: [
      'transaction_id', 'total_steps', 'cart_value', 'currency',
      'services_selected', 'appointment_date', 'payment_method'
    ],
    business_context: 'Conversion funnel optimization for spa bookings',
    examples: [
      {
        funnel_step: 'service_selection',
        step_number: 1,
        total_steps: 5,
        services_selected: ['hot_stone_massage', 'facial_treatment']
      },
      {
        funnel_step: 'payment_confirmation',
        step_number: 5,
        total_steps: 5,
        transaction_id: 'spa_booking_001',
        cart_value: 300,
        currency: 'USD'
      }
    ]
  },
  {
    event_type: 'contact_interaction',
    description: 'Contact form, phone, and communication tracking',
    required_fields: ['contact_method'],
    optional_fields: [
      'form_type', 'inquiry_type', 'success', 'error_details',
      'phone_number_clicked', 'email_clicked', 'chat_initiated'
    ],
    business_context: 'Lead generation and customer communication analysis',
    examples: [
      {
        contact_method: 'contact_form',
        form_type: 'general_inquiry',
        inquiry_type: 'service_question',
        success: true
      },
      {
        contact_method: 'phone_click',
        phone_number_clicked: '+1-503-XXX-XXXX'
      }
    ]
  },
  {
    event_type: 'content_engagement',
    description: 'Content reading and media interaction',
    required_fields: ['content_type'],
    optional_fields: [
      'content_title', 'content_category', 'reading_progress',
      'time_on_page', 'scroll_depth', 'video_play', 'image_view'
    ],
    business_context: 'Content effectiveness and user engagement measurement',
    examples: [
      {
        content_type: 'blog_article',
        content_title: 'Benefits of Hot Stone Massage',
        content_category: 'Wellness Education',
        reading_progress: 75,
        time_on_page: 180,
        scroll_depth: 85
      }
    ]
  },
  {
    event_type: 'search',
    description: 'Site search and service discovery tracking',
    required_fields: ['search_query'],
    optional_fields: [
      'search_results_count', 'search_category', 'filter_applied',
      'result_clicked', 'no_results'
    ],
    business_context: 'Understanding customer service discovery patterns',
    examples: [
      {
        search_query: 'couples massage',
        search_results_count: 3,
        search_category: 'services',
        result_clicked: true
      }
    ]
  },
  {
    event_type: 'download',
    description: 'Resource and document download tracking',
    required_fields: ['resource_name'],
    optional_fields: [
      'resource_type', 'file_size', 'download_source',
      'user_authenticated'
    ],
    business_context: 'Resource usage and marketing material effectiveness',
    examples: [
      {
        resource_name: 'service_menu.pdf',
        resource_type: 'menu',
        file_size: '2.3MB',
        download_source: 'services_page'
      }
    ]
  }
];

// Spa-specific tracking contexts
export const spaTrackingContexts = {
  business_type: 'wellness_spa',
  industry: 'health_wellness',
  service_categories: [
    'massage_therapy',
    'facial_treatments', 
    'body_treatments',
    'wellness_packages',
    'gift_certificates',
    'membership_programs'
  ],
  conversion_goals: [
    'service_booking',
    'gift_certificate_purchase',
    'membership_signup',
    'consultation_request',
    'newsletter_signup'
  ],
  customer_journey_stages: [
    'awareness',
    'consideration',
    'service_selection',
    'booking_process',
    'confirmation',
    'post_visit'
  ]
};

// Helper functions
export const getEventTypeConfig = (eventType: string): IEventTypeConfig | undefined => {
  return spaEventTypes.find(config => config.event_type === eventType);
};

export const validateEventData = (eventType: string, eventData: Record<string, any>): {
  isValid: boolean;
  missingFields: string[];
  warnings: string[];
} => {
  const config = getEventTypeConfig(eventType);
  
  if (!config) {
    return {
      isValid: false,
      missingFields: [],
      warnings: [`Unknown event type: ${eventType}`]
    };
  }
  
  const missingFields = config.required_fields.filter(field => 
    !(field in eventData) || eventData[field] === null || eventData[field] === undefined
  );
  
  const warnings: string[] = [];
  
  // Check for PII in event data
  const piiFields = ['email', 'phone', 'name', 'address'];
  const detectedPii = piiFields.filter(field => field in eventData);
  if (detectedPii.length > 0) {
    warnings.push(`Potential PII detected in fields: ${detectedPii.join(', ')}`);
  }
  
  return {
    isValid: missingFields.length === 0,
    missingFields,
    warnings
  };
};

export default trackingConfig; 