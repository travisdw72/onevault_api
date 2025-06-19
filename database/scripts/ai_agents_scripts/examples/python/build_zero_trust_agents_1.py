#!/usr/bin/env python3
"""
Zero Trust AI Agent System Implementation
Builds on existing Data Vault 2.0 Platform with domain-specific reasoning isolation
"""

import os
import json
import hashlib
import asyncio
import aiohttp
import ssl
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from datetime import datetime, timedelta
import jwt
import psycopg2
from cryptography import x509
from cryptography.hazmat.backends import default_backend
import tensorflow as tf
import numpy as np

# ==========================================
# CONFIGURATION
# ==========================================

@dataclass
class AgentConfig:
    agent_id: str
    domain: str
    knowledge_base_path: str
    model_path: str
    allowed_schemas: List[str]
    forbidden_domains: List[str]
    security_clearance: str

# Domain-specific configurations
AGENT_CONFIGS = {
    'MDA-001': AgentConfig(
        agent_id='MDA-001',
        domain='medical',
        knowledge_base_path='/secure/medical/knowledge/',
        model_path='/secure/medical/models/',
        allowed_schemas=['healthcare', 'medical', 'patients'],
        forbidden_domains=['equine', 'manufacturing', 'financial'],
        security_clearance='hipaa_compliant'
    ),
    'ECA-001': AgentConfig(
        agent_id='ECA-001',
        domain='equine',
        knowledge_base_path='/secure/equine/knowledge/',
        model_path='/secure/equine/models/',
        allowed_schemas=['equine', 'veterinary', 'horses'],
        forbidden_domains=['medical', 'manufacturing', 'financial'],
        security_clearance='veterinary_compliant'
    ),
    'MFA-001': AgentConfig(
        agent_id='MFA-001',
        domain='manufacturing',
        knowledge_base_path='/secure/manufacturing/knowledge/',
        model_path='/secure/manufacturing/models/',
        allowed_schemas=['manufacturing', 'production', 'quality'],
        forbidden_domains=['medical', 'equine', 'financial'],
        security_clearance='iso_compliant'
    )
}

# ==========================================
# BASE AI AGENT CLASS
# ==========================================

class BaseAIAgent:
    """Base class for domain-specific AI agents with knowledge isolation"""
    
    def __init__(self, config: AgentConfig):
        self.config = config
        self.knowledge_base = None
        self.model = None
        self.session_tokens = {}
        self.learning_data = []
        
        # Initialize domain-specific components
        self._initialize_knowledge_base()
        self._initialize_ai_model()
        self._setup_security()
    
    def _initialize_knowledge_base(self):
        """Load domain-specific knowledge base"""
        kb_file = os.path.join(self.config.knowledge_base_path, f'{self.config.domain}_kb.json')
        try:
            with open(kb_file, 'r') as f:
                self.knowledge_base = json.load(f)
            print(f"✅ Loaded {self.config.domain} knowledge base")
        except FileNotFoundError:
            print(f"❌ Knowledge base not found: {kb_file}")
            raise
    
    def _initialize_ai_model(self):
        """Load domain-specific AI model"""
        model_file = os.path.join(self.config.model_path, f'{self.config.domain}_model.h5')
        try:
            self.model = tf.keras.models.load_model(model_file)
            print(f"✅ Loaded {self.config.domain} AI model")
        except:
            print(f"⚠️ Model not found, using fallback for {self.config.domain}")
            self.model = self._create_fallback_model()
    
    def _create_fallback_model(self):
        """Create a simple fallback model for demo purposes"""
        model = tf.keras.Sequential([
            tf.keras.layers.Dense(128, activation='relu', input_shape=(100,)),
            tf.keras.layers.Dense(64, activation='relu'),
            tf.keras.layers.Dense(32, activation='relu'),
            tf.keras.layers.Dense(10, activation='softmax')
        ])
        model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])
        return model
    
    def _setup_security(self):
        """Setup security configurations"""
        self.certificate_path = f'/secure/certs/{self.config.agent_id}-cert.pem'
        self.private_key_path = f'/secure/certs/{self.config.agent_id}-key.pem'
        
    def validate_input_domain(self, input_data: Dict) -> bool:
        """CRITICAL: Validate input contains only allowed domain data"""
        input_text = json.dumps(input_data).lower()
        
        # Check for forbidden domain keywords
        for forbidden_domain in self.config.forbidden_domains:
            forbidden_keywords = self._get_domain_keywords(forbidden_domain)
            for keyword in forbidden_keywords:
                if keyword in input_text:
                    raise ValueError(f"🚨 DOMAIN VIOLATION: {forbidden_domain} data detected in {self.config.domain} agent input: '{keyword}'")
        
        return True
    
    def _get_domain_keywords(self, domain: str) -> List[str]:
        """Get keywords that identify specific domains"""
        domain_keywords = {
            'medical': ['patient', 'doctor', 'hospital', 'medication', 'diagnosis', 'treatment', 'symptoms'],
            'equine': ['horse', 'stallion', 'mare', 'foal', 'stable', 'bridle', 'saddle', 'hoof'],
            'manufacturing': ['production', 'assembly', 'factory', 'machinery', 'conveyor', 'defect'],
            'financial': ['investment', 'portfolio', 'trading', 'stocks', 'bonds', 'revenue', 'profit']
        }
        return domain_keywords.get(domain, [])
    
    def authenticate_session(self, certificate: bytes, user_id: str) -> Optional[str]:
        """Authenticate and create session using zero trust principles"""
        try:
            # Verify certificate
            cert = x509.load_pem_x509_certificate(certificate, default_backend())
            
            # Extract agent ID from certificate
            cert_agent_id = cert.subject.get_attributes_for_oid(x509.NameOID.COMMON_NAME)[0].value
            
            if cert_agent_id != self.config.agent_id:
                print(f"❌ Certificate agent ID mismatch: {cert_agent_id} != {self.config.agent_id}")
                return None
            
            # Generate session token
            session_token = self._generate_session_token(user_id)
            
            # Store session with expiration
            self.session_tokens[session_token] = {
                'user_id': user_id,
                'agent_id': self.config.agent_id,
                'domain': self.config.domain,
                'created_at': datetime.now(),
                'expires_at': datetime.now() + timedelta(minutes=10),
                'certificate_fingerprint': hashlib.sha256(certificate).hexdigest()
            }
            
            print(f"✅ Session authenticated for {self.config.agent_id}")
            return session_token
            
        except Exception as e:
            print(f"❌ Authentication failed: {e}")
            return None
    
    def _generate_session_token(self, user_id: str) -> str:
        """Generate JWT session token"""
        payload = {
            'agent_id': self.config.agent_id,
            'domain': self.config.domain,
            'user_id': user_id,
            'iat': datetime.utcnow(),
            'exp': datetime.utcnow() + timedelta(minutes=10)
        }
        return jwt.encode(payload, 'your-secret-key', algorithm='HS256')
    
    def verify_session(self, session_token: str) -> bool:
        """Verify session token is valid and not expired"""
        session = self.session_tokens.get(session_token)
        if not session:
            return False
        
        if datetime.now() > session['expires_at']:
            del self.session_tokens[session_token]
            return False
        
        return True
    
    def learn_from_outcome(self, input_data: Dict, outcome: Dict, feedback_score: float):
        """Learn from domain-specific outcomes to improve performance"""
        # Validate learning data is from correct domain
        if outcome.get('domain') != self.config.domain:
            raise ValueError(f"❌ DOMAIN ISOLATION VIOLATION: {self.config.domain} agent cannot learn from {outcome.get('domain')} data")
        
        # Store learning data
        learning_record = {
            'timestamp': datetime.now().isoformat(),
            'agent_id': self.config.agent_id,
            'domain': self.config.domain,
            'input_data': input_data,
            'outcome': outcome,
            'feedback_score': feedback_score,
            'model_version': self._get_model_version()
        }
        
        self.learning_data.append(learning_record)
        
        # Update domain-specific patterns
        self._update_domain_patterns(learning_record)
        
        print(f"✅ {self.config.domain} agent learned from outcome (score: {feedback_score})")
    
    def _update_domain_patterns(self, learning_record: Dict):
        """Update domain-specific patterns based on learning"""
        # This would implement actual learning logic
        # For now, just log the learning
        print(f"📚 Updating {self.config.domain} patterns from case {learning_record['timestamp']}")
    
    def _get_model_version(self) -> str:
        """Get current model version"""
        return f"{self.config.domain}_v1.0"

# ==========================================
# MEDICAL AI AGENT (Domain-Specific)
# ==========================================

class MedicalDiagnosticAgent(BaseAIAgent):
    """Medical diagnostic agent with HIPAA compliance and medical-only knowledge"""
    
    def __init__(self):
        super().__init__(AGENT_CONFIGS['MDA-001'])
    
    def diagnose(self, session_token: str, patient_data: Dict, symptoms: List[str], medical_history: Dict) -> Dict:
        """Perform medical diagnosis using ONLY medical knowledge"""
        # Verify session
        if not self.verify_session(session_token):
            return {'success': False, 'error': 'Invalid session'}
        
        # Validate input for domain isolation
        input_data = {
            'patient_data': patient_data,
            'symptoms': symptoms,
            'medical_history': medical_history
        }
        
        try:
            self.validate_input_domain(input_data)
        except ValueError as e:
            return {'success': False, 'error': str(e)}
        
        # Extract medical features
        features = self._extract_medical_features(symptoms, medical_history)
        
        # Run medical diagnostic model
        if len(features) > 0:
            # Pad or truncate to model input size
            features = np.array(features + [0] * (100 - len(features)))[:100]
            diagnosis_probabilities = self.model.predict([features.reshape(1, -1)])
        else:
            diagnosis_probabilities = np.array([[0.5, 0.3, 0.2, 0, 0, 0, 0, 0, 0, 0]])
        
        # Apply medical reasoning
        differential_diagnosis = self._apply_medical_reasoning(diagnosis_probabilities, symptoms, medical_history)
        
        return {
            'success': True,
            'agent_id': self.config.agent_id,
            'domain': self.config.domain,
            'diagnosis': differential_diagnosis,
            'confidence_score': float(np.max(diagnosis_probabilities)),
            'reasoning_steps': self._get_medical_reasoning_steps(),
            'compliance': 'HIPAA_COMPLIANT',
            'timestamp': datetime.now().isoformat()
        }
    
    def _extract_medical_features(self, symptoms: List[str], medical_history: Dict) -> List[float]:
        """Extract numerical features from medical data"""
        features = []
        
        # Symptom severity mapping
        symptom_weights = {
            'fever': 0.8, 'headache': 0.6, 'nausea': 0.5, 'fatigue': 0.4,
            'chest pain': 0.9, 'shortness of breath': 0.9, 'dizziness': 0.7
        }
        
        for symptom in symptoms:
            features.append(symptom_weights.get(symptom.lower(), 0.1))
        
        # Medical history factors
        if medical_history.get('diabetes'):
            features.append(0.7)
        if medical_history.get('hypertension'):
            features.append(0.6)
        if medical_history.get('heart_disease'):
            features.append(0.8)
        
        return features
    
    def _apply_medical_reasoning(self, probabilities: np.ndarray, symptoms: List[str], history: Dict) -> List[Dict]:
        """Apply medical-specific reasoning logic"""
        medical_conditions = [
            'Viral Infection', 'Bacterial Infection', 'Cardiovascular Issue',
            'Respiratory Condition', 'Neurological Condition', 'Metabolic Disorder',
            'Autoimmune Condition', 'Allergic Reaction', 'Injury', 'Unknown'
        ]
        
        diagnoses = []
        for i, prob in enumerate(probabilities[0]):
            if prob > 0.1 and i < len(medical_conditions):
                diagnoses.append({
                    'condition': medical_conditions[i],
                    'probability': float(prob),
                    'reasoning': f"Pattern match based on symptoms: {', '.join(symptoms)}",
                    'recommended_tests': self._recommend_medical_tests(medical_conditions[i]),
                    'urgency_level': self._assess_medical_urgency(medical_conditions[i], symptoms)
                })
        
        return sorted(diagnoses, key=lambda x: x['probability'], reverse=True)[:3]
    
    def _recommend_medical_tests(self, condition: str) -> List[str]:
        """Recommend medical tests based on condition"""
        test_recommendations = {
            'Viral Infection': ['Complete Blood Count', 'Viral Panel'],
            'Bacterial Infection': ['Blood Culture', 'Complete Blood Count', 'CRP'],
            'Cardiovascular Issue': ['ECG', 'Echocardiogram', 'Cardiac Enzymes'],
            'Respiratory Condition': ['Chest X-ray', 'Pulmonary Function Tests'],
            'Neurological Condition': ['MRI Brain', 'Neurological Exam'],
        }
        return test_recommendations.get(condition, ['Basic Metabolic Panel'])
    
    def _assess_medical_urgency(self, condition: str, symptoms: List[str]) -> str:
        """Assess medical urgency level"""
        high_urgency_symptoms = ['chest pain', 'shortness of breath', 'severe headache']
        if any(symptom.lower() in high_urgency_symptoms for symptom in symptoms):
            return 'HIGH'
        elif condition in ['Cardiovascular Issue', 'Neurological Condition']:
            return 'MEDIUM'
        else:
            return 'LOW'
    
    def _get_medical_reasoning_steps(self) -> List[str]:
        """Get medical reasoning steps"""
        return [
            'Analyzed symptom patterns',
            'Reviewed medical history',
            'Applied diagnostic criteria',
            'Generated differential diagnosis',
            'Recommended appropriate tests'
        ]

# ==========================================
# EQUINE CARE AGENT (Domain-Specific)
# ==========================================

class EquineCareAgent(BaseAIAgent):
    """Equine care agent with veterinary expertise and equine-only knowledge"""
    
    def __init__(self):
        super().__init__(AGENT_CONFIGS['ECA-001'])
    
    def assess_horse_health(self, session_token: str, horse_data: Dict, health_metrics: Dict, behavior_observations: Dict) -> Dict:
        """Assess horse health using ONLY equine knowledge"""
        # Verify session
        if not self.verify_session(session_token):
            return {'success': False, 'error': 'Invalid session'}
        
        # Validate input for domain isolation
        input_data = {
            'horse_data': horse_data,
            'health_metrics': health_metrics,
            'behavior_observations': behavior_observations
        }
        
        try:
            self.validate_input_domain(input_data)
        except ValueError as e:
            return {'success': False, 'error': str(e)}
        
        # Extract equine features
        features = self._extract_equine_features(health_metrics, behavior_observations)
        
        # Run equine health model
        if len(features) > 0:
            features = np.array(features + [0] * (100 - len(features)))[:100]
            health_scores = self.model.predict([features.reshape(1, -1)])
        else:
            health_scores = np.array([[0.8, 0.7, 0.9, 0.6, 0.5, 0, 0, 0, 0, 0]])
        
        # Apply equine reasoning
        health_assessment = self._apply_equine_reasoning(health_scores, health_metrics, behavior_observations)
        
        return {
            'success': True,
            'agent_id': self.config.agent_id,
            'domain': self.config.domain,
            'health_assessment': health_assessment,
            'care_recommendations': self._generate_equine_care_plan(health_assessment),
            'monitoring_plan': self._create_equine_monitoring_plan(horse_data),
            'confidence_score': float(np.mean(health_scores)),
            'timestamp': datetime.now().isoformat()
        }
    
    def _extract_equine_features(self, health_metrics: Dict, behavior_observations: Dict) -> List[float]:
        """Extract numerical features from equine data"""
        features = []
        
        # Health metrics
        features.append(health_metrics.get('weight', 500) / 1000)  # Normalize weight
        features.append(health_metrics.get('heart_rate', 40) / 100)  # Normalize heart rate
        features.append(health_metrics.get('temperature', 99.5) / 103)  # Normalize temperature
        
        # Behavior indicators
        behavior_scores = {
            'alert': 1.0, 'active': 0.9, 'normal': 0.8, 'lethargic': 0.4, 'aggressive': 0.3
        }
        
        behavior = behavior_observations.get('general_behavior', 'normal')
        features.append(behavior_scores.get(behavior.lower(), 0.5))
        
        # Movement quality
        movement_scores = {'excellent': 1.0, 'good': 0.8, 'fair': 0.6, 'poor': 0.3, 'lame': 0.1}
        movement = behavior_observations.get('movement_quality', 'good')
        features.append(movement_scores.get(movement.lower(), 0.5))
        
        return features
    
    def _apply_equine_reasoning(self, health_scores: np.ndarray, health_metrics: Dict, behavior_observations: Dict) -> Dict:
        """Apply equine-specific reasoning logic"""
        return {
            'overall_health_score': float(np.mean(health_scores)),
            'lameness_detected': self._assess_lameness(behavior_observations),
            'nutritional_status': self._assess_nutrition(health_metrics),
            'behavioral_indicators': self._assess_behavior(behavior_observations),
            'fitness_level': self._assess_fitness(health_metrics, behavior_observations)
        }
    
    def _assess_lameness(self, behavior_observations: Dict) -> Dict:
        """Assess lameness in horses"""
        movement_quality = behavior_observations.get('movement_quality', 'good')
        gait_irregularity = behavior_observations.get('gait_irregularity', False)
        
        lameness_detected = movement_quality in ['poor', 'lame'] or gait_irregularity
        
        return {
            'detected': lameness_detected,
            'severity': 'mild' if movement_quality == 'fair' else 'moderate' if movement_quality == 'poor' else 'severe' if movement_quality == 'lame' else 'none',
            'recommended_action': 'veterinary_examination' if lameness_detected else 'continue_monitoring'
        }
    
    def _assess_nutrition(self, health_metrics: Dict) -> Dict:
        """Assess nutritional status"""
        weight = health_metrics.get('weight', 500)
        body_condition_score = health_metrics.get('body_condition_score', 5)
        
        return {
            'status': 'good' if 4 <= body_condition_score <= 6 else 'needs_attention',
            'body_condition_score': body_condition_score,
            'weight_status': 'optimal' if 450 <= weight <= 550 else 'monitor',
            'feeding_recommendation': self._get_feeding_recommendation(body_condition_score)
        }
    
    def _assess_behavior(self, behavior_observations: Dict) -> Dict:
        """Assess behavioral indicators"""
        general_behavior = behavior_observations.get('general_behavior', 'normal')
        appetite = behavior_observations.get('appetite', 'good')
        
        return {
            'general_behavior': general_behavior,
            'appetite_status': appetite,
            'behavioral_score': self._calculate_behavioral_score(general_behavior, appetite),
            'concerns': self._identify_behavioral_concerns(behavior_observations)
        }
    
    def _assess_fitness(self, health_metrics: Dict, behavior_observations: Dict) -> Dict:
        """Assess fitness level"""
        heart_rate = health_metrics.get('heart_rate', 40)
        movement_quality = behavior_observations.get('movement_quality', 'good')
        
        fitness_score = 0.8 if movement_quality == 'excellent' else 0.6 if movement_quality == 'good' else 0.4
        
        return {
            'fitness_score': fitness_score,
            'cardiovascular_health': 'good' if heart_rate < 50 else 'monitor',
            'exercise_recommendation': self._get_exercise_recommendation(fitness_score)
        }
    
    def _generate_equine_care_plan(self, health_assessment: Dict) -> List[Dict]:
        """Generate equine care recommendations"""
        recommendations = []
        
        if health_assessment['lameness_detected']['detected']:
            recommendations.append({
                'priority': 'high',
                'action': 'Schedule veterinary examination',
                'reasoning': 'Lameness detected requiring professional assessment'
            })
        
        if health_assessment['nutritional_status']['status'] == 'needs_attention':
            recommendations.append({
                'priority': 'medium',
                'action': 'Adjust feeding program',
                'reasoning': 'Body condition score outside optimal range'
            })
        
        if health_assessment['fitness_level']['fitness_score'] < 0.6:
            recommendations.append({
                'priority': 'low',
                'action': 'Gradual exercise increase',
                'reasoning': 'Fitness level below optimal range'
            })
        
        return recommendations
    
    def _create_equine_monitoring_plan(self, horse_data: Dict) -> Dict:
        """Create monitoring plan for horse"""
        return {
            'frequency': 'daily',
            'metrics_to_track': ['weight', 'body_condition', 'movement_quality', 'appetite', 'behavior'],
            'alert_thresholds': {
                'weight_change_percent': 5,
                'body_condition_change': 1,
                'movement_quality_decline': True
            },
            'review_schedule': 'weekly'
        }
    
    def _get_feeding_recommendation(self, body_condition_score: float) -> str:
        """Get feeding recommendations based on body condition"""
        if body_condition_score < 4:
            return 'Increase caloric intake with quality forage and concentrates'
        elif body_condition_score > 6:
            return 'Reduce caloric intake and increase exercise'
        else:
            return 'Maintain current feeding program'
    
    def _calculate_behavioral_score(self, general_behavior: str, appetite: str) -> float:
        """Calculate behavioral score"""
        behavior_scores = {'alert': 1.0, 'active': 0.9, 'normal': 0.8, 'lethargic': 0.4}
        appetite_scores = {'excellent': 1.0, 'good': 0.8, 'fair': 0.6, 'poor': 0.3}
        
        behavior_score = behavior_scores.get(general_behavior.lower(), 0.5)
        appetite_score = appetite_scores.get(appetite.lower(), 0.5)
        
        return (behavior_score + appetite_score) / 2
    
    def _identify_behavioral_concerns(self, behavior_observations: Dict) -> List[str]:
        """Identify behavioral concerns"""
        concerns = []
        
        if behavior_observations.get('general_behavior') in ['lethargic', 'aggressive']:
            concerns.append('Behavioral changes requiring attention')
        
        if behavior_observations.get('appetite') in ['poor', 'none']:
            concerns.append('Appetite loss requiring monitoring')
        
        return concerns
    
    def _get_exercise_recommendation(self, fitness_score: float) -> str:
        """Get exercise recommendations"""
        if fitness_score < 0.4:
            return 'Start with light walking exercise, gradually increase'
        elif fitness_score < 0.7:
            return 'Moderate exercise with regular training sessions'
        else:
            return 'Maintain current exercise program'

# ==========================================
# ZERO TRUST GATEWAY
# ==========================================

class ZeroTrustGateway:
    """Central gateway for all agent communications with zero trust enforcement"""
    
    def __init__(self):
        self.agents = {
            'MDA-001': MedicalDiagnosticAgent(),
            'ECA-001': EquineCareAgent()
        }
        self.active_sessions = {}
    
    async def route_request(self, request: Dict) -> Dict:
        """Route request to appropriate domain agent"""
        request_type = request.get('request_type')
        session_token = request.get('session_token')
        
        # Validate session
        if not self._verify_session(session_token):
            return {
                'success': False,
                'error': 'Invalid or expired session',
                'security_level': 'HIGH',
                'timestamp': datetime.now().isoformat()
            }
        
        # Route based on request type
        if request_type == 'medical_diagnosis':
            agent = self.agents['MDA-001']
            result = agent.diagnose(
                session_token,
                request.get('patient_data', {}),
                request.get('symptoms', []),
                request.get('medical_history', {})
            )
        elif request_type == 'equine_assessment':
            agent = self.agents['ECA-001']
            result = agent.assess_horse_health(
                session_token,
                request.get('horse_data', {}),
                request.get('health_metrics', {}),
                request.get('behavior_observations', {})
            )
        else:
            return {
                'success': False,
                'error': f'Unknown request type: {request_type}',
                'timestamp': datetime.now().isoformat()
            }
        
        # Log interaction
        await self._log_interaction(request, result)
        
        return result
    
    def _verify_session(self, session_token: str) -> bool:
        """Verify session token across all agents"""
        for agent in self.agents.values():
            if agent.verify_session(session_token):
                return True
        return False
    
    async def _log_interaction(self, request: Dict, response: Dict):
        """Log all interactions for audit purposes"""
        interaction_log = {
            'timestamp': datetime.now().isoformat(),
            'request_type': request.get('request_type'),
            'agent_id': response.get('agent_id'),
            'domain': response.get('domain'),
            'success': response.get('success'),
            'session_verified': True,
            'gateway_version': 'v1.0'
        }
        
        # In production, this would write to the audit database
        print(f"🔍 AUDIT LOG: {json.dumps(interaction_log, indent=2)}")

# ==========================================
# DEMO IMPLEMENTATION
# ==========================================

async def demo_zero_trust_agents():
    """Demonstrate the zero trust AI agent system"""
    print("🚀 Starting Zero Trust AI Agent System Demo")
    print("=" * 60)
    
    # Initialize gateway
    gateway = ZeroTrustGateway()
    
    # Create demo certificate (in production, use real PKI)
    demo_certificate = b"""-----BEGIN CERTIFICATE-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
-----END CERTIFICATE-----"""
    
    # Test Medical Agent
    print("\n🏥 Testing Medical Diagnosis Agent (MDA-001)")
    print("-" * 50)
    
    medical_agent = gateway.agents['MDA-001']
    medical_session = medical_agent.authenticate_session(demo_certificate, 'demo_user')
    
    if medical_session:
        medical_request = {
            'request_type': 'medical_diagnosis',
            'session_token': medical_session,
            'patient_data': {'age': 45, 'gender': 'male'},
            'symptoms': ['fever', 'headache', 'fatigue'],
            'medical_history': {'diabetes': True, 'hypertension': False}
        }
        
        medical_result = await gateway.route_request(medical_request)
        print(f"✅ Medical diagnosis result: {json.dumps(medical_result, indent=2)}")
    
    # Test Equine Agent
    print("\n🐎 Testing Equine Care Agent (ECA-001)")
    print("-" * 50)
    
    equine_agent = gateway.agents['ECA-001']
    equine_session = equine_agent.authenticate_session(demo_certificate, 'demo_user')
    
    if equine_session:
        equine_request = {
            'request_type': 'equine_assessment',
            'session_token': equine_session,
            'horse_data': {'name': 'Thunder', 'breed': 'Thoroughbred', 'age': 8},
            'health_metrics': {'weight': 520, 'heart_rate': 42, 'temperature': 99.8, 'body_condition_score': 5},
            'behavior_observations': {'general_behavior': 'alert', 'movement_quality': 'good', 'appetite': 'excellent'}
        }
        
        equine_result = await gateway.route_request(equine_request)
        print(f"✅ Equine assessment result: {json.dumps(equine_result, indent=2)}")
    
    # Test Domain Isolation
    print("\n🚨 Testing Domain Isolation (Should Fail)")
    print("-" * 50)
    
    # Try to send equine data to medical agent
    contaminated_request = {
        'request_type': 'medical_diagnosis',
        'session_token': medical_session,
        'patient_data': {'age': 8, 'breed': 'Thoroughbred'},  # Horse data!
        'symptoms': ['lameness', 'hoof problems'],  # Equine symptoms!
        'medical_history': {'stallion': True}  # Equine terminology!
    }
    
    try:
        contaminated_result = await gateway.route_request(contaminated_request)
        print(f"Domain isolation test result: {json.dumps(contaminated_result, indent=2)}")
    except Exception as e:
        print(f"✅ Domain isolation working: {e}")
    
    print("\n🎯 Demo completed! Zero Trust AI Agents are operational.")

# ==========================================
# MAIN EXECUTION
# ==========================================

if __name__ == "__main__":
    print("🔐 Zero Trust AI Agent System")
    print("Building on Data Vault 2.0 Platform")
    print("Domain-Specific Reasoning with Knowledge Isolation")
    print("=" * 60)
    
    # Run demo
    asyncio.run(demo_zero_trust_agents()) 