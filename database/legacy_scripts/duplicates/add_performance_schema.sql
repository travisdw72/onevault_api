-- =====================================================
-- ONE BARN PERFORMANCE TRACKING SCHEMA
-- Data Vault 2.0 Implementation
-- =====================================================

-- Create performance schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS performance;
GRANT USAGE ON SCHEMA performance TO barn_user;

-- =====================================================
-- TRAINING SESSION MANAGEMENT
-- =====================================================

-- Training Session Hub
CREATE TABLE performance.training_session_h (
    training_session_hk BYTEA PRIMARY KEY,
    training_session_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(training_session_bk, tenant_hk)
);

-- Training Session Details Satellite
CREATE TABLE performance.training_session_details_s (
    training_session_hk BYTEA NOT NULL REFERENCES performance.training_session_h(training_session_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    session_date DATE NOT NULL,
    session_time TIME NOT NULL,
    duration_minutes INTEGER NOT NULL,
    session_type VARCHAR(100) NOT NULL, -- FLATWORK, JUMPING, TRAIL, LUNGING, GROUND_WORK
    discipline VARCHAR(100), -- DRESSAGE, JUMPING, WESTERN, TRAIL, etc.
    training_level VARCHAR(100), -- BEGINNER, INTERMEDIATE, ADVANCED, PROFESSIONAL
    location VARCHAR(255), -- Arena name, trail name, etc.
    weather_conditions VARCHAR(100),
    footing_conditions VARCHAR(100), -- GOOD, FAIR, POOR, WET, FROZEN
    trainer_name VARCHAR(255),
    assistant_trainer VARCHAR(255),
    session_focus TEXT, -- What was worked on
    exercises_performed TEXT[],
    goals_for_session TEXT,
    goals_achieved TEXT,
    areas_improved TEXT,
    areas_needing_work TEXT,
    horse_attitude VARCHAR(100), -- EAGER, WILLING, RESISTANT, TIRED, FRESH
    horse_energy_level VARCHAR(50), -- LOW, NORMAL, HIGH, VERY_HIGH
    horse_cooperation VARCHAR(50), -- EXCELLENT, GOOD, FAIR, POOR
    gait_quality JSONB, -- {"walk": "good", "trot": "excellent", "canter": "needs work"}
    technical_scores JSONB, -- Specific scores for movements/exercises
    overall_session_rating INTEGER CHECK (overall_session_rating BETWEEN 1 AND 10),
    trainer_satisfaction INTEGER CHECK (trainer_satisfaction BETWEEN 1 AND 10),
    horse_fitness_level INTEGER CHECK (horse_fitness_level BETWEEN 1 AND 10),
    session_notes TEXT,
    homework_assigned TEXT,
    next_session_focus TEXT,
    video_links TEXT[],
    photo_links TEXT[],
    equipment_used TEXT[],
    supplements_given TEXT[],
    injuries_noted TEXT,
    veterinary_concerns TEXT,
    farrier_concerns TEXT,
    created_by VARCHAR(255),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (training_session_hk, load_date)
);

-- =====================================================
-- COMPETITION MANAGEMENT
-- =====================================================

-- Competition Hub
CREATE TABLE performance.competition_h (
    competition_hk BYTEA PRIMARY KEY,
    competition_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(competition_bk, tenant_hk)
);

-- Competition Details Satellite
CREATE TABLE performance.competition_details_s (
    competition_hk BYTEA NOT NULL REFERENCES performance.competition_h(competition_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    competition_name VARCHAR(255) NOT NULL,
    competition_type VARCHAR(100) NOT NULL, -- SHOW, CLINIC, SCHOOLING, RATED, UNRATED
    discipline VARCHAR(100) NOT NULL, -- DRESSAGE, JUMPING, WESTERN, EVENTING, etc.
    competition_level VARCHAR(100), -- BEGINNER_NOVICE, NOVICE, TRAINING, PRELIMINARY, etc.
    governing_body VARCHAR(100), -- USEF, FEI, AQHA, etc.
    competition_date_start DATE NOT NULL,
    competition_date_end DATE NOT NULL,
    venue_name VARCHAR(255) NOT NULL,
    venue_address_street VARCHAR(255),
    venue_address_city VARCHAR(100),
    venue_address_state VARCHAR(50),
    venue_address_zip VARCHAR(20),
    venue_address_country VARCHAR(50),
    distance_from_barn INTEGER, -- Miles
    travel_time_hours DECIMAL(4,2),
    entry_deadline DATE,
    entry_fee DECIMAL(10,2),
    stall_fee DECIMAL(10,2),
    drug_fee DECIMAL(10,2),
    office_fee DECIMAL(10,2),
    total_fees DECIMAL(10,2),
    prize_money DECIMAL(10,2),
    weather_conditions VARCHAR(100),
    footing_conditions VARCHAR(100),
    competition_status VARCHAR(50) DEFAULT 'PLANNED', -- PLANNED, ENTERED, CONFIRMED, COMPLETED, CANCELLED, SCRATCHED
    entry_confirmation VARCHAR(100),
    stall_assignment VARCHAR(100),
    arrival_date DATE,
    departure_date DATE,
    transportation_arranged BOOLEAN DEFAULT false,
    transportation_cost DECIMAL(10,2),
    accommodation_needed BOOLEAN DEFAULT false,
    accommodation_cost DECIMAL(10,2),
    groom_required BOOLEAN DEFAULT false,
    special_requirements TEXT,
    notes TEXT,
    created_by VARCHAR(255),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (competition_hk, load_date)
);

-- Competition Results Satellite
CREATE TABLE performance.competition_result_s (
    competition_hk BYTEA NOT NULL REFERENCES performance.competition_h(competition_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    class_name VARCHAR(255) NOT NULL,
    class_number VARCHAR(50),
    division VARCHAR(100),
    section VARCHAR(100),
    ride_time TIME,
    order_of_go INTEGER,
    total_entries INTEGER,
    placement INTEGER,
    placement_suffix VARCHAR(10), -- st, nd, rd, th
    score DECIMAL(8,3),
    percentage DECIMAL(5,2),
    time_seconds DECIMAL(8,3),
    faults INTEGER,
    time_faults DECIMAL(5,2),
    elimination BOOLEAN DEFAULT false,
    elimination_reason TEXT,
    withdrawal BOOLEAN DEFAULT false,
    withdrawal_reason TEXT,
    prize_money_won DECIMAL(10,2),
    ribbon_color VARCHAR(50),
    points_earned DECIMAL(8,2),
    qualifying_score BOOLEAN DEFAULT false,
    personal_best BOOLEAN DEFAULT false,
    judge_names TEXT[],
    judge_scores JSONB, -- Individual judge scores
    judge_comments TEXT[],
    technical_scores JSONB, -- Breakdown of technical elements
    artistic_scores JSONB, -- Artistic/style scores
    penalty_details JSONB, -- Detailed penalty breakdown
    video_links TEXT[],
    photo_links TEXT[],
    performance_notes TEXT,
    areas_excelled TEXT,
    areas_for_improvement TEXT,
    horse_behavior_notes TEXT,
    equipment_issues TEXT,
    rider_satisfaction INTEGER CHECK (rider_satisfaction BETWEEN 1 AND 10),
    trainer_satisfaction INTEGER CHECK (trainer_satisfaction BETWEEN 1 AND 10),
    overall_performance_rating INTEGER CHECK (overall_performance_rating BETWEEN 1 AND 10),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (competition_hk, load_date, class_name)
);

-- =====================================================
-- PERFORMANCE GOALS & TRACKING
-- =====================================================

-- Performance Goal Hub
CREATE TABLE performance.performance_goal_h (
    performance_goal_hk BYTEA PRIMARY KEY,
    performance_goal_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    UNIQUE(performance_goal_bk, tenant_hk)
);

-- Performance Goal Details Satellite
CREATE TABLE performance.performance_goal_details_s (
    performance_goal_hk BYTEA NOT NULL REFERENCES performance.performance_goal_h(performance_goal_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    goal_name VARCHAR(255) NOT NULL,
    goal_type VARCHAR(100) NOT NULL, -- TRAINING, COMPETITION, FITNESS, BEHAVIOR
    goal_category VARCHAR(100), -- SHORT_TERM, LONG_TERM, SEASONAL, ANNUAL
    goal_description TEXT NOT NULL,
    target_date DATE,
    priority VARCHAR(50) DEFAULT 'MEDIUM', -- LOW, MEDIUM, HIGH, CRITICAL
    measurable_criteria TEXT,
    success_metrics JSONB,
    current_status VARCHAR(50) DEFAULT 'IN_PROGRESS', -- NOT_STARTED, IN_PROGRESS, COMPLETED, PAUSED, CANCELLED
    progress_percentage INTEGER DEFAULT 0 CHECK (progress_percentage BETWEEN 0 AND 100),
    milestones JSONB, -- Array of milestone objects
    obstacles_encountered TEXT,
    strategies_used TEXT,
    resources_needed TEXT,
    estimated_cost DECIMAL(10,2),
    actual_cost DECIMAL(10,2),
    completion_date DATE,
    outcome_achieved TEXT,
    lessons_learned TEXT,
    next_steps TEXT,
    created_by VARCHAR(255),
    assigned_to VARCHAR(255),
    last_reviewed_date DATE,
    next_review_date DATE,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (performance_goal_hk, load_date)
);

-- =====================================================
-- RELATIONSHIP LINKS
-- =====================================================

-- Horse-Training Session Link
CREATE TABLE performance.horse_training_l (
    link_horse_training_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    training_session_hk BYTEA NOT NULL REFERENCES performance.training_session_h(training_session_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Horse-Competition Link
CREATE TABLE performance.horse_competition_l (
    link_horse_competition_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    competition_hk BYTEA NOT NULL REFERENCES performance.competition_h(competition_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Horse-Performance Goal Link
CREATE TABLE performance.horse_performance_goal_l (
    link_horse_performance_goal_hk BYTEA PRIMARY KEY,
    horse_hk BYTEA NOT NULL REFERENCES equestrian.horse_h(horse_hk),
    performance_goal_hk BYTEA NOT NULL REFERENCES performance.performance_goal_h(performance_goal_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Trainer-Training Session Link
CREATE TABLE performance.trainer_training_session_l (
    link_trainer_training_session_hk BYTEA PRIMARY KEY,
    trainer_hk BYTEA NOT NULL REFERENCES equestrian.owner_h(trainer_hk), -- Reusing owner table for trainers
    training_session_hk BYTEA NOT NULL REFERENCES performance.training_session_h(training_session_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- =====================================================
-- PERFORMANCE ANALYTICS VIEWS
-- =====================================================

-- Training Progress Summary View
CREATE VIEW performance.training_progress_summary AS
SELECT 
    h.horse_hk,
    hd.registered_name,
    hd.barn_name,
    COUNT(ts.training_session_hk) as total_sessions,
    AVG(tsd.duration_minutes) as avg_session_duration,
    AVG(tsd.overall_session_rating) as avg_session_rating,
    AVG(tsd.trainer_satisfaction) as avg_trainer_satisfaction,
    AVG(tsd.horse_fitness_level) as avg_fitness_level,
    MAX(tsd.session_date) as last_training_date,
    COUNT(CASE WHEN tsd.session_date >= CURRENT_DATE - INTERVAL '30 days' THEN 1 END) as sessions_last_30_days,
    COUNT(CASE WHEN tsd.session_date >= CURRENT_DATE - INTERVAL '90 days' THEN 1 END) as sessions_last_90_days
FROM equestrian.horse_h h
JOIN equestrian.horse_details_s hd ON h.horse_hk = hd.horse_hk AND hd.load_end_date IS NULL
LEFT JOIN performance.horse_training_l htl ON h.horse_hk = htl.horse_hk
LEFT JOIN performance.training_session_h ts ON htl.training_session_hk = ts.training_session_hk
LEFT JOIN performance.training_session_details_s tsd ON ts.training_session_hk = tsd.training_session_hk AND tsd.load_end_date IS NULL
GROUP BY h.horse_hk, hd.registered_name, hd.barn_name;

-- Competition Performance Summary View
CREATE VIEW performance.competition_performance_summary AS
SELECT 
    h.horse_hk,
    hd.registered_name,
    hd.barn_name,
    COUNT(c.competition_hk) as total_competitions,
    COUNT(CASE WHEN cr.placement = 1 THEN 1 END) as first_place_wins,
    COUNT(CASE WHEN cr.placement <= 3 THEN 1 END) as top_three_finishes,
    COUNT(CASE WHEN cr.placement <= 6 THEN 1 END) as top_six_finishes,
    AVG(cr.score) as avg_score,
    AVG(cr.percentage) as avg_percentage,
    SUM(cr.prize_money_won) as total_prize_money,
    SUM(cr.points_earned) as total_points,
    MAX(cd.competition_date_start) as last_competition_date,
    COUNT(CASE WHEN cd.competition_date_start >= CURRENT_DATE - INTERVAL '365 days' THEN 1 END) as competitions_last_year
FROM equestrian.horse_h h
JOIN equestrian.horse_details_s hd ON h.horse_hk = hd.horse_hk AND hd.load_end_date IS NULL
LEFT JOIN performance.horse_competition_l hcl ON h.horse_hk = hcl.horse_hk
LEFT JOIN performance.competition_h c ON hcl.competition_hk = c.competition_hk
LEFT JOIN performance.competition_details_s cd ON c.competition_hk = cd.competition_hk AND cd.load_end_date IS NULL
LEFT JOIN performance.competition_result_s cr ON c.competition_hk = cr.competition_hk AND cr.load_end_date IS NULL
GROUP BY h.horse_hk, hd.registered_name, hd.barn_name;

-- =====================================================
-- REFERENCE DATA FOR PERFORMANCE TRACKING
-- =====================================================

-- Competition Types Reference
CREATE TABLE ref.competition_type_r (
    competition_type_code VARCHAR(20) PRIMARY KEY,
    competition_type_name VARCHAR(100) NOT NULL,
    discipline VARCHAR(100) NOT NULL,
    governing_body VARCHAR(100),
    typical_entry_fee_min DECIMAL(10,2),
    typical_entry_fee_max DECIMAL(10,2),
    qualification_required BOOLEAN DEFAULT false,
    points_available BOOLEAN DEFAULT false,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- Training Exercise Reference
CREATE TABLE ref.training_exercise_r (
    exercise_code VARCHAR(20) PRIMARY KEY,
    exercise_name VARCHAR(255) NOT NULL,
    exercise_category VARCHAR(100), -- FLATWORK, JUMPING, CONDITIONING, GROUND_WORK
    discipline VARCHAR(100),
    difficulty_level VARCHAR(50), -- BEGINNER, INTERMEDIATE, ADVANCED
    typical_duration INTEGER, -- Minutes
    equipment_needed TEXT[],
    description TEXT,
    benefits TEXT,
    prerequisites TEXT,
    safety_considerations TEXT,
    is_active BOOLEAN DEFAULT true,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Training session indexes
CREATE INDEX idx_training_session_h_session_bk_tenant ON performance.training_session_h(training_session_bk, tenant_hk);
CREATE INDEX idx_training_session_details_s_date ON performance.training_session_details_s(session_date) WHERE load_end_date IS NULL;
CREATE INDEX idx_training_session_details_s_type ON performance.training_session_details_s(session_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_training_session_details_s_discipline ON performance.training_session_details_s(discipline) WHERE load_end_date IS NULL;

-- Competition indexes
CREATE INDEX idx_competition_h_competition_bk_tenant ON performance.competition_h(competition_bk, tenant_hk);
CREATE INDEX idx_competition_details_s_date ON performance.competition_details_s(competition_date_start) WHERE load_end_date IS NULL;
CREATE INDEX idx_competition_details_s_type ON performance.competition_details_s(competition_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_competition_details_s_discipline ON performance.competition_details_s(discipline) WHERE load_end_date IS NULL;
CREATE INDEX idx_competition_result_s_placement ON performance.competition_result_s(placement) WHERE load_end_date IS NULL;

-- Performance goal indexes
CREATE INDEX idx_performance_goal_h_goal_bk_tenant ON performance.performance_goal_h(performance_goal_bk, tenant_hk);
CREATE INDEX idx_performance_goal_details_s_type ON performance.performance_goal_details_s(goal_type) WHERE load_end_date IS NULL;
CREATE INDEX idx_performance_goal_details_s_status ON performance.performance_goal_details_s(current_status) WHERE load_end_date IS NULL;
CREATE INDEX idx_performance_goal_details_s_target_date ON performance.performance_goal_details_s(target_date) WHERE load_end_date IS NULL;

-- Link table indexes
CREATE INDEX idx_horse_training_l_horse ON performance.horse_training_l(horse_hk);
CREATE INDEX idx_horse_training_l_training ON performance.horse_training_l(training_session_hk);
CREATE INDEX idx_horse_competition_l_horse ON performance.horse_competition_l(horse_hk);
CREATE INDEX idx_horse_competition_l_competition ON performance.horse_competition_l(competition_hk);
CREATE INDEX idx_horse_performance_goal_l_horse ON performance.horse_performance_goal_l(horse_hk);
CREATE INDEX idx_horse_performance_goal_l_goal ON performance.horse_performance_goal_l(performance_goal_hk);

-- =====================================================
-- INITIAL REFERENCE DATA
-- =====================================================

-- Insert common competition types
INSERT INTO ref.competition_type_r (competition_type_code, competition_type_name, discipline, governing_body, typical_entry_fee_min, typical_entry_fee_max, qualification_required, points_available, description) VALUES
('USEF_DRES', 'USEF Dressage Show', 'DRESSAGE', 'USEF', 35.00, 85.00, false, true, 'USEF recognized dressage competition'),
('USEF_HUNT', 'USEF Hunter Show', 'HUNTER', 'USEF', 25.00, 75.00, false, true, 'USEF recognized hunter competition'),
('USEF_JUMP', 'USEF Jumper Show', 'JUMPING', 'USEF', 30.00, 100.00, false, true, 'USEF recognized jumper competition'),
('SCHOOL_SHOW', 'Schooling Show', 'VARIOUS', 'LOCAL', 15.00, 40.00, false, false, 'Local schooling show for practice'),
('CLINIC', 'Training Clinic', 'VARIOUS', 'PRIVATE', 75.00, 300.00, false, false, 'Educational training clinic'),
('FEI_DRES', 'FEI Dressage', 'DRESSAGE', 'FEI', 100.00, 500.00, true, true, 'FEI international dressage competition');

-- Insert common training exercises
INSERT INTO ref.training_exercise_r (exercise_code, exercise_name, exercise_category, discipline, difficulty_level, typical_duration, equipment_needed, description, benefits) VALUES
('FLAT_BASIC', 'Basic Flatwork', 'FLATWORK', 'ALL', 'BEGINNER', 30, ARRAY['Arena'], 'Walk, trot, canter work focusing on rhythm and balance', 'Improves basic gaits and rider position'),
('FLAT_LATERAL', 'Lateral Work', 'FLATWORK', 'DRESSAGE', 'INTERMEDIATE', 45, ARRAY['Arena'], 'Leg yield, shoulder-in, haunches-in exercises', 'Develops suppleness and engagement'),
('JUMP_GRID', 'Grid Work', 'JUMPING', 'JUMPING', 'INTERMEDIATE', 30, ARRAY['Poles', 'Standards', 'Arena'], 'Series of small jumps in a line', 'Improves horse technique and rider timing'),
('JUMP_COURSE', 'Course Work', 'JUMPING', 'JUMPING', 'ADVANCED', 45, ARRAY['Full jump course', 'Arena'], 'Complete jumping course with multiple obstacles', 'Develops competition skills and stamina'),
('LUNGE_BASIC', 'Basic Lunging', 'GROUND_WORK', 'ALL', 'BEGINNER', 20, ARRAY['Lunge line', 'Whip', 'Round pen or arena'], 'Basic lunging for exercise and training', 'Builds fitness and obedience without rider weight'),
('TRAIL_RIDE', 'Trail Riding', 'CONDITIONING', 'ALL', 'BEGINNER', 60, ARRAY['Trail access'], 'Outdoor trail riding for fitness and mental stimulation', 'Improves fitness and provides mental variety');

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA performance TO barn_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA performance TO barn_user;

-- Success message
SELECT 'Performance Tracking Schema Successfully Created!' as status; 