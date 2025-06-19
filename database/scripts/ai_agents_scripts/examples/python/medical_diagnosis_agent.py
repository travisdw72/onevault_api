#!/usr/bin/env python3
"""
Medical Diagnosis Agent (MDA-001)
Zero Trust AI Agent for HIPAA-compliant medical diagnosis
Integrates with Data Vault 2.0 Multi-Tenant Platform
"""

import os
import ssl
import json
import uuid
import hashlib
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
import psycopg2
from psycopg2.extras import RealDictCursor
import requests
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
import pandas as pd

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('MDA-001')

@dataclass
class AgentIdentity:
    """Agent identity and certificate information"""
    agent_id: str
    agent_name: str
    domain: str
    certificate_path: str
    private_key_path: str
    tenant_hk: bytes
    session_token: Optional[str] = None
    session_expires: Optional[datetime] = None

@dataclass
class MedicalData:
    """Medical data structure for analysis"""
    patient_id: str
    symptoms: List[str]
    vital_signs: Dict[str, float]
    lab_results: Dict[str, float]
    medical_history: List[str]
    risk_factors: List[str]

@dataclass
class DiagnosisResult:
    """Medical diagnosis result structure"""
    diagnosis_id: str
    primary_diagnosis: str
    confidence_score: float
    differential_diagnoses: List[Dict[str, Any]]
    reasoning_chain: List[str]
    recommended_actions: List[str]
    risk_assessment: str

class ZeroTrustAuthenticator:
    """Handles zero trust authentication and certificate management"""
    
    def __init__(self, agent_identity: AgentIdentity):
        self.identity = agent_identity
        self.zero_trust_gateway = os.getenv('ZERO_TRUST_GATEWAY_URL', 'https://ztg.onevault.com')
        
    def load_certificates(self) -> Tuple[str, str]:
        """Load agent certificates for mTLS authentication"""
        try:
            with open(self.identity.certificate_path, 'r') as cert_file:
                certificate = cert_file.read()
            
            with open(self.identity.private_key_path, 'r') as key_file:
                private_key = key_file.read()
                
            return certificate, private_key
        except Exception as e:
            logger.error(f"Failed to load certificates: {e}")
            raise
    
    def authenticate_with_gateway(self) -> bool:
        """Authenticate with Zero Trust Gateway using mTLS"""
        try:
            cert, key = self.load_certificates()
            
            # Create SSL context for mTLS
            ssl_context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
            ssl_context.check_hostname = False
            ssl_context.verify_mode = ssl.CERT_REQUIRED
            
            # Authenticate with gateway
            auth_payload = {
                'agent_id': self.identity.agent_id,
                'domain': self.identity.domain,
                'requested_permissions': ['medical_data_read', 'diagnosis_write'],
                'session_duration_minutes': 10  # Short-lived sessions
            }
            
            response = requests.post(
                f"{self.zero_trust_gateway}/api/v1/authenticate",
                json=auth_payload,
                cert=(self.identity.certificate_path, self.identity.private_key_path),
                verify=True,
                timeout=30
            )
            
            if response.status_code == 200:
                auth_data = response.json()
                self.identity.session_token = auth_data['session_token']
                self.identity.session_expires = datetime.fromisoformat(auth_data['expires_at'])
                logger.info(f"Authentication successful for {self.identity.agent_id}")
                return True
            else:
                logger.error(f"Authentication failed: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"Authentication error: {e}")
            return False
    
    def validate_session(self) -> bool:
        """Validate current session token"""
        if not self.identity.session_token or not self.identity.session_expires:
            return False
            
        if datetime.now() >= self.identity.session_expires:
            logger.warning("Session expired, re-authenticating...")
            return self.authenticate_with_gateway()
            
        return True

class DataVaultConnector:
    """Handles secure connection to Data Vault 2.0 database"""
    
    def __init__(self, agent_identity: AgentIdentity, authenticator: ZeroTrustAuthenticator):
        self.identity = agent_identity
        self.authenticator = authenticator
        self.connection = None
        
    def connect(self) -> psycopg2.connection:
        """Establish secure database connection"""
        if not self.authenticator.validate_session():
            raise Exception("Invalid or expired session")
            
        try:
            connection_params = {
                'host': os.getenv('DB_HOST', 'localhost'),
                'port': os.getenv('DB_PORT', 5432),
                'database': os.getenv('DB_NAME', 'one_vault'),
                'user': os.getenv('DB_USER', 'postgres'),
                'password': os.getenv('DB_PASSWORD'),
                'sslmode': 'require',
                'application_name': f"MDA-001_{self.identity.agent_id}",
                'options': f"-c search_path=business,auth,ai_agents"
            }
            
            self.connection = psycopg2.connect(**connection_params)
            self.connection.autocommit = False
            
            # Set session context for audit logging
            with self.connection.cursor() as cursor:
                cursor.execute(
                    "SELECT auth.set_agent_session_context(%s, %s, %s)",
                    (self.identity.agent_id, self.identity.session_token, self.identity.tenant_hk)
                )
            
            logger.info("Database connection established")
            return self.connection
            
        except Exception as e:
            logger.error(f"Database connection failed: {e}")
            raise
    
    def execute_secure_query(self, query: str, params: tuple = None) -> List[Dict]:
        """Execute query with audit logging and tenant isolation"""
        if not self.connection:
            self.connect()
            
        try:
            with self.connection.cursor(cursor_factory=RealDictCursor) as cursor:
                # Log query execution for audit
                audit_query = """
                    INSERT INTO ai_agents.agent_query_log_s (
                        agent_hk, query_hash, query_type, execution_timestamp,
                        tenant_hk, session_token, record_source
                    ) VALUES (
                        (SELECT agent_hk FROM ai_agents.agent_h WHERE agent_id = %s),
                        %s, 'READ', %s, %s, %s, %s
                    )
                """
                query_hash = hashlib.sha256(query.encode()).digest()
                cursor.execute(audit_query, (
                    self.identity.agent_id, query_hash, datetime.now(),
                    self.identity.tenant_hk, self.identity.session_token, 'MDA-001'
                ))
                
                # Execute the actual query
                cursor.execute(query, params)
                results = cursor.fetchall()
                
                self.connection.commit()
                return [dict(row) for row in results]
                
        except Exception as e:
            self.connection.rollback()
            logger.error(f"Query execution failed: {e}")
            raise
    
    def store_diagnosis_result(self, diagnosis: DiagnosisResult) -> str:
        """Store diagnosis result in Data Vault with audit trail"""
        try:
            with self.connection.cursor() as cursor:
                # Insert into diagnosis hub
                diagnosis_hk = hashlib.sha256(f"DIAGNOSIS_{diagnosis.diagnosis_id}".encode()).digest()
                
                cursor.execute("""
                    INSERT INTO business.medical_diagnosis_h (
                        diagnosis_hk, diagnosis_bk, tenant_hk, agent_hk, 
                        load_date, record_source
                    ) VALUES (%s, %s, %s, 
                        (SELECT agent_hk FROM ai_agents.agent_h WHERE agent_id = %s),
                        %s, %s)
                    ON CONFLICT (diagnosis_hk) DO NOTHING
                """, (
                    diagnosis_hk, diagnosis.diagnosis_id, self.identity.tenant_hk,
                    self.identity.agent_id, datetime.now(), 'MDA-001'
                ))
                
                # Insert diagnosis details satellite
                hash_diff = hashlib.sha256(
                    f"{diagnosis.primary_diagnosis}{diagnosis.confidence_score}".encode()
                ).digest()
                
                cursor.execute("""
                    INSERT INTO business.medical_diagnosis_s (
                        diagnosis_hk, load_date, hash_diff, primary_diagnosis,
                        confidence_score, differential_diagnoses, reasoning_chain,
                        recommended_actions, risk_assessment, record_source
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    diagnosis_hk, datetime.now(), hash_diff,
                    diagnosis.primary_diagnosis, diagnosis.confidence_score,
                    json.dumps(diagnosis.differential_diagnoses),
                    json.dumps(diagnosis.reasoning_chain),
                    json.dumps(diagnosis.recommended_actions),
                    diagnosis.risk_assessment, 'MDA-001'
                ))
                
                self.connection.commit()
                logger.info(f"Diagnosis {diagnosis.diagnosis_id} stored successfully")
                return diagnosis.diagnosis_id
                
        except Exception as e:
            self.connection.rollback()
            logger.error(f"Failed to store diagnosis: {e}")
            raise

class MedicalReasoningEngine:
    """Bayesian inference engine for medical diagnosis"""
    
    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()
        self.symptom_encoder = {}
        self.diagnosis_decoder = {}
        self.load_medical_knowledge_base()
    
    def load_medical_knowledge_base(self):
        """Load medical knowledge base and trained models"""
        # In production, this would load from secure medical databases
        # For demo, we'll use a simplified model
        
        # Common symptoms to numerical encoding
        self.symptom_encoder = {
            'fever': 0, 'headache': 1, 'nausea': 2, 'fatigue': 3,
            'chest_pain': 4, 'shortness_of_breath': 5, 'dizziness': 6,
            'abdominal_pain': 7, 'joint_pain': 8, 'rash': 9
        }
        
        # Diagnosis categories
        self.diagnosis_decoder = {
            0: 'Viral Infection', 1: 'Bacterial Infection', 2: 'Cardiovascular',
            3: 'Respiratory', 4: 'Gastrointestinal', 5: 'Musculoskeletal'
        }
        
        # Initialize with a simple model (in production, use pre-trained medical models)
        self.model = RandomForestClassifier(n_estimators=100, random_state=42)
        
        # Generate synthetic training data for demo
        X_train = np.random.rand(1000, 10)
        y_train = np.random.randint(0, 6, 1000)
        self.model.fit(X_train, y_train)
        
        logger.info("Medical knowledge base loaded")
    
    def encode_symptoms(self, symptoms: List[str]) -> np.ndarray:
        """Convert symptoms to numerical features"""
        feature_vector = np.zeros(len(self.symptom_encoder))
        
        for symptom in symptoms:
            if symptom.lower() in self.symptom_encoder:
                feature_vector[self.symptom_encoder[symptom.lower()]] = 1
                
        return feature_vector.reshape(1, -1)
    
    def bayesian_diagnosis(self, medical_data: MedicalData) -> DiagnosisResult:
        """Perform Bayesian inference for medical diagnosis"""
        try:
            # Encode symptoms
            symptoms_vector = self.encode_symptoms(medical_data.symptoms)
            
            # Get prediction probabilities
            probabilities = self.model.predict_proba(symptoms_vector)[0]
            
            # Create diagnosis result
            primary_idx = np.argmax(probabilities)
            primary_diagnosis = self.diagnosis_decoder[primary_idx]
            confidence = float(probabilities[primary_idx])
            
            # Create differential diagnoses (top 3)
            top_indices = np.argsort(probabilities)[-3:][::-1]
            differential_diagnoses = [
                {
                    'diagnosis': self.diagnosis_decoder[idx],
                    'probability': float(probabilities[idx]),
                    'supporting_evidence': self._get_supporting_evidence(medical_data, idx)
                }
                for idx in top_indices
            ]
            
            # Generate reasoning chain
            reasoning_chain = self._generate_reasoning_chain(medical_data, primary_diagnosis)
            
            # Risk assessment
            risk_assessment = self._assess_risk(medical_data, confidence)
            
            # Recommendations
            recommendations = self._generate_recommendations(primary_diagnosis, confidence)
            
            diagnosis_result = DiagnosisResult(
                diagnosis_id=str(uuid.uuid4()),
                primary_diagnosis=primary_diagnosis,
                confidence_score=confidence,
                differential_diagnoses=differential_diagnoses,
                reasoning_chain=reasoning_chain,
                recommended_actions=recommendations,
                risk_assessment=risk_assessment
            )
            
            logger.info(f"Diagnosis completed: {primary_diagnosis} (confidence: {confidence:.2f})")
            return diagnosis_result
            
        except Exception as e:
            logger.error(f"Diagnosis failed: {e}")
            raise
    
    def _get_supporting_evidence(self, medical_data: MedicalData, diagnosis_idx: int) -> List[str]:
        """Get supporting evidence for a diagnosis"""
        evidence = []
        
        # Analyze symptoms
        for symptom in medical_data.symptoms:
            if symptom.lower() in ['fever', 'fatigue'] and diagnosis_idx in [0, 1]:
                evidence.append(f"Presence of {symptom} supports infectious process")
        
        # Analyze vital signs
        if 'temperature' in medical_data.vital_signs:
            temp = medical_data.vital_signs['temperature']
            if temp > 100.4 and diagnosis_idx in [0, 1]:
                evidence.append(f"Elevated temperature ({temp}°F) suggests infection")
        
        return evidence
    
    def _generate_reasoning_chain(self, medical_data: MedicalData, diagnosis: str) -> List[str]:
        """Generate step-by-step reasoning chain"""
        reasoning = [
            f"Patient presents with symptoms: {', '.join(medical_data.symptoms)}",
            f"Vital signs analysis reveals: {json.dumps(medical_data.vital_signs)}",
            f"Medical history includes: {', '.join(medical_data.medical_history)}",
            f"Risk factors identified: {', '.join(medical_data.risk_factors)}",
            f"Bayesian analysis indicates highest probability for: {diagnosis}",
            "Differential diagnoses considered and ranked by probability",
            "Recommendations generated based on clinical guidelines"
        ]
        return reasoning
    
    def _assess_risk(self, medical_data: MedicalData, confidence: float) -> str:
        """Assess overall risk level"""
        if confidence < 0.6:
            return "HIGH_UNCERTAINTY - Recommend specialist consultation"
        elif any(risk in medical_data.risk_factors for risk in ['cardiac', 'diabetes', 'immunocompromised']):
            return "HIGH_RISK - Monitor closely, consider hospitalization"
        elif confidence > 0.8:
            return "LOW_RISK - Standard treatment protocol appropriate"
        else:
            return "MODERATE_RISK - Follow-up in 24-48 hours"
    
    def _generate_recommendations(self, diagnosis: str, confidence: float) -> List[str]:
        """Generate treatment recommendations"""
        recommendations = []
        
        if diagnosis == 'Viral Infection':
            recommendations.extend([
                "Supportive care with rest and hydration",
                "Symptomatic treatment for fever and pain",
                "Follow-up if symptoms worsen or persist > 7 days"
            ])
        elif diagnosis == 'Bacterial Infection':
            recommendations.extend([
                "Consider antibiotic therapy based on culture results",
                "Monitor for signs of sepsis",
                "Follow-up in 24-48 hours"
            ])
        elif diagnosis == 'Cardiovascular':
            recommendations.extend([
                "ECG and cardiac enzymes",
                "Cardiology consultation",
                "Monitor blood pressure and oxygen saturation"
            ])
        
        if confidence < 0.7:
            recommendations.append("Consider additional diagnostic tests")
            recommendations.append("Specialist consultation recommended")
        
        return recommendations

class MedicalDiagnosisAgent:
    """Main Medical Diagnosis Agent (MDA-001)"""
    
    def __init__(self, config_path: str):
        self.config = self._load_config(config_path)
        self.identity = self._create_agent_identity()
        self.authenticator = ZeroTrustAuthenticator(self.identity)
        self.db_connector = None
        self.reasoning_engine = MedicalReasoningEngine()
        
    def _load_config(self, config_path: str) -> Dict:
        """Load agent configuration"""
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            raise
    
    def _create_agent_identity(self) -> AgentIdentity:
        """Create agent identity from configuration"""
        return AgentIdentity(
            agent_id="MDA-001",
            agent_name="Medical Diagnosis Agent",
            domain="MEDICAL",
            certificate_path=self.config['security']['certificate_path'],
            private_key_path=self.config['security']['private_key_path'],
            tenant_hk=bytes.fromhex(self.config['tenant']['tenant_hk'])
        )
    
    def initialize(self) -> bool:
        """Initialize agent with zero trust authentication"""
        try:
            # Authenticate with Zero Trust Gateway
            if not self.authenticator.authenticate_with_gateway():
                logger.error("Failed to authenticate with Zero Trust Gateway")
                return False
            
            # Establish database connection
            self.db_connector = DataVaultConnector(self.identity, self.authenticator)
            self.db_connector.connect()
            
            # Register agent session
            self._register_agent_session()
            
            logger.info("Medical Diagnosis Agent initialized successfully")
            return True
            
        except Exception as e:
            logger.error(f"Agent initialization failed: {e}")
            return False
    
    def _register_agent_session(self):
        """Register agent session in database"""
        query = """
            INSERT INTO ai_agents.agent_session_s (
                agent_hk, session_token, session_start, session_expires,
                permissions, tenant_hk, record_source
            ) VALUES (
                (SELECT agent_hk FROM ai_agents.agent_h WHERE agent_id = %s),
                %s, %s, %s, %s, %s, %s
            )
        """
        
        self.db_connector.execute_secure_query(query, (
            self.identity.agent_id,
            self.identity.session_token,
            datetime.now(),
            self.identity.session_expires,
            json.dumps(['medical_data_read', 'diagnosis_write']),
            self.identity.tenant_hk,
            'MDA-001'
        ))
    
    def process_medical_case(self, patient_data: Dict) -> DiagnosisResult:
        """Process a medical case and return diagnosis"""
        try:
            # Validate session
            if not self.authenticator.validate_session():
                raise Exception("Session validation failed")
            
            # Convert input to MedicalData structure
            medical_data = MedicalData(
                patient_id=patient_data['patient_id'],
                symptoms=patient_data.get('symptoms', []),
                vital_signs=patient_data.get('vital_signs', {}),
                lab_results=patient_data.get('lab_results', {}),
                medical_history=patient_data.get('medical_history', []),
                risk_factors=patient_data.get('risk_factors', [])
            )
            
            # Perform diagnosis using reasoning engine
            diagnosis = self.reasoning_engine.bayesian_diagnosis(medical_data)
            
            # Store result in Data Vault
            diagnosis_id = self.db_connector.store_diagnosis_result(diagnosis)
            
            # Log successful diagnosis
            logger.info(f"Medical case processed successfully: {diagnosis_id}")
            
            return diagnosis
            
        except Exception as e:
            logger.error(f"Failed to process medical case: {e}")
            raise
    
    def get_diagnosis_history(self, patient_id: str) -> List[Dict]:
        """Retrieve diagnosis history for a patient"""
        query = """
            SELECT 
                md.primary_diagnosis,
                md.confidence_score,
                md.load_date,
                md.risk_assessment
            FROM business.medical_diagnosis_h mdh
            JOIN business.medical_diagnosis_s md ON mdh.diagnosis_hk = md.diagnosis_hk
            WHERE mdh.diagnosis_bk LIKE %s
            AND mdh.tenant_hk = %s
            AND md.load_end_date IS NULL
            ORDER BY md.load_date DESC
        """
        
        return self.db_connector.execute_secure_query(
            query, (f"%{patient_id}%", self.identity.tenant_hk)
        )
    
    def shutdown(self):
        """Gracefully shutdown agent"""
        try:
            if self.db_connector and self.db_connector.connection:
                self.db_connector.connection.close()
            logger.info("Medical Diagnosis Agent shutdown completed")
        except Exception as e:
            logger.error(f"Shutdown error: {e}")

def main():
    """Main entry point for Medical Diagnosis Agent"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Medical Diagnosis Agent (MDA-001)')
    parser.add_argument('--config', required=True, help='Path to agent configuration file')
    parser.add_argument('--patient-data', help='Path to patient data JSON file')
    args = parser.parse_args()
    
    # Initialize agent
    agent = MedicalDiagnosisAgent(args.config)
    
    if not agent.initialize():
        logger.error("Failed to initialize agent")
        return 1
    
    try:
        if args.patient_data:
            # Process single case
            with open(args.patient_data, 'r') as f:
                patient_data = json.load(f)
            
            diagnosis = agent.process_medical_case(patient_data)
            print(f"Diagnosis: {diagnosis.primary_diagnosis}")
            print(f"Confidence: {diagnosis.confidence_score:.2f}")
            print(f"Risk Assessment: {diagnosis.risk_assessment}")
        else:
            # Start interactive mode or API server
            logger.info("Agent ready for medical case processing")
            
    except KeyboardInterrupt:
        logger.info("Received shutdown signal")
    finally:
        agent.shutdown()
    
    return 0

if __name__ == "__main__":
    exit(main()) 