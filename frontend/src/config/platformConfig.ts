import { ICustomerConfig } from '../../../backend/app/interfaces/config/customerConfig.interface';

// Platform-wide configuration interface
export interface IPlatformConfig {
  api: {
    baseUrl: string;
    version: string;
    timeout: number;
    retryAttempts: number;
  };
  authentication: {
    tokenKey: string;
    refreshTokenKey: string;
    sessionTimeout: number;
    maxLoginAttempts: number;
  };
  ui: {
    theme: 'light' | 'dark' | 'auto';
    language: string;
    dateFormat: string;
    timeFormat: string;
    currency: string;
  };
  features: {
    enableAnalytics: boolean;
    enableNotifications: boolean;
    enableAutoSave: boolean;
    enableOfflineMode: boolean;
  };
  compliance: {
    enableAuditLogging: boolean;
    enableDataEncryption: boolean;
    enableSessionTracking: boolean;
  };
  development: {
    debugMode: boolean;
    mockData: boolean;
    logLevel: 'error' | 'warn' | 'info' | 'debug';
  };
}

// Customer-specific UI configuration interface
export interface ICustomerUIConfig {
  customerId: string;
  branding: {
    theme: {
      primaryColor: string;
      secondaryColor: string;
      accentColor: string;
      backgroundColor: string;
      textColor: string;
    };
    typography: {
      primaryFont: string;
      secondaryFont: string;
      baseFontSize: string;
    };
    logo: {
      primary: string;
      secondary?: string;
      favicon: string;
    };
    customCss?: string;
  };
  navigation: {
    menuItems: IMenuItem[];
    layout: 'sidebar' | 'topbar' | 'hybrid';
    showBreadcrumbs: boolean;
  };
  dashboard: {
    defaultWidgets: string[];
    allowCustomization: boolean;
    refreshInterval: number;
  };
  features: {
    enabled: string[];
    disabled: string[];
    beta: string[];
  };
}

export interface IMenuItem {
  id: string;
  label: string;
  icon?: string;
  route?: string;
  children?: IMenuItem[];
  permissions?: string[];
  badge?: {
    text: string;
    color: string;
  };
}

// Environment variable access
const getEnvVar = (key: string, defaultValue?: string): string => {
  if (typeof window !== 'undefined') {
    // Browser environment - access env vars through build-time injection
    return (window as any).__ENV__?.[key] || defaultValue || '';
  }
  // Node.js environment (for SSR)
  return defaultValue || '';
};

const isDevelopment = () => {
  return getEnvVar('NODE_ENV', 'development') === 'development';
};

// Platform configuration
export const platformConfig: IPlatformConfig = {
  api: {
    baseUrl: getEnvVar('REACT_APP_API_BASE_URL', 'http://localhost:8000/api/v1'),
    version: 'v1',
    timeout: 30000,
    retryAttempts: 3
  },
  authentication: {
    tokenKey: 'onevault_auth_token',
    refreshTokenKey: 'onevault_refresh_token',
    sessionTimeout: 1800000, // 30 minutes in milliseconds
    maxLoginAttempts: 3
  },
  ui: {
    theme: 'auto',
    language: 'en-US',
    dateFormat: 'MM/DD/YYYY',
    timeFormat: '12h',
    currency: 'USD'
  },
  features: {
    enableAnalytics: true,
    enableNotifications: true,
    enableAutoSave: true,
    enableOfflineMode: false
  },
  compliance: {
    enableAuditLogging: true,
    enableDataEncryption: true,
    enableSessionTracking: true
  },
  development: {
    debugMode: isDevelopment(),
    mockData: getEnvVar('REACT_APP_USE_MOCK_DATA') === 'true',
    logLevel: isDevelopment() ? 'debug' : 'error'
  }
};

// Customer UI configuration for One Spa
export const oneSpaUIConfig: ICustomerUIConfig = {
  customerId: 'ONE_SPA_LUXE_WELLNESS',
  branding: {
    theme: {
      primaryColor: '#2D5AA0',
      secondaryColor: '#E8B931',
      accentColor: '#F5F5F5',
      backgroundColor: '#FFFFFF',
      textColor: '#2C3E50'
    },
    typography: {
      primaryFont: 'Montserrat, sans-serif',
      secondaryFont: 'Playfair Display, serif',
      baseFontSize: '16px'
    },
    logo: {
      primary: '/assets/logos/luxe-wellness-primary.svg',
      secondary: '/assets/logos/luxe-wellness-secondary.svg',
      favicon: '/assets/logos/luxe-wellness-favicon.ico'
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
      .treatment-card {
        border-radius: 12px;
        box-shadow: 0 4px 6px rgba(45, 90, 160, 0.1);
        transition: transform 0.2s ease-in-out;
      }
      .treatment-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 8px 15px rgba(45, 90, 160, 0.15);
      }
    `
  },
  navigation: {
    layout: 'sidebar',
    showBreadcrumbs: true,
    menuItems: [
      {
        id: 'dashboard',
        label: 'Dashboard',
        icon: 'dashboard',
        route: '/dashboard'
      },
      {
        id: 'clients',
        label: 'Clients',
        icon: 'people',
        route: '/clients',
        permissions: ['read_clients']
      },
      {
        id: 'appointments',
        label: 'Appointments',
        icon: 'calendar',
        route: '/appointments',
        children: [
          {
            id: 'schedule',
            label: 'Schedule',
            route: '/appointments/schedule'
          },
          {
            id: 'booking',
            label: 'New Booking',
            route: '/appointments/new'
          }
        ]
      },
      {
        id: 'services',
        label: 'Services',
        icon: 'spa',
        route: '/services',
        children: [
          {
            id: 'treatments',
            label: 'Treatments',
            route: '/services/treatments'
          },
          {
            id: 'packages',
            label: 'Packages',
            route: '/services/packages'
          },
          {
            id: 'memberships',
            label: 'Memberships',
            route: '/services/memberships'
          }
        ]
      },
      {
        id: 'staff',
        label: 'Staff',
        icon: 'group',
        route: '/staff',
        permissions: ['manage_staff']
      },
      {
        id: 'inventory',
        label: 'Inventory',
        icon: 'inventory',
        route: '/inventory',
        permissions: ['manage_inventory']
      },
      {
        id: 'reports',
        label: 'Reports',
        icon: 'analytics',
        route: '/reports',
        permissions: ['view_reports'],
        children: [
          {
            id: 'financial',
            label: 'Financial',
            route: '/reports/financial'
          },
          {
            id: 'client-analytics',
            label: 'Client Analytics',
            route: '/reports/clients'
          },
          {
            id: 'staff-performance',
            label: 'Staff Performance',
            route: '/reports/staff'
          }
        ]
      },
      {
        id: 'settings',
        label: 'Settings',
        icon: 'settings',
        route: '/settings',
        permissions: ['admin_access']
      }
    ]
  },
  dashboard: {
    defaultWidgets: [
      'daily-appointments',
      'revenue-summary', 
      'client-satisfaction',
      'staff-utilization',
      'upcoming-events',
      'inventory-alerts'
    ],
    allowCustomization: true,
    refreshInterval: 300000 // 5 minutes
  },
  features: {
    enabled: [
      'client-management',
      'appointment-scheduling',
      'pos-system',
      'inventory-management',
      'staff-scheduling',
      'financial-reporting',
      'marketing-tools',
      'mobile-app-integration'
    ],
    disabled: [
      'advanced-analytics',
      'multi-location-management'
    ],
    beta: [
      'ai-recommendations',
      'voice-booking'
    ]
  }
};

// Helper functions following the established pattern
export const getPlatformConfig = (): IPlatformConfig => {
  return platformConfig;
};

export const getCustomerUIConfig = (customerId: string): ICustomerUIConfig | null => {
  // In a real implementation, this would fetch from the config registry
  if (customerId === 'ONE_SPA_LUXE_WELLNESS') {
    return oneSpaUIConfig;
  }
  return null;
};

export const getApiUrl = (endpoint: string): string => {
  const baseUrl = platformConfig.api.baseUrl.replace(/\/+$/, '');
  const cleanEndpoint = endpoint.replace(/^\/+/, '');
  return `${baseUrl}/${cleanEndpoint}`;
};

export const getThemeVariables = (customerId?: string): Record<string, string> => {
  if (customerId) {
    const customerConfig = getCustomerUIConfig(customerId);
    if (customerConfig) {
      const theme = customerConfig.branding.theme;
      return {
        '--primary-color': theme.primaryColor,
        '--secondary-color': theme.secondaryColor,
        '--accent-color': theme.accentColor,
        '--background-color': theme.backgroundColor,
        '--text-color': theme.textColor,
        '--primary-font': customerConfig.branding.typography.primaryFont,
        '--secondary-font': customerConfig.branding.typography.secondaryFont,
        '--base-font-size': customerConfig.branding.typography.baseFontSize
      };
    }
  }
  
  // Default theme variables
  return {
    '--primary-color': '#1976d2',
    '--secondary-color': '#dc004e',
    '--accent-color': '#f5f5f5',
    '--background-color': '#ffffff',
    '--text-color': '#333333',
    '--primary-font': 'Roboto, sans-serif',
    '--secondary-font': 'Roboto, sans-serif',
    '--base-font-size': '16px'
  };
};

export const getCustomCSS = (customerId?: string): string => {
  if (customerId) {
    const customerConfig = getCustomerUIConfig(customerId);
    return customerConfig?.branding.customCss || '';
  }
  return '';
};

export const getEnabledFeatures = (customerId?: string): string[] => {
  if (customerId) {
    const customerConfig = getCustomerUIConfig(customerId);
    return customerConfig?.features.enabled || [];
  }
  return [];
};

export const isFeatureEnabled = (feature: string, customerId?: string): boolean => {
  const enabledFeatures = getEnabledFeatures(customerId);
  return enabledFeatures.includes(feature);
};

export const getNavigationMenu = (customerId?: string): IMenuItem[] => {
  if (customerId) {
    const customerConfig = getCustomerUIConfig(customerId);
    return customerConfig?.navigation.menuItems || [];
  }
  return [];
};

export const getDashboardWidgets = (customerId?: string): string[] => {
  if (customerId) {
    const customerConfig = getCustomerUIConfig(customerId);
    return customerConfig?.dashboard.defaultWidgets || [];
  }
  return [];
};

// Format helper functions
export const formatCurrency = (amount: number): string => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: platformConfig.ui.currency
  }).format(amount);
};

export const formatDate = (date: Date): string => {
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(date);
};

export const formatTime = (date: Date): string => {
  const use24Hour = platformConfig.ui.timeFormat === '24h';
  return new Intl.DateTimeFormat('en-US', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: !use24Hour
  }).format(date);
};

// Export default config
export default platformConfig; 