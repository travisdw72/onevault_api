-- Check which password management API functions exist
SELECT 
    n.nspname as schema,
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE (n.nspname = 'api' AND p.proname LIKE '%password%')
   OR (n.nspname = 'auth' AND p.proname IN ('change_password', 'reset_password', 'update_user_password_direct'))
ORDER BY n.nspname, p.proname; 