-- Dify Agent Logs Cleanup Script
-- This script clears various agent and workflow log data from the Dify database
-- WARNING: This will permanently delete log data. Make sure to backup before running.

-- Clear agent thoughts and tool execution logs
TRUNCATE TABLE message_agent_thoughts CASCADE;

-- Clear workflow execution logs
TRUNCATE TABLE workflow_runs CASCADE;
TRUNCATE TABLE workflow_app_logs CASCADE;
TRUNCATE TABLE workflow_node_executions CASCADE;

-- Clear tool model invocation logs
TRUNCATE TABLE tool_model_invokes CASCADE;

-- Clear API request logs
TRUNCATE TABLE api_requests CASCADE;

-- Clear general operation logs
TRUNCATE TABLE operation_logs CASCADE;

-- Optional: Clear message-related logs (uncomment if needed)
-- These contain conversation data but also include agent interactions
-- TRUNCATE TABLE messages CASCADE;
-- TRUNCATE TABLE message_chains CASCADE;
-- TRUNCATE TABLE message_files CASCADE;
-- TRUNCATE TABLE message_feedbacks CASCADE;
-- TRUNCATE TABLE message_annotations CASCADE;

-- Reset sequence counters (if using PostgreSQL with sequences)
-- This ensures clean ID generation after truncate
-- Note: Some tables use UUID generation, so sequences may not apply

VACUUM ANALYZE message_agent_thoughts;
VACUUM ANALYZE workflow_runs;
VACUUM ANALYZE workflow_app_logs;
VACUUM ANALYZE workflow_node_executions;
VACUUM ANALYZE tool_model_invokes;
VACUUM ANALYZE api_requests;
VACUUM ANALYZE operation_logs;

-- Display cleanup summary
SELECT 
    'message_agent_thoughts' as table_name, 
    COUNT(*) as remaining_records 
FROM message_agent_thoughts
UNION ALL
SELECT 
    'workflow_runs' as table_name, 
    COUNT(*) as remaining_records 
FROM workflow_runs
UNION ALL
SELECT 
    'workflow_app_logs' as table_name, 
    COUNT(*) as remaining_records 
FROM workflow_app_logs
UNION ALL
SELECT 
    'workflow_node_executions' as table_name, 
    COUNT(*) as remaining_records 
FROM workflow_node_executions
UNION ALL
SELECT 
    'tool_model_invokes' as table_name, 
    COUNT(*) as remaining_records 
FROM tool_model_invokes
UNION ALL
SELECT 
    'api_requests' as table_name, 
    COUNT(*) as remaining_records 
FROM api_requests
UNION ALL
SELECT 
    'operation_logs' as table_name, 
    COUNT(*) as remaining_records 
FROM operation_logs;

-- Completion message
SELECT 'Agent logs cleanup completed successfully!' as status;