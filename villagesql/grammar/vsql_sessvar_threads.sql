SELECT THREAD_ID, VARIABLE_NAME, LENGTH(VARIABLE_VALUE) FROM performance_schema.variables_by_thread WHERE VARIABLE_NAME LIKE 'vsql%'
SELECT VARIABLE_NAME, VARIABLE_VALUE FROM performance_schema.variables_by_thread WHERE VARIABLE_NAME = 'vsql_session_var_test.session_str_var' ORDER BY THREAD_ID LIMIT 5
SELECT COUNT(*), SUM(LENGTH(VARIABLE_VALUE)) FROM performance_schema.variables_by_thread WHERE VARIABLE_NAME LIKE 'vsql%'
