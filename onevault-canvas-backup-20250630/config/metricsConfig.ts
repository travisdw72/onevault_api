import { brandConfig } from './brandConfig';

export interface MetricDefinition {
  id: string;
  label: string;
  value: number | string;
  color: keyof typeof brandConfig.colors;
  icon: string;
  trend?: {
    direction: 'up' | 'down' | 'stable';
    percentage: number;
    period: string;
  };
  unit?: string;
  formatType: 'number' | 'currency' | 'percentage' | 'duration' | 'bytes';
  description?: string;
  priority: number;
  category: 'workflow' | 'performance' | 'ai' | 'data' | 'system';
}

export const metricsConfig = {
  // 📊 Live metrics definitions
  metrics: [
    {
      id: 'metric_active_workflows',
      label: 'Active Workflows',
      value: 15,
      color: 'synapticGreen' as const,
      icon: '⚡',
      trend: {
        direction: 'up' as const,
        percentage: 12,
        period: 'this week'
      },
      unit: 'workflows',
      formatType: 'number' as const,
      description: 'Currently running AI workflow instances',
      priority: 1,
      category: 'workflow' as const
    },
    {
      id: 'metric_executions_today',
      label: 'Executions Today',
      value: 247,
      color: 'electricBlue' as const,
      icon: '🔄',
      trend: {
        direction: 'up' as const,
        percentage: 23,
        period: 'vs yesterday'
      },
      unit: 'runs',
      formatType: 'number' as const,
      description: 'Workflow executions completed today',
      priority: 2,
      category: 'workflow' as const
    },
    {
      id: 'metric_ai_agents_running',
      label: 'AI Agents Running',
      value: 8,
      color: 'neuralPurple' as const,
      icon: '🤖',
      trend: {
        direction: 'stable' as const,
        percentage: 0,
        period: 'stable'
      },
      unit: 'agents',
      formatType: 'number' as const,
      description: 'Active AI model instances processing data',
      priority: 3,
      category: 'ai' as const
    },
    {
      id: 'metric_success_rate',
      label: 'Success Rate',
      value: 98.5,
      color: 'activeGold' as const,
      icon: '✨',
      trend: {
        direction: 'up' as const,
        percentage: 2.1,
        period: 'this month'
      },
      unit: '%',
      formatType: 'percentage' as const,
      description: 'Workflow execution success percentage',
      priority: 4,
      category: 'performance' as const
    },
    {
      id: 'metric_data_processed',
      label: 'Data Processed',
      value: 2.3,
      color: 'dataLime' as const,
      icon: '📊',
      trend: {
        direction: 'up' as const,
        percentage: 45,
        period: 'this week'
      },
      unit: 'TB',
      formatType: 'bytes' as const,
      description: 'Total data volume processed through workflows',
      priority: 5,
      category: 'data' as const
    },
    {
      id: 'metric_response_time',
      label: 'Avg Response Time',
      value: 1.2,
      color: 'quantumTeal' as const,
      icon: '⚡',
      trend: {
        direction: 'down' as const,
        percentage: 15,
        period: 'improved'
      },
      unit: 'sec',
      formatType: 'duration' as const,
      description: 'Average workflow execution response time',
      priority: 6,
      category: 'performance' as const
    },
    {
      id: 'metric_api_calls',
      label: 'API Calls Today',
      value: 1543,
      color: 'fusionOrange' as const,
      icon: '🔗',
      trend: {
        direction: 'up' as const,
        percentage: 18,
        period: 'vs yesterday'
      },
      unit: 'calls',
      formatType: 'number' as const,
      description: 'External API integrations called today',
      priority: 7,
      category: 'system' as const
    },
    {
      id: 'metric_cost_savings',
      label: 'Cost Savings',
      value: 2847,
      color: 'coralDecision' as const,
      icon: '💰',
      trend: {
        direction: 'up' as const,
        percentage: 34,
        period: 'this month'
      },
      unit: '$',
      formatType: 'currency' as const,
      description: 'Estimated cost savings from automation',
      priority: 8,
      category: 'performance' as const
    }
  ],

  // 🎨 Metric display configuration
  display: {
    grid: {
      mobile: { columns: 1, gap: 'md' },
      tablet: { columns: 2, gap: 'lg' },
      desktop: { columns: 3, gap: 'xl' },
      ultrawide: { columns: 4, gap: 'xl' }
    },
    animation: {
      countUp: {
        duration: 2000,
        useEasing: true,
        useGrouping: true,
        separator: ','
      },
      cardHover: {
        scale: 1.02,
        duration: 300,
        glowIntensity: 0.8
      },
      trendIndicator: {
        pulseSpeed: 2000,
        colorTransition: 300
      }
    },
    thresholds: {
      excellent: { min: 95, color: 'synapticGreen' },
      good: { min: 80, color: 'activeGold' },
      warning: { min: 60, color: 'alertAmber' },
      critical: { min: 0, color: 'criticalRed' }
    }
  },

  // 📱 Responsive configuration
  responsive: {
    mobile: {
      maxVisibleMetrics: 4,
      priorityOrder: [1, 2, 3, 4],
      showExpandButton: true
    },
    tablet: {
      maxVisibleMetrics: 6,
      priorityOrder: [1, 2, 3, 4, 5, 6],
      showExpandButton: false
    },
    desktop: {
      maxVisibleMetrics: 8,
      priorityOrder: [1, 2, 3, 4, 5, 6, 7, 8],
      showExpandButton: false
    }
  },

  // 🔄 Real-time update configuration
  realTime: {
    enabled: true,
    updateInterval: 30000, // 30 seconds
    simulateChanges: true, // For demo purposes
    changeRange: {
      small: { min: 0.95, max: 1.05 }, // ±5%
      medium: { min: 0.9, max: 1.1 },  // ±10%
      large: { min: 0.8, max: 1.2 }    // ±20%
    }
  },

  // 🎯 Accessibility configuration
  accessibility: {
    announceUpdates: true,
    updateDelay: 1000, // Wait 1s before announcing
    formatAnnouncements: {
      increase: "{label} increased to {value} {unit}",
      decrease: "{label} decreased to {value} {unit}",
      stable: "{label} remains at {value} {unit}"
    }
  }
};

// 🔧 Utility functions for metrics
export const formatMetricValue = (value: number | string, type: MetricDefinition['formatType']): string => {
  if (typeof value === 'string') return value;
  
  switch (type) {
    case 'number':
      return new Intl.NumberFormat('en-US').format(value);
    case 'currency':
      return new Intl.NumberFormat('en-US', { 
        style: 'currency', 
        currency: 'USD',
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
      }).format(value);
    case 'percentage':
      return `${value.toFixed(1)}%`;
    case 'duration':
      return `${value.toFixed(1)}s`;
    case 'bytes':
      const units = ['B', 'KB', 'MB', 'GB', 'TB'];
      let size = value * 1024 * 1024 * 1024 * 1024; // Convert TB to bytes
      let unitIndex = 4; // Start at TB
      while (size < 1024 && unitIndex > 0) {
        size *= 1024;
        unitIndex--;
      }
      return `${value.toFixed(1)} ${units[unitIndex]}`;
    default:
      return value.toString();
  }
};

export const getTrendColor = (direction: 'up' | 'down' | 'stable'): keyof typeof brandConfig.colors => {
  switch (direction) {
    case 'up':
      return 'synapticGreen';
    case 'down':
      return 'criticalRed';
    case 'stable':
      return 'textSecondary';
  }
};

export const getMetricsByCategory = (category: MetricDefinition['category']): MetricDefinition[] => {
  return metricsConfig.metrics.filter(metric => metric.category === category);
};

export const getTopPriorityMetrics = (count: number): MetricDefinition[] => {
  return metricsConfig.metrics
    .sort((a, b) => a.priority - b.priority)
    .slice(0, count);
}; 