-- =====================================================================================
-- Phase 4: Blocking Detection & Deadlock Analysis Functions
-- One Vault Multi-Tenant Data Vault 2.0 Platform
-- =====================================================================================

-- Function to detect and analyze blocking sessions
CREATE OR REPLACE FUNCTION lock_monitoring.detect_blocking_sessions(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_min_blocking_duration_seconds INTEGER DEFAULT 30
) RETURNS TABLE (
    blocking_session_id INTEGER,
    blocked_sessions_count INTEGER,
    blocking_duration_seconds INTEGER,
    blocking_severity VARCHAR(20),
    recommended_action TEXT
) AS $$
DECLARE
    v_blocking_record RECORD;
    v_blocking_session_hk BYTEA;
    v_blocking_session_bk VARCHAR(255);
    v_severity VARCHAR(20);
    v_impact_score DECIMAL(5,2);
    v_escalation_level INTEGER;
BEGIN
    -- Find sessions that are blocking others
    FOR v_blocking_record IN 
        WITH blocking_analysis AS (
            SELECT 
                blocking.pid as blocking_pid,
                blocking.usename as blocking_user,
                blocking.datname as blocking_database,
                blocking.application_name,
                blocking.client_addr,
                blocking.client_hostname,
                blocking.state,
                blocking.query as blocking_query,
                blocking.query_start,
                blocking.xact_start,
                blocking.state_change,
                blocking.backend_type,
                COUNT(blocked.pid) as blocked_sessions_count,
                array_agg(blocked.pid) as blocked_pids,
                array_agg(blocked.query) as blocked_queries,
                MAX(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - COALESCE(blocked.query_start, blocked.xact_start)))::INTEGER) as max_blocked_duration,
                AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - COALESCE(blocked.query_start, blocked.xact_start)))::INTEGER) as avg_blocked_duration,
                EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - COALESCE(blocking.query_start, blocking.xact_start)))::INTEGER as blocking_duration,
                COUNT(DISTINCT blocked.usename) as distinct_blocked_users,
                COUNT(*) FILTER (WHERE bl.mode IN ('AccessExclusiveLock', 'ExclusiveLock')) as exclusive_locks_held
            FROM pg_stat_activity blocking
            JOIN pg_locks bl ON blocking.pid = bl.pid AND bl.granted
            JOIN pg_locks wl ON (
                bl.locktype = wl.locktype AND
                bl.database IS NOT DISTINCT FROM wl.database AND
                bl.relation IS NOT DISTINCT FROM wl.relation AND
                bl.page IS NOT DISTINCT FROM wl.page AND
                bl.tuple IS NOT DISTINCT FROM wl.tuple AND
                bl.virtualxid IS NOT DISTINCT FROM wl.virtualxid AND
                bl.transactionid IS NOT DISTINCT FROM wl.transactionid AND
                bl.classid IS NOT DISTINCT FROM wl.classid AND
                bl.objid IS NOT DISTINCT FROM wl.objid AND
                bl.objsubid IS NOT DISTINCT FROM wl.objsubid AND
                NOT wl.granted
            )
            JOIN pg_stat_activity blocked ON wl.pid = blocked.pid
            WHERE blocking.backend_type = 'client backend'
            AND blocked.backend_type = 'client backend'
            AND (p_tenant_hk IS NULL OR EXISTS (
                SELECT 1 FROM auth.user_h uh 
                WHERE uh.tenant_hk = p_tenant_hk 
                AND uh.user_bk = blocking.usename
            ))
            GROUP BY blocking.pid, blocking.usename, blocking.datname, blocking.application_name,
                     blocking.client_addr, blocking.client_hostname, blocking.state, blocking.query,
                     blocking.query_start, blocking.xact_start, blocking.state_change, blocking.backend_type
            HAVING COUNT(blocked.pid) > 0
            AND EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - COALESCE(blocking.query_start, blocking.xact_start)))::INTEGER >= p_min_blocking_duration_seconds
        )
        SELECT *,
            -- Calculate total locks held by this session
            (SELECT COUNT(*) FROM pg_locks pl WHERE pl.pid = ba.blocking_pid AND pl.granted) as total_locks_held
        FROM blocking_analysis ba
        ORDER BY ba.blocked_sessions_count DESC, ba.blocking_duration DESC
    LOOP
        -- Calculate severity and impact score
        v_impact_score := LEAST(100.0, GREATEST(0.0,
            (v_blocking_record.blocked_sessions_count * 15.0) + -- Each blocked session adds impact
            CASE WHEN v_blocking_record.blocking_duration > 600 THEN 30.0 
                 WHEN v_blocking_record.blocking_duration > 300 THEN 20.0 
                 WHEN v_blocking_record.blocking_duration > 60 THEN 10.0 ELSE 5.0 END + -- Duration impact
            (v_blocking_record.exclusive_locks_held * 10.0) + -- Exclusive locks increase impact
            (v_blocking_record.distinct_blocked_users * 5.0) -- Multiple users affected
        ));
        
        -- Determine severity level
        v_severity := CASE 
            WHEN v_impact_score >= 80 OR v_blocking_record.blocked_sessions_count >= 10 THEN 'CRITICAL'
            WHEN v_impact_score >= 60 OR v_blocking_record.blocked_sessions_count >= 5 THEN 'HIGH'
            WHEN v_impact_score >= 40 OR v_blocking_record.blocked_sessions_count >= 2 THEN 'MEDIUM'
            ELSE 'LOW'
        END;
        
        -- Determine escalation level
        v_escalation_level := CASE 
            WHEN v_severity = 'CRITICAL' THEN 3
            WHEN v_severity = 'HIGH' THEN 2
            WHEN v_severity = 'MEDIUM' THEN 1
            ELSE 0
        END;
        
        -- Generate business key and hash key
        v_blocking_session_bk := 'BLOCKING_' || v_blocking_record.blocking_pid || '_' || 
                                to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
        v_blocking_session_hk := util.hash_binary(v_blocking_session_bk);
        
        -- Insert hub record
        INSERT INTO lock_monitoring.blocking_session_h VALUES (
            v_blocking_session_hk, v_blocking_session_bk, 
            COALESCE(p_tenant_hk, util.hash_binary('SYSTEM')),
            util.current_load_date(), 'BLOCKING_DETECTOR'
        ) ON CONFLICT (blocking_session_bk) DO NOTHING;
        
        -- Insert satellite record
        INSERT INTO lock_monitoring.blocking_session_s VALUES (
            v_blocking_session_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(v_blocking_session_bk || v_severity || v_impact_score::text),
            v_blocking_record.blocking_pid,
            CURRENT_TIMESTAMP - (v_blocking_record.blocking_duration || ' seconds')::INTERVAL,
            v_blocking_record.blocking_user,
            v_blocking_record.blocking_database,
            v_blocking_record.application_name,
            v_blocking_record.client_addr,
            v_blocking_record.client_hostname,
            v_blocking_record.state,
            v_blocking_record.blocking_query,
            v_blocking_record.query_start,
            v_blocking_record.xact_start,
            v_blocking_record.state_change,
            v_blocking_record.blocked_sessions_count,
            v_blocking_record.total_locks_held,
            v_blocking_record.exclusive_locks_held,
            v_blocking_record.blocking_duration,
            v_severity,
            v_impact_score,
            CASE WHEN v_blocking_record.blocking_duration > 600 AND v_severity IN ('HIGH', 'CRITICAL') THEN true ELSE false END, -- auto_kill_eligible
            CASE WHEN v_severity = 'CRITICAL' THEN 300 ELSE 600 END, -- kill_threshold_seconds
            v_escalation_level,
            CURRENT_TIMESTAMP,
            1, -- connection_count_from_client
            false, -- is_superuser - would need additional query
            v_blocking_record.backend_type,
            'BLOCKING_DETECTOR'
        ) ON CONFLICT (blocking_session_hk, load_date) DO NOTHING;
        
        -- Return blocking session analysis
        RETURN QUERY SELECT 
            v_blocking_record.blocking_pid,
            v_blocking_record.blocked_sessions_count,
            v_blocking_record.blocking_duration,
            v_severity,
            CASE 
                WHEN v_severity = 'CRITICAL' AND v_blocking_record.blocking_duration > 600 THEN 
                    'IMMEDIATE ACTION: Consider terminating session ' || v_blocking_record.blocking_pid
                WHEN v_severity = 'HIGH' AND v_blocking_record.blocking_duration > 300 THEN 
                    'HIGH PRIORITY: Monitor session ' || v_blocking_record.blocking_pid || ' closely'
                WHEN v_severity = 'MEDIUM' THEN 
                    'MEDIUM PRIORITY: Review query optimization for session ' || v_blocking_record.blocking_pid
                ELSE 
                    'LOW PRIORITY: Normal blocking activity'
            END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to detect and analyze deadlocks
CREATE OR REPLACE FUNCTION lock_monitoring.detect_deadlocks(
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS TABLE (
    deadlock_detected BOOLEAN,
    involved_sessions INTEGER[],
    deadlock_severity VARCHAR(20),
    resolution_action TEXT
) AS $$
DECLARE
    v_deadlock_record RECORD;
    v_deadlock_event_hk BYTEA;
    v_deadlock_event_bk VARCHAR(255);
    v_deadlock_count INTEGER := 0;
    v_deadlock_graph JSONB;
BEGIN
    -- Detect potential deadlocks by analyzing lock wait chains
    FOR v_deadlock_record IN 
        WITH RECURSIVE lock_chain AS (
            -- Base case: sessions waiting for locks
            SELECT 
                waiting.pid as waiter_pid,
                blocking.pid as blocker_pid,
                waiting.query as waiter_query,
                blocking.query as blocker_query,
                waiting.usename as waiter_user,
                blocking.usename as blocker_user,
                1 as chain_length,
                ARRAY[waiting.pid, blocking.pid] as pid_chain,
                waiting.pid as original_waiter
            FROM pg_locks waiting_lock
            JOIN pg_stat_activity waiting ON waiting_lock.pid = waiting.pid
            JOIN pg_locks blocking_lock ON (
                waiting_lock.locktype = blocking_lock.locktype AND
                waiting_lock.database IS NOT DISTINCT FROM blocking_lock.database AND
                waiting_lock.relation IS NOT DISTINCT FROM blocking_lock.relation AND
                waiting_lock.page IS NOT DISTINCT FROM blocking_lock.page AND
                waiting_lock.tuple IS NOT DISTINCT FROM blocking_lock.tuple AND
                waiting_lock.virtualxid IS NOT DISTINCT FROM blocking_lock.virtualxid AND
                waiting_lock.transactionid IS NOT DISTINCT FROM blocking_lock.transactionid AND
                waiting_lock.classid IS NOT DISTINCT FROM blocking_lock.classid AND
                waiting_lock.objid IS NOT DISTINCT FROM blocking_lock.objid AND
                waiting_lock.objsubid IS NOT DISTINCT FROM blocking_lock.objsubid AND
                NOT waiting_lock.granted AND
                blocking_lock.granted
            )
            JOIN pg_stat_activity blocking ON blocking_lock.pid = blocking.pid
            WHERE waiting.backend_type = 'client backend'
            AND blocking.backend_type = 'client backend'
            
            UNION ALL
            
            -- Recursive case: extend the chain
            SELECT 
                lc.waiter_pid,
                next_blocking.pid as blocker_pid,
                lc.waiter_query,
                next_blocking.query as blocker_query,
                lc.waiter_user,
                next_blocking.usename as blocker_user,
                lc.chain_length + 1,
                lc.pid_chain || next_blocking.pid,
                lc.original_waiter
            FROM lock_chain lc
            JOIN pg_locks next_waiting_lock ON next_waiting_lock.pid = lc.blocker_pid
            JOIN pg_locks next_blocking_lock ON (
                next_waiting_lock.locktype = next_blocking_lock.locktype AND
                next_waiting_lock.database IS NOT DISTINCT FROM next_blocking_lock.database AND
                next_waiting_lock.relation IS NOT DISTINCT FROM next_blocking_lock.relation AND
                next_waiting_lock.page IS NOT DISTINCT FROM next_blocking_lock.page AND
                next_waiting_lock.tuple IS NOT DISTINCT FROM next_blocking_lock.tuple AND
                next_waiting_lock.virtualxid IS NOT DISTINCT FROM next_blocking_lock.virtualxid AND
                next_waiting_lock.transactionid IS NOT DISTINCT FROM next_blocking_lock.transactionid AND
                next_waiting_lock.classid IS NOT DISTINCT FROM next_blocking_lock.classid AND
                next_waiting_lock.objid IS NOT DISTINCT FROM next_blocking_lock.objid AND
                next_waiting_lock.objsubid IS NOT DISTINCT FROM next_blocking_lock.objsubid AND
                NOT next_waiting_lock.granted AND
                next_blocking_lock.granted
            )
            JOIN pg_stat_activity next_blocking ON next_blocking_lock.pid = next_blocking.pid
            WHERE lc.chain_length < 10 -- Prevent infinite recursion
            AND next_blocking.pid != ALL(lc.pid_chain) -- Avoid cycles in chain building
        ),
        deadlock_cycles AS (
            SELECT DISTINCT
                lc.original_waiter,
                lc.pid_chain,
                lc.chain_length,
                array_agg(DISTINCT lc.waiter_query) as involved_queries,
                array_agg(DISTINCT lc.waiter_user) as involved_users
            FROM lock_chain lc
            WHERE lc.blocker_pid = lc.original_waiter -- Cycle detected
            GROUP BY lc.original_waiter, lc.pid_chain, lc.chain_length
        )
        SELECT 
            dc.*,
            CURRENT_TIMESTAMP as detection_time
        FROM deadlock_cycles dc
        WHERE (p_tenant_hk IS NULL OR EXISTS (
            SELECT 1 FROM auth.user_h uh 
            WHERE uh.tenant_hk = p_tenant_hk 
            AND uh.user_bk = ANY(dc.involved_users)
        ))
    LOOP
        v_deadlock_count := v_deadlock_count + 1;
        
        -- Build deadlock graph
        v_deadlock_graph := jsonb_build_object(
            'cycle_length', v_deadlock_record.chain_length,
            'involved_pids', v_deadlock_record.pid_chain,
            'involved_queries', v_deadlock_record.involved_queries,
            'involved_users', v_deadlock_record.involved_users,
            'detection_timestamp', v_deadlock_record.detection_time
        );
        
        -- Generate business key and hash key
        v_deadlock_event_bk := 'DEADLOCK_' || array_to_string(v_deadlock_record.pid_chain, '_') || '_' ||
                              to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS_US');
        v_deadlock_event_hk := util.hash_binary(v_deadlock_event_bk);
        
        -- Insert hub record
        INSERT INTO lock_monitoring.deadlock_event_h VALUES (
            v_deadlock_event_hk, v_deadlock_event_bk, 
            COALESCE(p_tenant_hk, util.hash_binary('SYSTEM')),
            util.current_load_date(), 'DEADLOCK_DETECTOR'
        ) ON CONFLICT (deadlock_event_bk) DO NOTHING;
        
        -- Insert satellite record
        INSERT INTO lock_monitoring.deadlock_event_s VALUES (
            v_deadlock_event_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(v_deadlock_event_bk || v_deadlock_record.chain_length::text),
            CURRENT_TIMESTAMP,
            encode(v_deadlock_event_hk, 'hex'),
            v_deadlock_record.pid_chain,
            v_deadlock_record.involved_queries,
            v_deadlock_record.involved_users,
            v_deadlock_record.pid_chain[1], -- First PID as victim candidate
            v_deadlock_record.involved_queries[1], -- First query as victim candidate
            'DETECTED', -- deadlock_resolution
            0, -- deadlock_duration_ms - would be calculated in real deadlock
            ARRAY[]::VARCHAR(200)[], -- affected_tables - would need additional analysis
            ARRAY[]::VARCHAR(50)[], -- lock_types_involved - would need additional analysis
            1.0, -- deadlock_frequency_score - would be calculated based on history
            'Review transaction ordering and consider using explicit locking',
            v_deadlock_graph,
            CASE WHEN v_deadlock_record.chain_length > 3 THEN 'HIGH' ELSE 'MEDIUM' END,
            0, -- recovery_time_seconds
            false, -- data_consistency_affected
            false, -- automatic_retry_successful
            true, -- manual_intervention_required
            1, -- similar_deadlocks_count
            'DEADLOCK_DETECTOR'
        ) ON CONFLICT (deadlock_event_hk, load_date) DO NOTHING;
        
        -- Return deadlock detection results
        RETURN QUERY SELECT 
            true,
            v_deadlock_record.pid_chain,
            CASE WHEN v_deadlock_record.chain_length > 3 THEN 'HIGH' ELSE 'MEDIUM' END,
            'Deadlock cycle detected involving ' || array_length(v_deadlock_record.pid_chain, 1) || ' sessions. Consider terminating session ' || v_deadlock_record.pid_chain[1];
    END LOOP;
    
    -- If no deadlocks detected
    IF v_deadlock_count = 0 THEN
        RETURN QUERY SELECT false, ARRAY[]::INTEGER[], 'NONE'::VARCHAR(20), 'No deadlocks detected'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to perform lock wait analysis
CREATE OR REPLACE FUNCTION lock_monitoring.analyze_lock_waits(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_analysis_period_hours INTEGER DEFAULT 24
) RETURNS TABLE (
    analysis_summary VARCHAR(200),
    total_lock_events INTEGER,
    blocking_events INTEGER,
    average_wait_time_ms DECIMAL(10,2),
    efficiency_score DECIMAL(5,2),
    recommendations TEXT[]
) AS $$
DECLARE
    v_analysis_hk BYTEA;
    v_analysis_bk VARCHAR(255);
    v_period_start TIMESTAMP WITH TIME ZONE;
    v_period_end TIMESTAMP WITH TIME ZONE;
    v_total_events INTEGER;
    v_blocking_events INTEGER;
    v_deadlock_events INTEGER;
    v_avg_wait_time DECIMAL(10,2);
    v_max_wait_time DECIMAL(10,2);
    v_efficiency_score DECIMAL(5,2);
    v_recommendations TEXT[];
    v_contention_hotspots JSONB;
    v_most_contended_table VARCHAR(200);
    v_most_blocking_user VARCHAR(100);
BEGIN
    v_period_end := CURRENT_TIMESTAMP;
    v_period_start := v_period_end - (p_analysis_period_hours || ' hours')::INTERVAL;
    
    -- Analyze lock activity from the specified period
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE blocking_pid IS NOT NULL),
        0, -- deadlock events - would need separate tracking
        COALESCE(AVG(lock_duration_seconds * 1000), 0),
        COALESCE(MAX(lock_duration_seconds * 1000), 0)
    INTO v_total_events, v_blocking_events, v_deadlock_events, v_avg_wait_time, v_max_wait_time
    FROM lock_monitoring.lock_activity_s las
    WHERE las.load_date >= v_period_start
    AND las.load_end_date IS NULL
    AND (p_tenant_hk IS NULL OR EXISTS (
        SELECT 1 FROM lock_monitoring.lock_activity_h lah
        WHERE lah.lock_activity_hk = las.lock_activity_hk
        AND lah.tenant_hk = p_tenant_hk
    ));
    
    -- Find most contended table
    SELECT table_name INTO v_most_contended_table
    FROM lock_monitoring.lock_activity_s las
    WHERE las.load_date >= v_period_start
    AND las.load_end_date IS NULL
    AND las.table_name IS NOT NULL
    GROUP BY las.table_name
    ORDER BY COUNT(*) DESC, AVG(lock_duration_seconds) DESC
    LIMIT 1;
    
    -- Find most blocking user
    SELECT user_name INTO v_most_blocking_user
    FROM lock_monitoring.lock_activity_s las
    WHERE las.load_date >= v_period_start
    AND las.load_end_date IS NULL
    AND las.blocking_pid IS NOT NULL
    GROUP BY las.user_name
    ORDER BY COUNT(*) DESC
    LIMIT 1;
    
    -- Calculate efficiency score
    v_efficiency_score := LEAST(100.0, GREATEST(0.0,
        100.0 - 
        (CASE WHEN v_total_events > 0 THEN (v_blocking_events::DECIMAL / v_total_events) * 50.0 ELSE 0.0 END) - -- Blocking penalty
        (CASE WHEN v_avg_wait_time > 1000 THEN 30.0 WHEN v_avg_wait_time > 500 THEN 15.0 ELSE 0.0 END) - -- Wait time penalty
        (v_deadlock_events * 10.0) -- Deadlock penalty
    ));
    
    -- Generate recommendations
    v_recommendations := ARRAY[]::TEXT[];
    
    IF v_blocking_events > (v_total_events * 0.1) THEN
        v_recommendations := array_append(v_recommendations, 'High blocking ratio detected - review transaction isolation levels');
    END IF;
    
    IF v_avg_wait_time > 1000 THEN
        v_recommendations := array_append(v_recommendations, 'Average lock wait time exceeds 1 second - optimize query performance');
    END IF;
    
    IF v_most_contended_table IS NOT NULL THEN
        v_recommendations := array_append(v_recommendations, 'Table ' || v_most_contended_table || ' shows high contention - consider partitioning or indexing');
    END IF;
    
    IF v_deadlock_events > 0 THEN
        v_recommendations := array_append(v_recommendations, 'Deadlocks detected - review transaction ordering and locking strategies');
    END IF;
    
    IF array_length(v_recommendations, 1) IS NULL THEN
        v_recommendations := array_append(v_recommendations, 'Lock activity appears normal - continue monitoring');
    END IF;
    
    -- Build contention hotspots
    v_contention_hotspots := jsonb_build_object(
        'most_contended_table', v_most_contended_table,
        'most_blocking_user', v_most_blocking_user,
        'analysis_period_hours', p_analysis_period_hours
    );
    
    -- Generate business key and hash key
    v_analysis_bk := 'LOCK_ANALYSIS_' || 
                    COALESCE(encode(p_tenant_hk, 'hex'), 'SYSTEM') || '_' ||
                    to_char(v_period_start, 'YYYYMMDD_HH24') || '_' ||
                    p_analysis_period_hours::text || 'H';
    v_analysis_hk := util.hash_binary(v_analysis_bk);
    
    -- Insert hub record
    INSERT INTO lock_monitoring.lock_wait_analysis_h VALUES (
        v_analysis_hk, v_analysis_bk, 
        COALESCE(p_tenant_hk, util.hash_binary('SYSTEM')),
        util.current_load_date(), 'LOCK_ANALYZER'
    ) ON CONFLICT (lock_wait_analysis_bk) DO NOTHING;
    
    -- Insert satellite record
    INSERT INTO lock_monitoring.lock_wait_analysis_s VALUES (
        v_analysis_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(v_analysis_bk || v_efficiency_score::text),
        v_period_start,
        v_period_end,
        v_total_events,
        v_blocking_events,
        v_deadlock_events,
        v_avg_wait_time,
        v_max_wait_time,
        0, -- lock_timeout_events
        v_most_contended_table,
        v_most_blocking_user,
        NULL, -- most_blocked_user
        0, -- peak_concurrent_locks
        v_efficiency_score,
        v_contention_hotspots,
        v_recommendations,
        0, -- lock_escalation_events
        0, -- shared_lock_conflicts
        0, -- exclusive_lock_conflicts
        0, -- update_lock_conflicts
        0, -- intent_lock_conflicts
        LEAST(100.0, v_blocking_events::DECIMAL / GREATEST(1, v_total_events) * 100), -- performance_impact_score
        EXTRACT(HOUR FROM v_period_start) BETWEEN 8 AND 18, -- business_hours_impact
        EXTRACT(HOUR FROM v_period_start) BETWEEN 2 AND 6, -- maintenance_window_impact
        CASE 
            WHEN v_efficiency_score > 90 THEN 'IMPROVING'
            WHEN v_efficiency_score > 70 THEN 'STABLE'
            ELSE 'DEGRADING'
        END, -- trend_direction
        CASE 
            WHEN v_efficiency_score < 50 THEN 'Immediate attention required for lock contention'
            WHEN v_efficiency_score < 70 THEN 'Monitor closely for performance degradation'
            ELSE 'Continue current monitoring practices'
        END, -- forecast_next_period
        'LOCK_ANALYZER'
    ) ON CONFLICT (lock_wait_analysis_hk, load_date) DO NOTHING;
    
    RETURN QUERY SELECT 
        'Lock Analysis for ' || p_analysis_period_hours || ' hour period',
        v_total_events,
        v_blocking_events,
        v_avg_wait_time,
        v_efficiency_score,
        v_recommendations;
END;
$$ LANGUAGE plpgsql;

-- Function to automatically resolve blocking situations
CREATE OR REPLACE FUNCTION lock_monitoring.auto_resolve_blocking(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_max_blocking_duration_seconds INTEGER DEFAULT 600,
    p_dry_run BOOLEAN DEFAULT true
) RETURNS TABLE (
    session_pid INTEGER,
    action_taken VARCHAR(100),
    resolution_result VARCHAR(20),
    impact_assessment TEXT
) AS $$
DECLARE
    v_blocking_record RECORD;
    v_kill_result BOOLEAN;
    v_action_taken VARCHAR(100);
    v_resolution_result VARCHAR(20);
BEGIN
    -- Find sessions eligible for automatic termination
    FOR v_blocking_record IN 
        SELECT 
            bss.session_pid,
            bss.blocking_duration_seconds,
            bss.blocked_sessions_count,
            bss.blocking_severity,
            bss.auto_kill_eligible,
            bss.user_name,
            bss.current_query,
            bss.is_superuser
        FROM lock_monitoring.blocking_session_h bsh
        JOIN lock_monitoring.blocking_session_s bss ON bsh.blocking_session_hk = bss.blocking_session_hk
        WHERE bss.load_end_date IS NULL
        AND bss.auto_kill_eligible = true
        AND bss.blocking_duration_seconds >= p_max_blocking_duration_seconds
        AND bss.blocking_severity IN ('HIGH', 'CRITICAL')
        AND bss.is_superuser = false -- Don't auto-kill superuser sessions
        AND (p_tenant_hk IS NULL OR bsh.tenant_hk = p_tenant_hk)
        ORDER BY bss.blocking_severity DESC, bss.blocked_sessions_count DESC, bss.blocking_duration_seconds DESC
        LIMIT 5 -- Limit to 5 sessions per execution for safety
    LOOP
        IF p_dry_run THEN
            v_action_taken := 'DRY_RUN: Would terminate session';
            v_resolution_result := 'SIMULATED';
        ELSE
            -- Attempt to terminate the blocking session
            BEGIN
                PERFORM pg_terminate_backend(v_blocking_record.session_pid);
                v_action_taken := 'TERMINATED';
                v_resolution_result := 'SUCCESS';
                v_kill_result := true;
            EXCEPTION WHEN OTHERS THEN
                v_action_taken := 'TERMINATION_FAILED';
                v_resolution_result := 'FAILED';
                v_kill_result := false;
            END;
        END IF;
        
        -- Log the resolution action
        UPDATE lock_monitoring.blocking_session_s 
        SET load_end_date = util.current_load_date()
        WHERE blocking_session_hk IN (
            SELECT bsh.blocking_session_hk 
            FROM lock_monitoring.blocking_session_h bsh
            JOIN lock_monitoring.blocking_session_s bss ON bsh.blocking_session_hk = bss.blocking_session_hk
            WHERE bss.session_pid = v_blocking_record.session_pid
            AND bss.load_end_date IS NULL
        );
        
        RETURN QUERY SELECT 
            v_blocking_record.session_pid,
            v_action_taken,
            v_resolution_result,
            'Session was blocking ' || v_blocking_record.blocked_sessions_count || ' other sessions for ' || 
            v_blocking_record.blocking_duration_seconds || ' seconds with ' || v_blocking_record.blocking_severity || ' severity';
    END LOOP;
END;
$$ LANGUAGE plpgsql; 