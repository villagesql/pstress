-- Run once per fresh datadir, before pstress step 1.
-- Creates the vsql_cube R-tree tables that grammar/vsql_cube_*.sql work on, in
-- their own database: pstress drops and recreates `test` at step 1.
--
-- The cube type converts only literals and prepared statement parameters, so
-- computed values go in through PREPARE ... USING. Every index is declared
-- before any rows exist: building an index over rows or rebuilding the table
-- crashes the server today (Btree_load::build, buf0buf.cc:4794).

SET PERSIST vsql_allow_preview_extensions = ON;
INSTALL EXTENSION vsql_cube;

CREATE DATABASE vsql;
USE vsql;

-- Dense 2-D points and small boxes.
CREATE TABLE cb1 (
  id INT PRIMARY KEY,
  c `cube`(2) NOT NULL,
  INDEX ic (c) USING EXTENDED(vsql_cube.rtree)
);

-- Nullable: NULL values are not indexed.
CREATE TABLE cb2 (
  id INT PRIMARY KEY,
  c `cube`(3),
  INDEX ic (c) USING EXTENDED(vsql_cube.rtree)
);

-- Taxicab and Chebyshev indexes on one column (warning 1831 is expected).
CREATE TABLE cb3 (
  id INT PRIMARY KEY,
  c `cube`(2) NOT NULL,
  INDEX il1 (c cube_rtree_l1) USING EXTENDED(vsql_cube.rtree),
  INDEX ilinf (c cube_rtree_linf) USING EXTENDED(vsql_cube.rtree)
);

-- Wide entries, about 10 per page: a deep tree with many splits.
CREATE TABLE cb4 (
  id INT PRIMARY KEY,
  c `cube`(100) NOT NULL,
  INDEX ic (c) USING EXTENDED(vsql_cube.rtree)
);

-- Composite primary key with a variable-length part.
CREATE TABLE cb5 (
  a INT NOT NULL,
  b VARCHAR(20) NOT NULL,
  c `cube`(2) NOT NULL,
  PRIMARY KEY (a, b),
  INDEX ic (c) USING EXTENDED(vsql_cube.rtree)
);

-- Hidden row id primary key.
CREATE TABLE cb6 (
  c `cube`(2) NOT NULL,
  INDEX ic (c) USING EXTENDED(vsql_cube.rtree)
);

CREATE TABLE cb_log (
  id INT AUTO_INCREMENT PRIMARY KEY,
  src VARCHAR(16),
  ref INT,
  r DOUBLE
);

DELIMITER //

-- A random cube for table t: a point, or with probability box_pct/100 a small
-- box, with coordinates in 0-100 (cb4: 100 dimensions in 0-10). cb2 gets NULL
-- with probability 1/10.
CREATE FUNCTION f_cb_val(t VARCHAR(4), box_pct INT) RETURNS VARCHAR(4000) NO SQL
BEGIN
  DECLARE n INT DEFAULT IF(t = 'cb4', 100, IF(t = 'cb2', 3, 2));
  DECLARE hi DOUBLE DEFAULT IF(t = 'cb4', 10, 100);
  DECLARE i INT DEFAULT 1;
  DECLARE p VARCHAR(2000) DEFAULT '';
  DECLARE q VARCHAR(2000) DEFAULT '';
  DECLARE x DOUBLE;
  DECLARE box INT DEFAULT RAND() * 100 < box_pct;
  IF t = 'cb2' AND RAND() < 0.1 THEN
    RETURN NULL;
  END IF;
  WHILE i <= n DO
    SET x = ROUND(RAND() * hi, 2);
    SET p = CONCAT(p, IF(i > 1, ',', ''), x);
    SET q = CONCAT(q, IF(i > 1, ',', ''), ROUND(x + RAND() * hi / 50, 2));
    SET i = i + 1;
  END WHILE;
  RETURN IF(box, CONCAT('(', p, '),(', q, ')'), CONCAT('(', p, ')'));
END//

-- Inserts n rows into t with random ids in 1-id_max; duplicates are skipped.
CREATE PROCEDURE p_cb_ins(t VARCHAR(4), n INT, id_max INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  WHILE i < n DO
    SET @p_cb_id = FLOOR(1 + RAND() * id_max);
    SET @p_cb_v = f_cb_val(t, 20);
    CASE t
      WHEN 'cb5' THEN
        SET @p_cb_b = CONCAT('k', REPEAT('x', @p_cb_id % 13), @p_cb_id % 7);
        PREPARE p_cb_s FROM 'INSERT IGNORE INTO vsql.cb5 VALUES (?, ?, ?)';
        EXECUTE p_cb_s USING @p_cb_id, @p_cb_b, @p_cb_v;
      WHEN 'cb6' THEN
        PREPARE p_cb_s FROM 'INSERT INTO vsql.cb6 VALUES (?)';
        EXECUTE p_cb_s USING @p_cb_v;
      ELSE
        SET @s = CONCAT('INSERT IGNORE INTO vsql.', t, ' VALUES (?, ?)');
        PREPARE p_cb_s FROM @s;
        EXECUTE p_cb_s USING @p_cb_id, @p_cb_v;
    END CASE;
    DEALLOCATE PREPARE p_cb_s;
    SET i = i + 1;
  END WHILE;
END//

-- Moves n random rows of t: far to a new random place, or near by up to
-- about 1 unit. cb6 has no key column, so its rows are picked by value.
CREATE PROCEDURE p_cb_move(t VARCHAR(4), n INT, far INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  WHILE i < n DO
    SET @p_cb_id = FLOOR(1 + RAND() * 5000);
    SET @p_cb_v = f_cb_val(t, IF(far, 20, 0));
    IF NOT far AND t IN ('cb1', 'cb3', 'cb5', 'cb6') THEN
      SET @p_cb_v = CONCAT('(', ROUND(RAND() * 2 + 49, 2), ',', ROUND(RAND() * 2 + 49, 2), ')');
    END IF;
    CASE t
      WHEN 'cb5' THEN
        PREPARE p_cb_s FROM 'UPDATE vsql.cb5 SET c = ? WHERE a >= ? ORDER BY a LIMIT 1';
      WHEN 'cb6' THEN
        PREPARE p_cb_s FROM 'UPDATE vsql.cb6 SET c = ? ORDER BY cube_distance(c, ''(50,50)'') LIMIT 1';
      ELSE
        SET @s = CONCAT('UPDATE vsql.', t, ' SET c = ? WHERE id >= ? ORDER BY id LIMIT 1');
        PREPARE p_cb_s FROM @s;
    END CASE;
    IF t = 'cb6' THEN
      EXECUTE p_cb_s USING @p_cb_v;
    ELSE
      EXECUTE p_cb_s USING @p_cb_v, @p_cb_id;
    END IF;
    DEALLOCATE PREPARE p_cb_s;
    SET i = i + 1;
  END WHILE;
END//

DELIMITER ;

-- One row per p_cb_chk call; init/vsql_cube_check.sql reports them after
-- every restart and marks them seen.
CREATE TABLE cb_chk (
  id INT AUTO_INCREMENT PRIMARY KEY,
  t VARCHAR(8) NOT NULL,
  fn VARCHAR(32) NOT NULL,
  lim INT NOT NULL,
  filt INT NOT NULL,
  n_rows INT,
  c_idx INT,
  c_full INT,
  same_d INT,
  same_k INT,
  q VARCHAR(4000),
  d_idx MEDIUMTEXT,
  d_full MEDIUMTEXT,
  k_idx MEDIUMTEXT,
  k_full MEDIUMTEXT,
  seen INT NOT NULL DEFAULT 0
);

DELIMITER //

-- Compares one KNN query through the R-tree index with the same query
-- without it, in one REPEATABLE READ snapshot. The index is exact, so the
-- distances, in the order the index returned them, must equal the sorted
-- distances of the full scan (same_d), and the keys of the rows closer than
-- the last distance must be the same (same_k; rows tied at the last distance
-- may differ). lim = 0 compares every row: the index must return exactly
-- COUNT(*) non-NULL rows. filt = 1 adds WHERE MOD(id, 7) = 0, which makes the
-- limit inexact. tt is cb1, cb2, cb4, cb5, cb6, cb3l1 or cb3linf.
-- Commits the caller's transaction first.
CREATE PROCEDURE p_cb_chk(tt VARCHAR(8), lim INT, filt INT)
BEGIN
  DECLARE iso VARCHAR(32) DEFAULT @@SESSION.transaction_isolation;
  DECLARE t VARCHAR(8) DEFAULT tt;
  DECLARE fn VARCHAR(32) DEFAULT 'cube_distance';
  DECLARE ix VARCHAR(16) DEFAULT 'ic';
  DECLARE k VARCHAR(64) DEFAULT 'id';
  DECLARE w VARCHAR(64) DEFAULT 'c IS NOT NULL';
  DECLARE lm VARCHAR(16) DEFAULT IF(lim = 0, '1000000', lim);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET SESSION transaction_isolation = iso;
    RESIGNAL;
  END;
  CASE tt
    WHEN 'cb3l1' THEN SET t = 'cb3', fn = 'cube_taxicab_distance', ix = 'il1, ilinf';
    WHEN 'cb3linf' THEN SET t = 'cb3', fn = 'cube_chebyshev_distance', ix = 'il1, ilinf';
    WHEN 'cb5' THEN SET k = 'CONCAT(a, '':'', b)';
    WHEN 'cb6' THEN SET k = 'NULL';
    ELSE BEGIN END;
  END CASE;
  IF filt THEN
    SET w = CONCAT(w, IF(t = 'cb5', ' AND MOD(a, 7) = 0', IF(t = 'cb6', ' AND MOD(ROUND(cube_ll_coord(c, 1)), 7) = 0', ' AND MOD(id, 7) = 0')));
  END IF;
  COMMIT;
  SET SESSION transaction_isolation = 'REPEATABLE-READ';
  SET SESSION group_concat_max_len = 16 * 1024 * 1024;
  START TRANSACTION WITH CONSISTENT SNAPSHOT;

  SET @p_cb_q = f_cb_val(IF(t = 'cb2', 'cb1', t), 25);
  IF t = 'cb2' THEN
    SET @p_cb_q = CONCAT('(', ROUND(RAND() * 100, 2), ',', ROUND(RAND() * 100, 2), ',', ROUND(RAND() * 100, 2), ')');
  END IF;

  SET @s = CONCAT('SELECT COUNT(*) INTO @p_cb_n FROM vsql.', t, ' WHERE ', w);
  PREPARE p_cb_s FROM @s;
  EXECUTE p_cb_s;
  DEALLOCATE PREPARE p_cb_s;

  -- The derived table keeps the scan order, so the GROUP_CONCAT of d without
  -- ORDER BY lists the distances in the order the index returned them.
  SET @s = CONCAT('SELECT COUNT(*), GROUP_CONCAT(d), MAX(d) INTO @p_cb_ci, @p_cb_di, @p_cb_mi ',
                  'FROM (SELECT ROUND(', fn, '(c, ?), 9) AS d FROM vsql.', t,
                  IF(filt, CONCAT(' WHERE ', w), ''),
                  ' ORDER BY ', fn, '(c, ?) LIMIT ', lm, ') x');
  PREPARE p_cb_s FROM @s;
  EXECUTE p_cb_s USING @p_cb_q, @p_cb_q;
  DEALLOCATE PREPARE p_cb_s;

  SET @s = CONCAT('SELECT COUNT(*), GROUP_CONCAT(d ORDER BY d), MAX(d) INTO @p_cb_cf, @p_cb_df, @p_cb_mf ',
                  'FROM (SELECT ROUND(', fn, '(c, ?), 9) AS d FROM vsql.', t,
                  ' IGNORE INDEX (', ix, ') WHERE ', w,
                  ' ORDER BY ', fn, '(c, ?) LIMIT ', lm, ') x');
  PREPARE p_cb_s FROM @s;
  EXECUTE p_cb_s USING @p_cb_q, @p_cb_q;
  DEALLOCATE PREPARE p_cb_s;

  SET @p_cb_ki = NULL, @p_cb_kf = NULL;
  IF k <> 'NULL' THEN
    SET @s = CONCAT('SELECT GROUP_CONCAT(k ORDER BY k) INTO @p_cb_ki ',
                    'FROM (SELECT ', k, ' AS k, ROUND(', fn, '(c, ?), 9) AS d FROM vsql.', t,
                    IF(filt, CONCAT(' WHERE ', w), ''),
                    ' ORDER BY ', fn, '(c, ?) LIMIT ', lm, ') x WHERE d < ?');
    PREPARE p_cb_s FROM @s;
    EXECUTE p_cb_s USING @p_cb_q, @p_cb_q, @p_cb_mf;
    DEALLOCATE PREPARE p_cb_s;
    SET @s = CONCAT('SELECT GROUP_CONCAT(k ORDER BY k) INTO @p_cb_kf ',
                    'FROM (SELECT ', k, ' AS k, ROUND(', fn, '(c, ?), 9) AS d FROM vsql.', t,
                    ' IGNORE INDEX (', ix, ') WHERE ', w,
                    ' ORDER BY ', fn, '(c, ?) LIMIT ', lm, ') x WHERE d < ?');
    PREPARE p_cb_s FROM @s;
    EXECUTE p_cb_s USING @p_cb_q, @p_cb_q, @p_cb_mf;
    DEALLOCATE PREPARE p_cb_s;
  END IF;

  INSERT INTO vsql.cb_chk (t, fn, lim, filt, n_rows, c_idx, c_full, same_d, same_k, q,
                           d_idx, d_full, k_idx, k_full)
  VALUES (tt, fn, lim, filt, @p_cb_n, @p_cb_ci, @p_cb_cf, @p_cb_di <=> @p_cb_df,
          @p_cb_ki <=> @p_cb_kf, @p_cb_q,
          IF(@p_cb_di <=> @p_cb_df, NULL, @p_cb_di), IF(@p_cb_di <=> @p_cb_df, NULL, @p_cb_df),
          IF(@p_cb_ki <=> @p_cb_kf, NULL, @p_cb_ki), IF(@p_cb_ki <=> @p_cb_kf, NULL, @p_cb_kf));
  COMMIT;
  SET SESSION transaction_isolation = iso;
END//

DELIMITER ;

-- One row per p_cb_lchk call, reported like cb_chk.
CREATE TABLE cb_lchk (
  id INT AUTO_INCREMENT PRIMARY KEY,
  t VARCHAR(8) NOT NULL,
  fn VARCHAR(32) NOT NULL,
  lim INT NOT NULL,
  filt INT NOT NULL,
  lck VARCHAR(32) NOT NULL,
  iso VARCHAR(32) NOT NULL,
  full_cmp INT NOT NULL,
  n_rows INT,
  c_idx INT,
  c_full INT,
  dups INT,
  ordered INT,
  missing INT,
  same_d INT,
  same_k INT,
  q VARCHAR(4000),
  d_idx MEDIUMTEXT,
  d_full MEDIUMTEXT,
  k_idx MEDIUMTEXT,
  k_full MEDIUMTEXT,
  seen INT NOT NULL DEFAULT 0
);

DELIMITER //

-- Checks one locking KNN read (mode 1 FOR UPDATE, 2 FOR SHARE, 3 FOR UPDATE
-- SKIP LOCKED) at the session's isolation level. The rows go into a temporary
-- table in the order the index returned them. In every mode no row may come
-- back twice (dups), distances must not decrease (ordered), and every row
-- must still exist with the returned cube when re-read by primary key in the
-- same transaction (missing). With full_cmp = 1, for quiescent use only, the
-- same locking query without the index must give the same distances and the
-- same keys below the last distance, as in p_cb_chk; lim = 0 reads every row.
-- Under load use full_cmp = 0: other rows may change between the two reads.
-- cb6 has no key, so dups and missing are not checked there.
-- Commits the caller's transaction first.
CREATE PROCEDURE p_cb_lchk(tt VARCHAR(8), lim INT, filt INT, mode INT, full_cmp INT)
BEGIN
  DECLARE t VARCHAR(8) DEFAULT tt;
  DECLARE fn VARCHAR(32) DEFAULT 'cube_distance';
  DECLARE ix VARCHAR(16) DEFAULT 'ic';
  DECLARE kc VARCHAR(64) DEFAULT 'id, ''''';
  DECLARE kj VARCHAR(64) DEFAULT 'x.id = i.a';
  DECLARE w VARCHAR(128) DEFAULT 'c IS NOT NULL';
  DECLARE lm VARCHAR(16) DEFAULT IF(lim = 0, '1000000', lim);
  DECLARE lc VARCHAR(32) DEFAULT CASE mode WHEN 2 THEN ' FOR SHARE'
                                           WHEN 3 THEN ' FOR UPDATE SKIP LOCKED'
                                           ELSE ' FOR UPDATE' END;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  CASE tt
    WHEN 'cb3l1' THEN SET t = 'cb3', fn = 'cube_taxicab_distance', ix = 'il1, ilinf';
    WHEN 'cb3linf' THEN SET t = 'cb3', fn = 'cube_chebyshev_distance', ix = 'il1, ilinf';
    WHEN 'cb5' THEN SET kc = 'a, b', kj = 'x.a = i.a AND x.b = i.b';
    WHEN 'cb6' THEN SET kc = 'NULL, NULL', kj = NULL;
    ELSE BEGIN END;
  END CASE;
  IF filt THEN
    SET w = CONCAT(w, IF(t = 'cb5', ' AND MOD(a, 7) = 0', IF(t = 'cb6', ' AND MOD(ROUND(cube_ll_coord(c, 1)), 7) = 0', ' AND MOD(id, 7) = 0')));
  END IF;
  COMMIT;
  SET SESSION group_concat_max_len = 16 * 1024 * 1024;
  CREATE TEMPORARY TABLE IF NOT EXISTS vsql.cb_tmp_i (
    seq INT AUTO_INCREMENT PRIMARY KEY, a INT, b VARCHAR(40), d DOUBLE, cv VARCHAR(4000));
  CREATE TEMPORARY TABLE IF NOT EXISTS vsql.cb_tmp_f LIKE vsql.cb_tmp_i;
  TRUNCATE TABLE vsql.cb_tmp_i;
  TRUNCATE TABLE vsql.cb_tmp_f;

  SET @p_cb_q = f_cb_val(IF(t = 'cb2', 'cb1', t), 25);
  IF t = 'cb2' THEN
    SET @p_cb_q = CONCAT('(', ROUND(RAND() * 100, 2), ',', ROUND(RAND() * 100, 2), ',', ROUND(RAND() * 100, 2), ')');
  END IF;

  START TRANSACTION;
  -- c IS NOT NULL keeps the index plan's result: SERIALIZABLE reads do not use
  -- the KNN scan, and the sort they use puts NULL distances first.
  SET @s = CONCAT('INSERT INTO vsql.cb_tmp_i (a, b, d, cv) SELECT ', kc, ', ROUND(', fn,
                  '(c, ?), 9), cube_to_string(c) FROM vsql.', t, ' WHERE ', w,
                  ' ORDER BY ', fn, '(c, ?) LIMIT ', lm, lc);
  PREPARE p_cb_s FROM @s;
  EXECUTE p_cb_s USING @p_cb_q, @p_cb_q;
  DEALLOCATE PREPARE p_cb_s;

  SELECT COUNT(*), GROUP_CONCAT(d ORDER BY seq), GROUP_CONCAT(d ORDER BY d), MAX(d),
         IF(kj IS NULL, 0, COUNT(*) - COUNT(DISTINCT a, b))
    INTO @p_cb_ci, @p_cb_di, @p_cb_ds, @p_cb_mi, @p_cb_dups
    FROM vsql.cb_tmp_i;

  SET @p_cb_found = @p_cb_ci;
  IF kj IS NOT NULL THEN
    SET @s = CONCAT('SELECT COUNT(*) INTO @p_cb_found FROM vsql.cb_tmp_i i STRAIGHT_JOIN vsql.', t,
                    ' x ON ', kj, ' AND cube_to_string(x.c) = i.cv FOR SHARE OF x');
    PREPARE p_cb_s FROM @s;
    EXECUTE p_cb_s;
    DEALLOCATE PREPARE p_cb_s;
  END IF;

  SET @p_cb_n = NULL, @p_cb_cf = NULL, @p_cb_df = NULL, @p_cb_ki = NULL, @p_cb_kf = NULL;
  IF full_cmp THEN
    SET @s = CONCAT('SELECT COUNT(*) INTO @p_cb_n FROM vsql.', t, ' WHERE ', w);
    PREPARE p_cb_s FROM @s;
    EXECUTE p_cb_s;
    DEALLOCATE PREPARE p_cb_s;
    SET @s = CONCAT('INSERT INTO vsql.cb_tmp_f (a, b, d, cv) SELECT ', kc, ', ROUND(', fn,
                    '(c, ?), 9), cube_to_string(c) FROM vsql.', t, ' IGNORE INDEX (', ix,
                    ') WHERE ', w, ' ORDER BY ', fn, '(c, ?) LIMIT ', lm, lc);
    PREPARE p_cb_s FROM @s;
    EXECUTE p_cb_s USING @p_cb_q, @p_cb_q;
    DEALLOCATE PREPARE p_cb_s;
    SELECT COUNT(*), GROUP_CONCAT(d ORDER BY d), MAX(d) INTO @p_cb_cf, @p_cb_df, @p_cb_mf
      FROM vsql.cb_tmp_f;
    IF kj IS NOT NULL THEN
      SELECT GROUP_CONCAT(CONCAT(a, ':', b) ORDER BY CONCAT(a, ':', b)) INTO @p_cb_ki
        FROM vsql.cb_tmp_i WHERE d < @p_cb_mf;
      SELECT GROUP_CONCAT(CONCAT(a, ':', b) ORDER BY CONCAT(a, ':', b)) INTO @p_cb_kf
        FROM vsql.cb_tmp_f WHERE d < @p_cb_mf;
    END IF;
  END IF;

  SET @p_cb_samek = IF(full_cmp, @p_cb_ki <=> @p_cb_kf, NULL);
  IF @p_cb_dups > 0 OR @p_cb_ci > @p_cb_found THEN
    -- Rows returned twice go first, with their positions, so the report's
    -- truncation cannot hide them.
    SELECT GROUP_CONCAT(CONCAT(a, ':', b, '@', s) SEPARATOR ' ') INTO @p_cb_dk
      FROM (SELECT a, b, GROUP_CONCAT(seq ORDER BY seq) AS s FROM vsql.cb_tmp_i
            GROUP BY a, b HAVING COUNT(*) > 1) x;
    SELECT CONCAT_WS(' ', CONCAT('twice ', @p_cb_dk, ' all'),
                     GROUP_CONCAT(CONCAT(a, ':', b, '=', cv) ORDER BY seq SEPARATOR ' ')) INTO @p_cb_ki
      FROM vsql.cb_tmp_i;
    SET @p_cb_kf = NULL;
  END IF;

  INSERT INTO vsql.cb_lchk (t, fn, lim, filt, lck, iso, full_cmp, n_rows, c_idx, c_full, dups,
                            ordered, missing, same_d, same_k, q, d_idx, d_full, k_idx, k_full)
  VALUES (tt, fn, lim, filt, TRIM(lc), @@SESSION.transaction_isolation, full_cmp, @p_cb_n,
          @p_cb_ci, @p_cb_cf, @p_cb_dups, @p_cb_di <=> @p_cb_ds, @p_cb_ci - @p_cb_found,
          IF(full_cmp, @p_cb_di <=> @p_cb_df, NULL), @p_cb_samek,
          @p_cb_q,
          IF(@p_cb_di <=> @p_cb_ds AND (NOT full_cmp OR @p_cb_di <=> @p_cb_df), NULL, @p_cb_di),
          IF(full_cmp AND NOT (@p_cb_di <=> @p_cb_df), @p_cb_df, NULL),
          IF(@p_cb_ki <=> @p_cb_kf, NULL, @p_cb_ki),
          IF(@p_cb_ki <=> @p_cb_kf, NULL, @p_cb_kf));
  COMMIT;
END//

-- Commits or rolls back XA transaction 'xc1' of vsql_cube_txn when it is
-- left prepared by a killed server or a closed session; its locks would make
-- the checks time out.
CREATE PROCEDURE p_cb_xa_end()
BEGIN
  DECLARE CONTINUE HANDLER FOR 1397 BEGIN END;
  IF RAND() < 0.5 THEN
    XA COMMIT 'xc1';
  ELSE
    XA ROLLBACK 'xc1';
  END IF;
END//

DELIMITER ;

-- Procedures must not return result sets: pstress reads only the first result
-- of a CALL, which leaves its connection out of sync for the rest of the run.
CREATE PROCEDURE p_cb_knn(lim INT)
  INSERT INTO cb_log (src, ref, r)
  SELECT 'p_cb_knn', id, cube_distance(c, '(50,50)')
  FROM cb1 ORDER BY cube_distance(c, '(50,50)') LIMIT lim;

DELIMITER //

-- Runs one transaction shape on a random row of t (cb1, cb2, cb3 or cb4) and
-- commits it (fin = 1) or rolls it back (fin = 0). These are the cases purge
-- and rollback have to tell apart:
--   1 delete the row and insert it again with the same id and value
--   2 move the row away and back three times
--   3 insert a new row and delete it
--   4 move, savepoint, delete, roll back to the savepoint, move again
--   5 delete and re-insert as in 1, then move the row away
--   6 change the primary key away and back, then away again
-- Commits the caller's transaction first.
CREATE PROCEDURE p_cb_txn(t VARCHAR(4), kind INT, fin INT)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  COMMIT;
  START TRANSACTION;
  SET @p_cb_id = FLOOR(1 + RAND() * IF(t = 'cb4', 3000, 6000)), @p_cb_v = NULL;
  SET @s = CONCAT('SELECT id, cube_to_string(c) INTO @p_cb_id, @p_cb_v FROM vsql.', t,
                  ' WHERE id >= ? ORDER BY id LIMIT 1 FOR UPDATE');
  PREPARE p_cb_t FROM @s;
  EXECUTE p_cb_t USING @p_cb_id;
  DEALLOCATE PREPARE p_cb_t;
  SET @p_cb_far = f_cb_val(IF(t = 'cb2', 'cb1', t), 20);
  IF kind = 1 OR kind = 5 THEN
    SET @s = CONCAT('DELETE FROM vsql.', t, ' WHERE id = ?');
    PREPARE p_cb_t FROM @s;
    EXECUTE p_cb_t USING @p_cb_id;
    DEALLOCATE PREPARE p_cb_t;
    SET @s = CONCAT('INSERT INTO vsql.', t, ' VALUES (?, ?)');
    PREPARE p_cb_t FROM @s;
    EXECUTE p_cb_t USING @p_cb_id, @p_cb_v;
    DEALLOCATE PREPARE p_cb_t;
  END IF;
  IF kind = 2 OR kind = 5 THEN
    SET @s = CONCAT('UPDATE vsql.', t, ' SET c = ? WHERE id = ?');
    PREPARE p_cb_t FROM @s;
    EXECUTE p_cb_t USING @p_cb_far, @p_cb_id;
    IF kind = 2 THEN
      EXECUTE p_cb_t USING @p_cb_v, @p_cb_id;
      EXECUTE p_cb_t USING @p_cb_far, @p_cb_id;
      EXECUTE p_cb_t USING @p_cb_v, @p_cb_id;
      EXECUTE p_cb_t USING @p_cb_far, @p_cb_id;
      EXECUTE p_cb_t USING @p_cb_v, @p_cb_id;
    END IF;
    DEALLOCATE PREPARE p_cb_t;
  END IF;
  IF kind = 3 THEN
    SET @p_cb_new = 20000 + FLOOR(RAND() * 10000);
    SET @s = CONCAT('INSERT IGNORE INTO vsql.', t, ' VALUES (?, ?)');
    PREPARE p_cb_t FROM @s;
    EXECUTE p_cb_t USING @p_cb_new, @p_cb_far;
    DEALLOCATE PREPARE p_cb_t;
    SET @s = CONCAT('DELETE FROM vsql.', t, ' WHERE id = ?');
    PREPARE p_cb_t FROM @s;
    EXECUTE p_cb_t USING @p_cb_new;
    DEALLOCATE PREPARE p_cb_t;
  END IF;
  IF kind = 4 THEN
    SET @s = CONCAT('UPDATE vsql.', t, ' SET c = ? WHERE id = ?');
    PREPARE p_cb_t FROM @s;
    EXECUTE p_cb_t USING @p_cb_far, @p_cb_id;
    SAVEPOINT p_cb_sp;
    SET @s = CONCAT('DELETE FROM vsql.', t, ' WHERE id = ?');
    PREPARE p_cb_d FROM @s;
    EXECUTE p_cb_d USING @p_cb_id;
    DEALLOCATE PREPARE p_cb_d;
    ROLLBACK TO SAVEPOINT p_cb_sp;
    EXECUTE p_cb_t USING @p_cb_v, @p_cb_id;
    DEALLOCATE PREPARE p_cb_t;
  END IF;
  IF kind = 6 THEN
    SET @p_cb_new = @p_cb_id + 20000;
    SET @s = CONCAT('UPDATE vsql.', t, ' SET id = ? WHERE id = ?');
    PREPARE p_cb_t FROM @s;
    EXECUTE p_cb_t USING @p_cb_new, @p_cb_id;
    EXECUTE p_cb_t USING @p_cb_id, @p_cb_new;
    EXECUTE p_cb_t USING @p_cb_new, @p_cb_id;
    DEALLOCATE PREPARE p_cb_t;
  END IF;
  IF fin THEN
    COMMIT;
  ELSE
    ROLLBACK;
  END IF;
END//

DELIMITER ;

CREATE TRIGGER cb1_au AFTER UPDATE ON cb1 FOR EACH ROW
  INSERT INTO cb_log (src, ref, r) VALUES ('cb1_au', NEW.id, cube_distance(NEW.c, OLD.c));

CALL p_cb_ins('cb1', 4000, 6000);
CALL p_cb_ins('cb2', 3000, 6000);
CALL p_cb_ins('cb3', 3000, 6000);
CALL p_cb_ins('cb4', 2000, 3000);
CALL p_cb_ins('cb5', 3000, 6000);
CALL p_cb_ins('cb6', 3000, 6000);
