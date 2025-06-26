# Render Deployment Fix
## Using the Correct OneVault API Version

## 🔍 **Problem Identified**
Your Render deployment is currently using the simplified `main.py` instead of the full enterprise `app/main.py`. This is why several endpoints return 404 and the database integration isn't working.

## 🔧 **Fix Required**

### Option 1: Update Procfile (Recommended)
Update your `Procfile` in the onevault_api folder:

**Current:**
```
web: python -m uvicorn main:app --host 0.0.0.0 --port $PORT
```

**Should be:**
```
web: python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

### Option 2: Update railway.toml
Update your `railway.toml`:

**Current:**
```toml
[deploy]
startCommand = "uvicorn main:app --host 0.0.0.0 --port $PORT"
```

**Should be:**
```toml
[deploy]
startCommand = "uvicorn app.main:app --host 0.0.0.0 --port $PORT"
```

## 🔄 **Steps to Fix on Render**

1. **Go to your Render dashboard**
2. **Find your OneVault API service**
3. **Go to Settings**
4. **Update the Start Command to:**
   ```
   python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT
   ```
5. **Save and redeploy**

## 🎯 **Expected Results After Fix**

Once you deploy the correct version (`app/main.py`), you should get:

✅ **All endpoints working:**
- `/health/detailed` - Detailed platform status
- `/health/customer/one_spa` - Customer-specific health check  
- `/api/v1/customer/config` - Customer configuration
- `/api/v1/track` - Site tracking with database integration

✅ **Database integration:**
- Token validation through database
- Proper Data Vault 2.0 tracking
- Customer configuration loading
- Full audit logging

## 🧪 **How to Verify the Fix**

After redeployment, run the test again:
```bash
python test_onevault_connection.py
```

You should see:
- **8/8 tests passing** (instead of 3/8)
- **Site tracking working** with database function calls
- **Customer configuration** properly loaded
- **All health checks** returning data

## 📱 **Alternative Quick Test**

You can also test with cURL:
```bash
# This should work after the fix:
curl https://onevault-api.onrender.com/health/detailed

# This should return customer data:
curl https://onevault-api.onrender.com/health/customer/one_spa
```

## ⚠️ **Important Notes**

1. **Database Connection:** Make sure your `SYSTEM_DATABASE_URL` environment variable is set correctly in Render
2. **Customer Configuration:** The enterprise version expects customer configurations to be available
3. **Dependencies:** The `app/main.py` version has additional dependencies that should already be in your `requirements.txt`

The fix is simple - just change the start command to use `app.main:app` instead of `main:app`! 