# TypeScript Configuration Pattern - OneVault Platform

## Overview

We've implemented TypeScript configuration files as the **single source of truth** for all platform and customer configurations, following the established pattern used across the OneVault platform. This approach provides type safety, intellisense, and maintainability while eliminating configuration drift between systems.

## Pattern Structure

### 1. **Interface-First Design**
All configurations start with comprehensive TypeScript interfaces:

```typescript
export interface ICustomerConfig {
  customerId: string;
  customerName: string;
  industryType: 'spa_wellness' | 'financial_services' | 'equestrian';
  branding: IBrandingConfig;
  locations: ILocation[];
  compliance: IComplianceConfig;
  // ... other sections
}
```

### 2. **Structured Configuration Objects**
Configurations are organized into logical sections:

```typescript
export const oneSpaConfig: ICustomerConfig = {
  // Core identification
  customerId: 'ONE_SPA_LUXE_WELLNESS',
  customerName: 'Luxe Wellness Spa Collection',
  
  // Branding configuration
  branding: {
    companyName: 'Luxe Wellness Spa Collection',
    colors: {
      primary: '#2D5AA0',
      secondary: '#E8B931'
    }
  },
  
  // ... other sections
};
```

### 3. **Helper Functions**
Utility functions work with the configuration data:

```typescript
export const getLocationById = (locationId: string) => {
  return oneSpaConfig.locations.find(location => location.id === locationId);
};

export const calculateMonthlyTotal = () => {
  const base = oneSpaConfig.pricing.basePlan.monthlyPrice;
  // ... calculation logic
  return total;
};
```

## Implementation Architecture

### Backend Integration

#### Configuration Registry (`configRegistry.ts`)
Central registry managing all customer configurations:

```typescript
class ConfigRegistry implements IConfigRegistry {
  private readonly configs: Map<string, ICustomerConfig> = new Map();
  
  public getCustomerConfig(customerId: string): ICustomerConfig | null;
  public validateConfig(config: ICustomerConfig): IConfigValidationResult;
  // ... other methods
}
```

#### Python Bridge (`config.py`)
Python backend accesses TypeScript configs through a Node.js bridge:

```python
class TypeScriptConfigBridge:
    def get_customer_config(self, customer_id: str) -> Optional[Dict[str, Any]]:
        """Get customer configuration from TypeScript config."""
        return self._execute_typescript_function(f"getCustomerConfig('{customer_id}')")
```

#### Node.js Bridge (`configBridge.js`)
Executable bridge that provides configuration data to Python:

```javascript
const configFunctions = {
  getCustomerConfig: (customerId) => {
    return mockCustomerConfigs[customerId] || null;
  },
  // ... other functions
};
```

### Frontend Integration

#### Platform Configuration (`platformConfig.ts`)
Frontend-specific configuration with customer awareness:

```typescript
export const platformConfig: IPlatformConfig = {
  api: {
    baseUrl: getEnvVar('REACT_APP_API_BASE_URL', 'http://localhost:8000/api/v1'),
    timeout: 30000
  },
  // ... other sections
};

export const getThemeVariables = (customerId?: string): Record<string, string> => {
  if (customerId) {
    const customerConfig = getCustomerUIConfig(customerId);
    // Return customer-specific theme variables
  }
  // Return default theme variables
};
```

## File Structure

```
OneVault/
├── backend/
│   ├── app/
│   │   ├── interfaces/config/
│   │   │   └── customerConfig.interface.ts    # Core interfaces
│   │   ├── core/
│   │   │   ├── config.py                      # Python config manager
│   │   │   └── configRegistry.ts              # TS config registry
│   │   └── utils/
│   │       └── configBridge.js                # Node.js bridge
│   └── requirements/
├── customers/
│   └── configurations/
│       └── one_spa/
│           └── oneSpaConfig.ts                # Customer-specific config
├── frontend/
│   └── src/
│       └── config/
│           └── platformConfig.ts              # Frontend platform config
└── TYPESCRIPT_CONFIG_GUIDE.md                # This guide
```

## Configuration Sections

### Core Customer Configuration

#### 1. **Identification**
```typescript
customerId: 'ONE_SPA_LUXE_WELLNESS'
customerName: 'Luxe Wellness Spa Collection'
industryType: 'spa_wellness'
```

#### 2. **Branding**
```typescript
branding: {
  companyName: 'Luxe Wellness Spa Collection',
  displayName: 'The ONE Spa',
  colors: {
    primary: '#2D5AA0',    // Professional Blue
    secondary: '#E8B931',  // Luxe Gold
  },
  fonts: {
    primary: 'Montserrat, sans-serif',
    secondary: 'Playfair Display, serif'
  }
}
```

#### 3. **Locations**
```typescript
locations: [
  {
    id: 'BEVERLY_HILLS',
    name: 'Beverly Hills Flagship',
    address: {
      street: '9876 Rodeo Drive',
      city: 'Beverly Hills',
      state: 'CA'
    },
    isActive: true
  }
]
```

#### 4. **Compliance**
```typescript
compliance: {
  requiredFrameworks: ['HIPAA', 'CCPA', 'PCI_DSS'],
  hipaa: {
    enabled: true,
    baaRequired: true,
    auditRetentionYears: 6
  }
}
```

#### 5. **Security**
```typescript
security: {
  authentication: {
    mfaRequired: true,
    passwordPolicy: {
      minLength: 12,
      requireUppercase: true
    },
    sessionTimeout: 30
  }
}
```

#### 6. **Pricing**
```typescript
pricing: {
  basePlan: {
    name: 'Luxe Wellness Premium',
    monthlyPrice: 4999,
    annualPrice: 53988
  },
  addOns: [
    {
      id: 'ADDITIONAL_LOCATION',
      monthlyPrice: 299
    }
  ]
}
```

## Benefits of This Pattern

### 1. **Type Safety**
- Compile-time error checking
- Intellisense and autocomplete
- Refactoring support

### 2. **Single Source of Truth**
- No configuration drift
- Centralized validation
- Consistent access patterns

### 3. **Developer Experience**
- Rich IDE support
- Self-documenting code
- Easy debugging

### 4. **Maintainability**
- Clear structure and organization
- Reusable helper functions
- Version control friendly

### 5. **Cross-Platform Compatibility**
- TypeScript configs work in browser and Node.js
- Python bridge for backend integration
- Consistent data structures

## Usage Examples

### Backend (Python)
```python
from backend.app.core.config import get_customer_config

# Get customer configuration
config = get_customer_config('ONE_SPA_LUXE_WELLNESS')
if config:
    company_name = config['branding']['companyName']
    is_hipaa = config['compliance']['hipaa']['enabled']
```

### Frontend (TypeScript)
```typescript
import { getCustomerUIConfig, getThemeVariables } from '@/config/platformConfig';

// Get customer-specific UI configuration
const uiConfig = getCustomerUIConfig('ONE_SPA_LUXE_WELLNESS');
const themeVars = getThemeVariables('ONE_SPA_LUXE_WELLNESS');

// Apply theme variables to CSS
Object.entries(themeVars).forEach(([property, value]) => {
  document.documentElement.style.setProperty(property, value);
});
```

### Configuration Registry
```typescript
import { getCustomerConfig, isValidCustomer } from '@/core/configRegistry';

// Validate customer
if (isValidCustomer('ONE_SPA_LUXE_WELLNESS')) {
  const config = getCustomerConfig('ONE_SPA_LUXE_WELLNESS');
  const frameworks = getCustomerComplianceFrameworks('ONE_SPA_LUXE_WELLNESS');
}
```

## Adding New Customers

### 1. Create Configuration File
```typescript
// customers/configurations/new_customer/newCustomerConfig.ts
import { ICustomerConfig } from '../../../backend/app/interfaces/config/customerConfig.interface';

export const newCustomerConfig: ICustomerConfig = {
  customerId: 'NEW_CUSTOMER_ID',
  customerName: 'New Customer Name',
  // ... complete configuration
};
```

### 2. Register in Registry
```typescript
// backend/app/core/configRegistry.ts
import { newCustomerConfig } from '../../../customers/configurations/new_customer/newCustomerConfig';

class ConfigRegistry {
  private loadConfigurations(): void {
    this.registerConfig(oneSpaConfig);
    this.registerConfig(newCustomerConfig); // Add new customer
  }
}
```

### 3. Update Bridge (if needed)
```javascript
// backend/app/utils/configBridge.js
const mockCustomerConfigs = {
  'ONE_SPA_LUXE_WELLNESS': { /* existing config */ },
  'NEW_CUSTOMER_ID': { /* new customer config */ }
};
```

## Validation and Error Handling

### Automatic Validation
```typescript
export const validateCustomerConfig = (config: ICustomerConfig): IConfigValidationResult => {
  const errors: string[] = [];
  const warnings: string[] = [];
  
  // Required field validation
  if (!config.customerId) {
    errors.push('customerId is required');
  }
  
  // Compliance validation
  if (config.compliance?.hipaa?.enabled && !config.security?.encryption?.dataAtRest) {
    errors.push('Data at rest encryption is required for HIPAA compliance');
  }
  
  return { isValid: errors.length === 0, errors, warnings };
};
```

### Runtime Validation
```python
# Python backend validation
validation_result = customer_config_manager.validate_customer_config(customer_id)
if not validation_result['is_valid']:
    raise ValueError(f"Invalid configuration: {validation_result['errors']}")
```

## Environment Configuration

### Development vs Production
```typescript
const getCustomerEnvironment = (customerId: string): string => {
  const config = getCustomerConfig(customerId);
  return config?.environment || 'development';
};
```

### Feature Flags
```typescript
const isFeatureEnabled = (feature: string, customerId?: string): boolean => {
  const enabledFeatures = getEnabledFeatures(customerId);
  return enabledFeatures.includes(feature);
};
```

## Best Practices

### 1. **Always Use Interfaces**
Define interfaces before implementing configurations.

### 2. **Validate Early**
Validate configurations at startup and during runtime.

### 3. **Cache Appropriately**
Cache configurations but provide cache invalidation.

### 4. **Document Choices**
Use comments to explain configuration decisions.

### 5. **Version Configurations**
Include version information for configuration migration.

### 6. **Test Configurations**
Write tests for configuration validation and helper functions.

## Migration Guide

If migrating from YAML configurations:

### 1. **Extract Interfaces**
Create TypeScript interfaces matching your YAML structure.

### 2. **Convert Data**
Transform YAML data to TypeScript objects.

### 3. **Add Helper Functions**
Create utility functions for common operations.

### 4. **Update Access Patterns**
Replace YAML file reads with TypeScript imports.

### 5. **Validate Migration**
Ensure all functionality works with new configuration system.

---

This TypeScript configuration pattern provides a robust, type-safe, and maintainable foundation for the OneVault platform's multi-customer architecture while following established development patterns. 