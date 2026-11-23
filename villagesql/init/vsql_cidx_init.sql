-- Run once per fresh datadir, before pstress step 1.
-- Creates the tables that grammar/vsql_cidx_*.sql work on, in their own
-- database: pstress drops and recreates `test` at step 1.
--
-- vsql_knn_index_test keeps its index entries in memory, so its indexes are
-- empty after every restart. The workload looks for crashes, assertions and
-- hangs, not for KNN results.

SET PERSIST vsql_allow_preview_extensions = ON;
INSTALL EXTENSION vsql_knn_index_test;
INSTALL EXTENSION vsql_index_test;
INSTALL EXTENSION vsql_ext_index_test;

CREATE DATABASE ci;
USE ci;

CREATE TABLE k1 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  grp INT NOT NULL,
  v KVECTOR NOT NULL,
  s VARCHAR(32),
  KEY k_grp (grp),
  INDEX iv (v) USING EXTENDED(vsql_knn_index_test.kvec_l2)
);

CREATE TABLE k2 (
  a INT NOT NULL,
  b VARCHAR(8) NOT NULL,
  v KVECTOR,
  PRIMARY KEY (a, b),
  INDEX il2 (v) USING EXTENDED(vsql_knn_index_test.kvec_l2),
  INDEX icos (v kvec_profile_cos) USING EXTENDED(vsql_knn_index_test.kvec_cos)
);

CREATE TABLE k3 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  v KVECTOR NOT NULL,
  w KVECTOR,
  INDEX iv (v) USING EXTENDED(vsql_knn_index_test.kvec_l2),
  INDEX iw (w kvec_profile_cos) USING EXTENDED(vsql_knn_index_test.kvec_cos)
);

CREATE TABLE k4 (
  id INT PRIMARY KEY,
  v KVECTOR
);

CREATE TABLE d1 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  a dummy_type_vector,
  INDEX ia (a) USING EXTENDED(dummy_index_hnsw)
);

CREATE TABLE e1 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  a ext_index_wide_blob,
  INDEX ia (a) USING EXTENDED(ext_index)
);

DELIMITER |
CREATE PROCEDURE ci.seed(n INT)
BEGIN
  PREPARE p1 FROM 'INSERT INTO ci.k1 (grp, v, s) VALUES (?, ?, ''seed'')';
  PREPARE p2 FROM 'INSERT IGNORE INTO ci.k2 (a, b, v) VALUES (?, ?, ?)';
  PREPARE p3 FROM 'INSERT INTO ci.k3 (v, w) VALUES (?, ?)';
  PREPARE p4 FROM 'INSERT IGNORE INTO ci.k4 (id, v) VALUES (?, ?)';
  PREPARE p5 FROM 'INSERT INTO ci.e1 (a) VALUES (?)';
  WHILE n > 0 DO
    SET @n = n;
    SET @g = FLOOR(RAND() * 10);
    SET @b = ELT(1 + FLOOR(RAND() * 3), 'x', 'y', 'z');
    SET @kv = CONCAT('[', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ']');
    SET @kw = CONCAT('[', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ']');
    EXECUTE p1 USING @g, @kv;
    EXECUTE p2 USING @n, @b, @kv;
    EXECUTE p3 USING @kv, @kw;
    EXECUTE p4 USING @n, @kw;
    IF n % 10 = 0 THEN
      SET @e = REPEAT('e', 1 + FLOOR(RAND() * 12000));
      EXECUTE p5 USING @e;
    END IF;
    SET n = n - 1;
  END WHILE;
  DEALLOCATE PREPARE p1;
  DEALLOCATE PREPARE p2;
  DEALLOCATE PREPARE p3;
  DEALLOCATE PREPARE p4;
  DEALLOCATE PREPARE p5;
END|
DELIMITER ;
CALL ci.seed(300);
-- One row only: a second row in a dummy_index_hnsw index asserts
-- (row0ins.cc:272), see grammar/vsql_cidx_nyi.sql.
INSERT INTO ci.d1 (a) VALUES ('[1,2,3,4]');
