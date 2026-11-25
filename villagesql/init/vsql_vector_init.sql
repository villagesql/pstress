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

-- One row per p_vv_chk call; init/vsql_vector_check.sql reports them after
-- every restart and marks them seen.
CREATE TABLE vv_chk (
  id INT AUTO_INCREMENT PRIMARY KEY,
  t VARCHAR(8) NOT NULL,
  self_q INT NOT NULL,
  lim INT NOT NULL,
  ef INT,
  n_rows INT,
  c INT,
  cd INT,
  ordered INT,
  hit INT,
  mind DOUBLE,
  q VARCHAR(200),
  seen INT NOT NULL DEFAULT 0
);

DELIMITER //

-- Checks one KNN query against the HNSW index of t ('vv1', 'vv2', 'vv5' for its
-- v column, 'vv5w' for its w column; no query uses vv3's inner product index) in one REPEATABLE READ snapshot.
-- HNSW is approximate, so only some properties must hold for every query:
-- no row twice (cd = c) and rows in distance order (ordered = 1). Recall
-- against the same query without the index (hit of lim), short results
-- (c < lim with enough rows) and a query with an existing row's vector that
-- misses it (self_q = 1, mind > 0) are logged for the check to summarize.
-- The query vector is random, or with self_q = 1 an existing row's vector.
-- Commits the caller's transaction first.
CREATE PROCEDURE p_vv_chk(tt VARCHAR(8), self_q INT, lim INT)
BEGIN
  DECLARE iso VARCHAR(32) DEFAULT @@SESSION.transaction_isolation;
  DECLARE t VARCHAR(8) DEFAULT tt;
  DECLARE fn VARCHAR(32) DEFAULT 'L2_DISTANCE';
  DECLARE col VARCHAR(4) DEFAULT 'v';
  DECLARE ix VARCHAR(4) DEFAULT 'iv';
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET SESSION transaction_isolation = iso;
    RESIGNAL;
  END;
  CASE tt
    WHEN 'vv2' THEN SET fn = 'COSINE_DISTANCE';
    WHEN 'vv5' THEN SET fn = 'L1_DISTANCE';
    WHEN 'vv5w' THEN SET t = 'vv5', col = 'w', ix = 'iw';
    ELSE SET t = 'vv1';
  END CASE;
  COMMIT;
  SET SESSION transaction_isolation = 'REPEATABLE-READ';
  START TRANSACTION WITH CONSISTENT SNAPSHOT;

  SET @p_vv_q = NULL;
  IF self_q = 1 THEN
    -- 9 significant digits give back the stored float exactly.
    SET @s = CONCAT('SELECT FLOOR(1 + RAND() * MAX(id)) INTO @p_vv_id FROM vsql.', t);
    PREPARE p_vv_s FROM @s;
    EXECUTE p_vv_s;
    DEALLOCATE PREPARE p_vv_s;
    SET @s = CONCAT('SELECT VECTOR_FORMAT(', col, ', 9) INTO @p_vv_q FROM vsql.', t,
                    ' WHERE id >= ? ORDER BY id LIMIT 1');
    PREPARE p_vv_s FROM @s;
    EXECUTE p_vv_s USING @p_vv_id;
    DEALLOCATE PREPARE p_vv_s;
  END IF;
  IF @p_vv_q IS NULL THEN
    SET self_q = 0;
    SET @p_vv_q = CONCAT('[', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',',
                         ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',',
                         ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',',
                         ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ']');
  END IF;

  SET @s = CONCAT('SELECT COUNT(*) INTO @p_vv_n FROM vsql.', t);
  PREPARE p_vv_s FROM @s;
  EXECUTE p_vv_s;
  DEALLOCATE PREPARE p_vv_s;

  -- The derived table keeps the scan order, so the GROUP_CONCAT without
  -- ORDER BY lists the distances in the order the index returned them.
  SET @s = CONCAT('SELECT COUNT(*), COUNT(DISTINCT id), ',
                  'GROUP_CONCAT(ROUND(d, 4)) <=> GROUP_CONCAT(ROUND(d, 4) ORDER BY d), MIN(d) ',
                  'INTO @p_vv_c, @p_vv_cd, @p_vv_ord, @p_vv_mind ',
                  'FROM (SELECT id, ', fn, '(', col, ', ?) AS d FROM vsql.', t,
                  ' ORDER BY ', fn, '(', col, ', ?) LIMIT ', lim, ') k');
  PREPARE p_vv_s FROM @s;
  EXECUTE p_vv_s USING @p_vv_q, @p_vv_q;
  DEALLOCATE PREPARE p_vv_s;

  SET @s = CONCAT('SELECT COUNT(*) INTO @p_vv_hit FROM ',
                  '(SELECT id FROM vsql.', t, ' ORDER BY ', fn, '(', col, ', ?) LIMIT ', lim, ') a ',
                  'JOIN (SELECT id FROM vsql.', t, ' IGNORE INDEX (', ix, ') ORDER BY ', fn, '(', col,
                  ', ?) LIMIT ', lim, ') b ON a.id = b.id');
  PREPARE p_vv_s FROM @s;
  EXECUTE p_vv_s USING @p_vv_q, @p_vv_q;
  DEALLOCATE PREPARE p_vv_s;

  INSERT INTO vsql.vv_chk (t, self_q, lim, ef, n_rows, c, cd, ordered, hit, mind, q)
  VALUES (tt, self_q, lim, @@SESSION.vsql_vector.ef_search, @p_vv_n, @p_vv_c, @p_vv_cd,
          @p_vv_ord, @p_vv_hit, @p_vv_mind, @p_vv_q);
  COMMIT;
  SET SESSION transaction_isolation = iso;
END//

DELIMITER ;

CALL p_vv_seed(500);

INSERT INTO vv2 (grp, v) SELECT grp, v FROM vv1;
INSERT INTO vv3 (grp, v) SELECT grp, v FROM vv1;
INSERT INTO vv4 (grp, v, w) SELECT grp, v, v FROM vv1 WHERE id <= 300;
INSERT INTO vv5 (grp, v, w) SELECT grp, v, v FROM vv1 WHERE id <= 300;
