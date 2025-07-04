export const roleConfig = {
  // 🎭 Role Definitions
  roles: {
    viewer: {
      name: "Data Observer",
      description: "Read-only access to workflows and analytics",
      level: 1,
      color: "electric-blue",
      icon: "👁️",
      capabilities: [
        "view_workflows",
        "view_analytics", 
        "view_logs",
        "export_data"
      ]
    },
    builder: {
      name: "Workflow Architect",
      description: "Create and modify AI workflows",
      level: 2,
      color: "neural-purple",
      icon: "🏗️",
      capabilities: [
        "create_workflows",
        "edit_workflows",
        "deploy_workflows",
        "view_analytics",
        "manage_templates"
      ]
    },
    admin: {
      name: "System Commander", 
      description: "Manage team and organizational settings",
      level: 3,
      color: "synaptic-green",
      icon: "⚙️",
      capabilities: [
        "manage_users",
        "configure_integrations",
        "view_audit_logs",
        "manage_billing",
        "configure_security"
      ]
    },
    owner: {
      name: "Neural Network Master",
      description: "Complete platform administration",
      level: 4,
      color: "active-gold",
      icon: "👑",
      capabilities: [
        "all_permissions",
        "manage_admins",
        "configure_platform",
        "access_api_keys",
        "manage_enterprise"
      ]
    }
  },

  // 🗺️ Role-based Routing
  routing: {
    viewer: {
      defaultPath: "/dashboard",
      allowedPaths: [
        "/dashboard",
        "/workflows",
        "/workflows/*",
        "/gallery",
        "/templates",
        "/templates/*",
        "/analytics",
        "/logs",
        "/profile",
        "/help"
      ],
      redirects: {
        "/": "/dashboard",
        "/admin": "/dashboard",
        "/settings": "/profile"
      }
    },
    builder: {
      defaultPath: "/dashboard",
      allowedPaths: [
        "/dashboard",
        "/workflows", 
        "/workflows/*",
        "/gallery",
        "/templates",
        "/templates/*",
        "/analytics",
        "/integrations",
        "/profile",
        "/help"
      ],
      redirects: {
        "/": "/dashboard",
        "/admin": "/dashboard"
      }
    },
    admin: {
      defaultPath: "/admin/dashboard",
      allowedPaths: [
        "/admin/*",
        "/workflows",
        "/workflows/*",
        "/gallery",
        "/templates",
        "/templates/*",
        "/builder", 
        "/analytics",
        "/users",
        "/billing",
        "/security",
        "/profile",
        "/help"
      ],
      redirects: {
        "/": "/admin/dashboard"
      }
    },
    owner: {
      defaultPath: "/admin/dashboard",
      allowedPaths: ["*"], // Access to everything
      redirects: {
        "/": "/admin/dashboard"
      }
    }
  },

  // 🎯 Onboarding Flow by Role
  onboarding: {
    ai_engineer: {
      role: "builder",
      steps: [
        {
          id: "api_integration_demo",
          title: "Connect Your First API",
          description: "Learn how to integrate external services",
          component: "ApiIntegrationTutorial",
          duration: "5 min"
        },
        {
          id: "advanced_nodes",
          title: "Master Advanced Nodes",
          description: "Explore our most powerful workflow components", 
          component: "AdvancedNodesTour",
          duration: "8 min"
        },
        {
          id: "performance_tips",
          title: "Optimize for Scale",
          description: "Best practices for high-performance workflows",
          component: "PerformanceGuide", 
          duration: "6 min"
        }
      ]
    },
    business_analyst: {
      role: "builder",
      steps: [
        {
          id: "csv_analysis_tutorial", 
          title: "Analyze Your First Dataset",
          description: "Upload and process CSV data with AI",
          component: "CsvAnalysisTutorial",
          duration: "7 min"
        },
        {
          id: "reporting_setup",
          title: "Create Automated Reports",
          description: "Build dashboards and scheduled reports",
          component: "ReportingSetup",
          duration: "10 min"
        },
        {
          id: "automation_basics",
          title: "Automate Business Processes", 
          description: "Connect your business tools seamlessly",
          component: "AutomationBasics",
          duration: "12 min"
        }
      ]
    },
    content_creator: {
      role: "builder",
      steps: [
        {
          id: "ai_prompting_guide",
          title: "Master AI Content Generation",
          description: "Learn effective prompting techniques",
          component: "AiPromptingGuide",
          duration: "6 min"
        },
        {
          id: "content_workflows",
          title: "Build Content Pipelines",
          description: "Automate your entire content process",
          component: "ContentWorkflows",
          duration: "9 min"
        },
        {
          id: "iteration_loops",
          title: "Optimize with Feedback",
          description: "Create self-improving content systems",
          component: "IterationLoops",
          duration: "8 min"
        }
      ]
    },
    automation_migrant: {
      role: "builder", 
      steps: [
        {
          id: "platform_comparison",
          title: "OneVault vs Your Current Tool",
          description: "See how OneVault improves your workflow",
          component: "PlatformComparison",
          duration: "5 min"
        },
        {
          id: "migration_tools", 
          title: "Import Your Existing Automations",
          description: "Use our migration wizard for easy transfer",
          component: "MigrationWizard",
          duration: "15 min"
        },
        {
          id: "advanced_features",
          title: "Unlock New Capabilities",
          description: "Discover features you couldn't use before",
          component: "AdvancedFeatures",
          duration: "10 min"
        }
      ]
    },
    ai_novice: {
      role: "viewer",
      steps: [
        {
          id: "ai_basics_video",
          title: "What is AI Automation?",
          description: "Watch: Understanding AI workflows in 5 minutes",
          component: "AiBasicsVideo",
          duration: "5 min"
        },
        {
          id: "simple_workflows",
          title: "Your First AI Workflow",
          description: "Build a simple automation step by step",
          component: "SimpleWorkflowTutorial", 
          duration: "10 min"
        },
        {
          id: "practical_examples",
          title: "Real-World AI Use Cases",
          description: "See how others use AI automation",
          component: "PracticalExamples",
          duration: "8 min"
        }
      ]
    }
  },

  // 🔐 Permission System
  permissions: {
    // Workflow permissions
    "view_workflows": ["viewer", "builder", "admin", "owner"],
    "create_workflows": ["builder", "admin", "owner"],
    "edit_workflows": ["builder", "admin", "owner"],
    "delete_workflows": ["builder", "admin", "owner"],
    "deploy_workflows": ["builder", "admin", "owner"],
    
    // Analytics permissions
    "view_analytics": ["viewer", "builder", "admin", "owner"],
    "view_advanced_analytics": ["builder", "admin", "owner"],
    "export_analytics": ["builder", "admin", "owner"],
    
    // User management
    "view_users": ["admin", "owner"],
    "manage_users": ["admin", "owner"],
    "invite_users": ["admin", "owner"],
    
    // System administration
    "configure_integrations": ["admin", "owner"],
    "manage_billing": ["admin", "owner"],
    "view_audit_logs": ["admin", "owner"],
    "configure_security": ["admin", "owner"],
    "manage_api_keys": ["owner"],
    
    // Enterprise features
    "white_label": ["owner"],
    "custom_branding": ["owner"],
    "enterprise_sso": ["owner"]
  },

  // 🎨 Role Visual Themes
  themes: {
    viewer: {
      primaryColor: "electric-blue",
      accent: "neural-gray",
      navIcon: "👁️",
      dashboardLayout: "analytics-focused"
    },
    builder: {
      primaryColor: "neural-purple", 
      accent: "synaptic-green",
      navIcon: "🏗️",
      dashboardLayout: "builder-focused"
    },
    admin: {
      primaryColor: "synaptic-green",
      accent: "electric-blue", 
      navIcon: "⚙️",
      dashboardLayout: "admin-focused"
    },
    owner: {
      primaryColor: "active-gold",
      accent: "neural-purple",
      navIcon: "👑", 
      dashboardLayout: "master-control"
    }
  },

  // 📱 Feature Flags by Role
  features: {
    ai_assistant: ["builder", "admin", "owner"],
    advanced_templates: ["builder", "admin", "owner"],
    custom_nodes: ["builder", "admin", "owner"],
    team_collaboration: ["admin", "owner"],
    white_labeling: ["owner"],
    enterprise_sso: ["owner"],
    audit_logging: ["admin", "owner"],
    performance_monitoring: ["builder", "admin", "owner"],
    api_access: ["builder", "admin", "owner"],
    webhook_endpoints: ["builder", "admin", "owner"]
  }
};

// Utility functions for role checking
export const hasPermission = (userRole: string, permission: string): boolean => {
  const allowedRoles = roleConfig.permissions[permission as keyof typeof roleConfig.permissions];
  return allowedRoles?.includes(userRole) || false;
};

export const canAccessPath = (userRole: string, path: string): boolean => {
  const roleRouting = roleConfig.routing[userRole as keyof typeof roleConfig.routing];
  if (!roleRouting) return false;
  
  return roleRouting.allowedPaths.some(allowedPath => {
    if (allowedPath === "*") return true;
    if (allowedPath.endsWith("/*")) {
      const basePath = allowedPath.slice(0, -2);
      return path.startsWith(basePath);
    }
    return path === allowedPath;
  });
};

export const getDefaultPath = (userRole: string): string => {
  return roleConfig.routing[userRole as keyof typeof roleConfig.routing]?.defaultPath || "/";
};

export const hasFeature = (userRole: string, feature: string): boolean => {
  const allowedRoles = roleConfig.features[feature as keyof typeof roleConfig.features];
  return allowedRoles?.includes(userRole) || false;
}; 