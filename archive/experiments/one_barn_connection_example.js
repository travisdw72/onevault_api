/**
 * One Barn Platform - Data Vault 2.0 Connection Example
 * =====================================================
 * 
 * This example demonstrates how One Barn connects to the Data Vault 2.0 API
 * using the generated credentials and following our ELT process standards.
 */

require('dotenv').config({ path: './one_barn_platform.env' });
const axios = require('axios');

class OneBarnDataVaultClient {
    constructor() {
        // Load configuration from environment
        this.config = {
            apiKey: process.env.API_KEY,
            apiSecret: process.env.API_SECRET,
            tenantId: process.env.TENANT_ID,
            baseUrl: process.env.API_BASE_URL,
            timeout: parseInt(process.env.API_TIMEOUT),
        };
        
        // Create axios instance with default headers
        this.client = axios.create({
            baseURL: this.config.baseUrl,
            timeout: this.config.timeout,
            headers: {
                'X-API-Key': this.config.apiKey,
                'X-API-Secret': this.config.apiSecret,
                'X-Tenant-ID': this.config.tenantId,
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'User-Agent': 'OneBarnPlatform/1.0.0'
            }
        });
        
        // Add request interceptor for logging
        this.client.interceptors.request.use(
            (config) => {
                console.log(`🚀 API Request: ${config.method?.toUpperCase()} ${config.url}`);
                if (process.env.DEBUG_QUERIES === 'true') {
                    console.log('   Headers:', config.headers);
                    console.log('   Data:', config.data);
                }
                return config;
            },
            (error) => {
                console.error('❌ Request Error:', error);
                return Promise.reject(error);
            }
        );
        
        // Add response interceptor for logging
        this.client.interceptors.response.use(
            (response) => {
                console.log(`✅ API Response: ${response.status} ${response.statusText}`);
                return response;
            },
            (error) => {
                console.error('❌ Response Error:', error.response?.status, error.response?.data);
                return Promise.reject(error);
            }
        );
    }
    
    /**
     * Test connection to Data Vault 2.0 API
     */
    async testConnection() {
        try {
            console.log('\n🔍 Testing connection to Data Vault 2.0...\n');
            
            const response = await this.client.get('/health');
            
            console.log('✅ Connection successful!');
            console.log('   API Version:', response.data?.version);
            console.log('   Tenant ID:', response.data?.tenantId);
            console.log('   Timestamp:', response.data?.timestamp);
            
            return true;
        } catch (error) {
            console.error('❌ Connection failed:', error.message);
            return false;
        }
    }
    
    /**
     * Fetch horses using our Data Vault 2.0 API
     * Follows the ELT process standards defined in api-rules-and-regulations.mdc
     */
    async getHorses(params = {}) {
        try {
            console.log('\n🐎 Fetching horses from Data Vault 2.0...\n');
            
            const response = await this.client.get('/horses', {
                params: {
                    page: params.page || 1,
                    pageSize: params.pageSize || 10,
                    sortBy: params.sortBy || 'name',
                    sortDirection: params.sortDirection || 'ASC',
                    statusFilter: params.status || 'ACTIVE',
                    ...params.filters
                }
            });
            
            console.log('✅ Horses retrieved successfully!');
            console.log('   Total Count:', response.data.meta?.totalCount);
            console.log('   Page:', response.data.meta?.currentPage);
            console.log('   Horses on this page:', response.data.items?.length);
            
            // Log first horse as example
            if (response.data.items?.length > 0) {
                console.log('\n📊 Example Horse Data:');
                console.log('   Name:', response.data.items[0].name);
                console.log('   Breed:', response.data.items[0].breed);
                console.log('   Status:', response.data.items[0].status);
                console.log('   Load Date:', response.data.items[0].loadDate);
            }
            
            return response.data;
        } catch (error) {
            console.error('❌ Failed to fetch horses:', error.message);
            throw error;
        }
    }
    
    /**
     * Create a new horse record
     * Data flows through: Raw → Staging → Business → InfoMart
     */
    async createHorse(horseData) {
        try {
            console.log('\n🆕 Creating new horse record...\n');
            
            const response = await this.client.post('/horses', {
                name: horseData.name,
                breed: horseData.breed,
                dateOfBirth: horseData.dateOfBirth,
                color: horseData.color,
                gender: horseData.gender,
                registrationNumber: horseData.registrationNumber,
                ownerClientId: horseData.ownerClientId,
                status: horseData.status || 'ACTIVE',
                // Additional metadata for audit trail
                submittedBy: 'OneBarnPlatform',
                submissionTimestamp: new Date().toISOString()
            });
            
            console.log('✅ Horse created successfully!');
            console.log('   Horse ID:', response.data.id);
            console.log('   Business Key:', response.data.horseBk);
            console.log('   Load Date:', response.data.loadDate);
            
            return response.data;
        } catch (error) {
            console.error('❌ Failed to create horse:', error.message);
            if (error.response?.data?.validationErrors) {
                console.error('   Validation Errors:', error.response.data.validationErrors);
            }
            throw error;
        }
    }
    
    /**
     * Fetch training sessions with historical data
     */
    async getTrainingSessions(params = {}) {
        try {
            console.log('\n🏃 Fetching training sessions...\n');
            
            const response = await this.client.get('/training/sessions', {
                params: {
                    horseId: params.horseId,
                    startDate: params.startDate,
                    endDate: params.endDate,
                    includeHistory: params.includeHistory || false,
                    effectiveDate: params.effectiveDate,
                    ...params
                }
            });
            
            console.log('✅ Training sessions retrieved!');
            console.log('   Total Sessions:', response.data.meta?.totalCount);
            
            return response.data;
        } catch (error) {
            console.error('❌ Failed to fetch training sessions:', error.message);
            throw error;
        }
    }
    
    /**
     * Submit bulk data (follows Raw Layer ELT standards)
     */
    async submitBulkData(dataType, records) {
        try {
            console.log(`\n📦 Submitting bulk ${dataType} data...\n`);
            
            const response = await this.client.post(`/bulk/${dataType}`, {
                records: records,
                batchId: `ONEBARN_${Date.now()}`,
                sourceSystem: 'OneBarnPlatform',
                extractTimestamp: new Date().toISOString(),
                processingOptions: {
                    validateOnSubmit: true,
                    skipDuplicates: true,
                    enableBusinessRules: true
                }
            });
            
            console.log('✅ Bulk data submitted successfully!');
            console.log('   Batch ID:', response.data.batchId);
            console.log('   Records Submitted:', response.data.recordsSubmitted);
            console.log('   Processing Status:', response.data.processingStatus);
            
            return response.data;
        } catch (error) {
            console.error(`❌ Failed to submit bulk ${dataType}:`, error.message);
            throw error;
        }
    }
    
    /**
     * Get audit trail for compliance
     */
    async getAuditTrail(resourceType, resourceId, params = {}) {
        try {
            console.log(`\n📋 Fetching audit trail for ${resourceType}...\n`);
            
            const response = await this.client.get(`/audit/${resourceType}/${resourceId}`, {
                params: {
                    startDate: params.startDate,
                    endDate: params.endDate,
                    actionFilter: params.action,
                    userFilter: params.user,
                    includeDataChanges: params.includeDataChanges || true,
                    ...params
                }
            });
            
            console.log('✅ Audit trail retrieved!');
            console.log('   Total Audit Events:', response.data.meta?.totalCount);
            
            return response.data;
        } catch (error) {
            console.error('❌ Failed to fetch audit trail:', error.message);
            throw error;
        }
    }
}

// Example usage
async function demonstrateOneBarnIntegration() {
    const client = new OneBarnDataVaultClient();
    
    try {
        // Test connection
        await client.testConnection();
        
        // Fetch horses
        const horses = await client.getHorses({
            page: 1,
            pageSize: 5,
            status: 'ACTIVE'
        });
        
        // Create a new horse (example)
        if (process.env.DEMO_MODE === 'true') {
            const newHorse = await client.createHorse({
                name: 'Thunder Bay',
                breed: 'Thoroughbred',
                dateOfBirth: '2020-03-15',
                color: 'Bay',
                gender: 'Stallion',
                registrationNumber: 'TB20200315001',
                ownerClientId: 'CLIENT_12345',
                status: 'ACTIVE'
            });
        }
        
        // Fetch training sessions
        if (horses.items?.length > 0) {
            const trainingSessions = await client.getTrainingSessions({
                horseId: horses.items[0].id,
                startDate: '2024-01-01',
                endDate: '2024-12-31'
            });
        }
        
        console.log('\n🎉 One Barn integration demonstration completed successfully!');
        
    } catch (error) {
        console.error('\n💥 Integration demonstration failed:', error.message);
        process.exit(1);
    }
}

// Export for use in other modules
module.exports = OneBarnDataVaultClient;

// Run demonstration if this file is executed directly
if (require.main === module) {
    demonstrateOneBarnIntegration();
} 