SET SESSION vsql_session_var_test.session_str_var = 'short'
SET SESSION vsql_session_var_test.session_str_var = REPEAT('s', FLOOR(1 + RAND() * 3000))
SET SESSION vsql_session_var_test.session_str_var = REPEAT('t', FLOOR(1 + RAND() * 64))
SET SESSION vsql_session_var_test.session_str_var = ''
SET SESSION vsql_session_var_test.session_str_var = DEFAULT
SET SESSION vsql_session_var_test.session_int_var = CAST(FLOOR(RAND() * 100000) AS SIGNED)
SET SESSION vsql_session_var_test.session_int_var = DEFAULT
SET @@session.vsql_session_var_test.session_str_var = CONCAT('c', CONNECTION_ID()), @@session.vsql_session_var_test.session_int_var = CONNECTION_ID()
SET GLOBAL vsql_session_var_test.session_str_var = REPEAT('g', FLOOR(1 + RAND() * 2000))
SET GLOBAL vsql_session_var_test.session_str_var = DEFAULT
SET GLOBAL vsql_session_var_test.session_int_var = CAST(FLOOR(RAND() * 1000) AS SIGNED)
SET PERSIST vsql_session_var_test.session_str_var = REPEAT('p', FLOOR(1 + RAND() * 500))
SET PERSIST vsql_session_var_test.session_int_var = CAST(FLOOR(RAND() * 1000) AS SIGNED)
SET PERSIST_ONLY vsql_session_var_test.session_int_var = 7
RESET PERSIST IF EXISTS vsql_session_var_test.session_str_var
RESET PERSIST IF EXISTS vsql_session_var_test.session_int_var
SET GLOBAL vsql_config_vars_test.label = REPEAT('l', FLOOR(1 + RAND() * 1000))
SET GLOBAL vsql_config_vars_test.max_items = CAST(FLOOR(RAND() * 100) AS SIGNED)
SET GLOBAL vsql_config_vars_test.mode = 'activate'
SET GLOBAL vsql_config_vars_test.mode = 'sync'
SET GLOBAL vsql_config_vars_test.mode = 'bogus'
SET PERSIST vsql_config_vars_test.label = CONCAT('persisted', CONNECTION_ID())
SET PERSIST vsql_config_vars_test.mode = 'grant'
SET PERSIST_ONLY vsql_config_vars_test.max_items = 42
RESET PERSIST IF EXISTS vsql_config_vars_test.label
RESET PERSIST IF EXISTS vsql_config_vars_test.mode
SET GLOBAL vsql_range_clamp_test.min_setting = CAST(FLOOR(RAND() * 1000) AS SIGNED)
SET GLOBAL vsql_range_clamp_test.max_setting = CAST(FLOOR(RAND() * 1000) AS SIGNED)
SET GLOBAL vsql_range_clamp_test.max_setting = 2000
SET GLOBAL vsql_range_clamp_test.label = REPEAT('r', FLOOR(1 + RAND() * 200))
SET PERSIST vsql_range_clamp_test.min_setting = 10
RESET PERSIST IF EXISTS vsql_range_clamp_test.min_setting
SELECT @@session.vsql_session_var_test.session_str_var, @@session.vsql_session_var_test.session_int_var, @@global.vsql_session_var_test.session_str_var
SELECT LENGTH(@@session.vsql_session_var_test.session_str_var), @@global.vsql_config_vars_test.label, @@global.vsql_config_vars_test.mode, @@global.vsql_config_vars_test.max_items
SELECT @@global.vsql_range_clamp_test.min_setting <= @@global.vsql_range_clamp_test.max_setting, @@global.vsql_range_clamp_test.label
SELECT read_session_int_var(), LENGTH(read_session_str_var())
SELECT vsql_session_var_test.read_session_int_var(), vsql_session_var_test.read_session_str_var()
SELECT read_session_int_var() FROM T1 LIMIT 20
PREPARE ps_sv FROM 'SELECT read_session_int_var(), read_session_str_var()'
EXECUTE ps_sv
DEALLOCATE PREPARE ps_sv
CALL vsv.p_sv()
CALL vsv.p_sv_set(REPEAT('q', FLOOR(1 + RAND() * 1000)))
SELECT LENGTH(vsv.f_sv())
INSERT INTO vsv.svt (s) VALUES (NULL)
DELETE FROM vsv.svt ORDER BY id LIMIT 20
SELECT * FROM performance_schema.session_variables WHERE VARIABLE_NAME LIKE 'vsql%'
SELECT * FROM performance_schema.global_variables WHERE VARIABLE_NAME LIKE 'vsql%'
SELECT * FROM performance_schema.persisted_variables WHERE VARIABLE_NAME LIKE 'vsql%'
SELECT VARIABLE_NAME, VARIABLE_SOURCE, SET_TIME FROM performance_schema.variables_info WHERE VARIABLE_NAME LIKE 'vsql%'
SHOW SESSION VARIABLES LIKE 'vsql%'
SHOW GLOBAL VARIABLES LIKE 'vsql_config%'
