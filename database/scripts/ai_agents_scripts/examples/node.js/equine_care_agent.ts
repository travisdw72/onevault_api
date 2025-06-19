/**
 * Equine Care Agent (ECA-001)
 * Zero Trust AI Agent for Veterinary Care and Horse Health Management
 * Integrates with Data Vault 2.0 Multi-Tenant Platform
 */

import fs from 'fs';
import https from 'https';
import crypto from 'crypto';
import { Pool, PoolClient, QueryResult } from 'pg';
import express, { Express, Request, Response } from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import winston from 'winston';
import { z } from 'zod';
import axios, { AxiosInstance } from 'axios';
import * as tf from '@tensorflow/tfjs-node';

// Types and Interfaces
interface AgentIdentity {
  agentId: string;
  agentName: string;
  domain: string;
  certificatePath: string;
  privateKeyPath: string;
  tenantHk: Buffer;
  sessionToken?: string;
  sessionExpires?: Date;
}

interface EquineData {
  horseId: string;
  breed: string;
  age: number;
  symptoms: string[];
  vitalSigns: {
    heartRate?: number;
    respiratoryRate?: number;
    temperature?: number;
    bloodPressure?: string;
  };
  behaviorObservations: string[];
  medicalHistory: string[];
  vaccinationRecord: Array<{
    vaccine: string;
    date: string;
    veterinarian: string;
  }>;
}

interface VeterinaryDiagnosis {
  diagnosisId: string;
  primaryDiagnosis: string;
  confidenceScore: number;
  differentialDiagnoses: Array<{
    diagnosis: string;
    probability: number;
    supportingEvidence: string[];
  }>;
  reasoningChain: string[];
  treatmentRecommendations: string[];
  urgencyLevel: 'ROUTINE' | 'URGENT' | 'EMERGENCY';
  followUpRequired: boolean;
}

// Validation Schemas
const EquineDataSchema = z.object({
  horseId: z.string().min(1),
  breed: z.string().min(1),
  age: z.number().min(0).max(50),
  symptoms: z.array(z.string()),
  vitalSigns: z.object({
    heartRate: z.number().optional(),
    respiratoryRate: z.number().optional(),
    temperature: z.number().optional(),
    bloodPressure: z.string().optional(),
  }),
  behaviorObservations: z.array(z.string()),
  medicalHistory: z.array(z.string()),
  vaccinationRecord: z.array(z.object({
    vaccine: z.string(),
    date: z.string(),
    veterinarian: z.string(),
  })),
});

// Logger Configuration
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'ECA-001' },
  transports: [
    new winston.transports.File({ filename: 'logs/eca-error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/eca-combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ],
});

class ZeroTrustAuthenticator {
  private identity: AgentIdentity;
  private zeroTrustGateway: string;
  private httpsAgent: https.Agent;

  constructor(identity: AgentIdentity) {
    this.identity = identity;
    this.zeroTrustGateway = process.env.ZERO_TRUST_GATEWAY_URL || 'https://ztg.onevault.com';
    
    // Configure HTTPS agent with client certificates
    this.httpsAgent = new https.Agent({
      cert: fs.readFileSync(this.identity.certificatePath),
      key: fs.readFileSync(this.identity.privateKeyPath),
      ca: fs.readFileSync(process.env.CA_CERT_PATH || '/etc/ssl/ca/ca.crt'),
      rejectUnauthorized: true,
    });
  }

  async authenticateWithGateway(): Promise<boolean> {
    try {
      const authPayload = {
        agent_id: this.identity.agentId,
        domain: this.identity.domain,
        requested_permissions: ['equine_data_read', 'veterinary_diagnosis_write'],
        session_duration_minutes: 10
      };

      const response = await axios.post(
        `${this.zeroTrustGateway}/api/v1/authenticate`,
        authPayload,
        {
          httpsAgent: this.httpsAgent,
          timeout: 30000,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'ECA-001/1.0.0'
          }
        }
      );

      if (response.status === 200) {
        this.identity.sessionToken = response.data.session_token;
        this.identity.sessionExpires = new Date(response.data.expires_at);
        logger.info(`Authentication successful for ${this.identity.agentId}`);
        return true;
      } else {
        logger.error(`Authentication failed: ${response.status} - ${response.statusText}`);
        return false;
      }
    } catch (error) {
      logger.error('Authentication error:', error);
      return false;
    }
  }

  validateSession(): boolean {
    if (!this.identity.sessionToken || !this.identity.sessionExpires) {
      return false;
    }

    if (new Date() >= this.identity.sessionExpires) {
      logger.warn('Session expired, re-authenticating...');
      return false;
    }

    return true;
  }

  async renewSession(): Promise<boolean> {
    if (!this.validateSession()) {
      return this.authenticateWithGateway();
    }
    return true;
  }
}

class DataVaultConnector {
  private pool: Pool;
  private identity: AgentIdentity;
  private authenticator: ZeroTrustAuthenticator;

  constructor(identity: AgentIdentity, authenticator: ZeroTrustAuthenticator) {
    this.identity = identity;
    this.authenticator = authenticator;
    
    this.pool = new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'one_vault',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD,
      ssl: {
        rejectUnauthorized: true,
        ca: fs.readFileSync(process.env.DB_CA_CERT || '/etc/ssl/db/ca.crt')
      },
      max: 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
      application_name: `ECA-001_${this.identity.agentId}`
    });
  }

  async executeSecureQuery(query: string, params: any[] = []): Promise<any[]> {
    if (!this.authenticator.validateSession()) {
      throw new Error('Invalid or expired session');
    }

    const client: PoolClient = await this.pool.connect();
    
    try {
      // Set session context for audit logging
      await client.query(
        'SELECT auth.set_agent_session_context($1, $2, $3)',
        [this.identity.agentId, this.identity.sessionToken, this.identity.tenantHk]
      );

      // Log query for audit trail
      const queryHash = crypto.createHash('sha256').update(query).digest();
      await client.query(`
        INSERT INTO ai_agents.agent_query_log_s (
          agent_hk, query_hash, query_type, execution_timestamp,
          tenant_hk, session_token, record_source
        ) VALUES (
          (SELECT agent_hk FROM ai_agents.agent_h WHERE agent_id = $1),
          $2, 'READ', $3, $4, $5, $6
        )
      `, [
        this.identity.agentId,
        queryHash,
        new Date(),
        this.identity.tenantHk,
        this.identity.sessionToken,
        'ECA-001'
      ]);

      // Execute the actual query
      const result: QueryResult = await client.query(query, params);
      return result.rows;

    } catch (error) {
      logger.error('Query execution failed:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  async storeVeterinaryDiagnosis(diagnosis: VeterinaryDiagnosis): Promise<string> {
    const client: PoolClient = await this.pool.connect();
    
    try {
      await client.query('BEGIN');

      // Insert into veterinary diagnosis hub
      const diagnosisHk = crypto.createHash('sha256')
        .update(`VETERINARY_DIAGNOSIS_${diagnosis.diagnosisId}`)
        .digest();

      await client.query(`
        INSERT INTO business.veterinary_diagnosis_h (
          diagnosis_hk, diagnosis_bk, tenant_hk, agent_hk,
          load_date, record_source
        ) VALUES ($1, $2, $3, 
          (SELECT agent_hk FROM ai_agents.agent_h WHERE agent_id = $4),
          $5, $6)
        ON CONFLICT (diagnosis_hk) DO NOTHING
      `, [
        diagnosisHk,
        diagnosis.diagnosisId,
        this.identity.tenantHk,
        this.identity.agentId,
        new Date(),
        'ECA-001'
      ]);

      // Insert diagnosis details satellite
      const hashDiff = crypto.createHash('sha256')
        .update(`${diagnosis.primaryDiagnosis}${diagnosis.confidenceScore}`)
        .digest();

      await client.query(`
        INSERT INTO business.veterinary_diagnosis_s (
          diagnosis_hk, load_date, hash_diff, primary_diagnosis,
          confidence_score, differential_diagnoses, reasoning_chain,
          treatment_recommendations, urgency_level, follow_up_required,
          record_source
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      `, [
        diagnosisHk,
        new Date(),
        hashDiff,
        diagnosis.primaryDiagnosis,
        diagnosis.confidenceScore,
        JSON.stringify(diagnosis.differentialDiagnoses),
        JSON.stringify(diagnosis.reasoningChain),
        JSON.stringify(diagnosis.treatmentRecommendations),
        diagnosis.urgencyLevel,
        diagnosis.followUpRequired,
        'ECA-001'
      ]);

      await client.query('COMMIT');
      logger.info(`Veterinary diagnosis ${diagnosis.diagnosisId} stored successfully`);
      return diagnosis.diagnosisId;

    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('Failed to store veterinary diagnosis:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  async close(): Promise<void> {
    await this.pool.end();
  }
}

class VeterinaryReasoningEngine {
  private model: tf.LayersModel | null = null;
  private symptomsEncoder: Map<string, number>;
  private diagnosisDecoder: Map<number, string>;
  
  constructor() {
    this.symptomsEncoder = new Map();
    this.diagnosisDecoder = new Map();
    this.initializeVeterinaryKnowledge();
  }

  private initializeVeterinaryKnowledge(): void {
    // Equine-specific symptoms encoding
    const equineSymptoms = [
      'lameness', 'colic', 'fever', 'lethargy', 'loss_of_appetite',
      'nasal_discharge', 'coughing', 'difficulty_breathing', 'swelling',
      'abnormal_gait', 'head_shaking', 'weight_loss', 'diarrhea'
    ];

    equineSymptoms.forEach((symptom, index) => {
      this.symptomsEncoder.set(symptom, index);
    });

    // Common equine diagnoses
    const equineDiagnoses = [
      'Equine Influenza', 'Strangles', 'Colic', 'Laminitis',
      'Navicular Disease', 'Equine Herpesvirus', 'Rain Rot',
      'Thrush', 'Suspensory Ligament Injury', 'Gastric Ulcers'
    ];

    equineDiagnoses.forEach((diagnosis, index) => {
      this.diagnosisDecoder.set(index, diagnosis);
    });

    logger.info('Veterinary knowledge base initialized');
  }

  private encodeSymptoms(symptoms: string[]): number[] {
    const featureVector = new Array(this.symptomsEncoder.size).fill(0);
    
    symptoms.forEach(symptom => {
      const normalizedSymptom = symptom.toLowerCase().replace(/\s+/g, '_');
      const index = this.symptomsEncoder.get(normalizedSymptom);
      if (index !== undefined) {
        featureVector[index] = 1;
      }
    });

    return featureVector;
  }

  async veterinaryDiagnosis(equineData: EquineData): Promise<VeterinaryDiagnosis> {
    try {
      // Encode symptoms for AI processing
      const symptomsVector = this.encodeSymptoms(equineData.symptoms);
      
      // For demonstration, using rule-based logic
      // In production, this would use trained veterinary AI models
      const diagnosisScores = this.calculateDiagnosisScores(equineData, symptomsVector);
      
      // Get primary diagnosis
      const primaryIndex = diagnosisScores.indexOf(Math.max(...diagnosisScores));
      const primaryDiagnosis = this.diagnosisDecoder.get(primaryIndex) || 'Unknown Condition';
      const confidence = diagnosisScores[primaryIndex];

      // Create differential diagnoses
      const differentialDiagnoses = this.createDifferentialDiagnoses(diagnosisScores, equineData);
      
      // Generate reasoning chain
      const reasoningChain = this.generateVeterinaryReasoning(equineData, primaryDiagnosis);
      
      // Assess urgency
      const urgencyLevel = this.assessUrgency(equineData, primaryDiagnosis);
      
      // Generate treatment recommendations
      const treatmentRecommendations = this.generateTreatmentRecommendations(primaryDiagnosis, equineData);

      const diagnosis: VeterinaryDiagnosis = {
        diagnosisId: crypto.randomUUID(),
        primaryDiagnosis,
        confidenceScore: confidence,
        differentialDiagnoses,
        reasoningChain,
        treatmentRecommendations,
        urgencyLevel,
        followUpRequired: confidence < 0.8 || urgencyLevel !== 'ROUTINE'
      };

      logger.info(`Veterinary diagnosis completed: ${primaryDiagnosis} (confidence: ${confidence.toFixed(2)})`);
      return diagnosis;

    } catch (error) {
      logger.error('Veterinary diagnosis failed:', error);
      throw error;
    }
  }

  private calculateDiagnosisScores(equineData: EquineData, symptomsVector: number[]): number[] {
    // Simplified scoring system - in production, use trained models
    const scores = new Array(this.diagnosisDecoder.size).fill(0.1);
    
    // Rule-based scoring for common conditions
    if (equineData.symptoms.includes('colic') || equineData.symptoms.includes('abdominal_pain')) {
      scores[2] = 0.9; // Colic
    }
    
    if (equineData.symptoms.includes('lameness')) {
      scores[3] = 0.8; // Laminitis
      scores[4] = 0.7; // Navicular Disease
    }
    
    if (equineData.symptoms.includes('fever') && equineData.symptoms.includes('nasal_discharge')) {
      scores[0] = 0.85; // Equine Influenza
      scores[1] = 0.75; // Strangles
    }

    // Age-based adjustments
    if (equineData.age > 15) {
      scores[4] += 0.1; // Navicular more common in older horses
    }

    // Vital signs adjustments
    if (equineData.vitalSigns.temperature && equineData.vitalSigns.temperature > 101.5) {
      scores[0] += 0.1; // Fever indicates infection
      scores[1] += 0.1;
    }

    return scores;
  }

  private createDifferentialDiagnoses(scores: number[], equineData: EquineData): Array<{
    diagnosis: string;
    probability: number;
    supportingEvidence: string[];
  }> {
    return scores
      .map((score, index) => ({
        diagnosis: this.diagnosisDecoder.get(index) || 'Unknown',
        probability: score,
        supportingEvidence: this.getSupportingEvidence(equineData, index)
      }))
      .sort((a, b) => b.probability - a.probability)
      .slice(0, 3);
  }

  private getSupportingEvidence(equineData: EquineData, diagnosisIndex: number): string[] {
    const evidence: string[] = [];
    const diagnosis = this.diagnosisDecoder.get(diagnosisIndex);

    // Add supporting evidence based on symptoms and diagnosis
    if (diagnosis === 'Colic' && equineData.symptoms.includes('colic')) {
      evidence.push('Patient exhibits classic colic symptoms');
      if (equineData.behaviorObservations.includes('pawing') || 
          equineData.behaviorObservations.includes('rolling')) {
        evidence.push('Behavioral signs consistent with abdominal discomfort');
      }
    }

    if (diagnosis === 'Laminitis' && equineData.symptoms.includes('lameness')) {
      evidence.push('Lameness observed in affected limbs');
      if (equineData.breed.toLowerCase().includes('pony')) {
        evidence.push('Breed predisposition for laminitis');
      }
    }

    return evidence;
  }

  private generateVeterinaryReasoning(equineData: EquineData, diagnosis: string): string[] {
    return [
      `Equine patient (${equineData.breed}, ${equineData.age} years old) presents with symptoms: ${equineData.symptoms.join(', ')}`,
      `Vital signs analysis: Heart rate ${equineData.vitalSigns.heartRate || 'not recorded'}, Temperature ${equineData.vitalSigns.temperature || 'not recorded'}°F`,
      `Behavioral observations: ${equineData.behaviorObservations.join(', ')}`,
      `Medical history review: ${equineData.medicalHistory.join(', ')}`,
      `Vaccination record reviewed: ${equineData.vaccinationRecord.length} vaccinations on file`,
      `Veterinary expert system analysis indicates: ${diagnosis}`,
      'Differential diagnoses considered and ranked by probability',
      'Treatment recommendations based on equine veterinary guidelines'
    ];
  }

  private assessUrgency(equineData: EquineData, diagnosis: string): 'ROUTINE' | 'URGENT' | 'EMERGENCY' {
    if (diagnosis === 'Colic' || equineData.symptoms.includes('severe_pain')) {
      return 'EMERGENCY';
    }
    
    if (equineData.vitalSigns.temperature && equineData.vitalSigns.temperature > 103) {
      return 'URGENT';
    }
    
    if (diagnosis === 'Laminitis' || equineData.symptoms.includes('severe_lameness')) {
      return 'URGENT';
    }

    return 'ROUTINE';
  }

  private generateTreatmentRecommendations(diagnosis: string, equineData: EquineData): string[] {
    const recommendations: string[] = [];

    switch (diagnosis) {
      case 'Colic':
        recommendations.push('Immediate veterinary examination required');
        recommendations.push('Withhold feed, allow small amounts of water');
        recommendations.push('Monitor vital signs closely');
        recommendations.push('Prepare for potential surgical intervention');
        break;
        
      case 'Laminitis':
        recommendations.push('Immediate box rest with deep bedding');
        recommendations.push('Apply ice boots to affected feet');
        recommendations.push('Anti-inflammatory medication as prescribed');
        recommendations.push('Radiographic evaluation of feet');
        break;
        
      case 'Equine Influenza':
        recommendations.push('Isolate from other horses');
        recommendations.push('Complete rest for 4-6 weeks');
        recommendations.push('Monitor temperature twice daily');
        recommendations.push('Supportive care with adequate nutrition');
        break;
        
      default:
        recommendations.push('Veterinary examination recommended');
        recommendations.push('Monitor symptoms and report changes');
        recommendations.push('Maintain regular feeding and exercise schedule');
    }

    return recommendations;
  }
}

class EquineCareAgent {
  private app: Express;
  private identity: AgentIdentity;
  private authenticator: ZeroTrustAuthenticator;
  private dbConnector: DataVaultConnector | null = null;
  private reasoningEngine: VeterinaryReasoningEngine;
  private config: any;

  constructor(configPath: string) {
    this.config = this.loadConfig(configPath);
    this.identity = this.createAgentIdentity();
    this.authenticator = new ZeroTrustAuthenticator(this.identity);
    this.reasoningEngine = new VeterinaryReasoningEngine();
    this.app = express();
    
    this.setupMiddleware();
    this.setupRoutes();
  }

  private loadConfig(configPath: string): any {
    try {
      const configData = fs.readFileSync(configPath, 'utf8');
      return JSON.parse(configData);
    } catch (error) {
      logger.error('Failed to load config:', error);
      throw error;
    }
  }

  private createAgentIdentity(): AgentIdentity {
    return {
      agentId: 'ECA-001',
      agentName: 'Equine Care Agent',
      domain: 'EQUINE',
      certificatePath: this.config.security.certificate_path,
      privateKeyPath: this.config.security.private_key_path,
      tenantHk: Buffer.from(this.config.tenant.tenant_hk, 'hex')
    };
  }

  private setupMiddleware(): void {
    // Security middleware
    this.app.use(helmet());
    
    // Rate limiting
    const limiter = rateLimit({
      windowMs: 15 * 60 * 1000, // 15 minutes
      max: 100, // limit each IP to 100 requests per windowMs
      message: 'Too many requests from this IP'
    });
    this.app.use(limiter);

    // JSON parsing
    this.app.use(express.json({ limit: '10mb' }));
    
    // Request logging
    this.app.use((req, res, next) => {
      logger.info(`${req.method} ${req.path}`, {
        ip: req.ip,
        userAgent: req.get('User-Agent')
      });
      next();
    });
  }

  private setupRoutes(): void {
    // Health check endpoint
    this.app.get('/health', (req: Request, res: Response) => {
      res.json({
        agent: this.identity.agentId,
        status: 'healthy',
        timestamp: new Date().toISOString(),
        session_valid: this.authenticator.validateSession()
      });
    });

    // Veterinary diagnosis endpoint
    this.app.post('/diagnose', async (req: Request, res: Response) => {
      try {
        // Validate session
        if (!this.authenticator.validateSession()) {
          return res.status(401).json({ error: 'Invalid or expired session' });
        }

        // Validate input data
        const equineData = EquineDataSchema.parse(req.body);
        
        // Perform diagnosis
        const diagnosis = await this.reasoningEngine.veterinaryDiagnosis(equineData);
        
        // Store in database
        if (this.dbConnector) {
          await this.dbConnector.storeVeterinaryDiagnosis(diagnosis);
        }

        res.json({
          success: true,
          diagnosis: {
            id: diagnosis.diagnosisId,
            primary_diagnosis: diagnosis.primaryDiagnosis,
            confidence: diagnosis.confidenceScore,
            urgency: diagnosis.urgencyLevel,
            follow_up_required: diagnosis.followUpRequired,
            differential_diagnoses: diagnosis.differentialDiagnoses,
            treatment_recommendations: diagnosis.treatmentRecommendations
          }
        });

      } catch (error) {
        logger.error('Diagnosis endpoint error:', error);
        res.status(500).json({ 
          error: 'Diagnosis processing failed',
          message: error instanceof Error ? error.message : 'Unknown error'
        });
      }
    });

    // Get horse health history
    this.app.get('/history/:horseId', async (req: Request, res: Response) => {
      try {
        if (!this.authenticator.validateSession() || !this.dbConnector) {
          return res.status(401).json({ error: 'Unauthorized' });
        }

        const history = await this.dbConnector.executeSecureQuery(`
          SELECT 
            vd.primary_diagnosis,
            vd.confidence_score,
            vd.urgency_level,
            vd.load_date
          FROM business.veterinary_diagnosis_h vdh
          JOIN business.veterinary_diagnosis_s vd ON vdh.diagnosis_hk = vd.diagnosis_hk
          WHERE vdh.diagnosis_bk LIKE $1
          AND vdh.tenant_hk = $2
          AND vd.load_end_date IS NULL
          ORDER BY vd.load_date DESC
        `, [`%${req.params.horseId}%`, this.identity.tenantHk]);

        res.json({ success: true, history });

      } catch (error) {
        logger.error('History endpoint error:', error);
        res.status(500).json({ error: 'Failed to retrieve history' });
      }
    });
  }

  async initialize(): Promise<boolean> {
    try {
      // Authenticate with Zero Trust Gateway
      if (!await this.authenticator.authenticateWithGateway()) {
        logger.error('Failed to authenticate with Zero Trust Gateway');
        return false;
      }

      // Initialize database connection
      this.dbConnector = new DataVaultConnector(this.identity, this.authenticator);

      // Register agent session
      await this.registerAgentSession();

      logger.info('Equine Care Agent initialized successfully');
      return true;

    } catch (error) {
      logger.error('Agent initialization failed:', error);
      return false;
    }
  }

  private async registerAgentSession(): Promise<void> {
    if (!this.dbConnector) return;

    await this.dbConnector.executeSecureQuery(`
      INSERT INTO ai_agents.agent_session_s (
        agent_hk, session_token, session_start, session_expires,
        permissions, tenant_hk, record_source
      ) VALUES (
        (SELECT agent_hk FROM ai_agents.agent_h WHERE agent_id = $1),
        $2, $3, $4, $5, $6, $7
      )
    `, [
      this.identity.agentId,
      this.identity.sessionToken,
      new Date(),
      this.identity.sessionExpires,
      JSON.stringify(['equine_data_read', 'veterinary_diagnosis_write']),
      this.identity.tenantHk,
      'ECA-001'
    ]);
  }

  async start(port: number = 3001): Promise<void> {
    if (!await this.initialize()) {
      throw new Error('Failed to initialize agent');
    }

    // Setup session renewal
    setInterval(async () => {
      await this.authenticator.renewSession();
    }, 5 * 60 * 1000); // Renew every 5 minutes

    this.app.listen(port, () => {
      logger.info(`Equine Care Agent listening on port ${port}`);
    });
  }

  async shutdown(): Promise<void> {
    try {
      if (this.dbConnector) {
        await this.dbConnector.close();
      }
      logger.info('Equine Care Agent shutdown completed');
    } catch (error) {
      logger.error('Shutdown error:', error);
    }
  }
}

// Main execution
async function main() {
  const configPath = process.argv[2] || './config/eca_001_config.json';
  
  const agent = new EquineCareAgent(configPath);
  
  // Graceful shutdown handling
  process.on('SIGTERM', async () => {
    logger.info('Received SIGTERM, shutting down gracefully');
    await agent.shutdown();
    process.exit(0);
  });

  process.on('SIGINT', async () => {
    logger.info('Received SIGINT, shutting down gracefully');
    await agent.shutdown();
    process.exit(0);
  });

  try {
    await agent.start(3001);
  } catch (error) {
    logger.error('Failed to start agent:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main().catch(error => {
    logger.error('Unhandled error:', error);
    process.exit(1);
  });
}

export { EquineCareAgent, VeterinaryReasoningEngine, ZeroTrustAuthenticator }; 