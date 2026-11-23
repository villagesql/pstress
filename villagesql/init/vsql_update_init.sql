-- Run once per fresh datadir, before pstress step 1.
-- Installs the update test extensions at 1.0.0 and creates the objects that
-- grammar/vsql_update_*.sql work on, in their own database: pstress drops and
-- recreates `test` at step 1. Columns and routine parameters of the
-- extensions' types are the dependents a version update has to rewrite.

SET PERSIST vsql_allow_preview_extensions = ON;
INSTALL EXTENSION update_test VERSION '1.0.0';
INSTALL EXTENSION update_schema_test VERSION '1.0.0';
INSTALL EXTENSION update_length_test VERSION '1.0.0';

CREATE DATABASE vupd;
USE vupd;

CREATE TABLE ut1 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  grp INT NOT NULL,
  val update_test.COUNTER
);

CREATE TABLE ut2 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  grp INT NOT NULL,
  val update_schema_test.MYTYPE
);

CREATE TABLE ut3 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  f update_length_test.FIX,
  v update_length_test.VAR
);

CREATE TABLE ut_log (
  id INT AUTO_INCREMENT PRIMARY KEY,
  src VARCHAR(16),
  r BIGINT
);

INSERT INTO ut1 (grp, val)
  WITH RECURSIVE seq (n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 300)
  SELECT n % 10, update_test.COUNTER::from_string(CAST(n AS CHAR)) FROM seq;

INSERT INTO ut2 (grp, val)
  SELECT grp, update_schema_test.MYTYPE::from_string(CAST(id AS CHAR)) FROM ut1;

-- FIX::from_string() sizes a value to its whole decode buffer, past FIX's 8
-- bytes, so FIX and VAR values are literals.
INSERT INTO ut3 (f, v) VALUES
  ('1', '7'),
  ('2', '14'),
  ('3', '21'),
  ('4', '28'),
  ('5', '35'),
  ('6', '42'),
  ('7', '49'),
  ('8', '56'),
  ('9', '63'),
  ('10', '70'),
  ('11', '77'),
  ('12', '84'),
  ('13', '91'),
  ('14', '98'),
  ('15', '105'),
  ('16', '112'),
  ('17', '119'),
  ('18', '126'),
  ('19', '133'),
  ('20', '140'),
  ('21', '147'),
  ('22', '154'),
  ('23', '161'),
  ('24', '168'),
  ('25', '175'),
  ('26', '182'),
  ('27', '189'),
  ('28', '196'),
  ('29', '203'),
  ('30', '210'),
  ('31', '217'),
  ('32', '224'),
  ('33', '231'),
  ('34', '238'),
  ('35', '245'),
  ('36', '252'),
  ('37', '259'),
  ('38', '266'),
  ('39', '273'),
  ('40', '280');

CREATE PROCEDURE p_ut_ins(IN c update_test.COUNTER)
  INSERT INTO ut1 (grp, val) VALUES (1, c);

CREATE FUNCTION f_ut_double(c update_test.COUNTER) RETURNS BIGINT DETERMINISTIC
  RETURN update_test.counter_double(c);

CREATE FUNCTION f_ut_id(c update_test.COUNTER) RETURNS update_test.COUNTER
  DETERMINISTIC RETURN c;

-- Returns a result set, so only CHECK_SQL calls it, never pstress.
CREATE PROCEDURE p_ut_echo(IN c update_test.COUNTER)
  SELECT 'RENDER', @ut_prefix, 'procedure parameter', c;

-- Procedures must not return result sets: pstress reads only the first result
-- of a CALL, which leaves its connection out of sync for the rest of the run.
CREATE PROCEDURE p_ut_scan(g INT)
  INSERT INTO ut_log (src, r)
  SELECT 'p_ut_scan', update_test.counter_double(val) FROM ut1 WHERE grp = g LIMIT 10;

CREATE TRIGGER ut1_ai AFTER INSERT ON ut1 FOR EACH ROW
  INSERT INTO ut_log (src, r) VALUES ('ut1_ai', update_test.counter_double(NEW.val));

-- A custom-type routine variable with a DEFAULT and a SET literal: the
-- variable table is rebuilt on every CALL, the literals are reused.
DELIMITER //
CREATE PROCEDURE p_ut_lit()
BEGIN
  DECLARE c update_test.COUNTER DEFAULT '7';
  INSERT INTO ut_log (src, r) VALUES ('p_ut_lit', update_test.counter_double(c));
  SET c = '9';
  INSERT INTO ut_log (src, r) VALUES ('p_ut_lit', update_test.counter_double(c));
END//
DELIMITER ;

-- Database for short-lived objects the grammar creates and drops.
CREATE DATABASE vupd2;
