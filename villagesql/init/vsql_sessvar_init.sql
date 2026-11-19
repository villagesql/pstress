-- Run once per fresh datadir, before pstress step 1.
-- Installs the extensions whose system variables grammar/vsql_sessvar*.sql
-- set and read, and creates routines and a trigger that read them, in their
-- own database: pstress drops and recreates `test` at step 1.
--
-- vsql_session_var_test: session-scoped session_int_var and session_str_var,
-- and VDFs read_session_int_var() and read_session_str_var() that read the
-- calling session's values.
-- vsql_config_vars_test: global label, max_items and mode (activate, grant,
-- sync), with on_change callbacks.
-- vsql_range_clamp_test: global min_setting and max_setting, kept ordered by a
-- shared on_change callback, and label.

SET PERSIST vsql_allow_preview_extensions = ON;
INSTALL EXTENSION vsql_session_var_test;
INSTALL EXTENSION vsql_config_vars_test;
INSTALL EXTENSION vsql_range_clamp_test;

CREATE DATABASE vsv;
USE vsv;

CREATE TABLE svt (
  id INT AUTO_INCREMENT PRIMARY KEY,
  s TEXT,
  i BIGINT
);

-- Procedures must not return result sets: pstress reads only the first result
-- of a CALL, which leaves its connection out of sync for the rest of the run.
CREATE PROCEDURE p_sv()
  SET @vsv_x = CONCAT(@@session.vsql_session_var_test.session_str_var,
                      @@session.vsql_session_var_test.session_int_var);

CREATE PROCEDURE p_sv_set(IN v VARCHAR(4000))
  SET SESSION vsql_session_var_test.session_str_var = v;

CREATE FUNCTION f_sv() RETURNS VARCHAR(4000) DETERMINISTIC
  RETURN CONCAT(@@session.vsql_session_var_test.session_str_var, ':',
                @@global.vsql_config_vars_test.label, ':',
                @@global.vsql_range_clamp_test.min_setting);

CREATE TRIGGER svt_bi BEFORE INSERT ON svt FOR EACH ROW
  SET NEW.s = @@session.vsql_session_var_test.session_str_var,
      NEW.i = @@session.vsql_session_var_test.session_int_var;
