-- Dify Agent Logs Selective Cleanup Script
-- This script provides selective deletion options for agent and workflow log data
-- Safer alternative to full truncate - allows date-based filtering

-- Configuration: Set the date threshold (modify as needed)
-- Delete records older than X days (default: 30 days)
-- Uncomment and modify the line below to set a specific date
-- SET @cutoff_date = DATE_SUB(NOW(), INTERVAL 30 DAY);

-- For PostgreSQL, use this instead:
-- DELETE operations with date filtering

-- Clear old agent thoughts (older than 30 days)
DELETE FROM message_agent_thoughts 
WHERE created_at < (CURRENT_TIMESTAMP - INTERVAL '30 days');

-- Clear old workflow runs (older than 30 days)  
DELETE FROM workflow_runs 
WHERE created_at < (CURRENT_TIMESTAMP - INTERVAL '30 days');

-- Clear old workflow app logs (older than 30 days)
DELETE FROM workflow_app_logs 
WHERE created_at < (CURRENT_TIMESTAMP - INTERVAL '30 days');

-- Clear old workflow node executions (older than 30 days)
DELETE FROM workflow_node_executions 
WHERE created_at < (CURRENT_TIMESTAMP - INTERVAL '30 days');

-- Clear old tool model invocation logs (older than 30 days)
-- Note: Check if this table has created_at column
DELETE FROM tool_model_invokes 
WHERE created_at < (CURRENT_TIMESTAMP - INTERVAL '30 days');

-- Clear old API request logs (older than 30 days)
DELETE FROM api_requests 
WHERE created_at < (CURRENT_TIMESTAMP - INTERVAL '30 days');

-- Clear old operation logs (older than 30 days)
DELETE FROM operation_logs 
WHERE created_at < (CURRENT_TIMESTAMP - INTERVAL '30 days');

-- Alternative: Delete by specific tenant_id (uncomment and set tenant ID)
-- DELETE FROM message_agent_thoughts WHERE tenant_id = 'your-tenant-id-here';
-- DELETE FROM workflow_runs WHERE tenant_id = 'your-tenant-id-here';
-- DELETE FROM workflow_app_logs WHERE tenant_id = 'your-tenant-id-here';
-- DELETE FROM workflow_node_executions WHERE tenant_id = 'your-tenant-id-here';

-- Alternative: Delete by specific app_id (uncomment and set app ID)
-- DELETE FROM message_agent_thoughts WHERE message_id IN (
--     SELECT id FROM messages WHERE app_id = 'your-app-id-here'
-- );
-- DELETE FROM workflow_runs WHERE app_id = 'your-app-id-here';
-- DELETE FROM workflow_app_logs WHERE app_id = 'your-app-id-here';
-- DELETE FROM workflow_node_executions WHERE app_id = 'your-app-id-here';

-- Run VACUUM to reclaim space
VACUUM ANALYZE message_agent_thoughts;
VACUUM ANALYZE workflow_runs;
VACUUM ANALYZE workflow_app_logs;
VACUUM ANALYZE workflow_node_executions;
VACUUM ANALYZE tool_model_invokes;
VACUUM ANALYZE api_requests;
VACUUM ANALYZE operation_logs;

-- Display cleanup summary with date ranges
SELECT 
    'message_agent_thoughts' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN created_at >= (CURRENT_TIMESTAMP - INTERVAL '7 days') THEN 1 END) as last_7_days,
    COUNT(CASE WHEN created_at >= (CURRENT_TIMESTAMP - INTERVAL '30 days') THEN 1 END) as last_30_days
FROM message_agent_thoughts
UNION ALL
SELECT 
    'workflow_runs' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN created_at >= (CURRENT_TIMESTAMP - INTERVAL '7 days') THEN 1 END) as last_7_days,
    COUNT(CASE WHEN created_at >= (CURRENT_TIMESTAMP - INTERVAL '30 days') THEN 1 END) as last_30_days
FROM workflow_runs
UNION ALL
SELECT 
    'workflow_app_logs' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN created_at >= (CURRENT_TIMESTAMP - INTERVAL '7 days') THEN 1 END) as last_7_days,
    COUNT(CASE WHEN created_at >= (CURRENT_TIMESTAMP - INTERVAL '30 days') THEN 1 END) as last_30_days
FROM workflow_app_logs
UNION ALL
SELECT 
    'workflow_node_executions' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN created_at >= (CURRENT_TIMESTAMP - INTERVAL '7 days') THEN 1 END) as last_7_days,
    COUNT(CASE WHEN created_at >= (CURRENT_TIMESTAMP - INTERVAL '30 days') THEN 1 END) as last_30_days
FROM workflow_node_executions;

SELECT 'Selective agent logs cleanup completed!' as status;