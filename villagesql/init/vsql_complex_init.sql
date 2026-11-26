-- Run once per fresh datadir, before pstress step 1.
-- Creates the VillageSQL objects that grammar/vsql_complex_*.sql work on, in
-- their own database: pstress drops and recreates `test` at step 1.

INSTALL EXTENSION vsql_complex;

CREATE DATABASE vsql;
USE vsql;

CREATE TABLE vc1 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  grp INT NOT NULL,
  c COMPLEX,
  c2 COMPLEX,
  s VARCHAR(64),
  KEY k_c (c),
  KEY k_grp_c (grp, c)
);

CREATE TABLE vc2 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  grp INT NOT NULL,
  c COMPLEX,
  c2 COMPLEX,
  r DOUBLE
);

CREATE TABLE vc3 (
  id INT PRIMARY KEY,
  c COMPLEX2 NOT NULL,
  UNIQUE KEY uk_c (c)
);

CREATE TABLE vc4 (
  id INT NOT NULL,
  grp INT NOT NULL,
  c COMPLEX,
  PRIMARY KEY (id),
  KEY k_c (c)
) PARTITION BY HASH (id) PARTITIONS 4;

CREATE TABLE vc_log (
  id INT AUTO_INCREMENT PRIMARY KEY,
  src VARCHAR(16),
  r DOUBLE,
  c COMPLEX
);

INSERT INTO vc1 (grp, c, c2, s)
  WITH RECURSIVE seq (n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 500)
  SELECT n % 10, COMPLEX::from_string(CONCAT('(', n, '.5,', -n, '.25)')),
         COMPLEX::from_string(CONCAT('(', -n, ',', n % 7, ')')),
         CONCAT('(', n % 13, ',', n % 11, ')')
  FROM seq;

INSERT INTO vc2 (grp, c, c2, r)
  SELECT grp, c, complex_conjugate(c), complex_abs(c) FROM vc1 WHERE id <= 300;

INSERT INTO vc3 (id, c)
  SELECT id, COMPLEX2::from_string(CONCAT('(', id, ',', id * 2, ')')) FROM vc1 WHERE id <= 200;

INSERT INTO vc4 (id, grp, c) SELECT id, grp, c FROM vc1;

CREATE FUNCTION f_vc_abs(s VARCHAR(64)) RETURNS DOUBLE DETERMINISTIC
  RETURN complex_abs(COMPLEX::from_string(s));

CREATE FUNCTION f_vc_conj(x COMPLEX) RETURNS COMPLEX DETERMINISTIC
  RETURN complex_conjugate(x);

CREATE PROCEDURE p_vc_insert(n INT)
  INSERT INTO vc1 (grp, c, c2, s)
  VALUES (n % 10, COMPLEX::from_string(CONCAT('(', n, ',', n / 3, ')')),
          COMPLEX::from_string(CONCAT('(', -n, ',0)')), CONCAT('(', n % 5, ',1)'));

-- Procedures must not return result sets: pstress reads only the first result
-- of a CALL, which leaves its connection out of sync for the rest of the run.
CREATE PROCEDURE p_vc_scan(g INT)
  INSERT INTO vc_log (src, r, c)
  SELECT 'p_vc_scan', complex_abs(complex_add(c, c)), complex_conjugate(c)
  FROM vc1 WHERE grp = g ORDER BY c LIMIT 20;

CREATE PROCEDURE p_vc_sum()
  INSERT INTO vc_log (src, c) SELECT 'p_vc_sum', complex_sum(c) FROM vc1 GROUP BY grp;

CREATE TRIGGER vc2_bi BEFORE INSERT ON vc2 FOR EACH ROW
  SET NEW.c2 = complex_conjugate(NEW.c), NEW.r = complex_abs(NEW.c);

CREATE TRIGGER vc1_au AFTER UPDATE ON vc1 FOR EACH ROW
  INSERT INTO vc_log (src, r, c) VALUES ('vc1_au', complex_real(NEW.c), NEW.c);

-- Text literals saved into or compared with a custom-type field inside a
-- statement that runs more than once: a routine variable's DEFAULT and SET
-- (the variable table is rebuilt on every CALL), a function called once per
-- row, and a trigger. The literal must not keep bytes owned by a table that
-- is gone by the next execution. The values logged under 'p_vc_lit def',
-- 'p_vc_lit set', 'p_vc_lit cmp' and 'f_vc_lit' are known, and
-- vsql_complex_check.sql checks them.
DELIMITER //
CREATE PROCEDURE p_vc_lit()
BEGIN
  DECLARE a COMPLEX DEFAULT '(1.5,2.5)';
  INSERT INTO vc_log (src, r, c) VALUES ('p_vc_lit def', complex_real(a), a);
  SET a = '(7,8)';
  INSERT INTO vc_log (src, r, c) VALUES ('p_vc_lit set', complex_real(a), a);
  INSERT INTO vc_log (src, r, c)
    SELECT 'p_vc_lit cmp', COUNT(*), a FROM vc1 WHERE c = '(1,2)' OR c = a;
END//
CREATE FUNCTION f_vc_lit(n INT) RETURNS DOUBLE DETERMINISTIC
BEGIN
  DECLARE a COMPLEX DEFAULT '(3,4)';
  RETURN complex_abs(a) + n;
END//
DELIMITER ;

CREATE TRIGGER vc2_ai AFTER INSERT ON vc2 FOR EACH ROW
  INSERT INTO vc_log (src, r)
    SELECT 'vc2_ai', COUNT(*) FROM vc1 WHERE grp = NEW.grp AND c = '(1,2)';

-- Database for the lifecycle workers (conf/vsql_lifecycle.conf).
CREATE DATABASE vlc;
