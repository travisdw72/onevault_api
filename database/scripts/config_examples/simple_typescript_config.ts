// Simple TypeScript Configuration Example
// Works without @types/node installation

// Type definitions for our configuration
interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password?: string;
}

interface SecurityConfig {
  passwordMinLength: number;
  sessionTimeoutMinutes: number;
  maxLoginAttempts: number;
}

interface QueryConfig {
  [key: string]: string;
}

interface AppConfig {
  database: DatabaseConfig;
  security: SecurityConfig;
  queries: QueryConfig;
  environment: string;
  debug: boolean;
}

// Environment detection (simplified without process.env)
const ENVIRONMENT = 'development'; // Would be process.env.ENVIRONMENT in real app
const IS_DEVELOPMENT = ENVIRONMENT === 'development';

// Configuration with type safety
const CONFIG: AppConfig = {
  database: {
    host: 'localhost',
    port: 5432,
    database: 'one_vault',
    user: 'postgres',
    password: undefined, // Would be process.env.DB_PASSWORD
  },
  
  security: {
    passwordMinLength: 12,
    sessionTimeoutMinutes: IS_DEVELOPMENT ? 30 : 15,
    maxLoginAttempts: IS_DEVELOPMENT ? 10 : 5,
  },
  
  queries: {
    getUserByEmail: `
      SELECT 
          up.first_name,
          up.last_name,
          up.email,
          uas.username,
          uas.last_login_date
      FROM auth.user_profile_s up
      JOIN auth.user_h uh ON up.user_hk = uh.user_hk
      JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
      WHERE up.email = $1 
      AND up.load_end_date IS NULL
      AND uas.load_end_date IS NULL
    `,
    
    getTenantStats: `
      SELECT 
          COUNT(DISTINCT uh.user_hk) as user_count,
          COUNT(DISTINCT CASE WHEN ss.session_status = 'ACTIVE' 
                              THEN sh.session_hk END) as active_sessions
      FROM auth.user_h uh
      LEFT JOIN auth.user_session_l usl ON uh.user_hk = usl.user_hk
      LEFT JOIN auth.session_h sh ON usl.session_hk = sh.session_hk
      LEFT JOIN auth.session_state_s ss ON sh.session_hk = ss.session_hk 
                                        AND ss.load_end_date IS NULL
      WHERE uh.tenant_hk = $1
      GROUP BY uh.tenant_hk
    `,
  },
  
  environment: ENVIRONMENT,
  debug: IS_DEVELOPMENT,
};

// Type-safe helper functions
function getQuery(queryName: keyof typeof CONFIG.queries): string {
  const query = CONFIG.queries[queryName];
  if (!query) {
    throw new Error(`Query '${queryName}' not found`);
  }
  return query.trim();
}

function validateConfig(): string[] {
  const errors: string[] = [];
  
  if (!CONFIG.database.password) {
    errors.push("Database password is required");
  }
  
  if (CONFIG.database.port < 1 || CONFIG.database.port > 65535) {
    errors.push(`Invalid database port: ${CONFIG.database.port}`);
  }
  
  if (CONFIG.security.passwordMinLength < 8) {
    errors.push("Password minimum length must be at least 8");
  }
  
  return errors;
}

// Export configuration and utilities
export {
  CONFIG,
  getQuery,
  validateConfig,
  IS_DEVELOPMENT
};

// Example usage (would be in a separate file)
export function exampleUsage() {
  // Type-safe access to configuration
  const dbHost = CONFIG.database.host; // TypeScript knows this is a string
  const dbPort = CONFIG.database.port; // TypeScript knows this is a number
  
  // Type-safe query access
  const userQuery = getQuery('getUserByEmail'); // Autocomplete works!
  
  // Validation
  const errors = validateConfig();
  if (errors.length > 0) {
    console.log('Configuration errors:', errors);
  }
  
  // Environment-specific logic
  if (IS_DEVELOPMENT) {
    console.log('Running in development mode');
    console.log('Debug queries enabled');
  }
  
  return {
    dbHost,
    dbPort,
    userQuery,
    errors,
    environment: CONFIG.environment
  };
}

// Advantages of TypeScript configuration
export const TYPESCRIPT_ADVANTAGES = [
  "Compile-time type checking catches errors before runtime",
  "Excellent IDE support with autocomplete and refactoring",
  "Interface definitions serve as documentation",
  "Type-safe environment variable parsing",
  "Perfect for sharing between frontend and backend",
  "Refactoring safety - rename properties and all usages update",
  "Integration with modern development tools",
  "Gradual adoption - can start with any and add types incrementally"
] as const;

// When to use TypeScript for configuration
export const WHEN_TO_USE_TYPESCRIPT = {
  perfect_for: [
    "Full-stack web applications (React + Node.js)",
    "Microservices that share configuration",
    "Teams that want maximum type safety",
    "Complex configuration with validation",
    "Projects with frequent refactoring"
  ],
  
  consider_alternatives: [
    "Pure database administration (Python/SQL tools)",
    "Simple scripts (YAML is easier to start)",
    "Non-JavaScript environments",
    "Quick prototyping (JSON/YAML faster initially)"
  ]
} as const; 