# AI Implementation Prompt for Collective Intelligence Agent System

## 🎯 **Task Overview**

You are tasked with implementing a sophisticated AI agent system for a multi-tenant horse farm management platform. This system combines individual farm intelligence with collective industry intelligence while maintaining strict tenant isolation and privacy.

## 🏗️ **System Architecture Requirements**

### **Database Foundation (Already Exists)**
- PostgreSQL with Data Vault 2.0 methodology
- Complete tenant isolation with `tenant_hk` in all tables
- Existing agent orchestration functions in `api.agent_request()`
- Learning system with `business.ai_learn_from_data()`

### **Three-Layer Intelligence System to Implement**

1. **Farm-Specific Intelligence** (Tenant Isolated)
   - Individual farm's horse data, treatments, outcomes
   - Private patterns and success rates
   - Confidential farm management insights

2. **Collective Intelligence** (Anonymized Cross-Tenant)
   - Statistical patterns from thousands of horses across all farms
   - Industry-wide treatment success rates
   - Anonymized best practices and seasonal trends

3. **AI Enhancement Layer** (GPT-4 + Combined Context)
   - Combines farm-specific + collective intelligence
   - Provides recommendations with statistical backing
   - Continuous learning from both intelligence layers

## 🗄️ **Database Implementation Requirements**

### **Create Collective Intelligence Schema**

Implement the following database structure:

```sql
-- Create collective intelligence schema and tables
CREATE SCHEMA collective_intelligence;

-- Anonymized health patterns table (cross-tenant)
CREATE TABLE collective_intelligence.health_pattern_h (
    pattern_hk BYTEA PRIMARY KEY,
    pattern_bk VARCHAR(255) NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

CREATE TABLE collective_intelligence.health_pattern_s (
    pattern_hk BYTEA NOT NULL REFERENCES collective_intelligence.health_pattern_h(pattern_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    symptom_pattern JSONB NOT NULL,           -- Anonymized symptoms
    treatment_pattern JSONB NOT NULL,         -- Anonymized treatments  
    outcome_pattern JSONB NOT NULL,           -- Success/failure rates
    frequency_count INTEGER NOT NULL,         -- How often this pattern occurs
    success_rate DECIMAL(5,2) NOT NULL,       -- Overall success rate
    confidence_score DECIMAL(5,2) NOT NULL,   -- Statistical confidence
    geographic_region VARCHAR(50),            -- Optional: climate/region data
    seasonal_pattern VARCHAR(20),             -- Spring, Summer, Fall, Winter
    horse_demographics JSONB,                 -- Age ranges, breeds (anonymized)
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (pattern_hk, load_date)
);

-- Industry insights table (cross-tenant statistical insights)
CREATE TABLE collective_intelligence.industry_insight_h (
    insight_hk BYTEA PRIMARY KEY,
    insight_bk VARCHAR(255) NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

CREATE TABLE collective_intelligence.industry_insight_s (
    insight_hk BYTEA NOT NULL REFERENCES collective_intelligence.industry_insight_h(insight_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    insight_type VARCHAR(100) NOT NULL,       -- TREATMENT_EFFICACY, SEASONAL_TREND, etc.
    insight_category VARCHAR(50) NOT NULL,    -- HEALTH, NUTRITION, EXERCISE
    insight_data JSONB NOT NULL,              -- Statistical insights
    supporting_data_points INTEGER NOT NULL,  -- How many records support this
    statistical_significance DECIMAL(5,2),    -- P-value or confidence interval
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (insight_hk, load_date)
);
```

### **Enhanced Agent Functions**

Create these PostgreSQL functions:

1. **`api.enhanced_agent_request()`** - Main orchestration function
2. **`collective_intelligence.get_industry_patterns()`** - Get anonymized patterns
3. **`collective_intelligence.contribute_anonymized_pattern()`** - Add to collective knowledge
4. **`collective_intelligence.anonymize_data()`** - Data anonymization
5. **`collective_intelligence.calculate_confidence_boost()`** - Confidence calculation

## 🌐 **Frontend Implementation Requirements**

### **Technology Stack**
- **Framework**: Vite + React + TypeScript
- **UI Library**: Refine + Ant Design
- **Routing**: React Router
- **State Management**: TanStack Query (React Query)
- **API Client**: Axios with tenant isolation headers

### **Required Components**

1. **Custom Hook: `useAIAgent()`**
   ```typescript
   // Must provide these functions:
   - analyzeHealth(data: HealthAnalysisData)
   - analyzeNutrition(data: NutritionAnalysisData) 
   - analyzeExercise(data: ExerciseAnalysisData)
   - comprehensiveAnalysis(horseId: string)
   
   // Must return these states:
   - isAnalyzing: boolean
   - healthResult: AIAgentResponse
   - agentMetrics: AgentMetrics
   - collectiveInsights: CollectiveIntelligence
   ```

2. **Service Layer: `aiAgentService`**
   ```typescript
   // Must implement these methods:
   - processRequest(request: AIAgentRequest): Promise<AIAgentResponse>
   - getDatabaseIntelligence(request): Promise<DatabaseIntelligenceResponse>
   - getCollectiveIntelligence(request): Promise<CollectiveIntelligenceResponse>
   - getAIAnalysis(context, request): Promise<OpenAIAnalysisResponse>
   - updateLearningSystem(request, analysis): Promise<void>
   ```

3. **React Components**
   ```typescript
   // Required components:
   - <HealthAnalysis /> - Health analysis interface
   - <NutritionAnalysis /> - Nutrition analysis interface  
   - <ExerciseAnalysis /> - Exercise analysis interface
   - <CollectiveInsightsDashboard /> - Industry insights display
   - <PrivacyControls /> - Privacy settings management
   ```

### **API Integration Requirements**

Create these API endpoints:

1. **`POST /api/v1/ai-agents/enhanced-analysis`**
   - Combines farm + collective intelligence
   - Calls OpenAI GPT-4 with enhanced context
   - Returns structured recommendations

2. **`POST /api/v1/ai-agents/database-intelligence`**
   - Gets farm-specific patterns and insights
   - Calls existing `api.agent_request()` function

3. **`POST /api/v1/ai-agents/collective-intelligence`**
   - Gets anonymized industry patterns
   - Calls `collective_intelligence.get_industry_patterns()`

4. **`POST /api/v1/ai-agents/learning-update`**
   - Updates both farm and collective learning
   - Anonymizes and contributes to collective knowledge

5. **`GET /api/v1/ai-agents/metrics`**
   - Returns agent performance metrics
   - Includes collective intelligence statistics

## 🤖 **OpenAI Integration Requirements**

### **Enhanced GPT-4 Prompts**

Create system prompts that include:

1. **Farm-Specific Context**
   ```
   FARM CONTEXT:
   - Historical cases: {farm_cases}
   - Success patterns: {farm_patterns}  
   - Risk factors: {farm_risks}
   - Confidence scores: {farm_confidence}
   ```

2. **Collective Intelligence Context**
   ```
   INDUSTRY INTELLIGENCE:
   - Similar cases across {total_farms} farms: {industry_cases}
   - Industry success rate: {industry_success_rate}
   - Statistical significance: {statistical_confidence}
   - Seasonal trends: {seasonal_patterns}
   - Geographic patterns: {geographic_trends}
   ```

3. **Enhanced Response Format**
   ```json
   {
     "priority_level": "HIGH|MEDIUM|LOW|CRITICAL",
     "confidence_level": 0.91,
     "statistical_backing": "Based on X industry cases + Y farm cases",
     "farm_specific_insights": "Your farm specific patterns...",
     "industry_insights": "Industry-wide patterns show...",
     "recommendations": [
       {
         "action": "Action title",
         "recommendation": "Detailed recommendation",
         "farm_success_rate": 0.85,
         "industry_success_rate": 0.87,
         "statistical_backing": "High confidence based on industry data",
         "urgency": "immediate|within_24h|within_week|routine"
       }
     ]
   }
   ```

## 🔒 **Privacy and Security Requirements**

### **Strict Data Anonymization**
- Remove all identifying information (farm names, owner names, horse names)
- Generalize specific values to ranges (temperature ranges, age groups)
- Use statistical patterns only, never individual case details

### **Tenant Isolation**
- Farm-specific data never crosses tenant boundaries
- Only anonymized patterns contribute to collective intelligence
- Each tenant controls their privacy settings

### **Privacy Controls**
```typescript
interface PrivacySettings {
  contributeToCollective: boolean;        // Help improve industry knowledge
  useCollectiveInsights: boolean;         // Benefit from industry patterns
  anonymizationLevel: 'FULL' | 'PARTIAL'; // Level of data anonymization
  geographicSharing: boolean;             // Share location/climate data
  shareOutcomes: boolean;                 // Share treatment outcomes
  shareSeasonalData: boolean;             // Share seasonal patterns
}
```

## 📊 **Expected Outcomes**

### **Enhanced Intelligence**
When a user analyzes a horse with colic symptoms:

1. **Farm Intelligence**: "Your farm has seen 15 similar cases with 85% success rate"
2. **Collective Intelligence**: "1,247 similar cases across 342 farms with 87% industry success rate"
3. **Enhanced AI Analysis**: GPT-4 with both contexts provides recommendations
4. **Statistical Backing**: "High confidence based on industry data + your farm's experience"
5. **Learning Update**: Contributes anonymized patterns back to collective knowledge

### **Network Effect Benefits**
- **Rare Conditions**: Expert advice even for conditions never seen on individual farms
- **Statistical Power**: Robust recommendations backed by thousands of cases
- **Seasonal Insights**: Proactive recommendations based on seasonal patterns
- **Treatment Validation**: Evidence-based treatment recommendations
- **Continuous Improvement**: System gets smarter with every farm's contributions

## 🎯 **Implementation Success Criteria**

### **Functional Requirements**
- ✅ Farm-specific intelligence working (already exists)
- ✅ Collective intelligence database schema implemented
- ✅ Enhanced agent functions created
- ✅ Frontend components with collective insights
- ✅ Privacy controls implemented
- ✅ OpenAI integration with enhanced prompts

### **Performance Requirements**
- Response time < 3 seconds for enhanced analysis
- Database queries optimized for collective intelligence
- Efficient anonymization and pattern matching

### **Privacy Requirements**
- Zero tenant data leakage
- Complete anonymization of collective patterns
- Granular privacy controls for each farm

### **Intelligence Requirements**
- Higher confidence scores with collective intelligence
- Relevant industry insights for each analysis
- Continuous learning and pattern improvement

## 🚀 **Implementation Priority**

### **Phase 1: Database Foundation**
1. Create collective intelligence schema
2. Implement enhanced agent functions
3. Create anonymization functions
4. Test with sample data

### **Phase 2: API Layer**
1. Create enhanced API endpoints
2. Integrate with OpenAI GPT-4
3. Implement privacy controls
4. Test API responses

### **Phase 3: Frontend Integration**
1. Create React components
2. Implement custom hooks
3. Build privacy controls UI
4. Create collective insights dashboard

### **Phase 4: Testing & Optimization**
1. Test with multiple tenants
2. Validate privacy and anonymization
3. Optimize performance
4. Gather user feedback

## 💡 **Key Implementation Notes**

1. **Maintain Existing Architecture**: Build on top of existing Data Vault 2.0 structure
2. **Privacy First**: Every collective intelligence feature must maintain strict anonymization
3. **Tenant Isolation**: Never compromise tenant data boundaries
4. **Statistical Rigor**: Ensure collective insights are statistically significant
5. **User Control**: Give farms complete control over their privacy settings
6. **Continuous Learning**: System should improve with every interaction

This implementation will create a revolutionary farm management platform that combines the power of individual farm intelligence with industry-wide collective knowledge, while maintaining the highest standards of privacy and security. 