SELECT vsql_usage_counter.add(FLOOR(RAND() * 100), FLOOR(RAND() * 100))
SELECT vsql_usage_counter.add(NULL, 1)
SELECT SUM(vsql_usage_counter.add(id, id)) FROM (SELECT 1 AS id UNION ALL SELECT 2 UNION ALL SELECT 3) d
SHOW GLOBAL STATUS LIKE 'vsql_usage_counter%'
SELECT VARIABLE_NAME, VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME LIKE 'vsql%'
SELECT vsql_thread_worker_test.active_port()
SET GLOBAL vsql_thread_worker_test.listener_enabled = OFF
SET GLOBAL vsql_thread_worker_test.listener_enabled = ON
SELECT vsql_lifecycle_test.tick_count()
SET GLOBAL vsql_lifecycle_test.monitor_enabled = OFF
SET GLOBAL vsql_lifecycle_test.monitor_enabled = ON
SELECT vsql_mysql_services_session_test.session_sql_command()
SELECT vsql_mysql_services_session_test.session_sql_command(), vsql_usage_counter.add(1, 2)
SET GLOBAL vsql_slow_query_log.enabled = OFF
SET GLOBAL vsql_slow_query_log.enabled = ON
SET GLOBAL vsql_slow_query_log.threshold_ms = 0
SET GLOBAL vsql_slow_query_log.threshold_ms = 2
SELECT SLEEP(0.002)
SELECT COUNT(*) FROM performance_schema.processlist WHERE USER = 'vef_worker'
SELECT NAME, PROCESSLIST_INFO FROM performance_schema.threads WHERE PROCESSLIST_USER = 'vef_worker'
SELECT * FROM INFORMATION_SCHEMA.EXTENSIONS
