import { ICustomerConfig } from '../../../backend/app/interfaces/config/customerConfig.interface';

export const oneBarnConfig: ICustomerConfig = {
  // Core identification
  customerId: 'one_barn',
  customerName: 'One Barn',
  industryType: 'equestrian',

  // Branding configuration
  branding: {
    companyName: 'One Barn',
    displayName: 'One Barn - Equine Pro Management',
    
    logo: {
      primary: '/assets/branding/one_barn/logo-primary.svg',
      secondary: '/assets/branding/one_barn/logo-secondary.svg',
      favicon: '/assets/branding/one_barn/favicon.ico'
    },
    
    colors: {
      primary: '#6B3A2C', // Stable Mahogany
      secondary: '#F4E8D8', // Arena Sand
      accent: '#2C5530', // Hunter Green
      background: '#F4E8D8', // Arena Sand
      text: '#1A1A1A' // Midnight Black
    },
    
    fonts: {
      primary: 'Playfair Display', // Elegant serif for equestrian
      secondary: 'Source Sans Pro'
    },
    
    customCss: `
      :root {
        --stable-mahogany: #6B3A2C;
        --arena-sand: #F4E8D8;
        --midnight-black: #1A1A1A;
        --hunter-green: #2C5530;
        --sterling-silver: #B8B5B0;
        --chestnut-glow: #C67B5C;
        --champion-gold: #D4A574;
        --ribbon-blue: #4A6FA5;
        --victory-rose: #B85450;
        --pasture-sage: #8B9574;
      }
      
      .equestrian-header {
        background: linear-gradient(135deg, var(--stable-mahogany), var(--champion-gold));
        color: var(--arena-sand);
      }
      
      .horse-card {
        border: 2px solid var(--hunter-green);
        border-radius: 8px;
        background: var(--arena-sand);
        color: var(--midnight-black);
      }
      
      .btn-primary {
        background-color: var(--stable-mahogany);
        color: var(--arena-sand);
        border: 2px solid transparent;
        transition: all 0.3s ease;
      }
      
      .btn-primary:hover {
        background-color: #5A3124;
        border-color: var(--champion-gold);
      }
    `
  },

  // Location configuration
  locations: [
    {
      id: 'MAIN_FACILITY',
      name: 'One Barn Main Facility',
      address: {
        street: '1500 Equestrian Way',
        city: 'Wellington',
        state: 'FL',
        zipCode: '33414',
        country: 'USA'
      },
      coordinates: {
        latitude: 26.6617,
        longitude: -80.2108
      },
      timezone: 'America/New_York',
      isActive: true
    },
    {
      id: 'TRAINING_ANNEX',
      name: 'One Barn Training Annex',
      address: {
        street: '1600 Polo Club Road',
        city: 'Wellington',
        state: 'FL',
        zipCode: '33414',
        country: 'USA'
      },
      coordinates: {
        latitude: 26.6650,
        longitude: -80.2150
      },
      timezone: 'America/New_York',
      isActive: true
    }
  ],

  // Compliance configuration
  compliance: {
    requiredFrameworks: ['GENERAL_BUSINESS', 'ANIMAL_WELFARE', 'INSURANCE'],
    hipaa: {
      enabled: false,
      baaRequired: false,
      auditRetentionYears: 0,
      encryptionRequired: false
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
      merchantCategory: 'equestrian_services'
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
      sessionTimeout: 60, // Longer for barn operations
      maxFailedAttempts: 5,
      lockoutDuration: 30
    },
    encryption: {
      algorithm: 'AES-256',
      keyRotationDays: 90,
      dataAtRest: true,
      dataInTransit: true
    },
    audit: {
      logAllAccess: true,
      retentionDays: 2555, // 7 years
      realTimeAlerts: true
    }
  },

  // Pricing configuration
  pricing: {
    basePlan: {
      name: 'One Barn Pro Package',
      monthlyPrice: 6999.00,
      annualPrice: 75589.00, // 10% discount for annual
      features: ['horse_management', 'boarding_management', 'training_schedules', 'financial_reporting']
    },
    addOns: [
      {
        id: 'additional_facility',
        name: 'Additional Facility',
        monthlyPrice: 399.00,
        annualPrice: 4309.00,
        description: 'Each additional barn/facility location'
      },
      {
        id: 'competition_management',
        name: 'Competition Management',
        monthlyPrice: 299.00,
        annualPrice: 3229.00,
        description: 'Advanced competition and show management'
      },
      {
        id: 'breeding_records',
        name: 'Breeding Records',
        monthlyPrice: 199.00,
        annualPrice: 2149.00,
        description: 'Comprehensive breeding and lineage tracking'
      }
    ],
    customization: {
      setupFee: 2500.00,
      hourlyRate: 250.00,
      minimumHours: 10
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
      id: 'MANAGEMENT',
      name: 'Facility Management',
      domain: 'management.onebarn.com',
      subdomain: 'management',
      isActive: true,
      users: {
        maxUsers: 15,
        adminUsers: ['admin@onebarn.com', 'barn.manager@onebarn.com'],
        roles: ['facility_owner', 'barn_manager', 'head_trainer', 'office_manager']
      },
      features: {
        enabled: ['horse_management', 'boarding_management', 'financial_reporting', 'staff_scheduling'],
        disabled: [],
        beta: ['ai_health_monitoring']
      }
    },
    {
      id: 'TRAINING',
      name: 'Training Operations',
      domain: 'training.onebarn.com',
      subdomain: 'training',
      isActive: true,
      users: {
        maxUsers: 25,
        adminUsers: ['head.trainer@onebarn.com'],
        roles: ['trainer', 'assistant_trainer', 'groom', 'exercise_rider']
      },
      features: {
        enabled: ['training_schedules', 'horse_progress', 'lesson_booking', 'client_communication'],
        disabled: ['financial_reporting'],
        beta: []
      }
    },
    {
      id: 'CLIENTS',
      name: 'Horse Owners Portal',
      domain: 'owners.onebarn.com',
      subdomain: 'owners',
      isActive: true,
      users: {
        maxUsers: 200,
        adminUsers: [],
        roles: ['horse_owner', 'authorized_agent', 'veterinarian', 'farrier']
      },
      features: {
        enabled: ['horse_status', 'billing_portal', 'appointment_booking', 'photo_sharing'],
        disabled: ['staff_management', 'facility_operations'],
        beta: ['mobile_notifications']
      }
    }
  ],

  // Analytics configuration
  analytics: {
    googleAnalytics: {
      enabled: true,
      trackingId: 'G-ONE-BARN-001',
      customDimensions: {
        'facility_location': 'custom_dimension_1',
        'service_type': 'custom_dimension_2',
        'horse_discipline': 'custom_dimension_3'
      }
    },
    customerAnalytics: {
      enabled: true,
      trackUserBehavior: true,
      trackBusinessMetrics: true,
      retentionDays: 2555 // 7 years for business records
    },
    reporting: {
      automated: true,
      frequency: 'weekly',
      recipients: ['admin@onebarn.com', 'barn.manager@onebarn.com']
    }
  },

  // Integration configuration
  integrations: {
    api: {
      enabled: true,
      rateLimit: 5000,
      apiKeys: {
        production: 'prod_key_placeholder',
        staging: 'staging_key_placeholder'
      }
    },
    webhooks: {
      enabled: true,
      endpoints: [
        {
          url: 'https://onebarn.com/webhooks/billing',
          events: ['payment.completed', 'subscription.updated'],
          secret: 'webhook_secret_placeholder'
        }
      ]
    },
    thirdParty: {
      quickbooks: {
        enabled: true,
        configuration: {
          companyId: 'equestrian_company_id'
        }
      },
      mailchimp: {
        enabled: true,
        configuration: {
          listId: 'equestrian_mailing_list'
        }
      }
    }
  },

  // Metadata
  createdDate: '2024-01-15T10:00:00Z',
  lastUpdated: '2024-01-15T10:00:00Z',
  configVersion: '1.0.0',
  environment: 'production' as const,

  // Custom fields for equestrian-specific requirements
  customFields: {
    facilities: {
      mainFacility: {
        stalls: 120,
        arenas: 6,
        paddocks: 25,
        trails: 15,
        washStalls: 8,
        tackRooms: 12
      },
      trainingAnnex: {
        stalls: 40,
        arenas: 3,
        paddocks: 10,
        trails: 8,
        washStalls: 4,
        tackRooms: 6
      }
    },
    animalWelfare: {
      enabled: true,
      certifications: ['USEF', 'FEI'],
      inspectionFrequency: 'quarterly',
      veterinaryRecordsRequired: true
    }
  }
};

// Helper functions following the established pattern
export const getLocationById = (locationId: string) => {
  return oneBarnConfig.locations.find(location => location.id === locationId);
};

export const calculateMonthlyTotal = () => {
  const basePrice = oneBarnConfig.pricing.basePlan.monthlyPrice;
  const additionalLocations = oneBarnConfig.locations.length - 1; // First location included
  const locationAddon = oneBarnConfig.pricing.addOns.find(addon => addon.id === 'additional_facility');
  const locationFee = locationAddon?.monthlyPrice || 0;
  
  return basePrice + (additionalLocations * locationFee);
};

export const getBrandingCss = () => {
  return oneBarnConfig.branding.customCss;
};

export const isLocationActive = (locationId: string) => {
  const location = getLocationById(locationId);
  return location?.isActive || false;
};

export const getFacilityCapacity = (locationId: string) => {
  // Access facilities from customFields since they're not in the standard ILocation interface
  if (locationId === 'MAIN_FACILITY') {
    return oneBarnConfig.customFields?.facilities?.mainFacility || null;
  } else if (locationId === 'TRAINING_ANNEX') {
    return oneBarnConfig.customFields?.facilities?.trainingAnnex || null;
  }
  return null;
};

export const getEnabledFeatures = (tenantId: string) => {
  const tenant = oneBarnConfig.tenants.find(t => t.id === tenantId);
  return tenant?.features.enabled || [];
};

export const getComplianceFrameworks = () => {
  return oneBarnConfig.compliance.requiredFrameworks;
};

export const getTotalMonthlyRevenue = () => {
  // Elite Equestrian: $6,999 base + $399 for 1 additional location = $7,398/month
  return calculateMonthlyTotal();
};

export default oneBarnConfig; 