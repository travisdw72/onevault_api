// 🧠 Anthropic Claude Vision API Integration Service
import axios, { AxiosError } from 'axios';

// 🔑 API Configuration
const ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages';
const API_VERSION = '2023-06-01';

// 📊 Types and Interfaces
export interface AnthropicConfig {
  apiKey: string;
  model?: string;
  maxTokens?: number;
  temperature?: number;
}

export interface PhotoAnalysisRequest {
  imageData: string; // base64 encoded image
  imageType: string; // mime type (e.g., 'image/jpeg')
  analysisPrompt?: string;
  photoIndex: number;
  sessionId: string;
}

export interface PhotoAnalysisResponse {
  photoIndex: number;
  sessionId: string;
  analysis: {
    overallHealthScore: number; // 0-100
    colicRiskLevel: 'low' | 'medium' | 'high' | 'critical';
    confidenceScore: number; // 0-1
    findings: {
      posture: {
        abnormal: boolean;
        description: string;
        severity: number; // 0-10
      };
      behavior: {
        concerningBehaviors: string[];
        normalBehaviors: string[];
        painIndicators: string[];
      };
      physicalSigns: {
        visible: string[];
        concerning: string[];
        normal: string[];
      };
      emergencyFlags: string[];
    };
    recommendations: string[];
    vetConsultation: boolean;
  };
  processingTime: number; // milliseconds
  timestamp: string;
  rawResponse: string;
}

export interface CompilationRequest {
  sessionId: string;
  photoAnalyses: PhotoAnalysisResponse[];
  timespan: number; // minutes
  additionalContext?: string;
}

export interface CompilationResponse {
  sessionId: string;
  finalAssessment: {
    overallRiskScore: number; // 0-100
    riskLevel: 'low' | 'medium' | 'high' | 'critical';
    confidenceScore: number; // 0-1
    progressionAnalysis: {
      improving: boolean;
      deteriorating: boolean;
      stable: boolean;
      emergencyProgression: boolean;
    };
    patternAnalysis: {
      consistentFindings: string[];
      changingPatterns: string[];
      emergingConcerns: string[];
    };
    veterinaryRecommendations: {
      urgency: 'routine' | 'soon' | 'urgent' | 'emergency';
      actions: string[];
      monitoring: string[];
      followUp: string;
    };
    summary: string;
  };
  processingTime: number;
  timestamp: string;
  totalCost: number; // estimated USD
}

// 🛡️ Error Types
export class AnthropicAPIError extends Error {
  constructor(
    message: string,
    public status?: number,
    public code?: string,
    public details?: any
  ) {
    super(message);
    this.name = 'AnthropicAPIError';
  }
}

// 🧠 Main Anthropic Service Class
export class AnthropicService {
  private config: AnthropicConfig;
  private defaultModel = 'claude-3-5-sonnet-20241022';

  constructor(config: AnthropicConfig) {
    this.config = {
      model: this.defaultModel,
      maxTokens: 1024,
      temperature: 0.3,
      ...config
    };

    if (!this.config.apiKey) {
      throw new AnthropicAPIError('Anthropic API key is required');
    }
  }

  // 📸 Analyze individual horse photo
  async analyzeHorsePhoto(request: PhotoAnalysisRequest): Promise<PhotoAnalysisResponse> {
    const startTime = Date.now();

    try {
      const analysisPrompt = request.analysisPrompt || this.getDefaultAnalysisPrompt();

      const anthropicRequest = {
        model: this.config.model,
        max_tokens: this.config.maxTokens,
        temperature: this.config.temperature,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: {
                  type: 'base64',
                  media_type: request.imageType,
                  data: request.imageData
                }
              },
              {
                type: 'text',
                text: analysisPrompt
              }
            ]
          }
        ]
      };

      const response = await axios.post(ANTHROPIC_API_URL, anthropicRequest, {
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': this.config.apiKey,
          'anthropic-version': API_VERSION
        },
        timeout: 30000 // 30 second timeout
      });

      const processingTime = Date.now() - startTime;
      const rawResponse = response.data.content[0].text;

      // Parse the structured response
      const analysis = this.parsePhotoAnalysis(rawResponse);

      return {
        photoIndex: request.photoIndex,
        sessionId: request.sessionId,
        analysis,
        processingTime,
        timestamp: new Date().toISOString(),
        rawResponse
      };

    } catch (error) {
      const processingTime = Date.now() - startTime;
      
      if (axios.isAxiosError(error)) {
        const axiosError = error as AxiosError;
        throw new AnthropicAPIError(
          `API request failed: ${axiosError.message}`,
          axiosError.response?.status,
          axiosError.code,
          axiosError.response?.data
        );
      }

      throw new AnthropicAPIError(
        `Photo analysis failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        undefined,
        undefined,
        { processingTime, photoIndex: request.photoIndex }
      );
    }
  }

  // 📋 Compile final veterinary assessment
  async compileHealthAssessment(request: CompilationRequest): Promise<CompilationResponse> {
    const startTime = Date.now();

    try {
      const compilationPrompt = this.getCompilationPrompt(request);

      const anthropicRequest = {
        model: this.config.model,
        max_tokens: 2048,
        temperature: 0.2, // Lower temperature for more consistent medical analysis
        messages: [
          {
            role: 'user',
            content: compilationPrompt
          }
        ]
      };

      const response = await axios.post(ANTHROPIC_API_URL, anthropicRequest, {
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': this.config.apiKey,
          'anthropic-version': API_VERSION
        },
        timeout: 45000 // 45 second timeout for compilation
      });

      const processingTime = Date.now() - startTime;
      const rawResponse = response.data.content[0].text;

      // Parse the compilation response
      const finalAssessment = this.parseCompilationResponse(rawResponse);

      // Calculate estimated cost (approximate)
      const totalTokens = request.photoAnalyses.length * 1000 + 2000; // Rough estimate
      const totalCost = (totalTokens / 1000) * 0.015; // Approximate Claude pricing

      return {
        sessionId: request.sessionId,
        finalAssessment,
        processingTime,
        timestamp: new Date().toISOString(),
        totalCost
      };

    } catch (error) {
      const processingTime = Date.now() - startTime;

      if (axios.isAxiosError(error)) {
        const axiosError = error as AxiosError;
        throw new AnthropicAPIError(
          `Compilation request failed: ${axiosError.message}`,
          axiosError.response?.status,
          axiosError.code,
          axiosError.response?.data
        );
      }

      throw new AnthropicAPIError(
        `Assessment compilation failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        undefined,
        undefined,
        { processingTime, sessionId: request.sessionId }
      );
    }
  }

  // 🎯 Default analysis prompt for horse health
  private getDefaultAnalysisPrompt(): string {
    return `
Analyze this horse photograph for signs of colic and overall health status. As a veterinary AI assistant, provide a detailed assessment in the following JSON format:

{
  "overallHealthScore": 0-100,
  "colicRiskLevel": "low|medium|high|critical",
  "confidenceScore": 0.0-1.0,
  "findings": {
    "posture": {
      "abnormal": true/false,
      "description": "detailed description of posture",
      "severity": 0-10
    },
    "behavior": {
      "concerningBehaviors": ["list of concerning behaviors observed"],
      "normalBehaviors": ["list of normal behaviors observed"],
      "painIndicators": ["specific pain indicators if any"]
    },
    "physicalSigns": {
      "visible": ["all visible physical signs"],
      "concerning": ["concerning physical signs"],
      "normal": ["normal physical signs"]
    },
    "emergencyFlags": ["any emergency indicators"]
  },
  "recommendations": ["immediate recommendations"],
  "vetConsultation": true/false
}

Focus specifically on:
1. Posture abnormalities (lying down inappropriately, abnormal standing position)
2. Signs of abdominal pain (looking at flanks, pawing, restlessness)
3. Behavioral indicators (sweating, anxiety, depression)
4. Physical condition (body position, facial expressions)
5. Emergency signs requiring immediate veterinary attention

Provide confidence scores based on image clarity and visibility of relevant indicators.
`;
  }

  // 📊 Compilation prompt for final assessment
  private getCompilationPrompt(request: CompilationRequest): string {
    const analysesData = JSON.stringify(request.photoAnalyses, null, 2);
    
    return `
Analyze these ${request.photoAnalyses.length} horse health assessments taken over ${request.timespan} minute(s) and compile a comprehensive veterinary assessment.

PHOTO ANALYSES:
${analysesData}

Please provide a final assessment in the following JSON format:

{
  "overallRiskScore": 0-100,
  "riskLevel": "low|medium|high|critical",
  "confidenceScore": 0.0-1.0,
  "progressionAnalysis": {
    "improving": true/false,
    "deteriorating": true/false,
    "stable": true/false,
    "emergencyProgression": true/false
  },
  "patternAnalysis": {
    "consistentFindings": ["findings that appeared consistently"],
    "changingPatterns": ["patterns that changed over time"],
    "emergingConcerns": ["new concerns that developed"]
  },
  "veterinaryRecommendations": {
    "urgency": "routine|soon|urgent|emergency",
    "actions": ["specific actions to take"],
    "monitoring": ["what to monitor going forward"],
    "followUp": "follow-up timeline and instructions"
  },
  "summary": "2-3 sentence summary of overall assessment"
}

Consider:
1. Patterns across the time series
2. Any progression or deterioration 
3. Consistency of findings
4. Overall risk level
5. Specific veterinary recommendations
6. Emergency indicators requiring immediate action

Base your assessment on veterinary medical knowledge for equine colic detection and health monitoring.
`;
  }

  // 🔍 Parse individual photo analysis response
  private parsePhotoAnalysis(rawResponse: string): PhotoAnalysisResponse['analysis'] {
    try {
      // Extract JSON from the response
      const jsonMatch = rawResponse.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        throw new Error('No JSON found in response');
      }

      const parsed = JSON.parse(jsonMatch[0]);
      
      // Validate and sanitize the response
      return {
        overallHealthScore: Math.max(0, Math.min(100, parsed.overallHealthScore || 75)),
        colicRiskLevel: ['low', 'medium', 'high', 'critical'].includes(parsed.colicRiskLevel) 
          ? parsed.colicRiskLevel : 'medium',
        confidenceScore: Math.max(0, Math.min(1, parsed.confidenceScore || 0.7)),
        findings: {
          posture: {
            abnormal: Boolean(parsed.findings?.posture?.abnormal),
            description: parsed.findings?.posture?.description || 'Normal standing posture observed',
            severity: Math.max(0, Math.min(10, parsed.findings?.posture?.severity || 2))
          },
          behavior: {
            concerningBehaviors: Array.isArray(parsed.findings?.behavior?.concerningBehaviors) 
              ? parsed.findings.behavior.concerningBehaviors : [],
            normalBehaviors: Array.isArray(parsed.findings?.behavior?.normalBehaviors) 
              ? parsed.findings.behavior.normalBehaviors : ['Alert and responsive'],
            painIndicators: Array.isArray(parsed.findings?.behavior?.painIndicators) 
              ? parsed.findings.behavior.painIndicators : []
          },
          physicalSigns: {
            visible: Array.isArray(parsed.findings?.physicalSigns?.visible) 
              ? parsed.findings.physicalSigns.visible : [],
            concerning: Array.isArray(parsed.findings?.physicalSigns?.concerning) 
              ? parsed.findings.physicalSigns.concerning : [],
            normal: Array.isArray(parsed.findings?.physicalSigns?.normal) 
              ? parsed.findings.physicalSigns.normal : []
          },
          emergencyFlags: Array.isArray(parsed.findings?.emergencyFlags) 
            ? parsed.findings.emergencyFlags : []
        },
        recommendations: Array.isArray(parsed.recommendations) ? parsed.recommendations : [],
        vetConsultation: Boolean(parsed.vetConsultation)
      };

    } catch (error) {
      // Fallback to safe defaults if parsing fails
      return {
        overallHealthScore: 75,
        colicRiskLevel: 'medium',
        confidenceScore: 0.5,
        findings: {
          posture: {
            abnormal: false,
            description: 'Unable to analyze posture from image',
            severity: 5
          },
          behavior: {
            concerningBehaviors: ['Analysis parsing error'],
            normalBehaviors: [],
            painIndicators: []
          },
          physicalSigns: {
            visible: ['Image analysis incomplete'],
            concerning: [],
            normal: []
          },
          emergencyFlags: []
        },
        recommendations: ['Consult veterinarian for proper assessment'],
        vetConsultation: true
      };
    }
  }

  // 📋 Parse compilation response
  private parseCompilationResponse(rawResponse: string): CompilationResponse['finalAssessment'] {
    try {
      const jsonMatch = rawResponse.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        throw new Error('No JSON found in compilation response');
      }

      const parsed = JSON.parse(jsonMatch[0]);

      return {
        overallRiskScore: Math.max(0, Math.min(100, parsed.overallRiskScore || 50)),
        riskLevel: ['low', 'medium', 'high', 'critical'].includes(parsed.riskLevel) 
          ? parsed.riskLevel : 'medium',
        confidenceScore: Math.max(0, Math.min(1, parsed.confidenceScore || 0.7)),
        progressionAnalysis: {
          improving: Boolean(parsed.progressionAnalysis?.improving),
          deteriorating: Boolean(parsed.progressionAnalysis?.deteriorating),
          stable: Boolean(parsed.progressionAnalysis?.stable),
          emergencyProgression: Boolean(parsed.progressionAnalysis?.emergencyProgression)
        },
        patternAnalysis: {
          consistentFindings: Array.isArray(parsed.patternAnalysis?.consistentFindings) 
            ? parsed.patternAnalysis.consistentFindings : [],
          changingPatterns: Array.isArray(parsed.patternAnalysis?.changingPatterns) 
            ? parsed.patternAnalysis.changingPatterns : [],
          emergingConcerns: Array.isArray(parsed.patternAnalysis?.emergingConcerns) 
            ? parsed.patternAnalysis.emergingConcerns : []
        },
        veterinaryRecommendations: {
          urgency: ['routine', 'soon', 'urgent', 'emergency'].includes(parsed.veterinaryRecommendations?.urgency) 
            ? parsed.veterinaryRecommendations.urgency : 'routine',
          actions: Array.isArray(parsed.veterinaryRecommendations?.actions) 
            ? parsed.veterinaryRecommendations.actions : [],
          monitoring: Array.isArray(parsed.veterinaryRecommendations?.monitoring) 
            ? parsed.veterinaryRecommendations.monitoring : [],
          followUp: parsed.veterinaryRecommendations?.followUp || 'Follow up as needed'
        },
        summary: parsed.summary || 'Comprehensive analysis completed. Consult with veterinarian for detailed interpretation.'
      };

    } catch (error) {
      // Fallback to safe defaults
      return {
        overallRiskScore: 50,
        riskLevel: 'medium',
        confidenceScore: 0.5,
        progressionAnalysis: {
          improving: false,
          deteriorating: false,
          stable: true,
          emergencyProgression: false
        },
        patternAnalysis: {
          consistentFindings: ['Analysis parsing error'],
          changingPatterns: [],
          emergingConcerns: []
        },
        veterinaryRecommendations: {
          urgency: 'routine',
          actions: ['Consult with veterinarian'],
          monitoring: ['Monitor horse closely'],
          followUp: 'Schedule veterinary consultation'
        },
        summary: 'Analysis compilation failed. Please consult with a veterinarian for proper assessment.'
      };
    }
  }

  // 🧪 Test API connection
  async testConnection(): Promise<boolean> {
    try {
      const testRequest = {
        model: this.config.model,
        max_tokens: 50,
        messages: [
          {
            role: 'user',
            content: 'Hello, please respond with "API connection successful"'
          }
        ]
      };

      const response = await axios.post(ANTHROPIC_API_URL, testRequest, {
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': this.config.apiKey,
          'anthropic-version': API_VERSION
        },
        timeout: 10000
      });

      return response.status === 200;

    } catch (error) {
      console.error('Anthropic API connection test failed:', error);
      return false;
    }
  }
}

// 🔧 Utility functions
export const createAnthropicService = (apiKey: string): AnthropicService => {
  return new AnthropicService({ apiKey });
};

export const validateApiKey = (apiKey: string): boolean => {
  return /^sk-ant-api\d{2}-[A-Za-z0-9_-]{95}-[A-Za-z0-9_-]{6}AA$/.test(apiKey);
}; 