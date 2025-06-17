import { ICustomerConfig } from '../../../backend/app/interfaces/config/customerConfig.interface';

export const oneSpaConfig: ICustomerConfig = {
  // Core identification
  customerId: 'ONE_SPA_LUXE_WELLNESS',
  customerName: 'Luxe Wellness Spa Collection',
  industryType: 'spa_wellness',

  // Branding configuration
  branding: {
    companyName: 'Luxe Wellness Spa Collection',
    displayName: 'The ONE Spa',
    logo: {
      primary: '/assets/logos/luxe-wellness-primary.svg',
      secondary: '/assets/logos/luxe-wellness-secondary.svg',
      favicon: '/assets/logos/luxe-wellness-favicon.ico'
    },
    colors: {
      primary: '#2D5AA0',    // Professional Blue
      secondary: '#E8B931',  // Luxe Gold
      accent: '#F5F5F5',     // Soft White
      background: '#FFFFFF',
      text: '#2C3E50'
    },
    fonts: {
      primary: 'Montserrat, sans-serif',
      secondary: 'Playfair Display, serif'
    },
    customCss: `
      .spa-signature { 
        font-family: 'Playfair Display', serif; 
        color: #2D5AA0; 
      }
      .luxury-accent { 
        border-left: 3px solid #E8B931; 
        padding-left: 12px; 
      }
    `
  },

  // Location configuration
  locations: [
    {
      id: 'BEVERLY_HILLS',
      name: 'Beverly Hills Flagship',
      address: {
        street: '9876 Rodeo Drive',
        city: 'Beverly Hills',
        state: 'CA',
        zipCode: '90210',
        country: 'USA'
      },
      coordinates: {
        latitude: 34.0696,
        longitude: -118.4012
      },
      timezone: 'America/Los_Angeles',
      isActive: true
    },
    {
      id: 'MANHATTAN_BEACH',
      name: 'Manhattan Beach Oceanside',
      address: {
        street: '1234 The Strand',
        city: 'Manhattan Beach',
        state: 'CA',
        zipCode: '90266',
        country: 'USA'
      },
      coordinates: {
        latitude: 33.8847,
        longitude: -118.4109
      },
      timezone: 'America/Los_Angeles',
      isActive: true
    },
    {
      id: 'NEWPORT_BEACH',
      name: 'Newport Beach Harbor',
      address: {
        street: '5678 Balboa Island Blvd',
        city: 'Newport Beach',
        state: 'CA',
        zipCode: '92661',
        country: 'USA'
      },
      coordinates: {
        latitude: 33.6189,
        longitude: -117.9298
      },
      timezone: 'America/Los_Angeles',
      isActive: true
    }
  ],

  // Compliance configuration
  compliance: {
    requiredFrameworks: ['HIPAA', 'CCPA', 'PCI_DSS'],
    hipaa: {
      enabled: true,
      baaRequired: true,
      auditRetentionYears: 6,
      encryptionRequired: true
    },
    gdpr: {
      enabled: false,
      dataRetentionDays: 0,
      rightToBeForgitten: false,
      consentRequired: false
    },
    sox: {
      enabled: false,
      financialReportingRequired: false,
      controlTestingRequired: false
    },
    pciDss: {
      enabled: true,
      level: '4',
      merchantCategory: 'spa_wellness_services'
    }
  },

  // Security configuration
  security: {
    authentication: {
      mfaRequired: true,
      passwordPolicy: {
        minLength: 12,
        requireUppercase: true,
        requireLowercase: true,
        requireNumbers: true,
        requireSpecialChars: true,
        maxAge: 90
      },
      sessionTimeout: 30,
      maxFailedAttempts: 3,
      lockoutDuration: 15
    },
    encryption: {
      algorithm: 'AES-256-GCM',
      keyRotationDays: 90,
      dataAtRest: true,
      dataInTransit: true
    },
    audit: {
      logAllAccess: true,
      retentionDays: 2555, // 7 years for HIPAA
      realTimeAlerts: true
    }
  },

  // Pricing configuration
  pricing: {
    basePlan: {
      name: 'Luxe Wellness Premium',
      monthlyPrice: 4999,
      annualPrice: 53988, // ~10% discount
      features: [
        'Multi-location management',
        'HIPAA-compliant client records',
        'Advanced scheduling system',
        'Financial reporting suite',
        'Staff management portal',
        'Client communication tools',
        'Inventory management',
        'Marketing automation'
      ]
    },
    addOns: [
      {
        id: 'ADDITIONAL_LOCATION',
        name: 'Additional Location',
        monthlyPrice: 299,
        annualPrice: 3228, // ~10% discount
        description: 'Full platform access for additional spa location'
      },
      {
        id: 'ADVANCED_ANALYTICS',
        name: 'Advanced Analytics Suite',
        monthlyPrice: 499,
        annualPrice: 5388,
        description: 'Business intelligence and predictive analytics'
      },
      {
        id: 'WHITE_LABEL_MOBILE',
        name: 'White-Label Mobile App',
        monthlyPrice: 799,
        annualPrice: 8628,
        description: 'Custom branded mobile app for clients'
      }
    ],
    customization: {
      setupFee: 2500,
      hourlyRate: 250,
      minimumHours: 8
    },
    billing: {
      currency: 'USD',
      paymentTerms: 'Net 30',
      invoiceFrequency: 'monthly'
    }
  },

  // Tenant configuration
  tenants: [
    {
      id: 'CORPORATE',
      name: 'Corporate Management',
      domain: 'corporate.luxewellness.com',
      subdomain: 'corporate',
      isActive: true,
      users: {
        maxUsers: 25,
        adminUsers: ['sarah.chen@luxewellness.com', 'michael.torres@luxewellness.com'],
        roles: ['owner', 'corporate_admin', 'financial_manager', 'operations_manager']
      },
      features: {
        enabled: ['multi_location_dashboard', 'consolidated_reporting', 'staff_management', 'financial_analytics'],
        disabled: [],
        beta: ['predictive_scheduling']
      }
    },
    {
      id: 'BEVERLY_HILLS',
      name: 'Beverly Hills Location',
      domain: 'beverlyhills.luxewellness.com',
      subdomain: 'beverlyhills',
      isActive: true,
      users: {
        maxUsers: 15,
        adminUsers: ['manager.bh@luxewellness.com'],
        roles: ['location_manager', 'therapist', 'front_desk', 'guest_services']
      },
      features: {
        enabled: ['client_management', 'scheduling', 'pos_system', 'staff_scheduling'],
        disabled: ['financial_reporting'],
        beta: []
      }
    },
    // Additional tenants for other locations...
  ],

  // Analytics configuration
  analytics: {
    googleAnalytics: {
      enabled: true,
      trackingId: 'G-LUXE-WELLNESS-001',
      customDimensions: {
        'location': 'custom_dimension_1',
        'service_category': 'custom_dimension_2',
        'client_type': 'custom_dimension_3'
      }
    },
    customerAnalytics: {
      enabled: true,
      trackUserBehavior: true,
      trackBusinessMetrics: true,
      retentionDays: 1095 // 3 years
    },
    reporting: {
      automated: true,
      frequency: 'weekly',
      recipients: ['sarah.chen@luxewellness.com', 'michael.torres@luxewellness.com']
    }
  },

  // Integration configuration
  integrations: {
    api: {
      enabled: true,
      rateLimit: 1000,
      apiKeys: {
        production: 'lw_prod_api_key_encrypted_value',
        staging: 'lw_staging_api_key_encrypted_value'
      }
    },
    webhooks: {
      enabled: true,
      endpoints: [
        {
          url: 'https://corporate.luxewellness.com/api/webhooks/bookings',
          events: ['booking.created', 'booking.cancelled', 'booking.completed'],
          secret: 'webhook_secret_encrypted'
        },
        {
          url: 'https://corporate.luxewellness.com/api/webhooks/payments',
          events: ['payment.completed', 'payment.failed', 'payment.refunded'],
          secret: 'webhook_secret_encrypted'
        }
      ]
    },
    thirdParty: {
      massageBook: {
        enabled: true,
        apiKey: 'mb_api_key_encrypted',
        configuration: {
          syncDirection: 'bidirectional',
          syncFrequency: 'real_time'
        }
      },
      stripe: {
        enabled: true,
        apiKey: 'stripe_api_key_encrypted',
        configuration: {
          webhookEndpoint: '/api/webhooks/stripe',
          currency: 'USD'
        }
      },
      mailchimp: {
        enabled: true,
        apiKey: 'mc_api_key_encrypted',
        configuration: {
          listId: 'luxe_wellness_main_list',
          automationEnabled: true
        }
      }
    }
  },

  // Metadata
  createdDate: '2024-01-15T08:00:00Z',
  lastUpdated: '2024-12-20T10:30:00Z',
  configVersion: '2.1.0',
  environment: 'production',

  // Spa-specific custom fields
  customFields: {
    spaSpecific: {
      serviceCategories: ['massage', 'facial', 'body_treatment', 'wellness'],
      roomTypes: ['single', 'couples', 'group', 'infrared_sauna'],
      therapistSpecialties: ['swedish', 'deep_tissue', 'hot_stone', 'prenatal', 'medical'],
      membershipPrograms: ['gold_90min', 'gold_60min', 'silver_90min', 'silver_60min'],
      packageOfferings: ['signature_experiences', 'couples_packages', 'professional_packages'],
      seasonalPromotions: {
        enabled: true,
        currentSeason: 'winter_wellness',
        promotionCodes: ['WINTER25', 'NEWCLIENT30', 'REFERRAL15']
      }
    },
    businessHours: {
      monday: { open: '09:00', close: '19:00', isOpen: true },
      tuesday: { open: '09:00', close: '19:00', isOpen: true },
      wednesday: { open: '09:00', close: '19:00', isOpen: true },
      thursday: { open: '09:00', close: '19:00', isOpen: true },
      friday: { open: '09:00', close: '20:00', isOpen: true },
      saturday: { open: '08:00', close: '20:00', isOpen: true },
      sunday: { open: '08:00', close: '18:00', isOpen: true }
    }
  }
};

// Helper functions following the established pattern
export const getLocationById = (locationId: string) => {
  return oneSpaConfig.locations.find(location => location.id === locationId);
};

export const getActiveLocations = () => {
  return oneSpaConfig.locations.filter(location => location.isActive);
};

export const getTenantByDomain = (domain: string) => {
  return oneSpaConfig.tenants.find(tenant => 
    tenant.domain === domain || `${tenant.subdomain}.luxewellness.com` === domain
  );
};

export const getEnabledIntegrations = () => {
  return Object.entries(oneSpaConfig.integrations.thirdParty)
    .filter(([_, integration]) => integration.enabled)
    .reduce((acc, [name, integration]) => {
      acc[name] = integration;
      return acc;
    }, {} as Record<string, any>);
};

export const calculateMonthlyTotal = () => {
  const base = oneSpaConfig.pricing.basePlan.monthlyPrice;
  const addOns = oneSpaConfig.pricing.addOns
    .filter(addOn => addOn.id === 'ADDITIONAL_LOCATION') // 2 additional locations
    .reduce((total, addOn) => total + (addOn.monthlyPrice * 2), 0);
  
  return base + addOns;
};

export const getCalculatedAnnualTotal = () => {
  const monthly = calculateMonthlyTotal();
  return monthly * 12 * 0.9; // 10% annual discount
};

export const getComplianceFrameworks = () => {
  return Object.entries(oneSpaConfig.compliance)
    .filter(([key, value]) => 
      typeof value === 'object' && 
      value !== null && 
      'enabled' in value && 
      value.enabled
    )
    .map(([key]) => key.toUpperCase());
};

export const getBrandingCss = () => {
  const { colors, fonts } = oneSpaConfig.branding;
  return `
    :root {
      --primary-color: ${colors.primary};
      --secondary-color: ${colors.secondary};
      --accent-color: ${colors.accent};
      --background-color: ${colors.background};
      --text-color: ${colors.text};
      --primary-font: ${fonts.primary};
      --secondary-font: ${fonts.secondary || fonts.primary};
    }
    ${oneSpaConfig.branding.customCss || ''}
  `;
};

export const getBusinessHoursForDay = (day: string) => {
  const businessHours = oneSpaConfig.customFields?.businessHours;
  return businessHours?.[day.toLowerCase()] || null;
};

export const isLocationOpenNow = (locationId: string) => {
  const now = new Date();
  const day = now.toLocaleDateString('en-US', { weekday: 'long' }).toLowerCase();
  const currentTime = now.toTimeString().slice(0, 5); // HH:MM format
  
  const hours = getBusinessHoursForDay(day);
  if (!hours || !hours.isOpen) return false;
  
  return currentTime >= hours.open && currentTime <= hours.close;
};

// Export config for use in other modules
export default oneSpaConfig; 