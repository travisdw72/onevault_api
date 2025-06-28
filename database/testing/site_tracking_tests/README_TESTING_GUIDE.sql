-- ============================================================================
-- SITE TRACKING SYSTEM TESTING GUIDE
-- Complete Testing Framework Documentation
-- ============================================================================
-- Purpose: Comprehensive testing guide for the One Vault Site Tracking System
-- Author: One Vault Development Team
-- Created: 2025-06-27
-- Event ID: 8cd163b059e08cf57d494eeb3f7715391c6da48b2a50f10ebda3e4f34528cb7c
-- ============================================================================

/*
🎯 TESTING OVERVIEW
==================

This testing framework provides comprehensive validation of the Site Tracking System,
implementing Data Vault 2.0 methodology with complete tenant isolation, HIPAA/GDPR
compliance, and real-time analytics capabilities.

📋 TESTING PHASES
=================

Phase 1: Raw Layer Verification
- Validates event ingestion and tenant isolation
- Checks payload structure and processing status
- Verifies batch processing and error handling

Phase 2: Staging Layer Debug & Verification  
- Debugs staging processing issues
- Validates data enrichment and quality scoring
- Tests field mapping and validation rules

Phase 3: Business Layer Verification
- Verifies Data Vault 2.0 hub/link/satellite creation
- Tests relationship establishment and data lineage
- Validates historical tracking and change detection

Phase 4: API & Audit Verification
- Tests API security and rate limiting
- Validates comprehensive audit logging
- Verifies HIPAA/GDPR compliance tracking

Phase 5: End-to-End Flow Verification
- Traces complete data pipeline flow
- Tests multi-event processing and session aggregation
- Validates data consistency across all layers

Phase 6: Performance & Monitoring
- Measures processing performance and throughput
- Tests analytics functions and reporting capabilities
- Validates system resource utilization

🔧 DEBUGGING & TROUBLESHOOTING
===============================

The framework includes comprehensive debugging tools for:
- Field mapping issues (event_type vs evt_type)
- Tenant isolation problems
- Processing pipeline failures
- Data quality validation
- Performance optimization

📁 FILE STRUCTURE
=================

01_phase1_raw_layer_verification.sql     - Raw layer testing
02_phase2_staging_layer_debug.sql        - Staging layer debugging  
03_staging_manual_processing_fix.sql     - Manual processing fixes
04_phase3_business_layer_verification.sql - Business layer testing
05_phase4_api_audit_verification.sql     - API and audit testing
06_phase5_end_to_end_flow.sql            - End-to-end flow testing
07_phase6_performance_monitoring.sql     - Performance testing
08_debug_troubleshooting.sql             - Debugging utilities
09_complete_system_test.sql              - All phases combined
README_TESTING_GUIDE.sql                 - This documentation

🚀 QUICK START GUIDE
====================

For New Events:
1. Run 01_phase1_raw_layer_verification.sql
2. Run 02_phase2_staging_layer_debug.sql
3. If issues found, run 03_staging_manual_processing_fix.sql
4. Continue with phases 4-6 for complete validation

For System Health Check:
1. Run 09_complete_system_test.sql for overview
2. Run individual phase files for detailed analysis

For Debugging Issues:
1. Run 08_debug_troubleshooting.sql first
2. Follow recommended fixes
3. Re-run relevant phase tests

📊 SUCCESS CRITERIA
===================

✅ Raw Layer Success:
- Events successfully ingested with correct tenant isolation
- Processing status shows PROCESSED
- No critical validation errors

✅ Staging Layer Success:
- Events processed with validation_status = VALID
- Quality score > 0.7
- Enrichment_status = ENRICHED

✅ Business Layer Success:
- Hub records created for all entities
- Link relationships established correctly
- Satellite data populated with proper historization

✅ Pipeline Success:
- End-to-end data flow completed
- Processing times within acceptable ranges
- No data loss or corruption detected

🔍 COMMON ISSUES & SOLUTIONS
============================

Issue 1: "null value in column event_type"
Solution: Run 03_staging_manual_processing_fix.sql

Issue 2: Wrong tenant isolation
Solution: Verify tenant registration and hash key matching

Issue 3: Business layer not processing
Solution: Check staging triggers and business processing functions

Issue 4: Performance degradation
Solution: Run Phase 6 performance analysis and optimize indexes

🛡️ SECURITY & COMPLIANCE
=========================

All testing follows security best practices:
- Tenant isolation strictly enforced
- Audit logging for all data access
- HIPAA/GDPR compliance validation
- No sensitive data exposure in test results

📈 MONITORING & ALERTING
========================

The testing framework provides metrics for:
- Processing success rates
- Data quality scores  
- Performance benchmarks
- Error rates and patterns
- System resource utilization

🔄 CONTINUOUS TESTING
=====================

Recommended testing schedule:
- Daily: Quick system health check (09_complete_system_test.sql)
- Weekly: Full phase testing (01-08 individual files)
- Monthly: Performance benchmarking and optimization
- Ad-hoc: Debugging when issues detected

💡 BEST PRACTICES
=================

1. Always test in sequence: Raw → Staging → Business → API → Flow → Performance
2. Address issues at each layer before proceeding
3. Use debugging tools proactively
4. Monitor tenant isolation at every phase
5. Document any custom fixes or workarounds
6. Regular performance baseline updates

📞 SUPPORT & MAINTENANCE
========================

For testing framework issues:
1. Check debugging output in 08_debug_troubleshooting.sql
2. Review error logs in audit tables
3. Verify system prerequisites and dependencies
4. Escalate to development team if unresolved

🎯 TESTING OBJECTIVES SUMMARY
=============================

This framework ensures:
- ✅ Complete data pipeline validation
- ✅ Multi-tenant isolation verification  
- ✅ Data Vault 2.0 methodology compliance
- ✅ Security and audit trail completeness
- ✅ Performance and scalability validation
- ✅ Real-time analytics capability testing

🏁 CONCLUSION
=============

This comprehensive testing framework provides the tools necessary to validate
all aspects of the Site Tracking System, ensuring reliability, security, and
performance in production environments.

Run tests regularly, address issues promptly, and maintain comprehensive
documentation of all testing activities for audit and compliance purposes.

*/

-- Quick Status Check Query
SELECT 
    '🎯 SITE TRACKING SYSTEM STATUS' as system_status,
    'Use this testing framework to validate system health' as instruction,
    CURRENT_TIMESTAMP as last_updated,
    '9 testing files available' as available_tests,
    'Start with 09_complete_system_test.sql for overview' as quick_start; 