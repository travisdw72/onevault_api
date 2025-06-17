# Universal Learning Loop - Raw & Staging Layer

## 🌍 Overview

This directory contains the complete raw and staging layer implementation for the **Universal Learning Loop** - a cross-industry data processing and AI learning platform that supports any business domain (horse training, medical, manufacturing, retail, etc.).

## 🏗️ Architecture

The Universal Learning Loop follows **Data Vault 2.0** methodology with **complete tenant isolation** and **HIPAA/GDPR compliance**:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Raw Schema    │───▶│  Staging Schema │───▶│ Business Schema │
│                 │    │                 │    │                 │
│ • external_data │    │ • user_input_   │    │ • entity_h      │
│ • user_input    │    │   validation    │    │ • asset_h       │
│ • file_data     │    │ • data_validation│    │ • transaction_h │
│ • sensor_data   │    │ • business_rule │    │ • ...           │
└─────────────────┘    │ • entity_resolve│    └─────────────────┘
                       │ • standardization│
                       └─────────────────┘
```

## 📁 Files Structure

| File | Purpose | Dependencies |
|------|---------|--------------|
| `01_create_raw_schema.sql` | Creates raw schema and tables | util schema functions |
| `02_create_staging_schema.sql` | Creates staging schema and tables | raw schema tables |
| `03_create_raw_staging_functions.sql` | Helper functions for data processing | raw/staging tables |
| `04_create_raw_staging_indexes.sql` | Performance optimization indexes | all tables |
| `run_all_raw_staging.sql` | **Master script** - runs everything | all above files |
| `rollback_raw_staging.sql` | Safe removal of all objects | none |

## 🚀 Quick Start

### Option 1: Run Everything (Recommended)
```bash
# Connect to your database
psql -h localhost -U postgres -d one_vault_demo_barn

# Run the master script
\i run_all_raw_staging.sql
```

### Option 2: Run Individual Scripts
```bash
# Connect to database
psql -h localhost -U postgres -d one_vault_demo_barn

# Run scripts in order
\i 01_create_raw_schema.sql
\i 02_create_staging_schema.sql  
\i 03_create_raw_staging_functions.sql
\i 04_create_raw_staging_indexes.sql
```

## 🗄️ Raw Schema Tables

The raw schema stores data **exactly as received** without any transformation:

### `raw.external_data_h/s`
- **Purpose**: API calls, system integrations, external feeds
- **Examples**: Horse registry APIs, medical device APIs, manufacturing systems
- **Key Fields**: `source_system`, `raw_payload` (JSONB), `processing_status`

### `raw.user_input_h/s`  
- **Purpose**: User form submissions, interactions, direct input
- **Examples**: Training session forms, patient intake forms, production reports
- **Key Fields**: `input_type`, `raw_input_data` (JSONB), `validation_status`

### `raw.file_data_h/s`
- **Purpose**: File uploads, documents, media
- **Examples**: Horse photos, medical scans, production videos
- **Key Fields**: `original_filename`, `file_content` (BYTEA), `virus_scan_status`

### `raw.sensor_data_h/s`
- **Purpose**: IoT sensors, equipment monitoring, real-time data
- **Examples**: Training equipment sensors, medical device readings, production line sensors
- **Key Fields**: `sensor_type`, `sensor_readings` (JSONB), `anomaly_detected`

## 🔄 Staging Schema Tables

The staging schema validates, processes, and prepares data for the business layer:

### `staging.user_input_validation_h/s`
- **Purpose**: Real-time user input validation and sanitization
- **Processing**: Security scanning, format validation, data quality assessment

### `staging.user_behavior_analysis_h/s`
- **Purpose**: User interaction pattern analysis
- **Processing**: Navigation flows, usage metrics, behavioral insights

### `staging.data_validation_h/s`
- **Purpose**: External data quality assessment
- **Processing**: Completeness, accuracy, consistency, validity scoring

### `staging.business_rule_h/s`
- **Purpose**: Domain-specific business logic application
- **Processing**: Transformations, enrichments, calculated fields

### `staging.entity_resolution_h/s`
- **Purpose**: Duplicate detection and entity matching
- **Processing**: Fuzzy matching, confidence scoring, master data recommendations

### `staging.standardization_h/s`
- **Purpose**: Data cleaning and formatting
- **Processing**: Format conversions, data cleansing, quality improvements

## ⚙️ Helper Functions

### Raw Data Ingestion
```sql
-- Insert external API data
SELECT raw.insert_external_data(
    p_tenant_hk := tenant_hash_key,
    p_source_system := 'HORSE_REGISTRY_API',
    p_source_endpoint := '/api/v1/horses',
    p_raw_payload := '{"horse_id": "12345", "name": "Thunder"}'::jsonb
);

-- Insert user form data  
SELECT raw.insert_user_input(
    p_tenant_hk := tenant_hash_key,
    p_user_hk := user_hash_key,
    p_session_hk := session_hash_key,
    p_input_type := 'TRAINING_SESSION_FORM',
    p_form_identifier := 'session_creation',
    p_raw_input_data := '{"duration": 60, "exercises": ["jumping", "dressage"]}'::jsonb
);
```

### Staging Processing
```sql
-- Start validation process
SELECT staging.start_user_input_validation(
    p_tenant_hk := tenant_hash_key,
    p_raw_user_input_hk := raw_data_hash_key,
    p_validation_type := 'COMPREHENSIVE'
);

-- Calculate data quality score
SELECT staging.calculate_data_quality_score(
    p_completeness_score := 95.0,
    p_accuracy_score := 88.0,
    p_consistency_score := 92.0,
    p_validity_score := 90.0
);
```

## 🎯 Universal Industry Support

This infrastructure supports **ANY industry** through configuration-driven domain mapping:

### Equine Industry
```sql
-- Raw horse training data
INSERT INTO raw.external_data_s (...) VALUES (
    'TRAINING_SYSTEM', 
    '{"horse_id": "TH001", "session_type": "jumping", "performance_score": 8.5}'::jsonb
);
```

### Medical Industry  
```sql
-- Raw patient examination data
INSERT INTO raw.external_data_s (...) VALUES (
    'MRI_SYSTEM',
    '{"patient_id": "PT001", "scan_type": "brain_mri", "findings": [...]}'::jsonb
);
```

### Manufacturing Industry
```sql
-- Raw production line data
INSERT INTO raw.sensor_data_s (...) VALUES (
    'LINE_01_TEMP_SENSOR',
    '{"temperature": 450.2, "pressure": 15.8, "timestamp": "2024-01-15T10:30:00Z"}'::jsonb
);
```

## 🔐 Security & Compliance

### Tenant Isolation
- Every table includes `tenant_hk` for **complete tenant separation**
- All queries are automatically tenant-scoped
- Zero data leakage between tenants

### Data Privacy
- **HIPAA compliant** - audit trails, access logging, encryption support
- **GDPR compliant** - data retention, right to be forgotten, consent tracking
- **Configurable data classification** levels

### Performance Optimization
- **Strategic indexing** on tenant, timestamp, and status fields
- **JSONB GIN indexes** for advanced analytics
- **Partial indexes** for operational efficiency
- **Query plan optimization** with updated statistics

## 📊 Monitoring & Analytics

### Processing Statistics
```sql
-- Get daily processing statistics
SELECT * FROM staging.get_processing_statistics(
    p_tenant_hk := your_tenant_hash,
    p_processing_date := CURRENT_DATE
);
```

### Data Quality Metrics
```sql
-- Monitor data quality trends
SELECT 
    validation_timestamp,
    overall_quality_score,
    data_source_type
FROM staging.data_validation_s 
WHERE tenant_hk = your_tenant_hash
AND validation_timestamp >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY validation_timestamp DESC;
```

## 🧪 Testing

### Basic Functionality Test
The master script includes automatic validation:
- ✅ Schema creation verification
- ✅ Function availability check  
- ✅ Index creation confirmation
- ✅ Basic data flow testing

### Manual Testing
```sql
-- Test raw data insertion
SELECT raw.insert_external_data(
    (SELECT tenant_hk FROM auth.tenant_h LIMIT 1),
    'TEST_SYSTEM',
    '/test/endpoint', 
    '{"test": "data"}'::jsonb
);

-- Verify insertion
SELECT count(*) FROM raw.external_data_s WHERE source_system = 'TEST_SYSTEM';
```

## 🔄 Rollback Instructions

### Complete Removal
```bash
# WARNING: This removes ALL raw and staging data!
psql -h localhost -U postgres -d one_vault_demo_barn
\i rollback_raw_staging.sql
```

### Partial Rollback
```sql
-- Remove only staging schema
DROP SCHEMA staging CASCADE;

-- Remove only raw schema  
DROP SCHEMA raw CASCADE;
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Missing Dependencies
**Error**: `function util.hash_binary(text) does not exist`
**Solution**: Ensure your database has the core utility functions installed first

#### 2. Permission Errors
**Error**: `permission denied for schema raw`
**Solution**: Grant necessary permissions:
```sql
GRANT USAGE ON SCHEMA raw TO your_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA raw TO your_user;
```

#### 3. Constraint Violations
**Error**: `violates foreign key constraint "fk_user_input_s_user_h_user_hk"`
**Solution**: Ensure referenced tables exist and contain the referenced keys

### Performance Issues

#### Slow Queries
1. **Check indexes**: Verify all indexes are created properly
2. **Update statistics**: Run `ANALYZE` on affected tables
3. **Check query plans**: Use `EXPLAIN ANALYZE` to identify bottlenecks

#### High Memory Usage
1. **JSONB size**: Monitor large JSON payloads in raw data
2. **Batch processing**: Process data in smaller batches
3. **Cleanup**: Use `VACUUM` regularly on high-churn tables

## 🎯 Next Steps

1. **Test with Sample Data**: Insert test data for your industry
2. **Configure Business Rules**: Set up domain-specific processing rules
3. **API Integration**: Connect your APIs to raw data ingestion functions
4. **Monitoring Setup**: Implement real-time processing monitoring
5. **AI/ML Pipeline**: Configure learning pattern extraction

## 📚 Related Documentation

- [Data Vault 2.0 Standards](../docs/data-vault-standards.md)
- [Universal Learning Loop Architecture](../docs/universal-learning-loop.md)
- [Tenant Isolation Guide](../docs/tenant-isolation.md)
- [API Integration Examples](../docs/api-integration.md)

---

## 🤝 Support

For questions or issues with the Universal Learning Loop infrastructure:

1. Check this README for common solutions
2. Review the generated SQL for specific error messages
3. Examine the completion logs from `run_all_raw_staging.sql`
4. Test with minimal data samples to isolate issues

**Ready to power universal business optimization across ANY industry!** 🚀 