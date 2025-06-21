# 🚀 System Operations Expansion Guide

## Overview

This guide provides step-by-step instructions for expanding the System Operations Tenant with new functionality while maintaining architectural consistency, security standards, and enterprise-grade quality.

## 🎯 **Quick Start Checklist**

Before adding new system operations:

- [ ] **Architecture Review** - Does this belong in system operations?
- [ ] **Security Assessment** - What are the security implications?
- [ ] **Data Flow Design** - How will data flow through the layers?
- [ ] **Integration Points** - What systems will this interact with?
- [ ] **Testing Strategy** - How will this be tested?
- [ ] **Documentation Plan** - What documentation is needed?

## 📋 **Adding New System Operations**

### **Step 1: Operation Classification**

Determine which category your new operation falls into:

#### **🔗 External Integration Operations**
- API integrations with third-party services
- Data imports from external systems
- Webhook processing
- File uploads/downloads

#### **🛠️ Administrative Operations**
- System configuration changes
- Bulk data operations
- User management tasks
- System maintenance

#### **📊 Analytics Operations**
- Cross-tenant reporting
- Performance metrics
- Usage analytics
- Business intelligence

#### **🔍 Monitoring Operations**
- Health checks
- Performance monitoring
- Alert processing
- System diagnostics

### **Step 2: Implementation Template**

Use this template for all new system operations:

```sql
-- ============================================================================
-- SYSTEM OPERATION: [OPERATION_NAME]
-- ============================================================================
-- Purpose: [Clear description of what this operation does]
-- Category: [External Integration | Administrative | Analytics | Monitoring]
-- Dependencies: [List any dependencies]
-- Security: [Security considerations and access requirements]
-- ============================================================================

CREATE OR REPLACE FUNCTION system_[operation_name](
    -- Parameters with clear types and descriptions
    p_parameter_1 [TYPE],  -- Description of parameter 1
    p_parameter_2 [TYPE],  -- Description of parameter 2
    p_admin_user_hk BYTEA DEFAULT NULL  -- Optional admin user for authorization
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER  -- Important for system operations
AS $$
DECLARE
    -- System tenant constant (always required)
    v_system_tenant_hk BYTEA := '\x0000000000000000000000000000000000000000000000000000000000000001'::bytea;
    
    -- Operation-specific variables
    v_operation_hk BYTEA;
    v_operation_bk VARCHAR(255);
    v_result JSONB;
BEGIN
    -- ========================================
    -- PHASE 1: Input Validation & Security
    -- ========================================
    
    -- Validate required parameters
    IF p_parameter_1 IS NULL THEN
        RAISE EXCEPTION 'Parameter 1 is required';
    END IF;
    
    -- Authorization check (if admin user required)
    IF p_admin_user_hk IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM auth.user_h 
            WHERE user_hk = p_admin_user_hk 
            AND tenant_hk = v_system_tenant_hk
        ) THEN
            RAISE EXCEPTION 'Unauthorized: Admin user not in system tenant';
        END IF;
    END IF;
    
    -- ========================================
    -- PHASE 2: Raw Layer Capture
    -- ========================================
    
    -- Generate unique identifiers
    v_operation_bk := '[OPERATION_PREFIX]_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS_US');
    v_operation_hk := util.hash_binary(v_operation_bk);
    
    -- Store in appropriate raw table
    INSERT INTO raw.[appropriate_table]_h VALUES (
        v_operation_hk,
        v_operation_bk,
        v_system_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    );
    
    -- ========================================
    -- PHASE 3: Business Logic Execution
    -- ========================================
    
    -- Implement your operation-specific logic here
    
    -- ========================================
    -- PHASE 4: Status Update & Response
    -- ========================================
    
    -- Return standardized response
    RETURN jsonb_build_object(
        'success', true,
        'message', '[Operation] completed successfully',
        'operation_id', v_operation_bk,
        'data', v_result,
        'completed_at', CURRENT_TIMESTAMP
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Return standardized error response
        RETURN jsonb_build_object(
            'success', false,
            'message', '[Operation] failed: ' || SQLERRM,
            'error_code', '[OPERATION]_FAILED',
            'failed_at', CURRENT_TIMESTAMP
        );
END;
$$;
```

## 🔧 **Common Patterns & Best Practices**

### **Always Use System Tenant Constant**
```sql
v_system_tenant_hk := '\x0000000000000000000000000000000000000000000000000000000000000001'::bytea;
```

### **Authorization Pattern**
```sql
-- System admin verification
IF p_admin_user_hk IS NOT NULL THEN
    IF NOT EXISTS (
        SELECT 1 FROM auth.user_h 
        WHERE user_hk = p_admin_user_hk 
        AND tenant_hk = v_system_tenant_hk
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Admin user not in system tenant';
    END IF;
END IF;
```

### **Standardized Response Pattern**
```sql
-- Success response
RETURN jsonb_build_object(
    'success', true,
    'message', 'Operation completed successfully',
    'operation_id', v_operation_bk,
    'data', v_result,
    'completed_at', CURRENT_TIMESTAMP
);

-- Error response
RETURN jsonb_build_object(
    'success', false,
    'message', 'Operation failed: ' || error_message,
    'error_code', 'OPERATION_FAILED',
    'failed_at', CURRENT_TIMESTAMP
);
```

## 📚 **Additional Resources**

- **System Operations Architecture**: `SYSTEM_OPERATIONS_ARCHITECTURE.md`
- **Main README**: `README.md`
- **Database Documentation**: `../docs/`

## 🚨 **Important Reminders**

1. **Always use system tenant constant** - Never hardcode or calculate
2. **Complete tenant isolation** - System operations should never access business tenant data directly
3. **Comprehensive error handling** - Always update raw record status
4. **Security first** - Validate authorization for admin operations
5. **Document everything** - Functions, tests, and integration points
6. **Test thoroughly** - Unit, integration, and security tests required

---

**Ready to expand? Follow this guide and maintain the high standards of the System Operations Tenant architecture!** 