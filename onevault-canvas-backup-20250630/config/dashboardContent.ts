export const dashboardContent = {
  // 👋 Welcome section content
  welcome: {
    greetings: {
      morning: "Good morning, Neural Architect",
      afternoon: "Welcome back, AI Commander", 
      evening: "Evening protocols active, Workflow Master",
      night: "Neural networks active, System Master"
    },
    taglines: [
      "Your AI workflows are evolving",
      "Neural networks await your command",
      "Intelligence flows through your designs",
      "Data streams pulse with opportunity",
      "Synaptic connections strengthening"
    ],
    currentStatus: {
      online: "Neural Network Online",
      processing: "AI Workflows Processing", 
      optimizing: "System Optimization Active",
      ready: "Ready for Command"
    }
  },

  // 🚀 Quick actions configuration
  quickActions: [
    {
      id: 'txt_action_start_building',
      title: 'Start Building',
      description: 'Create new AI workflow',
      icon: '🧠',
      route: '/canvas',
      color: 'synapticGreen',
      priority: 1,
      category: 'workflow'
    },
    {
      id: 'txt_action_ai_gallery',
      title: 'AI Gallery',
      description: 'Browse pre-built agents',
      icon: '🤖',
      route: '/gallery',
      color: 'neuralPurple',
      priority: 2,
      category: 'discover'
    },
    {
      id: 'txt_action_analytics',
      title: 'View Analytics',
      description: 'Performance insights',
      icon: '📊',
      route: '/analytics',
      color: 'electricBlue',
      priority: 3,
      category: 'insights'
    },
    {
      id: 'txt_action_quick_deploy',
      title: 'Quick Deploy',
      description: 'One-click templates',
      icon: '⚡',
      route: '/templates',
      color: 'activeGold',
      priority: 4,
      category: 'automation'
    }
  ],

  // 📊 Activity feed configuration
  activityFeed: {
    title: "Neural Activity Stream",
    emptyState: "No recent activity detected",
    loadMore: "Load Previous Activity",
    types: {
      workflow_execution: {
        icon: "⚡",
        color: "electricBlue",
        format: "Workflow {name} executed successfully"
      },
      agent_deployment: {
        icon: "🚀",
        color: "neuralPurple", 
        format: "AI Agent {name} deployed to production"
      },
      data_processing: {
        icon: "📊",
        color: "synapticGreen",
        format: "Processed {amount} of data through {workflow}"
      },
      system_optimization: {
        icon: "🔧",
        color: "activeGold",
        format: "System optimization completed - {improvement}% faster"
      },
      user_collaboration: {
        icon: "👥",
        color: "quantumTeal",
        format: "{user} joined workflow {name}"
      },
      integration_connected: {
        icon: "🔗",
        color: "fusionOrange",
        format: "Connected to {service} integration"
      }
    }
  },

  // 💡 Guided tour configuration
  guidedTour: {
    title: "Neural Network Orientation",
    description: "Master the command center in 5 minutes",
    aiAssistant: {
      name: "ARIA",
      subtitle: "AI Workflow Intelligence Assistant",
      avatar: "🧠",
      personality: "helpful_expert"
    },
    steps: [
      {
        id: "welcome_overview",
        title: "Welcome to Your Command Center",
        description: "This is where you orchestrate AI workflows like a neural network architect",
        target: ".welcome-header",
        position: "bottom",
        duration: 5000
      },
      {
        id: "metrics_explanation",
        title: "Live Neural Metrics",
        description: "Monitor your AI ecosystem's health and performance in real-time",
        target: ".metrics-grid",
        position: "top",
        duration: 4000
      },
      {
        id: "quick_actions_tour",
        title: "Rapid Deployment Actions",
        description: "Launch workflows, browse AI agents, and deploy solutions instantly",
        target: ".quick-actions",
        position: "top",
        duration: 4000
      },
      {
        id: "activity_monitoring",
        title: "Intelligence Activity Stream",
        description: "Track every synaptic connection and data flow in your neural network",
        target: ".activity-feed",
        position: "left",
        duration: 4000
      },
      {
        id: "completion_celebration",
        title: "Neural Network Mastery Achieved",
        description: "You're ready to architect the future of AI automation",
        target: "body",
        position: "center",
        duration: 3000,
        celebration: true
      }
    ]
  },

  // 📱 Responsive breakpoints content
  responsive: {
    mobile: {
      welcome: {
        shortGreeting: "Neural Command",
        compactTaglines: [
          "AI Workflows Active",
          "Networks Ready",
          "Systems Online"
        ]
      },
      quickActions: {
        maxVisible: 2,
        showMore: "More Actions"
      },
      activityFeed: {
        initialItems: 5,
        title: "Activity"
      }
    },
    tablet: {
      quickActions: {
        maxVisible: 3
      },
      activityFeed: {
        initialItems: 8
      }
    }
  },

  // 🎯 Accessibility content
  accessibility: {
    labels: {
      welcomeHeader: "Welcome header with user greeting and system status",
      metricsGrid: "Dashboard metrics showing workflow performance",
      quickActions: "Quick action buttons for common tasks",
      activityFeed: "Real-time activity feed showing system events",
      guidedTour: "Interactive guided tour overlay"
    },
    descriptions: {
      dashboard: "OneVault AI Workflow Builder dashboard showing system metrics, quick actions, and activity feed",
      metrics: "Performance metrics including active workflows, execution counts, and system health",
      actions: "Primary action buttons for creating workflows, viewing analytics, and accessing templates"
    }
  }
}; 