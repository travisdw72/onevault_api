-- =============================================
-- ADD MISSING COLUMNS FOR PROJECT GOAL 3
-- =============================================
-- This script adds missing columns that are referenced in procedures but don't exist in tables

-- Add created_date column to tenant_profile_s to match other profile tables
ALTER TABLE auth.tenant_profile_s 
ADD COLUMN IF NOT EXISTS created_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date();

-- Also add last_updated_date for consistency with other profile tables
ALTER TABLE auth.tenant_profile_s 
ADD COLUMN IF NOT EXISTS last_updated_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date();

-- Verification
DO $$ BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'MISSING COLUMNS ADDED!';
    RAISE NOTICE 'tenant_profile_s now has created_date and last_updated_date';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Now test with: SELECT util.test_registration();';
    RAISE NOTICE '===========================================';
END $$; 