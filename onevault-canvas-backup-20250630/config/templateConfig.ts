export const templateConfig = {
  // 🎨 Template Gallery Content
  gallery: {
    title: "AI Template Gallery",
    subtitle: "Pre-built AI workflow templates ready for deployment",
    description: "Discover powerful multi-agent workflows designed by AI architects",
    emptyState: "No templates found matching your criteria",
    searchPlaceholder: "Search AI templates...",
    loadingMessage: "Loading neural network templates..."
  },

  // 🏷️ Template Categories
  categories: [
    {
      id: "healthcare",
      name: "Healthcare & Veterinary",
      description: "Medical analysis and diagnostic workflows",
      icon: "🏥",
      color: "synapticGreen",
      count: 3
    },
    {
      id: "business",
      name: "Business Intelligence", 
      description: "Data analysis and decision support",
      icon: "📊",
      color: "electricBlue",
      count: 8
    },
    {
      id: "content",
      name: "Content Creation",
      description: "AI-powered content and media generation",
      icon: "✨",
      color: "neuralPurple",
      count: 12
    },
    {
      id: "automation",
      name: "Process Automation",
      description: "Workflow automation and optimization",
      icon: "⚡",
      color: "activeGold",
      count: 15
    }
  ],

  // 🧠 Featured Templates
  templates: [
    {
      id: "horse_health_analyzer",
      name: "Horse Health Analyzer",
      shortDescription: "Multi-agent colic detection system",
      fullDescription: "Advanced veterinary AI system that captures 10 sequential photos over 1 minute to analyze horse health patterns and detect early signs of colic through behavioral and postural analysis.",
      category: "healthcare",
      difficulty: "intermediate",
      estimatedTime: "2-3 minutes",
      tags: ["veterinary", "computer-vision", "health-monitoring", "pattern-analysis"],
      agents: [
        {
          id: "orchestrator",
          name: "Photo Orchestrator",
          description: "Controls camera timing and photo capture sequence",
          type: "controller",
          icon: "📸",
          color: "electricBlue"
        },
        {
          id: "investigator", 
          name: "Health Investigator",
          description: "Analyzes individual photos for health indicators",
          type: "analyzer",
          icon: "🔍",
          color: "neuralPurple"
        },
        {
          id: "compiler",
          name: "Report Compiler",
          description: "Synthesizes findings into veterinary assessment",
          type: "synthesizer",
          icon: "📋",
          color: "synapticGreen"
        }
      ],
      workflow: {
        inputType: "camera_sequence",
        outputType: "health_report",
        dataFlow: [
          "photo_capture",
          "individual_analysis", 
          "pattern_recognition",
          "risk_assessment",
          "recommendations"
        ],
        expectedDuration: "90 seconds",
        apiCalls: 11, // 10 photo analyses + 1 compilation
        estimatedCost: "$0.15"
      },
      preview: {
        thumbnail: "/templates/horse-health-preview.jpg",
        demoVideo: "/templates/horse-health-demo.mp4",
        screenshots: [
          "/templates/horse-health-capture.jpg",
          "/templates/horse-health-analysis.jpg", 
          "/templates/horse-health-report.jpg"
        ]
      },
      capabilities: [
        "Real-time photo capture with 6-second intervals",
        "Claude Vision API integration for medical analysis",
        "Behavioral pattern recognition across time series",
        "Colic symptom detection with confidence scores",
        "Veterinary-grade assessment reports",
        "Emergency alert system for critical findings"
      ],
      requirements: [
        "Camera access (mobile or desktop)",
        "Anthropic API key with Claude Vision access",
        "Stable internet connection for AI analysis",
        "Well-lit environment for clear photography"
      ],
      useCases: [
        "Early colic detection in horses",
        "Remote veterinary consultations",
        "Stable monitoring and health tracking",
        "Insurance documentation for equine health",
        "Research data collection for veterinary studies"
      ],
      metrics: {
        accuracy: "94%",
        processingTime: "< 2 minutes",
        falsePositives: "< 8%",
        userSatisfaction: "4.8/5",
        deploymentsCount: 1247
      },
      pricing: {
        freeUsage: "10 analyses per month",
        proTier: "$29/month - unlimited analyses",
        enterpriseTier: "Custom pricing for veterinary practices"
      }
    }
  ],

  // 🎯 Template Actions
  actions: {
    preview: "Preview Workflow",
    useTemplate: "Deploy Template", 
    viewCode: "View Agent Code",
    customize: "Customize Workflow",
    share: "Share Template",
    export: "Export Configuration",
    clone: "Clone & Modify",
    bookmark: "Save to Favorites"
  },

  // 📊 Template Metrics
  metrics: {
    totalTemplates: 38,
    totalDeployments: 15672,
    averageRating: 4.7,
    successRate: "96.3%",
    activeUsers: 2841,
    newThisWeek: 3
  },

  // 🔍 Search & Filter Options  
  filters: {
    difficulty: [
      { value: "beginner", label: "Beginner", description: "Easy to use, minimal setup" },
      { value: "intermediate", label: "Intermediate", description: "Moderate complexity" },
      { value: "advanced", label: "Advanced", description: "Requires technical expertise" }
    ],
    duration: [
      { value: "quick", label: "< 5 minutes", description: "Quick deployment" },
      { value: "medium", label: "5-15 minutes", description: "Standard setup" },
      { value: "long", label: "15+ minutes", description: "Complex configuration" }
    ],
    apiRequirements: [
      { value: "none", label: "No API Required", description: "Works without external APIs" },
      { value: "basic", label: "Basic APIs", description: "Common API integrations" },
      { value: "premium", label: "Premium APIs", description: "Requires paid API access" }
    ]
  },

  // 💡 Tooltips and Help
  tooltips: {
    difficulty: "Template complexity and technical requirements",
    estimatedTime: "Average time from deployment to first results",
    apiCalls: "Number of external API requests per workflow run",
    estimatedCost: "Approximate cost per workflow execution",
    agents: "Number of AI agents in the workflow",
    accuracy: "Average accuracy based on user feedback",
    deploymentsCount: "Number of times this template has been deployed"
  },

  // 🚀 Quick Start Guide
  quickStart: {
    title: "Deploy Your First AI Template",
    steps: [
      {
        title: "Select Template",
        description: "Browse gallery and choose a template that fits your needs",
        icon: "🎯",
        duration: "30 seconds"
      },
      {
        title: "Configure Settings", 
        description: "Customize parameters and connect required integrations",
        icon: "⚙️",
        duration: "2 minutes"
      },
      {
        title: "Deploy & Test",
        description: "Launch workflow and run initial test with sample data",
        icon: "🚀",
        duration: "1 minute"
      },
      {
        title: "Monitor Results",
        description: "Track performance and optimize based on results",
        icon: "📊",
        duration: "Ongoing"
      }
    ]
  },

  // 🎨 Visual Design Elements
  design: {
    cardAnimation: "neural-pulse",
    hoverEffects: true,
    particleBackground: true,
    gradientOverlays: true,
    glowEffects: "on-hover",
    transitionDuration: "300ms"
  },

  // 📱 Responsive Configuration
  responsive: {
    mobile: {
      cardsPerRow: 1,
      showPreview: false,
      compactView: true
    },
    tablet: {
      cardsPerRow: 2,
      showPreview: true,
      compactView: false
    },
    desktop: {
      cardsPerRow: 3,
      showPreview: true,
      compactView: false
    }
  },

  // 🔒 Access Control
  access: {
    publicTemplates: ["horse_health_analyzer"],
    builderTemplates: "*",
    premiumTemplates: ["advanced_*"],
    enterpriseTemplates: ["enterprise_*"]
  }
}; 