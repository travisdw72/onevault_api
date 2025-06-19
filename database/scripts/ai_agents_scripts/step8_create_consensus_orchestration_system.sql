-- ==========================================
-- ZERO TRUST AI AGENTS - STEP 8
-- Create Consensus and Orchestration System
-- Byzantine Fault Tolerance and Multi-Agent Coordination
-- ==========================================

BEGIN;

-- ==========================================
-- ORCHESTRATION SESSION MANAGEMENT
-- ==========================================

-- Orchestration Session Hub
CREATE TABLE ai_agents.orchestration_session_h (
    orchestration_hk BYTEA PRIMARY KEY,          -- SHA-256(session_id + tenant_hk)
    orchestration_bk VARCHAR(255) NOT NULL,     -- Orchestration business key
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Orchestration Session Details Satellite
CREATE TABLE ai_agents.orchestration_session_s (
    orchestration_hk BYTEA NOT NULL REFERENCES ai_agents.orchestration_session_h(orchestration_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Session Configuration
    orchestrator_agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    session_name VARCHAR(200) NOT NULL,
    session_purpose TEXT NOT NULL,
    coordination_strategy VARCHAR(100) NOT NULL,  -- 'consensus', 'hierarchical', 'democratic', 'expert_system'
    
    -- Session Timeline
    session_start TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    session_end TIMESTAMP WITH TIME ZONE,
    planned_duration INTERVAL,
    actual_duration INTERVAL GENERATED ALWAYS AS (session_end - session_start) STORED,
    
    -- Participating Agents
    total_participants INTEGER NOT NULL,
    active_participants INTEGER,
    required_participants INTEGER NOT NULL,
    minimum_consensus_threshold DECIMAL(5,4) NOT NULL DEFAULT 0.67,
    
    -- Session Status
    session_status VARCHAR(50) NOT NULL DEFAULT 'initializing', -- 'initializing', 'active', 'consensus_pending', 'completed', 'failed', 'timeout'
    consensus_achieved BOOLEAN DEFAULT false,
    consensus_timestamp TIMESTAMP WITH TIME ZONE,
    consensus_quality DECIMAL(5,4),
    
    -- Security and Trust
    session_security_level VARCHAR(50) NOT NULL, -- 'standard', 'high', 'maximum'
    zero_trust_verification BOOLEAN NOT NULL DEFAULT true,
    encryption_required BOOLEAN NOT NULL DEFAULT true,
    audit_level VARCHAR(50) NOT NULL DEFAULT 'comprehensive',
    
    -- Decision Context
    decision_domain VARCHAR(100) NOT NULL,        -- 'medical', 'equine', 'manufacturing', 'cross_domain'
    decision_complexity VARCHAR(50) NOT NULL,     -- 'simple', 'moderate', 'complex', 'highly_complex'
    decision_criticality VARCHAR(50) NOT NULL,    -- 'low', 'medium', 'high', 'critical'
    
    -- Results
    final_decision JSONB,
    decision_confidence DECIMAL(5,4),
    dissenting_opinions JSONB,
    decision_rationale TEXT,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (orchestration_hk, load_date)
);

-- ==========================================
-- PARTICIPANT MANAGEMENT
-- ==========================================

-- Orchestration Participant Link
CREATE TABLE ai_agents.orchestration_participant_l (
    participant_hk BYTEA PRIMARY KEY,            -- SHA-256(orchestration_hk + agent_hk)
    orchestration_hk BYTEA NOT NULL REFERENCES ai_agents.orchestration_session_h(orchestration_hk),
    agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Orchestration Participant Details Satellite
CREATE TABLE ai_agents.orchestration_participant_s (
    participant_hk BYTEA NOT NULL REFERENCES ai_agents.orchestration_participant_l(participant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Participant Role
    participant_role VARCHAR(100) NOT NULL,      -- 'primary', 'secondary', 'observer', 'validator', 'specialist'
    expertise_weight DECIMAL(5,4) NOT NULL DEFAULT 1.0, -- Weight of this agent's opinion
    voting_power DECIMAL(5,4) NOT NULL DEFAULT 1.0,
    
    -- Participation Status
    invitation_sent TIMESTAMP WITH TIME ZONE,
    participation_confirmed TIMESTAMP WITH TIME ZONE,
    participation_status VARCHAR(50) NOT NULL DEFAULT 'invited', -- 'invited', 'confirmed', 'active', 'disconnected', 'completed'
    
    -- Communication Details
    communication_channel VARCHAR(100),          -- How this agent communicates in session
    last_activity TIMESTAMP WITH TIME ZONE,
    messages_sent INTEGER DEFAULT 0,
    messages_received INTEGER DEFAULT 0,
    
    -- Performance Metrics
    response_time_avg_ms INTEGER,
    contribution_quality DECIMAL(5,4),
    reliability_score DECIMAL(5,4),
    
    -- Security Verification
    identity_verified BOOLEAN DEFAULT false,
    certificate_validated BOOLEAN DEFAULT false,
    behavioral_score_verified BOOLEAN DEFAULT false,
    security_clearance_level VARCHAR(50),
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (participant_hk, load_date)
);

-- ==========================================
-- CONSENSUS PROTOCOL IMPLEMENTATION
-- ==========================================

-- Consensus Round Hub
CREATE TABLE ai_agents.consensus_round_h (
    consensus_round_hk BYTEA PRIMARY KEY,        -- SHA-256(orchestration_hk + round_number)
    consensus_round_bk VARCHAR(255) NOT NULL,   -- Consensus round business key
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Consensus Round Details Satellite
CREATE TABLE ai_agents.consensus_round_s (
    consensus_round_hk BYTEA NOT NULL REFERENCES ai_agents.consensus_round_h(consensus_round_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Round Context
    orchestration_hk BYTEA NOT NULL REFERENCES ai_agents.orchestration_session_h(orchestration_hk),
    round_number INTEGER NOT NULL,
    round_type VARCHAR(50) NOT NULL,             -- 'proposal', 'voting', 'validation', 'finalization'
    
    -- Round Timeline
    round_start TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    round_end TIMESTAMP WITH TIME ZONE,
    round_timeout TIMESTAMP WITH TIME ZONE,
    round_duration INTERVAL GENERATED ALWAYS AS (round_end - round_start) STORED,
    
    -- Consensus Algorithm
    consensus_algorithm VARCHAR(100) NOT NULL,   -- 'pbft', 'raft', 'paxos', 'tendermint'
    algorithm_parameters JSONB,
    fault_tolerance_threshold INTEGER,            -- Maximum number of Byzantine faults tolerated
    
    -- Round Status
    round_status VARCHAR(50) NOT NULL DEFAULT 'active', -- 'active', 'completed', 'timeout', 'failed'
    consensus_achieved BOOLEAN DEFAULT false,
    votes_required INTEGER NOT NULL,
    votes_received INTEGER DEFAULT 0,
    byzantine_faults_detected INTEGER DEFAULT 0,
    
    -- Proposal Details
    proposal_data JSONB,
    proposal_hash BYTEA,                         -- Cryptographic hash of proposal
    proposer_agent_hk BYTEA REFERENCES ai_agents.agent_h(agent_hk),
    
    -- Voting Results
    votes_for INTEGER DEFAULT 0,
    votes_against INTEGER DEFAULT 0,
    votes_abstain INTEGER DEFAULT 0,
    consensus_percentage DECIMAL(5,2),
    
    -- Security and Verification
    cryptographic_proof BYTEA,                  -- Digital signature or proof
    verification_hash BYTEA,                    -- Hash for tamper detection
    merkle_root BYTEA,                          -- Merkle tree root for vote verification
    
    -- Quality Metrics
    participation_rate DECIMAL(5,4),
    decision_quality_score DECIMAL(5,4),
    time_to_consensus INTERVAL,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (consensus_round_hk, load_date)
);

-- ==========================================
-- VOTING MECHANISM
-- ==========================================

-- Vote Hub
CREATE TABLE ai_agents.vote_h (
    vote_hk BYTEA PRIMARY KEY,                   -- SHA-256(consensus_round_hk + agent_hk + vote_timestamp)
    vote_bk VARCHAR(255) NOT NULL,              -- Vote business key
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Vote Details Satellite
CREATE TABLE ai_agents.vote_s (
    vote_hk BYTEA NOT NULL REFERENCES ai_agents.vote_h(vote_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Vote Context
    consensus_round_hk BYTEA NOT NULL REFERENCES ai_agents.consensus_round_h(consensus_round_hk),
    voter_agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    
    -- Vote Details
    vote_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    vote_value VARCHAR(50) NOT NULL,             -- 'for', 'against', 'abstain', 'no_confidence'
    vote_weight DECIMAL(5,4) NOT NULL DEFAULT 1.0,
    vote_confidence DECIMAL(5,4) NOT NULL,
    
    -- Vote Rationale
    vote_reasoning TEXT,
    supporting_evidence JSONB,
    risk_assessment JSONB,
    alternative_proposals JSONB,
    
    -- Cryptographic Security
    vote_signature BYTEA NOT NULL,              -- Digital signature of vote
    vote_hash BYTEA NOT NULL,                   -- Hash of vote content
    signature_algorithm VARCHAR(50) NOT NULL DEFAULT 'RSA-SHA256',
    
    -- Verification Status
    signature_verified BOOLEAN DEFAULT false,
    timestamp_verified BOOLEAN DEFAULT false,
    agent_verified BOOLEAN DEFAULT false,
    vote_validity VARCHAR(50) DEFAULT 'pending', -- 'pending', 'valid', 'invalid', 'suspicious'
    
    -- Byzantine Fault Detection
    byzantine_behavior_detected BOOLEAN DEFAULT false,
    inconsistency_flags TEXT[],
    anomaly_score DECIMAL(5,4),
    
    -- Vote Impact
    influence_on_outcome DECIMAL(5,4),
    changed_decision BOOLEAN DEFAULT false,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (vote_hk, load_date)
);

-- ==========================================
-- DECISION EXECUTION TRACKING
-- ==========================================

-- Decision Execution Hub
CREATE TABLE ai_agents.decision_execution_h (
    execution_hk BYTEA PRIMARY KEY,              -- SHA-256(orchestration_hk + execution_timestamp)
    execution_bk VARCHAR(255) NOT NULL,         -- Execution business key
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Decision Execution Details Satellite
CREATE TABLE ai_agents.decision_execution_s (
    execution_hk BYTEA NOT NULL REFERENCES ai_agents.decision_execution_h(execution_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Execution Context
    orchestration_hk BYTEA NOT NULL REFERENCES ai_agents.orchestration_session_h(orchestration_hk),
    executor_agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    
    -- Decision Details
    decision_data JSONB NOT NULL,
    decision_hash BYTEA NOT NULL,
    consensus_proof BYTEA NOT NULL,              -- Proof of consensus from voting
    
    -- Execution Timeline
    execution_start TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    execution_end TIMESTAMP WITH TIME ZONE,
    planned_completion TIMESTAMP WITH TIME ZONE,
    execution_duration INTERVAL GENERATED ALWAYS AS (execution_end - execution_start) STORED,
    
    -- Execution Status
    execution_status VARCHAR(50) NOT NULL DEFAULT 'starting', -- 'starting', 'in_progress', 'completed', 'failed', 'partially_completed'
    completion_percentage DECIMAL(5,2) DEFAULT 0,
    
    -- Execution Steps
    total_steps INTEGER,
    completed_steps INTEGER DEFAULT 0,
    failed_steps INTEGER DEFAULT 0,
    execution_plan JSONB,
    step_results JSONB,
    
    -- Quality and Verification
    execution_quality DECIMAL(5,4),
    verification_required BOOLEAN DEFAULT true,
    verification_completed BOOLEAN DEFAULT false,
    verification_results JSONB,
    
    -- Impact Assessment
    business_impact JSONB,
    risk_mitigation_effectiveness DECIMAL(5,4),
    unexpected_consequences TEXT[],
    
    -- Audit and Compliance
    audit_trail JSONB NOT NULL,
    compliance_verified BOOLEAN DEFAULT false,
    regulatory_approval_required BOOLEAN DEFAULT false,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (execution_hk, load_date)
);

-- ==========================================
-- ORCHESTRATION FUNCTIONS
-- ==========================================

-- Function to initiate orchestration session
CREATE OR REPLACE FUNCTION ai_agents.initiate_orchestration_session(
    p_orchestrator_agent_hk BYTEA,
    p_session_name VARCHAR(200),
    p_session_purpose TEXT,
    p_decision_domain VARCHAR(100),
    p_participating_agents BYTEA[],
    p_consensus_threshold DECIMAL(5,4) DEFAULT 0.67
) RETURNS JSONB
SECURITY DEFINER
SET search_path = ai_agents, auth, audit
LANGUAGE plpgsql AS $$
DECLARE
    v_orchestration_hk BYTEA;
    v_tenant_hk BYTEA;
    v_agent_hk BYTEA;
    v_participant_hk BYTEA;
    i INTEGER;
BEGIN
    -- Get orchestrator tenant
    SELECT ais.tenant_hk INTO v_tenant_hk
    FROM ai_agents.agent_identity_s ais
    WHERE ais.agent_hk = p_orchestrator_agent_hk
    AND ais.load_end_date IS NULL
    LIMIT 1;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Orchestrator agent not found');
    END IF;
    
    -- Verify orchestrator has orchestration capability
    IF NOT EXISTS (
        SELECT 1 FROM ai_agents.agent_identity_s ais
        WHERE ais.agent_hk = p_orchestrator_agent_hk
        AND 'orchestration' = ANY(ais.allowed_data_types)
        AND ais.load_end_date IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Agent not authorized for orchestration');
    END IF;
    
    -- Generate orchestration session ID
    v_orchestration_hk := util.hash_binary(
        encode(p_orchestrator_agent_hk, 'hex') || p_session_name || CURRENT_TIMESTAMP::text
    );
    
    -- Insert orchestration session hub
    INSERT INTO ai_agents.orchestration_session_h VALUES (
        v_orchestration_hk,
        'ORCH_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS') || '_' || LEFT(p_session_name, 20),
        v_tenant_hk,
        util.current_load_date(),
        'orchestration_system'
    );
    
    -- Insert orchestration session details
    INSERT INTO ai_agents.orchestration_session_s VALUES (
        v_orchestration_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(encode(v_orchestration_hk, 'hex') || 'INITIALIZING'),
        p_orchestrator_agent_hk,
        p_session_name,
        p_session_purpose,
        'consensus', -- coordination strategy
        CURRENT_TIMESTAMP,
        NULL, -- session_end
        '2 hours'::INTERVAL, -- planned duration
        array_length(p_participating_agents, 1), -- total participants
        0, -- active participants
        GREATEST(1, array_length(p_participating_agents, 1) * 2 / 3), -- required participants (2/3 majority)
        p_consensus_threshold,
        'initializing',
        false, -- consensus achieved
        NULL, -- consensus timestamp
        NULL, -- consensus quality
        'high', -- session security level
        true, -- zero trust verification
        true, -- encryption required
        'comprehensive', -- audit level
        p_decision_domain,
        'moderate', -- decision complexity
        'medium', -- decision criticality
        NULL, -- final decision
        NULL, -- decision confidence
        NULL, -- dissenting opinions
        NULL, -- decision rationale
        'orchestration_system'
    );
    
    -- Add participants
    FOR i IN 1..array_length(p_participating_agents, 1) LOOP
        v_agent_hk := p_participating_agents[i];
        v_participant_hk := util.hash_binary(encode(v_orchestration_hk, 'hex') || encode(v_agent_hk, 'hex'));
        
        -- Insert participant link
        INSERT INTO ai_agents.orchestration_participant_l VALUES (
            v_participant_hk,
            v_orchestration_hk,
            v_agent_hk,
            v_tenant_hk,
            util.current_load_date(),
            'orchestration_system'
        );
        
        -- Insert participant details
        INSERT INTO ai_agents.orchestration_participant_s VALUES (
            v_participant_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(encode(v_participant_hk, 'hex') || 'INVITED'),
            'primary', -- participant role
            1.0, -- expertise weight
            1.0, -- voting power
            CURRENT_TIMESTAMP, -- invitation sent
            NULL, -- participation confirmed
            'invited',
            'secure_message_queue', -- communication channel
            NULL, -- last activity
            0, 0, -- messages sent/received
            NULL, NULL, NULL, -- performance metrics
            false, false, false, -- security verification
            'standard', -- security clearance
            'orchestration_system'
        );
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'orchestration_id', encode(v_orchestration_hk, 'hex'),
        'session_name', p_session_name,
        'total_participants', array_length(p_participating_agents, 1),
        'consensus_threshold', p_consensus_threshold,
        'status', 'initializing',
        'timestamp', CURRENT_TIMESTAMP
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to initiate orchestration session: ' || SQLERRM,
        'timestamp', CURRENT_TIMESTAMP
    );
END;
$$;

-- Function to conduct consensus round
CREATE OR REPLACE FUNCTION ai_agents.conduct_consensus_round(
    p_orchestration_hk BYTEA,
    p_proposal_data JSONB,
    p_round_type VARCHAR(50) DEFAULT 'voting',
    p_timeout_minutes INTEGER DEFAULT 30
) RETURNS JSONB
SECURITY DEFINER
SET search_path = ai_agents, auth, audit
LANGUAGE plpgsql AS $$
DECLARE
    v_round_hk BYTEA;
    v_tenant_hk BYTEA;
    v_round_number INTEGER;
    v_participants_count INTEGER;
    v_required_votes INTEGER;
BEGIN
    -- Get orchestration context
    SELECT os.tenant_hk INTO v_tenant_hk
    FROM ai_agents.orchestration_session_s os
    WHERE os.orchestration_hk = p_orchestration_hk
    AND os.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Orchestration session not found');
    END IF;
    
    -- Get next round number
    SELECT COALESCE(MAX(crs.round_number), 0) + 1 INTO v_round_number
    FROM ai_agents.consensus_round_s crs
    JOIN ai_agents.consensus_round_h crh ON crs.consensus_round_hk = crh.consensus_round_hk
    WHERE crs.orchestration_hk = p_orchestration_hk
    AND crs.load_end_date IS NULL;
    
    -- Count active participants
    SELECT COUNT(*) INTO v_participants_count
    FROM ai_agents.orchestration_participant_s ops
    WHERE ops.participant_hk IN (
        SELECT opl.participant_hk 
        FROM ai_agents.orchestration_participant_l opl 
        WHERE opl.orchestration_hk = p_orchestration_hk
    )
    AND ops.participation_status = 'active'
    AND ops.load_end_date IS NULL;
    
    v_required_votes := GREATEST(1, v_participants_count * 2 / 3); -- 2/3 majority
    
    -- Generate consensus round ID
    v_round_hk := util.hash_binary(
        encode(p_orchestration_hk, 'hex') || v_round_number::text || CURRENT_TIMESTAMP::text
    );
    
    -- Insert consensus round hub
    INSERT INTO ai_agents.consensus_round_h VALUES (
        v_round_hk,
        'ROUND_' || v_round_number || '_' || to_char(CURRENT_TIMESTAMP, 'HH24MISS'),
        v_tenant_hk,
        util.current_load_date(),
        'consensus_system'
    );
    
    -- Insert consensus round details
    INSERT INTO ai_agents.consensus_round_s VALUES (
        v_round_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(encode(v_round_hk, 'hex') || 'ACTIVE'),
        p_orchestration_hk,
        v_round_number,
        p_round_type,
        CURRENT_TIMESTAMP,
        NULL, -- round_end
        CURRENT_TIMESTAMP + (p_timeout_minutes || ' minutes')::INTERVAL, -- timeout
        'pbft', -- consensus algorithm (Practical Byzantine Fault Tolerance)
        jsonb_build_object('timeout_minutes', p_timeout_minutes, 'required_majority', 0.67),
        v_participants_count / 3, -- Byzantine fault tolerance (f = n/3)
        'active',
        false, -- consensus achieved
        v_required_votes,
        0, -- votes received
        0, -- byzantine faults detected
        p_proposal_data,
        util.hash_binary(p_proposal_data::text), -- proposal hash
        NULL, -- proposer (could be set if known)
        0, 0, 0, -- votes for/against/abstain
        0, -- consensus percentage
        NULL, NULL, NULL, -- cryptographic fields (would be populated by crypto system)
        0, -- participation rate
        NULL, -- decision quality score
        NULL, -- time to consensus
        'consensus_system'
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'round_id', encode(v_round_hk, 'hex'),
        'round_number', v_round_number,
        'round_type', p_round_type,
        'participants_count', v_participants_count,
        'required_votes', v_required_votes,
        'timeout', CURRENT_TIMESTAMP + (p_timeout_minutes || ' minutes')::INTERVAL,
        'proposal_hash', encode(util.hash_binary(p_proposal_data::text), 'hex'),
        'status', 'active',
        'timestamp', CURRENT_TIMESTAMP
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to conduct consensus round: ' || SQLERRM,
        'timestamp', CURRENT_TIMESTAMP
    );
END;
$$;

-- Create indexes for performance
CREATE INDEX idx_orchestration_session_h_tenant_hk ON ai_agents.orchestration_session_h(tenant_hk);
CREATE INDEX idx_orchestration_session_s_orchestrator ON ai_agents.orchestration_session_s(orchestrator_agent_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_orchestration_session_s_status ON ai_agents.orchestration_session_s(session_status) WHERE load_end_date IS NULL;
CREATE INDEX idx_orchestration_session_s_consensus ON ai_agents.orchestration_session_s(consensus_achieved) WHERE load_end_date IS NULL;
CREATE INDEX idx_orchestration_participant_l_orchestration ON ai_agents.orchestration_participant_l(orchestration_hk);
CREATE INDEX idx_orchestration_participant_l_agent ON ai_agents.orchestration_participant_l(agent_hk);
CREATE INDEX idx_orchestration_participant_s_status ON ai_agents.orchestration_participant_s(participation_status) WHERE load_end_date IS NULL;
CREATE INDEX idx_consensus_round_h_tenant_hk ON ai_agents.consensus_round_h(tenant_hk);
CREATE INDEX idx_consensus_round_s_orchestration ON ai_agents.consensus_round_s(orchestration_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_consensus_round_s_status ON ai_agents.consensus_round_s(round_status) WHERE load_end_date IS NULL;
CREATE INDEX idx_consensus_round_s_consensus ON ai_agents.consensus_round_s(consensus_achieved) WHERE load_end_date IS NULL;
CREATE INDEX idx_vote_h_tenant_hk ON ai_agents.vote_h(tenant_hk);
CREATE INDEX idx_vote_s_round ON ai_agents.vote_s(consensus_round_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_vote_s_voter ON ai_agents.vote_s(voter_agent_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_vote_s_validity ON ai_agents.vote_s(vote_validity) WHERE load_end_date IS NULL;
CREATE INDEX idx_decision_execution_h_tenant_hk ON ai_agents.decision_execution_h(tenant_hk);
CREATE INDEX idx_decision_execution_s_orchestration ON ai_agents.decision_execution_s(orchestration_hk) WHERE load_end_date IS NULL;
CREATE INDEX idx_decision_execution_s_status ON ai_agents.decision_execution_s(execution_status) WHERE load_end_date IS NULL;

-- Comments
COMMENT ON TABLE ai_agents.orchestration_session_h IS 'Hub table for multi-agent orchestration sessions with consensus mechanisms';
COMMENT ON TABLE ai_agents.orchestration_session_s IS 'Orchestration session details including consensus configuration and results';
COMMENT ON TABLE ai_agents.orchestration_participant_l IS 'Link table for agents participating in orchestration sessions';
COMMENT ON TABLE ai_agents.orchestration_participant_s IS 'Participant details including roles, weights, and performance metrics';
COMMENT ON TABLE ai_agents.consensus_round_h IS 'Hub table for consensus rounds within orchestration sessions';
COMMENT ON TABLE ai_agents.consensus_round_s IS 'Consensus round details with Byzantine Fault Tolerance protocols';
COMMENT ON TABLE ai_agents.vote_h IS 'Hub table for individual votes in consensus rounds';
COMMENT ON TABLE ai_agents.vote_s IS 'Vote details with cryptographic signatures and Byzantine fault detection';
COMMENT ON TABLE ai_agents.decision_execution_h IS 'Hub table for tracking execution of consensus decisions';
COMMENT ON TABLE ai_agents.decision_execution_s IS 'Decision execution details including progress tracking and impact assessment';

COMMENT ON FUNCTION ai_agents.initiate_orchestration_session IS 'Initiates a new multi-agent orchestration session with consensus protocols';
COMMENT ON FUNCTION ai_agents.conduct_consensus_round IS 'Conducts a consensus voting round with Byzantine Fault Tolerance';

COMMIT; 