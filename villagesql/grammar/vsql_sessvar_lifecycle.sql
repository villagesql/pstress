UNINSTALL EXTENSION vsql_session_var_test
UNINSTALL EXTENSION vsql_session_var_test
INSTALL EXTENSION vsql_session_var_test
UNINSTALL EXTENSION vsql_config_vars_test
INSTALL EXTENSION vsql_config_vars_test
UNINSTALL EXTENSION vsql_range_clamp_test
INSTALL EXTENSION vsql_range_clamp_test
SET SESSION vsql_session_var_test.session_str_var = REPEAT('w', FLOOR(1 + RAND() * 3000))
SET SESSION vsql_session_var_test.session_int_var = CAST(FLOOR(RAND() * 100000) AS SIGNED)
SELECT read_session_int_var(), LENGTH(read_session_str_var())
SET GLOBAL vsql_session_var_test.session_str_var = REPEAT('h', FLOOR(1 + RAND() * 100))
SET GLOBAL vsql_config_vars_test.label = 'from worker'
SET GLOBAL vsql_range_clamp_test.max_setting = CAST(FLOOR(RAND() * 1000) AS SIGNED)
SET PERSIST vsql_config_vars_test.max_items = 9
CALL vsv.p_sv()
SELECT LENGTH(vsv.f_sv())
INSERT INTO vsv.svt (s) VALUES (NULL)
SELECT * FROM INFORMATION_SCHEMA.EXTENSIONS
