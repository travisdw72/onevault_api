// TypeScript Configuration - Type-Safe and Powerful
// Combines the best of static typing with runtime flexibility

interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password?: string;
  connectionPool: {
    min: number;
    max: number;
    timeoutSeconds: number;
  };
}

interface SecurityConfig {
  passwordMinLength: number;
  sessionTimeoutMinutes: number;
  maxLoginAttempts: number;
  passwordRequirements: {
    uppercase: boolean;
    lowercase: boolean;
    numbers: boolean;
    specialChars: boolean;
    minLength: number;
  };
}

interface QueryConfig {
  [key: string]: string;
}

interface EnvironmentConfig {
  debug: boolean;
  logLevel: 'DEBUG' | 'INFO' | 'WARN' | 'ERROR';
  autoCreateTables: boolean;
  enableSqlLogging: boolean;
}

interface AppConfig {
  database: DatabaseConfig;
  environment: string;
  currentEnv: EnvironmentConfig;
  security: SecurityConfig;
  queries: QueryConfig;
  features: Record<string, boolean>;
  logging: {
    level: string;
    format: string;
    handlers: string[];
    filePath?: string;
  };
  api: {
    rateLimiting: {
      enabled: boolean;
      requestsPerMinute: number;
      burstLimit: number;
    };
    cors: {
      enabled: boolean;
      origins: string[];
    };
  };
}

// Environment detection with type safety
const ENVIRONMENT = process.env.ENVIRONMENT || 'development';
const IS_PRODUCTION = ENVIRONMENT === 'production';
const IS_DEVELOPMENT = ENVIRONMENT === 'development';

// Type-safe environment variable parsing
function getEnvNumber(key: string, defaultValue: number): number {
  const value = process.env[key];
  if (!value) return defaultValue;
  const parsed = parseInt(value, 10);
  if (isNaN(parsed)) {
    throw new Error(`Environment variable ${key} must be a valid number, got: ${value}`);
  }
  return parsed;
}

function getEnvString(key: string, defaultValue?: string): string {
  const value = process.env[key];
  if (!value && defaultValue === undefined) {
    throw new Error(`Environment variable ${key} is required`);
  }
  return value || defaultValue!;
}

function getEnvBoolean(key: string, defaultValue: boolean): boolean {
  const value = process.env[key];
  if (!value) return defaultValue;
  return value.toLowerCase() === 'true';
}

// Database configuration with environment-specific overrides
const DATABASE: DatabaseConfig = {
  host: getEnvString('DB_HOST', 'localhost'),
  port: getEnvNumber('DB_PORT', 5432),
  database: getEnvString('DB_NAME', 'one_vault'),
  user: getEnvString('DB_USER', 'postgres'),
  password: process.env.DB_PASSWORD, // Optional in development, required in production
  connectionPool: {
    min: IS_DEVELOPMENT ? 1 : 5,
    max: IS_DEVELOPMENT ? 10 : 50,
    timeoutSeconds: 30,
  }
};

// Environment-specific settings with strong typing
const ENVIRONMENTS: Record<string, EnvironmentConfig> = {
  development: {
    debug: true,
    logLevel: 'DEBUG',
    autoCreateTables: true,
    enableSqlLogging: true,
  },
  production: {
    debug: false,
    logLevel: 'INFO',
    autoCreateTables: false,
    enableSqlLogging: false,
  }
};

// Current environment settings with type safety
const CURRENT_ENV: EnvironmentConfig = ENVIRONMENTS[ENVIRONMENT] || ENVIRONMENTS.development;

// Security settings with calculations and type safety
const SECURITY: SecurityConfig = {
  passwordMinLength: 12,
  sessionTimeoutMinutes: IS_DEVELOPMENT ? 30 : 15,
  maxLoginAttempts: IS_DEVELOPMENT ? 10 : 5,
  passwordRequirements: {
    uppercase: true,
    lowercase: true,
    numbers: true,
    specialChars: true,
    minLength: 12,
  },
};

// SQL queries with proper formatting and type safety
const QUERIES: QueryConfig = {
  getUserByEmail: `
    -- Get user profile with authentication data
    SELECT 
        up.first_name,
        up.last_name,
        up.email,
        uas.username,
        uas.last_login_date,
        uas.password_last_changed,
        EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - uas.password_last_changed)) as password_age_days
    FROM auth.user_profile_s up
    JOIN auth.user_h uh ON up.user_hk = uh.user_hk
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE up.email = $1 
    AND up.load_end_date IS NULL
    AND uas.load_end_date IS NULL
  `,
  
  getTenantStats: `
    -- Get comprehensive tenant statistics
    SELECT 
        COUNT(DISTINCT uh.user_hk) as user_count,
        COUNT(DISTINCT CASE WHEN ss.session_status = 'ACTIVE' THEN sh.session_hk END) as active_sessions,
        MAX(uas.last_login_date) as last_activity,
        COUNT(DISTINCT CASE WHEN uas.last_login_date >= CURRENT_DATE - INTERVAL '7 days' 
                            THEN uh.user_hk END) as weekly_active_users,
        COUNT(DISTINCT CASE WHEN uas.last_login_date >= CURRENT_DATE - INTERVAL '30 days' 
                            THEN uh.user_hk END) as monthly_active_users
    FROM auth.user_h uh
    LEFT JOIN auth.user_session_l usl ON uh.user_hk = usl.user_hk
    LEFT JOIN auth.session_h sh ON usl.session_hk = sh.session_hk
    LEFT JOIN auth.session_state_s ss ON sh.session_hk = ss.session_hk AND ss.load_end_date IS NULL
    LEFT JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk AND uas.load_end_date IS NULL
    WHERE uh.tenant_hk = $1
    GROUP BY uh.tenant_hk
  `,
  
  auditPasswordSecurity: `
    -- Comprehensive password security audit
    SELECT 
        'PASSWORD SECURITY AUDIT' as audit_type,
        table_schema || '.' || table_name as table_location,
        column_name,
        data_type,
        CASE 
            WHEN column_name LIKE '%hash%' AND data_type = 'bytea' THEN '✅ SECURE HASH'
            WHEN column_name LIKE '%salt%' AND data_type = 'bytea' THEN '✅ SECURE SALT'
            WHEN column_name LIKE '%indicator%' THEN '✅ SAFE INDICATOR'
            WHEN column_name LIKE '%password%' AND data_type = 'bytea' THEN '✅ SECURE BINARY'
            WHEN column_name LIKE '%password%' AND data_type != 'bytea' THEN '⚠️ REVIEW NEEDED'
            ELSE '📋 OTHER'
        END as security_status
    FROM information_schema.columns 
    WHERE (LOWER(column_name) LIKE '%password%'
       OR LOWER(column_name) LIKE '%hash%'
       OR LOWER(column_name) LIKE '%salt%')
    AND table_schema NOT LIKE 'pg_%'
    AND table_schema != 'information_schema'
    ORDER BY 
        CASE WHEN column_name LIKE '%password%' AND data_type != 'bytea' THEN 1 ELSE 2 END,
        table_schema, 
        table_name, 
        column_name
  `
};

// Dynamic query generation based on environment
if (IS_DEVELOPMENT) {
  QUERIES.debugShowAllTables = `
    SELECT schemaname, tablename, tableowner 
    FROM pg_tables 
    WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
    ORDER BY schemaname, tablename
  `;
}

// Feature flags based on environment with type safety
const FEATURES: Record<string, boolean> = {
  enableDebugQueries: IS_DEVELOPMENT,
  enablePerformanceMonitoring: true,
  enableAuditLogging: true,
  enableAiMonitoring: IS_PRODUCTION,
  enableRealTimeAlerts: IS_PRODUCTION,
};

// Logging configuration
const LOGGING = {
  level: CURRENT_ENV.logLevel,
  format: '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
  handlers: IS_DEVELOPMENT ? ['console'] : ['console', 'file'],
  filePath: IS_PRODUCTION ? '/var/log/one_vault/app.log' : './app.log',
};

// API configuration with rate limiting
const API = {
  rateLimiting: {
    enabled: true,
    requestsPerMinute: IS_DEVELOPMENT ? 1000 : 100,
    burstLimit: 50,
  },
  cors: {
    enabled: IS_DEVELOPMENT,
    origins: IS_DEVELOPMENT ? ['http://localhost:3000'] : [],
  }
};

// Validation functions with type safety
function validateConfig(): string[] {
  const errors: string[] = [];
  
  if (!DATABASE.password) {
    errors.push("DB_PASSWORD environment variable must be set");
  }
  
  if (DATABASE.port < 1 || DATABASE.port > 65535) {
    errors.push(`Invalid database port: ${DATABASE.port}`);
  }
  
  if (SECURITY.passwordMinLength < 8) {
    errors.push("Password minimum length must be at least 8");
  }
  
  return errors;
}

// Helper functions for dynamic configuration with type safety
function getDatabaseUrl(): string {
  if (!DATABASE.password) {
    throw new Error("Database password is required to generate URL");
  }
  return `postgresql://${DATABASE.user}:${DATABASE.password}@${DATABASE.host}:${DATABASE.port}/${DATABASE.database}`;
}

function getQuery(queryName: keyof typeof QUERIES): string {
  const query = QUERIES[queryName];
  if (!query) {
    throw new Error(`Query '${queryName}' not found`);
  }
  return query.trim();
}

function getFeatureFlag(featureName: string): boolean {
  return FEATURES[featureName] || false;
}

// Export configuration as a single typed object
export const CONFIG: AppConfig = {
  database: DATABASE,
  environment: ENVIRONMENT,
  currentEnv: CURRENT_ENV,
  security: SECURITY,
  queries: QUERIES,
  features: FEATURES,
  logging: LOGGING,
  api: API,
};

// Export utility functions
export {
  validateConfig,
  getDatabaseUrl,
  getQuery,
  getFeatureFlag,
  IS_PRODUCTION,
  IS_DEVELOPMENT
};

// Advantages of TypeScript configuration:
export const ADVANTAGES = [
  "Compile-time type checking",
  "Excellent IDE support with autocomplete",
  "Refactoring safety",
  "Interface definitions for documentation",
  "Environment variable type safety",
  "Runtime validation with types",
  "Integration with modern tooling",
  "Gradual adoption possible",
  "Strong ecosystem support",
  "Perfect for frontend/backend sharing",
] as const;

// Validate configuration when module is loaded
if (require.main === module) {
  const errors = validateConfig();
  if (errors.length > 0) {
    console.error("Configuration errors:");
    errors.forEach(error => console.error(`  - ${error}`));
    process.exit(1);
  } else {
    console.log("✅ Configuration is valid");
    console.log(`Environment: ${ENVIRONMENT}`);
    console.log(`Database: ${DATABASE.host}:${DATABASE.port}/${DATABASE.database}`);
    console.log(`Debug mode: ${CURRENT_ENV.debug}`);
    console.log(`Available queries: ${Object.keys(QUERIES)}`);
  }
} 