# Backend Development Plan: Production Readiness APIs
## One Vault Multi-Tenant Data Vault 2.0 Platform

### Overview
This document outlines the backend API development requirements to support the production readiness infrastructure including backup/recovery, monitoring/alerting, performance optimization, and automated maintenance systems.

---

## 🏗️ **API ARCHITECTURE OVERVIEW**

### API Structure
```
/api/v1/
├── backup/                 # Phase 1: Backup & Recovery APIs
├── monitoring/             # Phase 2: Monitoring & Alerting APIs  
├── performance/            # Phase 3: Performance Optimization APIs
├── maintenance/            # Phase 3: Automated Maintenance APIs
└── system/                 # Cross-cutting system APIs
```

### Authentication & Authorization
- **JWT Token Authentication**: All APIs require valid JWT tokens
- **Tenant Isolation**: All APIs enforce tenant-based access control
- **Role-Based Access**: Different access levels (admin, operator, viewer)
- **API Rate Limiting**: Prevent abuse and ensure system stability

---

## 📦 **PHASE 1: BACKUP & RECOVERY APIs**

### Backup Management APIs

#### 1. Backup Operations
```typescript
// POST /api/v1/backup/execute
interface BackupExecuteRequest {
  backupType: 'FULL' | 'INCREMENTAL' | 'DIFFERENTIAL';
  tenantId?: string; // null for system-wide backup
  retentionPeriod?: string; // ISO 8601 duration
  encryptionEnabled?: boolean;
  compressionLevel?: number; // 1-9
  tags?: Record<string, string>;
}

interface BackupExecuteResponse {
  backupId: string;
  status: 'INITIATED' | 'RUNNING' | 'COMPLETED' | 'FAILED';
  estimatedDuration: string; // ISO 8601 duration
  backupLocation: string;
  message: string;
}

// GET /api/v1/backup/status/{backupId}
interface BackupStatusResponse {
  backupId: string;
  status: 'RUNNING' | 'COMPLETED' | 'FAILED' | 'CANCELLED';
  progress: number; // 0-100
  startTime: string; // ISO 8601
  endTime?: string; // ISO 8601
  duration?: number; // seconds
  backupSize?: number; // bytes
  errorMessage?: string;
  verificationStatus: 'PENDING' | 'VERIFIED' | 'FAILED';
}

// GET /api/v1/backup/list
interface BackupListRequest {
  tenantId?: string;
  backupType?: string;
  status?: string;
  startDate?: string; // ISO 8601
  endDate?: string; // ISO 8601
  page?: number;
  pageSize?: number;
}

interface BackupListResponse {
  backups: BackupInfo[];
  pagination: PaginationInfo;
}

interface BackupInfo {
  backupId: string;
  backupType: string;
  status: string;
  startTime: string;
  endTime?: string;
  backupSize: number;
  retentionExpiry: string;
  verificationStatus: string;
  tags: Record<string, string>;
}
```

#### 2. Recovery Operations
```typescript
// POST /api/v1/backup/recovery/initiate
interface RecoveryInitiateRequest {
  backupId: string;
  recoveryType: 'FULL' | 'POINT_IN_TIME' | 'SELECTIVE';
  targetTime?: string; // ISO 8601 for point-in-time recovery
  targetTenant?: string; // for selective recovery
  recoveryLocation?: string;
  validateOnly?: boolean; // dry run
}

interface RecoveryInitiateResponse {
  recoveryId: string;
  status: 'INITIATED' | 'RUNNING' | 'COMPLETED' | 'FAILED';
  estimatedDuration: string;
  recoveryPlan: RecoveryPlan;
}

interface RecoveryPlan {
  steps: RecoveryStep[];
  totalEstimatedTime: string;
  dataIntegrityChecks: string[];
  rollbackProcedure: string;
}

// GET /api/v1/backup/recovery/status/{recoveryId}
interface RecoveryStatusResponse {
  recoveryId: string;
  status: string;
  progress: number;
  currentStep: string;
  startTime: string;
  endTime?: string;
  errorMessage?: string;
  dataIntegrityResults?: IntegrityCheckResult[];
}
```

#### 3. Backup Verification
```typescript
// POST /api/v1/backup/verify/{backupId}
interface BackupVerifyResponse {
  verificationId: string;
  status: 'RUNNING' | 'COMPLETED' | 'FAILED';
  integrityChecks: IntegrityCheck[];
  overallResult: 'PASSED' | 'FAILED' | 'WARNING';
}

interface IntegrityCheck {
  checkType: 'CHECKSUM' | 'STRUCTURE' | 'CONSISTENCY';
  status: 'PASSED' | 'FAILED' | 'WARNING';
  details: string;
  errorCount?: number;
}
```

---

## 🔒 **PHASE 4: LOCK MONITORING & BLOCKING ANALYSIS APIs**

### Lock Monitoring APIs

#### 1. Lock Activity Monitoring
```typescript
// GET /api/v1/locks/activity
interface LockActivityRequest {
  tenantId?: string;
  timeRange?: {
    start: string; // ISO 8601
    end: string; // ISO 8601
  };
  lockType?: string;
  lockMode?: string;
  includeResolved?: boolean;
  page?: number;
  pageSize?: number;
}

interface LockActivityResponse {
  locks: LockActivity[];
  summary: LockActivitySummary;
  pagination: PaginationInfo;
}

interface LockActivity {
  lockId: string;
  lockType: string;
  lockMode: string;
  relationName: string;
  schemaName: string;
  tableName: string;
  sessionPid: number;
  userName: string;
  applicationName: string;
  clientAddr: string;
  queryText: string;
  lockAcquiredTime: string;
  lockDuration: number; // seconds
  lockGranted: boolean;
  blockingPid?: number;
  impactScore: number; // 0-100
  resolutionAction?: string;
  resolutionTime?: string;
}

interface LockActivitySummary {
  totalLocks: number;
  waitingLocks: number;
  blockingLocks: number;
  averageDuration: number;
  maxDuration: number;
  criticalLocks: number;
}

// POST /api/v1/locks/capture
interface LockCaptureRequest {
  tenantId?: string;
  forceCapture?: boolean;
}

interface LockCaptureResponse {
  captureId: string;
  locksCaptured: number;
  blockingLocks: number;
  criticalLocks: number;
  deadlocksDetected: number;
  captureTime: string;
}
```

#### 2. Blocking Session Management
```typescript
// GET /api/v1/locks/blocking-sessions
interface BlockingSessionsRequest {
  tenantId?: string;
  severity?: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  minDuration?: number; // seconds
  includeResolved?: boolean;
}

interface BlockingSessionsResponse {
  blockingSessions: BlockingSession[];
  summary: BlockingSessionSummary;
}

interface BlockingSession {
  sessionId: string;
  sessionPid: number;
  userName: string;
  databaseName: string;
  applicationName: string;
  clientAddr: string;
  sessionState: string;
  blockedSessionsCount: number;
  totalLocksHeld: number;
  exclusiveLocksHeld: number;
  blockingDuration: number; // seconds
  blockingSeverity: string;
  impactScore: number;
  autoKillEligible: boolean;
  escalationLevel: number;
  currentQuery: string;
  lastActivity: string;
  recommendedAction: string;
}

interface BlockingSessionSummary {
  totalBlockingSessions: number;
  criticalSessions: number;
  highSeveritySessions: number;
  totalBlockedSessions: number;
  averageBlockingDuration: number;
  autoResolutionCandidates: number;
}

// POST /api/v1/locks/blocking-sessions/{sessionPid}/terminate
interface TerminateSessionRequest {
  reason: string;
  dryRun?: boolean;
  force?: boolean;
}

interface TerminateSessionResponse {
  sessionPid: number;
  action: 'TERMINATED' | 'TERMINATION_FAILED' | 'DRY_RUN';
  result: 'SUCCESS' | 'FAILED' | 'SIMULATED';
  impactAssessment: string;
  affectedSessions: number[];
}
```

#### 3. Deadlock Detection & Analysis
```typescript
// GET /api/v1/locks/deadlocks
interface DeadlockRequest {
  tenantId?: string;
  timeRange?: {
    start: string;
    end: string;
  };
  severity?: string;
  includeResolved?: boolean;
}

interface DeadlockResponse {
  deadlocks: DeadlockEvent[];
  summary: DeadlockSummary;
}

interface DeadlockEvent {
  deadlockId: string;
  deadlockTimestamp: string;
  involvedSessions: number[];
  involvedQueries: string[];
  involvedUsers: string[];
  deadlockVictimPid: number;
  deadlockResolution: string;
  deadlockDuration: number; // milliseconds
  affectedTables: string[];
  lockTypesInvolved: string[];
  frequencyScore: number;
  preventionSuggestion: string;
  businessImpact: string;
  recoveryTime: number;
  dataConsistencyAffected: boolean;
  manualInterventionRequired: boolean;
  deadlockGraph: any; // JSON representation
}

interface DeadlockSummary {
  totalDeadlocks: number;
  criticalDeadlocks: number;
  averageResolutionTime: number;
  mostFrequentPattern: string;
  preventionRecommendations: string[];
}

// POST /api/v1/locks/deadlocks/detect
interface DeadlockDetectionResponse {
  detectionId: string;
  deadlocksDetected: boolean;
  deadlockCount: number;
  detectionTime: string;
  deadlocks: DeadlockEvent[];
}
```

#### 4. Lock Wait Analysis
```typescript
// GET /api/v1/locks/analysis
interface LockAnalysisRequest {
  tenantId?: string;
  analysisType: 'CURRENT' | 'HISTORICAL' | 'TREND';
  timeRange?: {
    start: string;
    end: string;
  };
  periodHours?: number; // for historical analysis
}

interface LockAnalysisResponse {
  analysis: LockWaitAnalysis;
  recommendations: string[];
  trends: LockTrend[];
}

interface LockWaitAnalysis {
  analysisId: string;
  analysisPeriod: {
    start: string;
    end: string;
  };
  totalLockEvents: number;
  blockingEvents: number;
  deadlockEvents: number;
  averageWaitTime: number; // milliseconds
  maxWaitTime: number;
  lockTimeoutEvents: number;
  mostContendedTable: string;
  mostBlockingUser: string;
  mostBlockedUser: string;
  peakConcurrentLocks: number;
  lockEfficiencyScore: number; // 0-100
  performanceImpactScore: number;
  businessHoursImpact: boolean;
  trendDirection: 'IMPROVING' | 'STABLE' | 'DEGRADING';
  contentiionHotspots: ContentionHotspot[];
}

interface ContentionHotspot {
  resourceType: 'TABLE' | 'INDEX' | 'SEQUENCE';
  resourceName: string;
  contentionScore: number;
  lockCount: number;
  averageWaitTime: number;
  recommendedAction: string;
}

interface LockTrend {
  metric: string;
  timePoints: TimePoint[];
  trend: 'INCREASING' | 'DECREASING' | 'STABLE';
  changeRate: number; // percentage
}
```

#### 5. Automated Lock Resolution
```typescript
// POST /api/v1/locks/auto-resolve
interface AutoResolveRequest {
  tenantId?: string;
  maxBlockingDuration?: number; // seconds
  dryRun?: boolean;
  severityThreshold?: 'HIGH' | 'CRITICAL';
  maxSessionsToTerminate?: number;
}

interface AutoResolveResponse {
  resolutionId: string;
  actionsPlanned: number;
  actionsExecuted: number;
  sessionsTerminated: number;
  resolutionResults: ResolutionResult[];
  overallResult: 'SUCCESS' | 'PARTIAL' | 'FAILED';
}

interface ResolutionResult {
  sessionPid: number;
  action: string;
  result: string;
  impactAssessment: string;
  blockedSessionsFreed: number;
}

// GET /api/v1/locks/auto-resolve/config
interface AutoResolveConfigResponse {
  enabled: boolean;
  maxBlockingDuration: number;
  severityThreshold: string;
  maxSessionsPerCycle: number;
  excludedUsers: string[];
  excludedApplications: string[];
  businessHoursOnly: boolean;
  notificationChannels: string[];
}

// PUT /api/v1/locks/auto-resolve/config
interface AutoResolveConfigRequest {
  enabled?: boolean;
  maxBlockingDuration?: number;
  severityThreshold?: string;
  maxSessionsPerCycle?: number;
  excludedUsers?: string[];
  excludedApplications?: string[];
  businessHoursOnly?: boolean;
  notificationChannels?: string[];
}
```

### Lock Monitoring Dashboard APIs

#### 6. Real-time Lock Dashboard
```typescript
// GET /api/v1/locks/dashboard/realtime
interface RealtimeLockDashboardResponse {
  timestamp: string;
  overview: {
    activeLocks: number;
    waitingLocks: number;
    blockingSessions: number;
    criticalSituations: number;
    systemEfficiency: number; // 0-100
  };
  topContention: ContentionHotspot[];
  recentDeadlocks: DeadlockEvent[];
  blockingSessionsAlert: BlockingSession[];
  performanceMetrics: {
    averageLockWaitTime: number;
    lockThroughput: number; // locks per second
    deadlockRate: number; // deadlocks per hour
    autoResolutionRate: number; // percentage
  };
  alerts: LockAlert[];
}

interface LockAlert {
  alertId: string;
  alertType: 'BLOCKING' | 'DEADLOCK' | 'CONTENTION' | 'PERFORMANCE';
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  message: string;
  timestamp: string;
  affectedResources: string[];
  recommendedAction: string;
  autoResolutionAvailable: boolean;
}

// GET /api/v1/locks/dashboard/historical
interface HistoricalLockDashboardRequest {
  timeRange: {
    start: string;
    end: string;
  };
  aggregation: 'HOUR' | 'DAY' | 'WEEK';
  tenantId?: string;
}

interface HistoricalLockDashboardResponse {
  timeRange: TimeRange;
  aggregation: string;
  metrics: {
    lockActivity: TimeSeriesData[];
    blockingEvents: TimeSeriesData[];
    deadlockEvents: TimeSeriesData[];
    efficiencyScore: TimeSeriesData[];
    performanceImpact: TimeSeriesData[];
  };
  trends: {
    lockActivityTrend: 'INCREASING' | 'DECREASING' | 'STABLE';
    blockingTrend: 'INCREASING' | 'DECREASING' | 'STABLE';
    efficiencyTrend: 'IMPROVING' | 'DEGRADING' | 'STABLE';
  };
  insights: string[];
}
```

---

## 📊 **PHASE 2: MONITORING & ALERTING APIs**

### Monitoring APIs

#### 1. System Health Monitoring
```typescript
// GET /api/v1/monitoring/health
interface SystemHealthResponse {
  overall: HealthStatus;
  components: ComponentHealth[];
  lastUpdated: string;
}

interface ComponentHealth {
  component: string;
  status: 'HEALTHY' | 'WARNING' | 'CRITICAL' | 'UNKNOWN';
  metrics: HealthMetric[];
  lastCheck: string;
}

interface HealthMetric {
  name: string;
  value: number;
  unit: string;
  threshold: {
    warning: number;
    critical: number;
  };
  trend: 'IMPROVING' | 'STABLE' | 'DEGRADING';
}

// GET /api/v1/monitoring/metrics
interface MetricsRequest {
  tenantId?: string;
  category?: 'PERFORMANCE' | 'AVAILABILITY' | 'SECURITY' | 'COMPLIANCE';
  timeRange: {
    start: string; // ISO 8601
    end: string; // ISO 8601
  };
  aggregation?: 'MINUTE' | 'HOUR' | 'DAY';
}

interface MetricsResponse {
  metrics: MetricSeries[];
  timeRange: TimeRange;
  aggregation: string;
}

interface MetricSeries {
  name: string;
  category: string;
  unit: string;
  dataPoints: DataPoint[];
}

interface DataPoint {
  timestamp: string;
  value: number;
  status?: 'NORMAL' | 'WARNING' | 'CRITICAL';
}
```

#### 2. Performance Analytics
```typescript
// GET /api/v1/monitoring/performance/dashboard
interface PerformanceDashboardResponse {
  summary: PerformanceSummary;
  topQueries: QueryPerformance[];
  systemResources: ResourceUtilization[];
  trends: PerformanceTrend[];
}

interface PerformanceSummary {
  avgResponseTime: number;
  throughput: number;
  errorRate: number;
  activeConnections: number;
  cacheHitRatio: number;
}

interface QueryPerformance {
  queryHash: string;
  queryText: string;
  avgExecutionTime: number;
  executionCount: number;
  performanceRating: 'EXCELLENT' | 'GOOD' | 'POOR' | 'CRITICAL';
  optimizationSuggestions: string[];
}
```

### Alerting APIs

#### 1. Alert Management
```typescript
// GET /api/v1/monitoring/alerts
interface AlertListRequest {
  tenantId?: string;
  status?: 'ACTIVE' | 'ACKNOWLEDGED' | 'RESOLVED';
  severity?: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  category?: string;
  timeRange?: TimeRange;
  page?: number;
  pageSize?: number;
}

interface AlertListResponse {
  alerts: Alert[];
  pagination: PaginationInfo;
  summary: AlertSummary;
}

interface Alert {
  alertId: string;
  alertName: string;
  severity: string;
  status: string;
  category: string;
  description: string;
  triggeredAt: string;
  acknowledgedAt?: string;
  resolvedAt?: string;
  assignedTo?: string;
  metricValue: number;
  threshold: number;
  actions: AlertAction[];
}

// POST /api/v1/monitoring/alerts/{alertId}/acknowledge
interface AlertAcknowledgeRequest {
  acknowledgmentNote?: string;
  assignTo?: string;
  estimatedResolution?: string; // ISO 8601
}

// POST /api/v1/monitoring/alerts/{alertId}/resolve
interface AlertResolveRequest {
  resolutionNote: string;
  rootCause?: string;
  preventiveActions?: string[];
}
```

#### 2. Incident Management
```typescript
// GET /api/v1/monitoring/incidents
interface IncidentListResponse {
  incidents: Incident[];
  pagination: PaginationInfo;
}

interface Incident {
  incidentId: string;
  title: string;
  severity: string;
  status: 'OPEN' | 'INVESTIGATING' | 'RESOLVED' | 'CLOSED';
  createdAt: string;
  resolvedAt?: string;
  assignedTo?: string;
  affectedServices: string[];
  relatedAlerts: string[];
  timeline: IncidentEvent[];
}

// POST /api/v1/monitoring/incidents/{incidentId}/update
interface IncidentUpdateRequest {
  status?: string;
  assignTo?: string;
  note: string;
  actionType: 'STATUS_CHANGE' | 'ASSIGNMENT' | 'NOTE' | 'ESCALATION';
}
```

#### 3. Notification Management
```typescript
// GET /api/v1/monitoring/notifications/channels
interface NotificationChannelsResponse {
  channels: NotificationChannel[];
}

interface NotificationChannel {
  channelId: string;
  type: 'EMAIL' | 'SLACK' | 'SMS' | 'WEBHOOK' | 'PAGERDUTY';
  name: string;
  configuration: Record<string, any>;
  isEnabled: boolean;
  testStatus: 'PASSED' | 'FAILED' | 'PENDING';
}

// POST /api/v1/monitoring/notifications/test
interface NotificationTestRequest {
  channelId: string;
  testMessage?: string;
}
```

---

## ⚡ **PHASE 3: PERFORMANCE OPTIMIZATION APIs**

### Query Performance APIs

#### 1. Query Analysis
```typescript
// GET /api/v1/performance/queries/analysis
interface QueryAnalysisRequest {
  tenantId?: string;
  timeRange: TimeRange;
  minExecutions?: number;
  performanceRating?: string[];
  sortBy?: 'execution_time' | 'frequency' | 'impact';
  page?: number;
  pageSize?: number;
}

interface QueryAnalysisResponse {
  queries: QueryAnalysis[];
  summary: QueryPerformanceSummary;
  pagination: PaginationInfo;
}

interface QueryAnalysis {
  queryHash: string;
  queryText: string;
  performanceRating: string;
  statistics: QueryStatistics;
  optimizationSuggestions: OptimizationSuggestion[];
  executionPlan?: ExecutionPlan;
}

interface QueryStatistics {
  totalExecutions: number;
  avgExecutionTime: number;
  minExecutionTime: number;
  maxExecutionTime: number;
  totalTime: number;
  cacheHitRatio: number;
  rowsExamined: number;
  rowsReturned: number;
}

interface OptimizationSuggestion {
  type: 'INDEX' | 'QUERY_REWRITE' | 'CONFIGURATION' | 'SCHEMA';
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  description: string;
  estimatedImprovement: number; // percentage
  implementationEffort: 'LOW' | 'MEDIUM' | 'HIGH';
  sqlSuggestion?: string;
}

// POST /api/v1/performance/queries/analyze
interface QueryAnalyzeRequest {
  queryText: string;
  parameters?: any[];
  explainOptions?: {
    analyze: boolean;
    buffers: boolean;
    timing: boolean;
    format: 'TEXT' | 'JSON' | 'XML';
  };
}

interface QueryAnalyzeResponse {
  executionPlan: ExecutionPlan;
  performance: QueryPerformanceMetrics;
  optimizationSuggestions: OptimizationSuggestion[];
}
```

#### 2. Index Optimization
```typescript
// GET /api/v1/performance/indexes/analysis
interface IndexAnalysisRequest {
  tenantId?: string;
  schemaName?: string;
  tableName?: string;
  recommendation?: 'CREATE' | 'DROP' | 'REBUILD' | 'REINDEX';
  efficiencyThreshold?: number;
}

interface IndexAnalysisResponse {
  indexes: IndexAnalysis[];
  recommendations: IndexRecommendation[];
  summary: IndexOptimizationSummary;
}

interface IndexAnalysis {
  schemaName: string;
  tableName: string;
  indexName: string;
  indexType: string;
  indexSize: number;
  usageStatistics: IndexUsageStats;
  efficiencyScore: number;
  bloatPercentage: number;
  recommendation: string;
  maintenancePriority: string;
}

interface IndexUsageStats {
  scans: number;
  tuplesRead: number;
  tuplesFetched: number;
  lastUsed?: string;
  usageRatio: number;
}

interface IndexRecommendation {
  type: 'CREATE' | 'DROP' | 'REBUILD';
  priority: string;
  tableName: string;
  indexDefinition?: string;
  estimatedBenefit: number;
  estimatedCost: string;
  reasoning: string;
}

// POST /api/v1/performance/indexes/optimize
interface IndexOptimizeRequest {
  recommendations: string[]; // recommendation IDs
  executeImmediately?: boolean;
  scheduleFor?: string; // ISO 8601
  maintenanceWindow?: {
    start: string; // time
    end: string; // time
  };
}
```

#### 3. Connection Pool Optimization
```typescript
// GET /api/v1/performance/connections/analysis
interface ConnectionAnalysisResponse {
  currentStatus: ConnectionPoolStatus;
  utilization: ConnectionUtilization;
  recommendations: ConnectionRecommendation[];
  historicalTrends: ConnectionTrend[];
}

interface ConnectionPoolStatus {
  maxConnections: number;
  currentConnections: number;
  activeConnections: number;
  idleConnections: number;
  waitingConnections: number;
  utilizationPercentage: number;
}

interface ConnectionRecommendation {
  type: 'INCREASE_POOL' | 'DECREASE_POOL' | 'CONFIGURE_POOLER' | 'OPTIMIZE_QUERIES';
  currentValue: number;
  recommendedValue: number;
  reasoning: string;
  estimatedImpact: string;
}

// POST /api/v1/performance/connections/configure
interface ConnectionConfigureRequest {
  maxConnections?: number;
  poolerConfiguration?: {
    poolMode: 'session' | 'transaction' | 'statement';
    maxClientConnections: number;
    defaultPoolSize: number;
    reservePoolSize: number;
  };
}
```

#### 4. Cache Optimization
```typescript
// GET /api/v1/performance/cache/analysis
interface CacheAnalysisResponse {
  cacheTypes: CacheAnalysis[];
  overallEfficiency: number;
  recommendations: CacheRecommendation[];
}

interface CacheAnalysis {
  cacheType: 'SHARED_BUFFERS' | 'QUERY_CACHE' | 'PLAN_CACHE';
  size: number;
  usedSize: number;
  hitRatio: number;
  missRatio: number;
  evictions: number;
  efficiencyScore: number;
  recommendations: string[];
}

interface CacheRecommendation {
  cacheType: string;
  currentSize: number;
  recommendedSize: number;
  reasoning: string;
  estimatedImprovement: number;
}
```

---

## 🔧 **PHASE 3: AUTOMATED MAINTENANCE APIs**

### Maintenance Task Management

#### 1. Task Configuration
```typescript
// GET /api/v1/maintenance/tasks
interface MaintenanceTaskListRequest {
  tenantId?: string;
  taskType?: 'VACUUM' | 'ANALYZE' | 'REINDEX' | 'CLEANUP' | 'BACKUP' | 'OPTIMIZE';
  category?: 'ROUTINE' | 'PERFORMANCE' | 'SECURITY' | 'COMPLIANCE';
  isEnabled?: boolean;
  page?: number;
  pageSize?: number;
}

interface MaintenanceTaskListResponse {
  tasks: MaintenanceTask[];
  pagination: PaginationInfo;
  summary: MaintenanceTaskSummary;
}

interface MaintenanceTask {
  taskId: string;
  taskName: string;
  taskType: string;
  category: string;
  description: string;
  schedule: TaskSchedule;
  isEnabled: boolean;
  priority: number;
  lastExecution?: TaskExecution;
  nextExecution?: string;
  configuration: TaskConfiguration;
}

interface TaskSchedule {
  frequency: 'HOURLY' | 'DAILY' | 'WEEKLY' | 'MONTHLY';
  cronExpression: string;
  maintenanceWindow?: {
    start: string; // time
    end: string; // time
  };
}

interface TaskConfiguration {
  maxExecutionTime: number; // minutes
  retryAttempts: number;
  retryDelay: number; // minutes
  requiresExclusiveLock: boolean;
  resourceLimits: {
    cpuLimitPercent: number;
    memoryLimitMB: number;
    ioLimitMBPS: number;
  };
  notificationSettings: {
    onSuccess: boolean;
    onFailure: boolean;
    recipients: string[];
  };
}

// POST /api/v1/maintenance/tasks
interface CreateMaintenanceTaskRequest {
  taskName: string;
  taskType: string;
  category: string;
  description: string;
  taskSQL?: string;
  taskFunction?: string;
  schedule: TaskSchedule;
  configuration: TaskConfiguration;
  tenantId?: string;
}

// PUT /api/v1/maintenance/tasks/{taskId}
interface UpdateMaintenanceTaskRequest {
  taskName?: string;
  description?: string;
  schedule?: TaskSchedule;
  configuration?: TaskConfiguration;
  isEnabled?: boolean;
}
```

#### 2. Task Execution
```typescript
// POST /api/v1/maintenance/tasks/{taskId}/execute
interface ExecuteTaskRequest {
  triggeredBy?: string;
  overrideSchedule?: boolean;
  dryRun?: boolean;
}

interface ExecuteTaskResponse {
  executionId: string;
  status: 'INITIATED' | 'RUNNING' | 'COMPLETED' | 'FAILED';
  estimatedDuration: number; // seconds
  message: string;
}

// GET /api/v1/maintenance/executions/{executionId}
interface TaskExecutionResponse {
  executionId: string;
  taskId: string;
  taskName: string;
  status: string;
  startTime: string;
  endTime?: string;
  duration?: number;
  progress?: number;
  rowsAffected?: number;
  spaceReclaimed?: number; // bytes
  errorMessage?: string;
  performanceImpact: number; // 0-100 score
  resourceUsage: ResourceUsage;
}

interface ResourceUsage {
  cpuUsagePercent: number;
  memoryUsageMB: number;
  diskIOMB: number;
  peakValues: {
    cpu: number;
    memory: number;
    diskIO: number;
  };
}

// GET /api/v1/maintenance/executions
interface ExecutionHistoryRequest {
  taskId?: string;
  status?: string;
  timeRange?: TimeRange;
  page?: number;
  pageSize?: number;
}
```

#### 3. Automated Optimization
```typescript
// POST /api/v1/maintenance/optimize/database
interface DatabaseOptimizeRequest {
  tenantId?: string;
  optimizationType: 'VACUUM' | 'ANALYZE' | 'REINDEX' | 'ALL';
  dryRun?: boolean;
  maxDuration?: number; // minutes
  maintenanceWindow?: {
    start: string;
    end: string;
  };
}

interface DatabaseOptimizeResponse {
  optimizationId: string;
  status: 'INITIATED' | 'RUNNING' | 'COMPLETED' | 'FAILED';
  optimizations: OptimizationResult[];
  summary: OptimizationSummary;
}

interface OptimizationResult {
  type: string;
  objectsProcessed: number;
  spaceReclaimedMB: number;
  performanceImprovementPercent: number;
  duration: number; // seconds
  status: 'COMPLETED' | 'FAILED' | 'SKIPPED';
  details: string;
}

// POST /api/v1/maintenance/cleanup/data
interface DataCleanupRequest {
  tenantId?: string;
  categories: ('AUDIT' | 'SESSION' | 'MONITORING' | 'BACKUP')[];
  dryRun?: boolean;
  customRetentionPolicies?: Record<string, number>; // category -> days
}

interface DataCleanupResponse {
  cleanupId: string;
  status: string;
  results: CleanupResult[];
  summary: CleanupSummary;
}

interface CleanupResult {
  category: string;
  recordsIdentified: number;
  recordsDeleted: number;
  spaceFreedMB: number;
  retentionPeriodDays: number;
  status: 'COMPLETED' | 'FAILED' | 'SKIPPED';
}
```

#### 4. Maintenance Scheduling
```typescript
// GET /api/v1/maintenance/schedule
interface MaintenanceScheduleResponse {
  upcomingTasks: ScheduledTask[];
  maintenanceWindows: MaintenanceWindow[];
  conflicts: ScheduleConflict[];
}

interface ScheduledTask {
  taskId: string;
  taskName: string;
  scheduledTime: string;
  estimatedDuration: number;
  priority: number;
  resourceRequirements: ResourceRequirements;
  dependencies: string[];
}

interface MaintenanceWindow {
  windowId: string;
  name: string;
  startTime: string; // time
  endTime: string; // time
  daysOfWeek: number[]; // 0-6, Sunday = 0
  isActive: boolean;
  allowedTaskTypes: string[];
}

interface ScheduleConflict {
  conflictType: 'RESOURCE' | 'TIME' | 'DEPENDENCY';
  affectedTasks: string[];
  description: string;
  suggestedResolution: string;
}

// POST /api/v1/maintenance/schedule/optimize
interface ScheduleOptimizeRequest {
  timeHorizon: number; // hours
  optimizationGoal: 'MINIMIZE_IMPACT' | 'MAXIMIZE_EFFICIENCY' | 'BALANCE';
  constraints: SchedulingConstraints;
}

interface SchedulingConstraints {
  maxConcurrentTasks: number;
  maintenanceWindows: string[];
  excludedTimeRanges: TimeRange[];
  resourceLimits: ResourceLimits;
}
```

### Maintenance Dashboard APIs

#### 1. Dashboard Data
```typescript
// GET /api/v1/maintenance/dashboard
interface MaintenanceDashboardResponse {
  summary: MaintenanceSummary;
  recentExecutions: TaskExecution[];
  upcomingTasks: ScheduledTask[];
  systemHealth: MaintenanceHealthStatus;
  trends: MaintenanceTrend[];
}

interface MaintenanceSummary {
  totalTasks: number;
  activeTasks: number;
  successRate: number; // percentage
  avgExecutionTime: number; // seconds
  tasksExecutedToday: number;
  nextMaintenanceWindow: string;
}

interface MaintenanceHealthStatus {
  overallStatus: 'HEALTHY' | 'WARNING' | 'CRITICAL';
  indicators: HealthIndicator[];
  recommendations: string[];
}

interface HealthIndicator {
  category: string;
  status: string;
  value: number;
  threshold: number;
  trend: 'IMPROVING' | 'STABLE' | 'DEGRADING';
}

// GET /api/v1/maintenance/reports
interface MaintenanceReportRequest {
  reportType: 'EXECUTION_SUMMARY' | 'PERFORMANCE_IMPACT' | 'OPTIMIZATION_RESULTS';
  timeRange: TimeRange;
  tenantId?: string;
  format?: 'JSON' | 'CSV' | 'PDF';
}
```

---

## 🔄 **CROSS-CUTTING SYSTEM APIs**

### System Configuration

#### 1. Configuration Management
```typescript
// GET /api/v1/system/configuration
interface SystemConfigurationResponse {
  database: DatabaseConfiguration;
  performance: PerformanceConfiguration;
  maintenance: MaintenanceConfiguration;
  monitoring: MonitoringConfiguration;
  backup: BackupConfiguration;
}

interface DatabaseConfiguration {
  maxConnections: number;
  sharedBuffers: string;
  effectiveCacheSize: string;
  workMem: string;
  maintenanceWorkMem: string;
  walLevel: string;
  maxWalSize: string;
  checkpointCompletionTarget: number;
}

// PUT /api/v1/system/configuration
interface UpdateConfigurationRequest {
  section: 'DATABASE' | 'PERFORMANCE' | 'MAINTENANCE' | 'MONITORING' | 'BACKUP';
  configuration: Record<string, any>;
  applyImmediately?: boolean;
  scheduleRestart?: string; // ISO 8601
}
```

#### 2. System Status
```typescript
// GET /api/v1/system/status
interface SystemStatusResponse {
  overall: 'HEALTHY' | 'WARNING' | 'CRITICAL' | 'MAINTENANCE';
  components: ComponentStatus[];
  version: VersionInfo;
  uptime: number; // seconds
  lastRestart: string;
}

interface ComponentStatus {
  component: string;
  status: string;
  version?: string;
  lastCheck: string;
  details: Record<string, any>;
}

// GET /api/v1/system/capacity
interface CapacityResponse {
  current: CapacityMetrics;
  projected: CapacityProjection[];
  recommendations: CapacityRecommendation[];
}

interface CapacityMetrics {
  cpu: ResourceCapacity;
  memory: ResourceCapacity;
  disk: ResourceCapacity;
  connections: ResourceCapacity;
}

interface ResourceCapacity {
  used: number;
  total: number;
  utilizationPercent: number;
  trend: 'INCREASING' | 'STABLE' | 'DECREASING';
}
```

### Audit and Compliance

#### 1. Audit Trail APIs
```typescript
// GET /api/v1/system/audit
interface AuditTrailRequest {
  tenantId?: string;
  userId?: string;
  action?: string;
  resource?: string;
  timeRange: TimeRange;
  page?: number;
  pageSize?: number;
}

interface AuditTrailResponse {
  events: AuditEvent[];
  pagination: PaginationInfo;
  summary: AuditSummary;
}

interface AuditEvent {
  eventId: string;
  timestamp: string;
  userId: string;
  tenantId: string;
  action: string;
  resource: string;
  details: Record<string, any>;
  ipAddress: string;
  userAgent: string;
  result: 'SUCCESS' | 'FAILURE' | 'PARTIAL';
}
```

#### 2. Compliance Reporting
```typescript
// GET /api/v1/system/compliance/report
interface ComplianceReportRequest {
  framework: 'HIPAA' | 'GDPR' | 'SOX' | 'PCI_DSS' | 'SOC2';
  timeRange: TimeRange;
  tenantId?: string;
  includeEvidence?: boolean;
}

interface ComplianceReportResponse {
  framework: string;
  overallScore: number; // 0-100
  requirements: ComplianceRequirement[];
  findings: ComplianceFinding[];
  recommendations: string[];
  evidencePackage?: string; // URL to download
}

interface ComplianceRequirement {
  requirementId: string;
  description: string;
  status: 'COMPLIANT' | 'NON_COMPLIANT' | 'PARTIAL' | 'NOT_APPLICABLE';
  score: number;
  evidence: string[];
  lastAssessed: string;
}
```

---

## 📊 **PHASE 5: CAPACITY PLANNING & GROWTH MANAGEMENT APIs**

### Capacity Planning Endpoints

#### Resource Utilization Management
```typescript
// Capture current resource utilization
// POST /api/v1/capacity/utilization/capture
interface CaptureUtilizationRequest {
  tenantId?: string;
  resourceTypes?: string[];
}

interface CaptureUtilizationResponse {
  success: boolean;
  data: ResourceUtilization[];
}

interface ResourceUtilization {
  resourceType: string;
  currentUsage: number;
  capacity: number;
  utilizationPercentage: number;
  status: 'NORMAL' | 'WARNING' | 'CRITICAL';
}

// Get resource utilization history
// GET /api/v1/capacity/utilization/history
interface UtilizationHistoryRequest {
  tenantId?: string;
  resourceType?: string;
  startDate?: string;
  endDate?: string;
  aggregation?: 'HOURLY' | 'DAILY' | 'WEEKLY';
}

interface UtilizationHistoryResponse {
  data: UtilizationDataPoint[];
}

interface UtilizationDataPoint {
  timestamp: string;
  resourceType: string;
  usage: number;
  capacity: number;
  utilizationPercentage: number;
}

// Get current capacity status
// GET /api/v1/capacity/status
interface CapacityStatusResponse {
  data: CapacityStatus[];
}

interface CapacityStatus {
  tenantId: string;
  resourceType: string;
  currentUsage: number;
  totalCapacity: number;
  utilizationPercentage: number;
  status: string;
  lastMeasurement: string;
}
```

#### Growth Pattern Analysis
```typescript
// Analyze growth patterns
// POST /api/v1/capacity/growth/analyze
interface AnalyzeGrowthRequest {
  tenantId?: string;
  resourceType?: string;
  analysisDays: number;
}

interface AnalyzeGrowthResponse {
  data: GrowthPattern[];
}

interface GrowthPattern {
  resourceType: string;
  patternType: 'LINEAR' | 'EXPONENTIAL' | 'SEASONAL' | 'STABLE';
  growthRatePercentage: number;
  confidenceLevel: number;
  forecast7d: number;
  forecast30d: number;
  forecast90d: number;
  timeToCapacityDays: number;
  recommendedAction: string;
}

// Get growth forecasts
// GET /api/v1/capacity/forecasts
interface ForecastsRequest {
  tenantId?: string;
  resourceType?: string;
  forecastHorizon?: '7d' | '30d' | '90d' | '1y';
}

interface ForecastsResponse {
  data: CapacityForecast[];
}

interface CapacityForecast {
  resourceType: string;
  currentUsage: number;
  projectedUsage: number;
  growthRate: number;
  confidenceLevel: number;
  timeToCapacity: number;
  recommendedActions: string[];
}

// Get growth forecast summary
// GET /api/v1/capacity/forecasts/summary
interface ForecastSummaryResponse {
  data: ForecastSummary[];
}

interface ForecastSummary {
  tenantId: string;
  resourceType: string;
  currentUsage: number;
  projected30d: number;
  projected90d: number;
  dailyGrowthRate: number;
  daysToCapacity: number;
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT';
}
```

#### Capacity Threshold Management
```typescript
// Create capacity threshold
// POST /api/v1/capacity/thresholds
interface CreateThresholdRequest {
  tenantId: string;
  thresholdName: string;
  resourceType: string;
  thresholdPercentage: number;
  thresholdType: 'WARNING' | 'CRITICAL' | 'MAXIMUM';
  alertEnabled: boolean;
  notificationChannels: string[];
}

interface CreateThresholdResponse {
  success: boolean;
  data: { thresholdId: string };
}

// Update capacity threshold
// PUT /api/v1/capacity/thresholds/{thresholdId}
interface UpdateThresholdRequest {
  thresholdPercentage?: number;
  alertEnabled?: boolean;
  notificationChannels?: string[];
  escalationEnabled?: boolean;
}

// Get capacity thresholds
// GET /api/v1/capacity/thresholds
interface ThresholdsRequest {
  tenantId?: string;
  resourceType?: string;
  thresholdType?: string;
  isActive?: boolean;
}

interface ThresholdsResponse {
  data: CapacityThreshold[];
}

interface CapacityThreshold {
  thresholdId: string;
  thresholdName: string;
  resourceType: string;
  thresholdPercentage: number;
  thresholdType: string;
  alertEnabled: boolean;
  lastTriggered: string;
  triggerCount24h: number;
  effectiveness: number;
}

// Evaluate capacity thresholds
// POST /api/v1/capacity/thresholds/evaluate
interface EvaluateThresholdsRequest {
  tenantId?: string;
}

interface EvaluateThresholdsResponse {
  data: ThresholdEvaluation[];
}

interface ThresholdEvaluation {
  thresholdName: string;
  resourceType: string;
  currentUtilization: number;
  thresholdPercentage: number;
  thresholdExceeded: boolean;
  alertSeverity: string;
  recommendedAction: string;
}

// Get capacity alerts
// GET /api/v1/capacity/alerts
interface CapacityAlertsRequest {
  tenantId?: string;
  severity?: string;
  status?: string;
  startDate?: string;
  endDate?: string;
}

interface CapacityAlertsResponse {
  data: CapacityAlert[];
}

interface CapacityAlert {
  alertId: string;
  thresholdName: string;
  resourceType: string;
  severity: string;
  currentUtilization: number;
  thresholdPercentage: number;
  triggeredAt: string;
  status: 'ACTIVE' | 'RESOLVED' | 'SUPPRESSED';
  resolutionTime: number;
}
```

#### Capacity Planning Operations
```typescript
// Run comprehensive capacity analysis
// POST /api/v1/capacity/analysis/run
interface RunAnalysisRequest {
  tenantId?: string;
  createDefaultThresholds: boolean;
}

interface RunAnalysisResponse {
  success: boolean;
  data: AnalysisResult;
}

interface AnalysisResult {
  analysisId: string;
  resourcesAnalyzed: number;
  patternsDetected: number;
  forecastsGenerated: number;
  thresholdsCreated: number;
  alertsTriggered: number;
}

// Get capacity planning dashboard
// GET /api/v1/capacity/dashboard
interface CapacityDashboardRequest {
  tenantId?: string;
}

interface CapacityDashboardResponse {
  data: CapacityDashboard;
}

interface CapacityDashboard {
  summary: {
    totalResources: number;
    resourcesAtCapacity: number;
    resourcesNearCapacity: number;
    averageUtilization: number;
    growthRate: number;
  };
  resourceStatus: {
    resourceType: string;
    utilization: number;
    status: string;
    daysToCapacity: number;
  }[];
  recentAlerts: {
    alertId: string;
    severity: string;
    message: string;
    timestamp: string;
  }[];
  growthTrends: {
    resourceType: string;
    trend: 'INCREASING' | 'STABLE' | 'DECREASING';
    growthRate: number;
    confidence: number;
  }[];
}

// Export capacity planning report
// GET /api/v1/capacity/reports/export
interface ExportReportRequest {
  tenantId?: string;
  reportType: 'UTILIZATION' | 'FORECASTS' | 'THRESHOLDS' | 'COMPREHENSIVE';
  format: 'JSON' | 'CSV' | 'PDF';
  startDate?: string;
  endDate?: string;
}
```

### Implementation Details

#### Database Integration
```typescript
// Capacity planning service implementation
export class CapacityPlanningService {
  async captureResourceUtilization(tenantId?: string): Promise<ResourceUtilization[]> {
    const result = await this.db.query(
      'SELECT * FROM capacity_planning.capture_resource_utilization($1)',
      [tenantId ? Buffer.from(tenantId, 'hex') : null]
    );
    return result.rows.map(this.mapResourceUtilization);
  }

  async analyzeGrowthPatterns(
    tenantId?: string,
    resourceType?: string,
    analysisDays: number = 30
  ): Promise<GrowthPattern[]> {
    const result = await this.db.query(
      'SELECT * FROM capacity_planning.analyze_growth_patterns($1, $2, $3)',
      [
        tenantId ? Buffer.from(tenantId, 'hex') : null,
        resourceType,
        analysisDays
      ]
    );
    return result.rows.map(this.mapGrowthPattern);
  }

  async createCapacityThreshold(threshold: CreateThresholdRequest): Promise<string> {
    const result = await this.db.query(
      'SELECT capacity_planning.create_capacity_threshold($1, $2, $3, $4, $5, $6)',
      [
        Buffer.from(threshold.tenantId, 'hex'),
        threshold.thresholdName,
        threshold.resourceType,
        threshold.thresholdPercentage,
        threshold.thresholdType,
        threshold.alertEnabled
      ]
    );
    return result.rows[0].create_capacity_threshold.toString('hex');
  }

  async evaluateThresholds(tenantId?: string): Promise<ThresholdEvaluation[]> {
    const result = await this.db.query(
      'SELECT * FROM capacity_planning.evaluate_capacity_thresholds($1)',
      [tenantId ? Buffer.from(tenantId, 'hex') : null]
    );
    return result.rows.map(this.mapThresholdEvaluation);
  }

  async runCapacityAnalysis(
    tenantId?: string,
    createDefaultThresholds: boolean = true
  ): Promise<AnalysisResult> {
    await this.db.query(
      'CALL capacity_planning.run_capacity_analysis($1, $2)',
      [
        tenantId ? Buffer.from(tenantId, 'hex') : null,
        createDefaultThresholds
      ]
    );
    
    return {
      analysisId: uuidv4(),
      resourcesAnalyzed: await this.getResourceCount(tenantId),
      patternsDetected: await this.getPatternCount(tenantId),
      forecastsGenerated: await this.getForecastCount(tenantId),
      thresholdsCreated: createDefaultThresholds ? 8 : 0,
      alertsTriggered: await this.getActiveAlertCount(tenantId)
    };
  }

  private mapResourceUtilization(row: any): ResourceUtilization {
    return {
      resourceType: row.resource_type,
      currentUsage: parseFloat(row.current_usage),
      capacity: parseFloat(row.capacity),
      utilizationPercentage: parseFloat(row.utilization_percentage),
      status: row.status
    };
  }

  private mapGrowthPattern(row: any): GrowthPattern {
    return {
      resourceType: row.resource_type,
      patternType: row.pattern_type,
      growthRatePercentage: parseFloat(row.growth_rate_percentage),
      confidenceLevel: parseFloat(row.confidence_level),
      forecast7d: parseFloat(row.forecast_7d),
      forecast30d: parseFloat(row.forecast_30d),
      forecast90d: parseFloat(row.forecast_90d),
      timeToCapacityDays: row.time_to_capacity_days,
      recommendedAction: row.recommended_action
    };
  }

  private mapThresholdEvaluation(row: any): ThresholdEvaluation {
    return {
      thresholdName: row.threshold_name,
      resourceType: row.resource_type,
      currentUtilization: parseFloat(row.current_utilization),
      thresholdPercentage: parseFloat(row.threshold_percentage),
      thresholdExceeded: row.threshold_exceeded,
      alertSeverity: row.alert_severity,
      recommendedAction: row.recommended_action
    };
  }
}
```

#### Real-time Monitoring Integration
```typescript
// WebSocket events for real-time capacity monitoring
export const CapacityEvents = {
  THRESHOLD_EXCEEDED: 'capacity:threshold_exceeded',
  FORECAST_UPDATED: 'capacity:forecast_updated',
  UTILIZATION_SPIKE: 'capacity:utilization_spike',
  CAPACITY_WARNING: 'capacity:capacity_warning'
};

// Real-time capacity monitoring
export class CapacityMonitoringService {
  private wsServer: WebSocketServer;
  private capacityService: CapacityPlanningService;

  async startMonitoring(): Promise<void> {
    // Monitor threshold evaluations every 5 minutes
    setInterval(async () => {
      const evaluations = await this.capacityService.evaluateThresholds();
      
      for (const evaluation of evaluations) {
        if (evaluation.thresholdExceeded) {
          this.wsServer.emit(CapacityEvents.THRESHOLD_EXCEEDED, {
            tenantId: evaluation.tenantId,
            resourceType: evaluation.resourceType,
            currentUtilization: evaluation.currentUtilization,
            threshold: evaluation.thresholdPercentage,
            severity: evaluation.alertSeverity,
            timestamp: new Date().toISOString()
          });
        }
      }
    }, 5 * 60 * 1000); // 5 minutes

    // Update forecasts daily
    setInterval(async () => {
      await this.capacityService.runCapacityAnalysis(null, false);
      this.wsServer.emit(CapacityEvents.FORECAST_UPDATED, {
        timestamp: new Date().toISOString()
      });
    }, 24 * 60 * 60 * 1000); // 24 hours
  }

  async handleUtilizationSpike(
    tenantId: string,
    resourceType: string,
    currentUtilization: number
  ): Promise<void> {
    // Trigger immediate analysis for spike detection
    const patterns = await this.capacityService.analyzeGrowthPatterns(
      tenantId,
      resourceType,
      7 // Last 7 days for spike analysis
    );

    const pattern = patterns.find(p => p.resourceType === resourceType);
    if (pattern && pattern.growthRatePercentage > 5.0) {
      this.wsServer.emit(CapacityEvents.UTILIZATION_SPIKE, {
        tenantId,
        resourceType,
        currentUtilization,
        growthRate: pattern.growthRatePercentage,
        timeToCapacity: pattern.timeToCapacityDays,
        timestamp: new Date().toISOString()
      });
    }
  }
}
```

#### Controller Implementation
```typescript
// Capacity planning controller
@Controller('/api/v1/capacity')
@UseGuards(JwtAuthGuard, RoleGuard)
export class CapacityPlanningController {
  constructor(
    private readonly capacityService: CapacityPlanningService,
    private readonly monitoringService: CapacityMonitoringService
  ) {}

  @Post('/utilization/capture')
  @Roles('admin', 'operator')
  async captureUtilization(
    @Body() request: CaptureUtilizationRequest
  ): Promise<CaptureUtilizationResponse> {
    const data = await this.capacityService.captureResourceUtilization(
      request.tenantId
    );
    return { success: true, data };
  }

  @Get('/utilization/history')
  @Roles('admin', 'operator', 'viewer')
  async getUtilizationHistory(
    @Query() request: UtilizationHistoryRequest
  ): Promise<UtilizationHistoryResponse> {
    const data = await this.capacityService.getUtilizationHistory(request);
    return { data };
  }

  @Post('/growth/analyze')
  @Roles('admin', 'operator')
  async analyzeGrowthPatterns(
    @Body() request: AnalyzeGrowthRequest
  ): Promise<AnalyzeGrowthResponse> {
    const data = await this.capacityService.analyzeGrowthPatterns(
      request.tenantId,
      request.resourceType,
      request.analysisDays
    );
    return { data };
  }

  @Get('/forecasts')
  @Roles('admin', 'operator', 'viewer')
  async getForecasts(
    @Query() request: ForecastsRequest
  ): Promise<ForecastsResponse> {
    const data = await this.capacityService.getForecasts(request);
    return { data };
  }

  @Post('/thresholds')
  @Roles('admin', 'operator')
  async createThreshold(
    @Body() request: CreateThresholdRequest
  ): Promise<CreateThresholdResponse> {
    const thresholdId = await this.capacityService.createCapacityThreshold(request);
    return { success: true, data: { thresholdId } };
  }

  @Post('/thresholds/evaluate')
  @Roles('admin', 'operator')
  async evaluateThresholds(
    @Body() request: EvaluateThresholdsRequest
  ): Promise<EvaluateThresholdsResponse> {
    const data = await this.capacityService.evaluateThresholds(request.tenantId);
    return { data };
  }

  @Post('/analysis/run')
  @Roles('admin', 'operator')
  async runAnalysis(
    @Body() request: RunAnalysisRequest
  ): Promise<RunAnalysisResponse> {
    const data = await this.capacityService.runCapacityAnalysis(
      request.tenantId,
      request.createDefaultThresholds
    );
    return { success: true, data };
  }

  @Get('/dashboard')
  @Roles('admin', 'operator', 'viewer')
  async getDashboard(
    @Query() request: CapacityDashboardRequest
  ): Promise<CapacityDashboardResponse> {
    const data = await this.capacityService.getCapacityDashboard(request.tenantId);
    return { data };
  }

  @Get('/reports/export')
  @Roles('admin', 'operator')
  async exportReport(
    @Query() request: ExportReportRequest,
    @Res() response: Response
  ): Promise<void> {
    const reportData = await this.capacityService.generateReport(request);
    
    if (request.format === 'JSON') {
      response.json(reportData);
    } else if (request.format === 'CSV') {
      response.setHeader('Content-Type', 'text/csv');
      response.setHeader('Content-Disposition', 'attachment; filename=capacity-report.csv');
      response.send(this.convertToCSV(reportData));
    } else if (request.format === 'PDF') {
      const pdfBuffer = await this.generatePDF(reportData);
      response.setHeader('Content-Type', 'application/pdf');
      response.setHeader('Content-Disposition', 'attachment; filename=capacity-report.pdf');
      response.send(pdfBuffer);
    }
  }
}
```

---

## 🔒 **PHASE 6: SECURITY HARDENING & COMPLIANCE AUTOMATION APIs**

### Security Management APIs

#### GET /api/v1/security/threats/active
```typescript
{
  "summary": "Get active security threats",
  "parameters": [
    {"name": "severity", "in": "query", "enum": ["LOW", "MEDIUM", "HIGH", "CRITICAL"]},
    {"name": "threat_type", "in": "query", "enum": ["BRUTE_FORCE", "SQL_INJECTION", "XSS", "PRIVILEGE_ESCALATION"]},
    {"name": "time_range", "in": "query", "enum": ["1h", "24h", "7d"]},
    {"name": "tenant_id", "in": "query", "required": false}
  ],
  "responses": {
    "200": {
      "threats": [
        {
          "threat_id": "uuid",
          "threat_type": "BRUTE_FORCE",
          "severity": "HIGH",
          "source_ip": "192.168.1.100",
          "target_resource": "/api/auth/login",
          "detection_timestamp": "2024-01-15T09:45:00Z",
          "confidence_score": 85.5,
          "status": "INVESTIGATING",
          "mitigation_actions": [
            "IP blocked temporarily",
            "User account locked"
          ],
          "indicators": {
            "failed_attempts": 15,
            "time_window_minutes": 5,
            "user_agents": ["suspicious-bot/1.0"]
          }
        }
      ],
      "total_count": 3,
      "summary": {
        "critical_threats": 0,
        "high_threats": 1,
        "medium_threats": 2,
        "low_threats": 0
      }
    }
  }
}
```

#### POST /api/v1/security/threats/investigate
```typescript
{
  "summary": "Update threat investigation status",
  "requestBody": {
    "threat_id": "uuid",
    "investigation_status": "INVESTIGATING|RESOLVED|FALSE_POSITIVE",
    "assigned_to": "security_analyst_id",
    "investigation_notes": "Confirmed brute force attack from compromised bot network",
    "mitigation_actions": [
      "Permanent IP ban implemented",
      "Enhanced monitoring activated"
    ]
  },
  "responses": {
    "200": {
      "threat_id": "uuid",
      "status": "INVESTIGATING",
      "updated_at": "2024-01-15T10:00:00Z",
      "assigned_to": "security_analyst_id"
    }
  }
}
```

#### GET /api/v1/security/vulnerabilities
```typescript
{
  "summary": "Get security vulnerabilities",
  "parameters": [
    {"name": "severity", "in": "query", "enum": ["LOW", "MEDIUM", "HIGH", "CRITICAL"]},
    {"name": "status", "in": "query", "enum": ["OPEN", "IN_PROGRESS", "PATCHED", "MITIGATED"]},
    {"name": "component", "in": "query", "required": false}
  ],
  "responses": {
    "200": {
      "vulnerabilities": [
        {
          "vulnerability_id": "uuid",
          "cve_id": "CVE-2024-0001",
          "vulnerability_name": "PostgreSQL Authentication Bypass",
          "severity": "CRITICAL",
          "cvss_score": 9.8,
          "affected_component": "PostgreSQL 13.2",
          "discovery_date": "2024-01-10T00:00:00Z",
          "patch_available": true,
          "patch_version": "PostgreSQL 13.14",
          "remediation_status": "IN_PROGRESS",
          "remediation_deadline": "2024-01-20T00:00:00Z",
          "business_impact": "High - affects authentication system",
          "compensating_controls": [
            "Additional firewall rules",
            "Enhanced monitoring"
          ]
        }
      ],
      "summary": {
        "total_vulnerabilities": 12,
        "critical": 1,
        "high": 3,
        "medium": 6,
        "low": 2,
        "overdue_remediations": 0
      }
    }
  }
}
```

### Security Incident APIs

#### POST /api/v1/security/incidents/create
```typescript
{
  "summary": "Create security incident",
  "requestBody": {
    "incident_type": "DATA_BREACH|UNAUTHORIZED_ACCESS|MALWARE|DDOS",
    "severity": "LOW|MEDIUM|HIGH|CRITICAL",
    "description": "Unauthorized access attempt detected",
    "affected_systems": ["auth-service", "database"],
    "affected_users": 0,
    "affected_records": 0,
    "data_types_affected": [],
    "detection_method": "Automated threat detection",
    "incident_commander": "security_lead_id"
  },
  "responses": {
    "201": {
      "incident_id": "uuid",
      "incident_number": "SEC-2024-001",
      "status": "OPEN",
      "created_at": "2024-01-15T10:00:00Z",
      "incident_commander": "security_lead_id"
    }
  }
}
```

#### PUT /api/v1/security/incidents/{incident_id}/status
```typescript
{
  "summary": "Update security incident status",
  "requestBody": {
    "status": "INVESTIGATING|CONTAINED|ERADICATED|RECOVERED|CLOSED",
    "status_notes": "Threat contained, investigating scope",
    "updated_by": "security_analyst_id",
    "containment_actions": [
      "Isolated affected systems",
      "Reset compromised credentials"
    ]
  },
  "responses": {
    "200": {
      "incident_id": "uuid",
      "status": "CONTAINED",
      "updated_at": "2024-01-15T10:30:00Z",
      "timeline": [
        {
          "timestamp": "2024-01-15T10:00:00Z",
          "status": "OPEN",
          "action": "Incident created"
        },
        {
          "timestamp": "2024-01-15T10:30:00Z",
          "status": "CONTAINED",
          "action": "Threat contained"
        }
      ]
    }
  }
}
```

### Compliance Management APIs

#### GET /api/v1/compliance/frameworks
```typescript
{
  "summary": "Get compliance frameworks status",
  "parameters": [
    {"name": "framework", "in": "query", "enum": ["HIPAA", "GDPR", "SOX", "PCI_DSS", "SOC2"]},
    {"name": "tenant_id", "in": "query", "required": false}
  ],
  "responses": {
    "200": {
      "frameworks": [
        {
          "framework_name": "HIPAA",
          "compliance_score": 94.5,
          "status": "COMPLIANT",
          "last_assessment": "2024-01-10T00:00:00Z",
          "next_assessment_due": "2024-04-10T00:00:00Z",
          "total_controls": 45,
          "compliant_controls": 42,
          "non_compliant_controls": 2,
          "controls_with_warnings": 1,
          "critical_findings": 0,
          "high_risk_findings": 2,
          "certification_status": "CERTIFIED",
          "certification_expiry": "2024-12-31T00:00:00Z"
        }
      ],
      "overall_compliance_score": 92.3
    }
  }
}
```

#### POST /api/v1/compliance/assessments/run
```typescript
{
  "summary": "Run compliance assessment",
  "requestBody": {
    "framework": "HIPAA|GDPR|SOX|PCI_DSS|SOC2",
    "assessment_type": "FULL|PARTIAL|TARGETED",
    "tenant_id": "string",
    "specific_controls": ["164.312(a)(1)", "164.308(a)(1)"]
  },
  "responses": {
    "202": {
      "assessment_id": "uuid",
      "framework": "HIPAA",
      "status": "INITIATED",
      "estimated_completion": "2024-01-15T11:00:00Z",
      "controls_to_assess": 45
    }
  }
}
```

#### GET /api/v1/compliance/assessments/{assessment_id}
```typescript
{
  "summary": "Get compliance assessment results",
  "responses": {
    "200": {
      "assessment_id": "uuid",
      "framework": "HIPAA",
      "status": "COMPLETED",
      "completion_timestamp": "2024-01-15T10:45:00Z",
      "overall_score": 94.5,
      "results": [
        {
          "control_reference": "164.312(a)(1)",
          "control_name": "Access Control",
          "assessment_result": "COMPLIANT",
          "score": 100.0,
          "findings": [],
          "evidence": "All users have unique identifiers and access controls are properly configured"
        },
        {
          "control_reference": "164.308(a)(1)",
          "control_name": "Security Officer",
          "assessment_result": "NON_COMPLIANT",
          "score": 75.0,
          "findings": [
            "Security officer role not formally documented",
            "Security responsibilities not clearly defined"
          ],
          "remediation_required": true,
          "remediation_priority": "HIGH",
          "remediation_deadline": "2024-02-15T00:00:00Z"
        }
      ],
      "summary": {
        "total_controls": 45,
        "compliant": 42,
        "non_compliant": 2,
        "warnings": 1,
        "critical_findings": 0,
        "high_risk_findings": 2
      }
    }
  }
}
```

#### GET /api/v1/compliance/reports
```typescript
{
  "summary": "Get compliance reports",
  "parameters": [
    {"name": "framework", "in": "query", "enum": ["HIPAA", "GDPR", "SOX", "PCI_DSS", "SOC2"]},
    {"name": "report_type", "in": "query", "enum": ["PERIODIC", "AD_HOC", "INCIDENT", "AUDIT"]},
    {"name": "date_from", "in": "query", "required": false},
    {"name": "date_to", "in": "query", "required": false}
  ],
  "responses": {
    "200": {
      "reports": [
        {
          "report_id": "uuid",
          "report_name": "HIPAA Monthly Compliance Report",
          "framework": "HIPAA",
          "report_type": "PERIODIC",
          "reporting_period": "2024-01-01 to 2024-01-31",
          "generation_timestamp": "2024-02-01T00:00:00Z",
          "overall_compliance_score": 94.5,
          "status": "PUBLISHED",
          "file_location": "/reports/hipaa-2024-01.pdf",
          "executive_summary": "Overall compliance remains strong with minor improvements needed in documentation",
          "next_report_due": "2024-03-01T00:00:00Z"
        }
      ],
      "total_count": 12
    }
  }
}
```

### Remediation Workflow APIs

#### GET /api/v1/compliance/remediation/tasks
```typescript
{
  "summary": "Get remediation tasks",
  "parameters": [
    {"name": "status", "in": "query", "enum": ["OPEN", "IN_PROGRESS", "COMPLETED", "CANCELLED"]},
    {"name": "priority", "in": "query", "enum": ["LOW", "MEDIUM", "HIGH", "URGENT"]},
    {"name": "assigned_to", "in": "query", "required": false},
    {"name": "due_date_from", "in": "query", "required": false},
    {"name": "due_date_to", "in": "query", "required": false}
  ],
  "responses": {
    "200": {
      "tasks": [
        {
          "task_id": "uuid",
          "title": "Update Security Officer Documentation",
          "description": "Formally document security officer role and responsibilities",
          "compliance_framework": "HIPAA",
          "control_reference": "164.308(a)(1)",
          "priority": "HIGH",
          "status": "OPEN",
          "assigned_to": "compliance_manager_id",
          "due_date": "2024-02-15T00:00:00Z",
          "estimated_effort_hours": 8,
          "task_type": "DOCUMENTATION",
          "dependencies": [],
          "verification_criteria": [
            "Security officer role documented in policy",
            "Responsibilities clearly defined",
            "Management approval obtained"
          ]
        }
      ],
      "summary": {
        "total_tasks": 15,
        "open": 8,
        "in_progress": 5,
        "overdue": 2,
        "completed_this_month": 12
      }
    }
  }
}
```

#### PUT /api/v1/compliance/remediation/tasks/{task_id}
```typescript
{
  "summary": "Update remediation task",
  "requestBody": {
    "status": "IN_PROGRESS|COMPLETED|ON_HOLD",
    "progress_notes": "Security officer documentation updated and under review",
    "actual_effort_hours": 6,
    "completion_evidence": "Updated policy document attached",
    "verification_status": "PENDING|VERIFIED|REJECTED",
    "updated_by": "compliance_manager_id"
  },
  "responses": {
    "200": {
      "task_id": "uuid",
      "status": "IN_PROGRESS",
      "updated_at": "2024-01-15T10:00:00Z",
      "progress_percentage": 75,
      "next_milestone": "Management review scheduled"
    }
  }
}
```

---

## 🔐 **AUTHENTICATION & AUTHORIZATION**

### JWT Token Structure
```json
{
  "sub": "user_id",
  "tenant_id": "tenant_uuid",
  "roles": ["admin", "security_analyst"],
  "permissions": [
    "backup:create",
    "monitoring:read",
    "security:investigate",
    "compliance:assess"
  ],
  "iat": 1642248000,
  "exp": 1642251600
}
```

### Role-Based Access Control (RBAC)

#### System Administrator
- Full access to all APIs
- Backup and recovery management
- System monitoring and configuration
- Security policy management

#### Security Analyst
- Security threat investigation
- Incident response management
- Vulnerability assessment
- Security audit access

#### Compliance Officer
- Compliance assessment and reporting
- Remediation task management
- Framework configuration
- Audit trail access

#### Tenant Administrator
- Tenant-scoped access to all APIs
- User management within tenant
- Tenant-specific monitoring
- Backup management for tenant data

#### Regular User
- Read-only access to personal data
- Basic monitoring dashboard
- Limited audit trail access

---

## 📊 **API MONITORING & ANALYTICS**

### API Metrics Collection
```json
{
  "api_endpoint": "/api/v1/security/threats/active",
  "method": "GET",
  "response_time_ms": 150,
  "status_code": 200,
  "tenant_id": "tenant_uuid",
  "user_id": "user_uuid",
  "timestamp": "2024-01-15T10:00:00Z",
  "request_size_bytes": 1024,
  "response_size_bytes": 4096,
  "database_queries": 3,
  "database_time_ms": 85
}
```

### Rate Limiting
- **Standard Users**: 1000 requests/hour
- **Premium Users**: 5000 requests/hour
- **System APIs**: 10000 requests/hour
- **Burst Limit**: 100 requests/minute

### API Health Endpoints
```json
{
  "GET /api/health": "Basic health check",
  "GET /api/health/detailed": "Detailed system health",
  "GET /api/metrics": "Prometheus metrics endpoint",
  "GET /api/version": "API version information"
}
```

---

## 🚀 **DEPLOYMENT CONSIDERATIONS**

### Environment Configuration
- **Development**: Full API access, debug logging
- **Staging**: Production-like with test data
- **Production**: Restricted access, audit logging

### API Versioning Strategy
- **URL Versioning**: `/api/v1/`, `/api/v2/`
- **Backward Compatibility**: Maintain v1 for 12 months
- **Deprecation Notices**: 6-month advance notice

### Documentation & Testing
- **OpenAPI/Swagger**: Auto-generated documentation
- **Postman Collections**: API testing collections
- **Integration Tests**: Automated API testing
- **Load Testing**: Performance validation

---

## 📈 **SUCCESS METRICS**

### API Performance Metrics
- **Response Time**: < 200ms average
- **Availability**: > 99.9% uptime
- **Error Rate**: < 0.1% of requests
- **Throughput**: 10,000+ requests/minute

### Security Metrics
- **Authentication Success**: > 99.5%
- **Authorization Accuracy**: 100%
- **Threat Detection**: < 5 minutes MTTD
- **Incident Response**: < 15 minutes MTTR

### Compliance Metrics
- **Assessment Automation**: 100% automated
- **Report Generation**: < 5 minutes
- **Remediation Tracking**: 100% tracked
- **Audit Trail**: 100% API calls logged

This comprehensive backend development plan provides enterprise-grade APIs for all production-ready infrastructure components, ensuring secure, scalable, and compliant operations for the One Vault Multi-Tenant Data Vault 2.0 Platform. 