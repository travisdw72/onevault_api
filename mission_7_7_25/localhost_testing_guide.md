# 🏠 Localhost Testing Guide
## **Test API Setup Scripts Against Local Development Server**

---

## 🎯 **Why Test Locally First?**

### **Development Benefits**
- **Faster iteration**: No network latency to Render
- **Offline development**: Work without internet
- **Debug API changes**: Test new endpoints before deployment
- **Safe experimentation**: No risk to production data
- **Cost efficiency**: No API call limits

### **Testing Workflow**
1. **Develop locally** → Test with localhost scripts
2. **Deploy to staging** → Test with staging URL  
3. **Deploy to production** → Test with production URL

---

## 🛠️ **Setup Instructions**

### **Step 1: Run Local API Server**

#### **Option A: FastAPI Development Server**
```bash
# Navigate to your API directory
cd onevault_api  # or wherever your API code is

# Run FastAPI development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Server will be available at: http://localhost:8000
```

#### **Option B: Production-like Server**
```bash
# Run with gunicorn for production testing
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

#### **Option C: Docker Container**
```bash
# If you have Docker setup
docker run -p 8000:8000 your-api-image

# Server available at: http://localhost:8000
```

### **Step 2: Test API Health**
```bash
# Verify local API is running
curl http://localhost:8000/api/system_health_check

# Expected response:
# {"status": "healthy", "timestamp": "2025-07-03T..."}
```

---

## 🧪 **Running Tests Against Localhost**

### **Method 1: Interactive Prompt (Current)**
```bash
# Run the main setup script
python one_barn_ai_api_setup.py

# When prompted, enter localhost URL:
API Base URL (press Enter for production): http://localhost:8000

# Script will run against your local server!
```

### **Method 2: Environment Variable**
```bash
# Set environment variable
export ONEVAULT_API_URL=http://localhost:8000

# Run with environment override
python one_barn_ai_api_setup.py
```

### **Method 3: Command Line Argument**
```bash
# Direct command line usage
python one_barn_ai_api_setup.py --api-url http://localhost:8000
```

### **Method 4: Quick Localhost Script**
```bash
# Use the enhanced localhost version
python one_barn_ai_localhost_setup.py

# Automatically uses http://localhost:8000
```

---

## 📊 **Expected Test Results**

### **✅ Successful Localhost Test**
```
🚀 One_Barn_AI API-Based Setup - July 7th Demo
============================================================
API Base: http://localhost:8000

🔄 Executing: API Health Check
✅ api_health_check: API operational - healthy

🔄 Executing: Tenant Registration  
✅ tenant_registration: Tenant created: One Barn AI Solutions

🔄 Executing: Admin Authentication
✅ admin_authentication: Admin authentication successful

Status: 🎉 DEMO READY!
API Endpoint: http://localhost:8000
```

### **❌ Common Localhost Issues**
```
❌ api_health_check: API connection failed: Connection refused
   → Solution: Make sure local API server is running

❌ tenant_registration: HTTP 404: Not Found
   → Solution: Check endpoint paths in local API

❌ admin_authentication: HTTP 500: Internal Server Error  
   → Solution: Check database connection in local setup
```

---

## 🔧 **Enhanced Scripts for Localhost**

### **Auto-Detecting Script**
I'll create versions that automatically detect and prefer localhost:

1. **Check if localhost:8000 is running**
2. **If yes**: Use localhost automatically
3. **If no**: Prompt for URL or use production

### **Development Workflow Scripts**
- `one_barn_ai_localhost_setup.py` - Defaults to localhost
- `one_barn_ai_staging_setup.py` - Uses staging URL
- `one_barn_ai_production_setup.py` - Uses production URL

---

## 📋 **Localhost Testing Checklist**

### **Prerequisites**
- [ ] Local API server running on port 8000
- [ ] Database connected and accessible
- [ ] All required API endpoints implemented
- [ ] Python requests library installed

### **Testing Steps**
- [ ] Run `curl http://localhost:8000/api/system_health_check`
- [ ] Execute `python one_barn_ai_api_setup.py` with localhost URL
- [ ] Verify all 7 setup steps complete successfully
- [ ] Run `python api_validation_quick_test.py` with localhost
- [ ] Check demo credentials work locally

### **Validation Points**
- [ ] Tenant creation works locally
- [ ] Authentication flow functions
- [ ] Demo users can be created
- [ ] AI agent sessions initialize
- [ ] API tokens generate successfully

---

## ⚡ **Quick Development Commands**

### **Localhost Testing (One-liner)**
```bash
# Test against localhost in one command
echo "http://localhost:8000" | python one_barn_ai_api_setup.py
```

### **Multi-Environment Testing**
```bash
# Test all environments in sequence
for url in "http://localhost:8000" "https://staging-api.onevault.com" "https://onevault-api.onrender.com"; do
  echo "Testing: $url"
  echo "$url" | python one_barn_ai_api_setup.py
done
```

### **Quick Local Validation**
```bash
# Fast localhost health check
curl -s http://localhost:8000/api/system_health_check | jq '.status'
```

---

## 🔄 **Development Workflow**

### **Daily Development Cycle**
1. **Start local API**: `uvicorn app.main:app --reload`
2. **Test changes**: `python one_barn_ai_api_setup.py` → localhost
3. **Validate quickly**: `python api_validation_quick_test.py`
4. **Fix issues**: Iterate on API code
5. **Deploy to staging**: Test with staging URL
6. **Deploy to production**: Final test with production URL

### **Pre-Demo Testing**
1. **Localhost**: Verify all features work
2. **Staging**: Test with production-like environment  
3. **Production**: Final validation before demo
4. **Backup plan**: Localhost as demo fallback if production issues

---

## 🚀 **Next Steps**

Would you like me to create:

1. **Enhanced scripts** with automatic localhost detection?
2. **Environment-specific** setup scripts?
3. **Docker compose** setup for local development?
4. **Testing automation** scripts for CI/CD?

The current scripts already work with localhost - you just enter the URL when prompted! But I can make it even more streamlined for development workflow.

**Localhost testing = Just change the URL! 🎯** 