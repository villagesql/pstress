-- Run once per fresh datadir, before pstress step 1.
-- Creates the VillageSQL objects that grammar/vsql_vector_*.sql work on, in
-- their own database: pstress drops and recreates `test` at step 1.
--
-- A computed SVECTOR value can only be stored through a prepared statement
-- parameter: SVECTOR::from_string() of a non-constant and a VARCHAR routine
-- variable are both rejected, and a routine with an SVECTOR parameter fails
-- to load. HNSW indexes are declared at CREATE TABLE, before any rows exist.

SET PERSIST vsql_allow_preview_extensions = ON;
INSTALL EXTENSION vsql_vector;

CREATE DATABASE vsql;
USE vsql;

CREATE TABLE vv1 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  grp INT NOT NULL,
  v SVECTOR(8) NOT NULL,
  s VARCHAR(64),
  KEY k_grp (grp),
  INDEX iv (v hnsw_l2) USING EXTENDED(hnsw) WITH (M = 8, ef_construction = 32)
);

CREATE TABLE vv2 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  grp INT NOT NULL,
  v SVECTOR(8) NOT NULL,
  INDEX iv (v hnsw_cosine) USING EXTENDED(hnsw)
);

CREATE TABLE vv3 (
  grp INT NOT NULL,
  id INT AUTO_INCREMENT,
  v SVECTOR(8) NOT NULL,
  PRIMARY KEY (grp, id),
  KEY k_id (id),
  INDEX iv (v hnsw_inner_product) USING EXTENDED(hnsw) WITH (M = 16, ef_construction = 64)
);

CREATE TABLE vv4 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  grp INT NOT NULL,
  v SVECTOR(8),
  w SVECTOR(8)
);

CREATE TABLE vv5 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  grp INT NOT NULL,
  v SVECTOR(8) NOT NULL,
  w SVECTOR(8) NOT NULL,
  n INT NOT NULL DEFAULT 0,
  INDEX iv (v hnsw_l1) USING EXTENDED(hnsw) WITH (M = 4, ef_construction = 16),
  INDEX iw (w hnsw_l2) USING EXTENDED(hnsw)
);

CREATE TABLE vv_log (
  id INT AUTO_INCREMENT PRIMARY KEY,
  src VARCHAR(16),
  ref INT,
  r DOUBLE
);

DELIMITER //

CREATE PROCEDURE p_vv_insert(g INT)
BEGIN
  SET @p_vv_g = g;
  SET @p_vv_v = CONCAT('[', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',',
                       ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',',
                       ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',',
                       ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ']');
  PREPARE p_vv_ins FROM 'INSERT INTO vsql.vv1 (grp, v, s) VALUES (?, ?, ''proc'')';
  EXECUTE p_vv_ins USING @p_vv_g, @p_vv_v;
  DEALLOCATE PREPARE p_vv_ins;
END//

CREATE PROCEDURE p_vv_seed(n INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  WHILE i < n DO
    CALL p_vv_insert(i % 10);
    SET i = i + 1;
  END WHILE;
END//

DELIMITER ;

-- Procedures must not return result sets: pstress reads only the first result
-- of a CALL, which leaves its connection out of sync for the rest of the run.
CREATE PROCEDURE p_vv_knn(g INT)
  INSERT INTO vv_log (src, ref, r)
  SELECT 'p_vv_knn', id, L2_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]')
  FROM vv1 WHERE grp = g ORDER BY L2_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 10;

CREATE PROCEDURE p_vv_norms()
  INSERT INTO vv_log (src, ref, r) SELECT 'p_vv_norms', grp, AVG(VECTOR_NORM(v)) FROM vv1 GROUP BY grp;

CREATE FUNCTION f_vv_dist(a INT, b INT) RETURNS DOUBLE READS SQL DATA
  RETURN (SELECT L2_DISTANCE(x.v, y.v) FROM vv1 x, vv1 y WHERE x.id = a AND y.id = b);

CREATE TRIGGER vv5_bi BEFORE INSERT ON vv5 FOR EACH ROW
  SET NEW.n = VECTOR_DIMENSION(NEW.v);

CREATE TRIGGER vv1_au AFTER UPDATE ON vv1 FOR EACH ROW
  INSERT INTO vv_log (src, ref, r) VALUES ('vv1_au', NEW.id, VECTOR_NORM(NEW.v));

CALL p_vv_seed(500);

INSERT INTO vv2 (grp, v) SELECT grp, v FROM vv1;
INSERT INTO vv3 (grp, v) SELECT grp, v FROM vv1;
INSERT INTO vv4 (grp, v, w) SELECT grp, v, v FROM vv1 WHERE id <= 300;
INSERT INTO vv5 (grp, v, w) SELECT grp, v, v FROM vv1 WHERE id <= 300;
