-- Run once per fresh datadir, before pstress step 1.
INSTALL EXTENSION vsql_slow_query_log;
INSTALL EXTENSION vsql_usage_counter;
INSTALL EXTENSION vsql_thread_worker_test;
INSTALL EXTENSION vsql_lifecycle_test;
INSTALL EXTENSION vsql_mysql_services_session_test;
SET GLOBAL vsql_slow_query_log.threshold_ms = 1;
SET GLOBAL vsql_slow_query_log.enabled = ON;
