-- Run once per fresh datadir, before pstress step 1.
-- Creates the vsql_textsearch bm25 tables that grammar/vsql_textsearch_*.sql
-- work on, in their own database: pstress drops and recreates `test` at
-- step 1.
--
-- Every table has the indexed doc column body and a VARCHAR txt holding the
-- same text, written by the same statement, so the checks can find the rows
-- that contain a word with REGEXP. doc converts only literals and prepared
-- statement parameters, so computed text goes in through PREPARE ... USING.
-- Every index is declared before any rows exist: the server cannot build a
-- custom index over rows or rebuild the table.
--
-- An index keeps memtable_docs row versions in memory and then writes them
-- out as a segment, and merges segments_per_level segments of one level into
-- one. tx1, tx3, tx5 and tx6 use small values so that DML, rollback, locking
-- reads and recovery act on segment documents while merges replace them;
-- tx2 and tx4 keep the defaults. tx_opt holds the values for the checks.

SET PERSIST vsql_allow_preview_extensions = ON;
INSTALL EXTENSION vsql_textsearch;

CREATE DATABASE vsql;
USE vsql;

-- The checked table.
CREATE TABLE tx1 (
  id INT PRIMARY KEY,
  body doc,
  txt VARCHAR(3000),
  INDEX ib (body) USING EXTENDED(vsql_textsearch.bm25) WITH (analyzer = 'simple', memtable_docs = 50, segments_per_level = 4)
);

-- english analyzer (stopwords, stemming): membership is not checked.
CREATE TABLE tx2 (
  id INT PRIMARY KEY,
  body doc,
  txt VARCHAR(3000),
  INDEX ib (body) USING EXTENDED(vsql_textsearch.bm25)
);

-- Composite primary key with a variable-length part. Every row version is
-- written out as its own segment, and merges run all the time.
CREATE TABLE tx3 (
  a INT NOT NULL,
  b VARCHAR(20) NOT NULL,
  body doc,
  txt VARCHAR(3000),
  PRIMARY KEY (a, b),
  INDEX ib (body) USING EXTENDED(vsql_textsearch.bm25) WITH (analyzer = 'simple', memtable_docs = 1, segments_per_level = 2)
);

-- Hidden row id primary key.
CREATE TABLE tx4 (
  body doc,
  txt VARCHAR(3000),
  INDEX ib (body) USING EXTENDED(vsql_textsearch.bm25) WITH (analyzer = 'simple')
);

-- Non-default parameters.
CREATE TABLE tx5 (
  id INT PRIMARY KEY,
  body doc,
  txt VARCHAR(3000),
  INDEX ib (body) USING EXTENDED(vsql_textsearch.bm25) WITH (analyzer = 'simple', k1 = '2.0', b = '0.3', memtable_docs = 7, segments_per_level = 3)
);

-- The vocabulary of the checked tables: no word is a substring of another,
-- and the low numbers are used most.
CREATE TABLE tx_words (n INT PRIMARY KEY, w VARCHAR(16) NOT NULL);
INSERT INTO tx_words VALUES
  (1, 'apple'), (2, 'river'), (3, 'stone'), (4, 'cloud'), (5, 'green'),
  (6, 'night'), (7, 'quick'), (8, 'silver'), (9, 'garden'), (10, 'copper'),
  (11, 'winter'), (12, 'amber'), (13, 'falcon'), (14, 'harbor'), (15, 'meadow'),
  (16, 'orchid'), (17, 'pepper'), (18, 'saddle'), (19, 'tunnel'), (20, 'velvet'),
  (21, 'maple'), (22, 'bridge'), (23, 'candle'), (24, 'desert'), (25, 'ember'),
  (26, 'forest'), (27, 'glacier'), (28, 'hollow'), (29, 'island'), (30, 'jungle'),
  (31, 'kettle'), (32, 'lantern'), (33, 'marble'), (34, 'nectar'), (35, 'oyster'),
  (36, 'prism'), (37, 'quartz'), (38, 'raven'), (39, 'summit'), (40, 'thistle');

-- Extra tx2 words: plurals, stopwords, capitals and non-ASCII text.
CREATE TABLE tx_words2 (n INT PRIMARY KEY, w VARCHAR(16) NOT NULL);
INSERT INTO tx_words2 VALUES
  (1, 'apples'), (2, 'rivers'), (3, 'the'), (4, 'and'), (5, 'of'),
  (6, 'Stone'), (7, 'CLOUDS'), (8, 'café'), (9, 'straße'), (10, '日本語'),
  (11, 'gardens'), (12, 'running'), (13, 'Falcons'), (14, 'naïve'), (15, 'a');

CREATE TABLE tx_log (
  id INT AUTO_INCREMENT PRIMARY KEY,
  src VARCHAR(16),
  ref INT,
  r DOUBLE
);

CREATE TABLE tx_opt (t VARCHAR(4) PRIMARY KEY, memtable_docs INT, segments_per_level INT);
INSERT INTO tx_opt VALUES ('tx1', 50, 4), ('tx2', 10000, 8), ('tx3', 1, 2), ('tx4', 10000, 8),
  ('tx5', 7, 3), ('tx6', 1, 2);

-- An index lists the segments left after merging in one root page, so a
-- table with a small memtable_docs takes only so many row versions.
-- Triggers call p_tx_budget for every row written to tx1, tx3 and tx5; it
-- fails the statement once the table has used base + per_sec * (seconds
-- since init) row versions. Rolled-back writes count too: an AUTO_INCREMENT
-- value is not given back. A datadir lives about 550 seconds.
CREATE TABLE tx_budget (t VARCHAR(4) PRIMARY KEY, base INT, per_sec INT, start DATETIME);
INSERT INTO tx_budget VALUES ('tx1', 20000, 200, NOW()), ('tx3', 4000, 40, NOW()), ('tx5', 5000, 60, NOW());
CREATE TABLE tx_seq1 (id INT AUTO_INCREMENT PRIMARY KEY);
CREATE TABLE tx_seq3 (id INT AUTO_INCREMENT PRIMARY KEY);
CREATE TABLE tx_seq5 (id INT AUTO_INCREMENT PRIMARY KEY);

DELIMITER //

CREATE PROCEDURE p_tx_budget(tt VARCHAR(4))
BEGIN
  DECLARE cap INT;
  CASE tt
    WHEN 'tx1' THEN INSERT INTO vsql.tx_seq1 VALUES (NULL);
    WHEN 'tx3' THEN INSERT INTO vsql.tx_seq3 VALUES (NULL);
    ELSE INSERT INTO vsql.tx_seq5 VALUES (NULL);
  END CASE;
  SELECT base + per_sec * TIMESTAMPDIFF(SECOND, start, NOW()) INTO cap
    FROM vsql.tx_budget WHERE t = tt;
  IF LAST_INSERT_ID() > cap THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'write budget of the table used up for now';
  END IF;
END//

CREATE TRIGGER tx1_bi BEFORE INSERT ON tx1 FOR EACH ROW CALL p_tx_budget('tx1')//
CREATE TRIGGER tx1_bu BEFORE UPDATE ON tx1 FOR EACH ROW CALL p_tx_budget('tx1')//
CREATE TRIGGER tx1_bd BEFORE DELETE ON tx1 FOR EACH ROW CALL p_tx_budget('tx1')//
CREATE TRIGGER tx3_bi BEFORE INSERT ON tx3 FOR EACH ROW CALL p_tx_budget('tx3')//
CREATE TRIGGER tx3_bu BEFORE UPDATE ON tx3 FOR EACH ROW CALL p_tx_budget('tx3')//
CREATE TRIGGER tx3_bd BEFORE DELETE ON tx3 FOR EACH ROW CALL p_tx_budget('tx3')//
CREATE TRIGGER tx5_bi BEFORE INSERT ON tx5 FOR EACH ROW CALL p_tx_budget('tx5')//
CREATE TRIGGER tx5_bu BEFORE UPDATE ON tx5 FOR EACH ROW CALL p_tx_budget('tx5')//
CREATE TRIGGER tx5_bd BEFORE DELETE ON tx5 FOR EACH ROW CALL p_tx_budget('tx5')//

DELIMITER ;

DELIMITER //

-- A vocabulary word, skewed to the low numbers. tx2 gets an extra word one
-- time in four.
CREATE FUNCTION f_tx_word(t VARCHAR(4)) RETURNS VARCHAR(16) READS SQL DATA
BEGIN
  DECLARE k INT;
  IF t = 'tx2' AND RAND() < 0.25 THEN
    SET k = FLOOR(1 + RAND() * 15);
    RETURN (SELECT w FROM vsql.tx_words2 WHERE n = k);
  END IF;
  SET k = FLOOR(1 + POW(RAND(), 3) * 40);
  RETURN (SELECT w FROM vsql.tx_words WHERE n = k);
END//

-- Random text for table t: empty, one word repeated, near 3000 bytes, or 1
-- to 20 words, with spaces and punctuation between them. NULL with
-- probability null_pct/100.
CREATE FUNCTION f_tx_text(t VARCHAR(4), null_pct INT) RETURNS VARCHAR(3000) READS SQL DATA
BEGIN
  DECLARE r DOUBLE DEFAULT RAND();
  DECLARE s VARCHAR(3000) DEFAULT '';
  DECLARE w VARCHAR(16);
  DECLARE n INT;
  DECLARE i INT DEFAULT 0;
  IF RAND() * 100 < null_pct THEN
    RETURN NULL;
  END IF;
  IF r < 0.06 THEN
    RETURN '';
  END IF;
  IF r < 0.11 THEN
    SET w = f_tx_word(t);
    RETURN TRIM(REPEAT(CONCAT(w, ' '), FLOOR(2 + RAND() * 60)));
  END IF;
  SET n = IF(r < 0.16, 1000, FLOOR(1 + RAND() * 20));
  WHILE i < n DO
    SET w = f_tx_word(t);
    IF LENGTH(s) + LENGTH(w) + 2 > 3000 THEN
      RETURN s;
    END IF;
    SET s = CONCAT(s, IF(i = 0, '', ELT(FLOOR(1 + RAND() * 6), ' ', ', ', '. ', '-', '; ', '  ')), w);
    SET i = i + 1;
  END WHILE;
  RETURN s;
END//

-- The tx3 key part b for a.
CREATE FUNCTION f_tx_b(a INT) RETURNS VARCHAR(20) DETERMINISTIC NO SQL
  RETURN CONCAT('k', REPEAT('x', a % 13), a % 7)//

-- Inserts n rows into t with random ids in 1-id_max; duplicates are skipped.
CREATE PROCEDURE p_tx_ins(t VARCHAR(4), n INT, id_max INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  WHILE i < n DO
    SET @p_tx_id = FLOOR(1 + RAND() * id_max);
    SET @p_tx_v = f_tx_text(t, 5);
    CASE t
      WHEN 'tx3' THEN
        SET @p_tx_b = f_tx_b(@p_tx_id);
        PREPARE p_tx_s FROM 'INSERT IGNORE INTO vsql.tx3 VALUES (?, ?, ?, ?)';
        EXECUTE p_tx_s USING @p_tx_id, @p_tx_b, @p_tx_v, @p_tx_v;
      WHEN 'tx4' THEN
        PREPARE p_tx_s FROM 'INSERT INTO vsql.tx4 VALUES (?, ?)';
        EXECUTE p_tx_s USING @p_tx_v, @p_tx_v;
      ELSE
        SET @s = CONCAT('INSERT IGNORE INTO vsql.', t, ' VALUES (?, ?, ?)');
        PREPARE p_tx_s FROM @s;
        EXECUTE p_tx_s USING @p_tx_id, @p_tx_v, @p_tx_v;
    END CASE;
    DEALLOCATE PREPARE p_tx_s;
    SET i = i + 1;
  END WHILE;
END//

-- The condition that selects the row of t with the given key, read from
-- @p_tx_id (and @p_tx_b for tx3).
CREATE FUNCTION f_tx_key(t VARCHAR(4)) RETURNS VARCHAR(128) NO SQL
  RETURN IF(t = 'tx3', CONCAT('a = ', @p_tx_id, ' AND b = ''', @p_tx_b, ''''),
            CONCAT('id = ', @p_tx_id))//

-- Picks the first row of t (not tx4) with key >= a random id into @p_tx_id
-- (and @p_tx_b) and its text into @p_tx_old; @p_tx_id is NULL if there is
-- none.
CREATE PROCEDURE p_tx_pick(t VARCHAR(4), id_max INT)
BEGIN
  SET @p_tx_id = NULL, @p_tx_b = NULL, @p_tx_old = NULL;
  SET @p_tx_lo = FLOOR(1 + RAND() * id_max);
  IF t = 'tx3' THEN
    SET @s = 'SELECT a, b, txt INTO @p_tx_id, @p_tx_b, @p_tx_old FROM vsql.tx3 WHERE a >= ? ORDER BY a, b LIMIT 1';
  ELSE
    SET @s = CONCAT('SELECT id, txt INTO @p_tx_id, @p_tx_old FROM vsql.', t, ' WHERE id >= ? ORDER BY id LIMIT 1');
  END IF;
  PREPARE p_tx_s FROM @s;
  EXECUTE p_tx_s USING @p_tx_lo;
  DEALLOCATE PREPARE p_tx_s;
  -- A user variable first created by SET @v = NULL is a binary string, and
  -- SELECT ... INTO keeps that type for a NULL txt. pstress --reconnect clears
  -- user variables, so this happens in its sessions. doc takes only character
  -- strings, and CONCAT(IFNULL(@p_tx_old, ''), ...) would be binary.
  SET @p_tx_old = CONVERT(@p_tx_old USING utf8mb4);
END//

-- Sets the text of the picked row (or, for tx4, of the row ranked first for
-- a random word) to @p_tx_v.
CREATE PROCEDURE p_tx_set(t VARCHAR(4))
BEGIN
  IF t = 'tx4' THEN
    SET @s = CONCAT('UPDATE vsql.tx4 SET body = ?, txt = ? ORDER BY bm25_distance(body, ''',
                    f_tx_word(t), ''') LIMIT 1');
  ELSE
    SET @s = CONCAT('UPDATE vsql.', t, ' SET body = ?, txt = ? WHERE ', f_tx_key(t));
  END IF;
  PREPARE p_tx_s FROM @s;
  EXECUTE p_tx_s USING @p_tx_v, @p_tx_v;
  DEALLOCATE PREPARE p_tx_s;
END//

-- Updates the text of n random rows of t. kind 0: new text; 1: a word added
-- to or removed from the text; 2: the same text again; 3: NULL; 4: NULL rows
-- get text again.
CREATE PROCEDURE p_tx_upd(t VARCHAR(4), n INT, kind INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  WHILE i < n DO
    IF kind = 4 THEN
      SET @p_tx_v = f_tx_text(t, 0);
      SET @s = CONCAT('UPDATE vsql.', t, ' SET body = ?, txt = ? WHERE txt IS NULL LIMIT 1');
      PREPARE p_tx_s FROM @s;
      EXECUTE p_tx_s USING @p_tx_v, @p_tx_v;
      DEALLOCATE PREPARE p_tx_s;
    ELSE
      IF t <> 'tx4' THEN
        CALL p_tx_pick(t, IF(t = 'tx1', 6000, 3000));
      END IF;
      SET @p_tx_v = CASE kind
        WHEN 0 THEN f_tx_text(t, 0)
        WHEN 1 THEN IF(@p_tx_old IS NULL OR RAND() < 0.5 OR LOCATE(' ', @p_tx_old) = 0,
                       TRIM(CONCAT(IFNULL(@p_tx_old, ''), ' ', f_tx_word(t))),
                       SUBSTRING(@p_tx_old, LOCATE(' ', @p_tx_old) + 1))
        WHEN 2 THEN @p_tx_old
        ELSE NULL END;
      -- A NULL user variable is a binary string, and doc takes only
      -- character strings.
      SET @p_tx_v = CONVERT(@p_tx_v USING utf8mb4);
      IF LENGTH(@p_tx_v) > 3000 THEN
        SET @p_tx_v = f_tx_text(t, 0);
      END IF;
      IF t = 'tx4' OR @p_tx_id IS NOT NULL THEN
        CALL p_tx_set(t);
      END IF;
    END IF;
    SET i = i + 1;
  END WHILE;
END//

-- Transaction shapes on one random row of t (not tx4), then COMMIT (fin 0)
-- or ROLLBACK (fin 1). Commits the caller's transaction first.
-- kind 1: delete the row and insert it again with the same key and text.
-- kind 2: change the text away and back three times, ending on either.
-- kind 3: insert a new row and delete it.
-- kind 4: change the text, SAVEPOINT, change it again and insert a row,
--         ROLLBACK TO SAVEPOINT, change it a third time.
-- kind 5: change the primary key away, back, and away again.
CREATE PROCEDURE p_tx_txn(t VARCHAR(4), kind INT, fin INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  DECLARE k VARCHAR(128);
  DECLARE id_max INT DEFAULT IF(t = 'tx1', 6000, 3000);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  START TRANSACTION;
  CALL p_tx_pick(t, id_max);
  IF @p_tx_id IS NULL THEN
    COMMIT;
  ELSE
    SET k = f_tx_key(t);
    CASE kind
      WHEN 1 THEN
        SET @s = CONCAT('DELETE FROM vsql.', t, ' WHERE ', k);
        PREPARE p_tx_s FROM @s;
        EXECUTE p_tx_s;
        DEALLOCATE PREPARE p_tx_s;
        SET @p_tx_v = @p_tx_old;
        IF t = 'tx3' THEN
          PREPARE p_tx_s FROM 'INSERT INTO vsql.tx3 VALUES (?, ?, ?, ?)';
          EXECUTE p_tx_s USING @p_tx_id, @p_tx_b, @p_tx_v, @p_tx_v;
        ELSE
          SET @s = CONCAT('INSERT INTO vsql.', t, ' VALUES (?, ?, ?)');
          PREPARE p_tx_s FROM @s;
          EXECUTE p_tx_s USING @p_tx_id, @p_tx_v, @p_tx_v;
        END IF;
        DEALLOCATE PREPARE p_tx_s;
      WHEN 2 THEN
        SET @p_tx_new = f_tx_text(t, 0);
        WHILE i < 3 DO
          SET @p_tx_v = @p_tx_new;
          CALL p_tx_set(t);
          SET @p_tx_v = @p_tx_old;
          CALL p_tx_set(t);
          SET i = i + 1;
        END WHILE;
        IF RAND() < 0.5 THEN
          SET @p_tx_v = @p_tx_new;
          CALL p_tx_set(t);
        END IF;
      WHEN 3 THEN
        SET @p_tx_id = id_max + FLOOR(1 + RAND() * 1000), @p_tx_b = f_tx_b(@p_tx_id);
        SET @p_tx_v = f_tx_text(t, 0);
        IF t = 'tx3' THEN
          PREPARE p_tx_s FROM 'INSERT IGNORE INTO vsql.tx3 VALUES (?, ?, ?, ?)';
          EXECUTE p_tx_s USING @p_tx_id, @p_tx_b, @p_tx_v, @p_tx_v;
        ELSE
          SET @s = CONCAT('INSERT IGNORE INTO vsql.', t, ' VALUES (?, ?, ?)');
          PREPARE p_tx_s FROM @s;
          EXECUTE p_tx_s USING @p_tx_id, @p_tx_v, @p_tx_v;
        END IF;
        DEALLOCATE PREPARE p_tx_s;
        SET @s = CONCAT('DELETE FROM vsql.', t, ' WHERE ', f_tx_key(t));
        PREPARE p_tx_s FROM @s;
        EXECUTE p_tx_s;
        DEALLOCATE PREPARE p_tx_s;
      WHEN 4 THEN
        SET @p_tx_v = f_tx_text(t, 0);
        CALL p_tx_set(t);
        SAVEPOINT s1;
        SET @p_tx_v = f_tx_text(t, 0);
        CALL p_tx_set(t);
        CALL p_tx_ins(t, 2, id_max);
        ROLLBACK TO SAVEPOINT s1;
        SET @p_tx_v = f_tx_text(t, 0);
        CALL p_tx_set(t);
      ELSE
        IF t = 'tx3' THEN
          SET @s = CONCAT('UPDATE vsql.tx3 SET a = a + 20000 WHERE ', k);
          SET @s2 = CONCAT('UPDATE vsql.tx3 SET a = a - 20000 WHERE a = ', @p_tx_id + 20000, ' AND b = ''', @p_tx_b, '''');
        ELSE
          SET @s = CONCAT('UPDATE vsql.', t, ' SET id = id + 20000 WHERE ', k);
          SET @s2 = CONCAT('UPDATE vsql.', t, ' SET id = id - 20000 WHERE id = ', @p_tx_id + 20000);
        END IF;
        PREPARE p_tx_s FROM @s;
        EXECUTE p_tx_s;
        DEALLOCATE PREPARE p_tx_s;
        PREPARE p_tx_s FROM @s2;
        EXECUTE p_tx_s;
        DEALLOCATE PREPARE p_tx_s;
        PREPARE p_tx_s FROM @s;
        EXECUTE p_tx_s;
        DEALLOCATE PREPARE p_tx_s;
    END CASE;
    IF fin THEN
      ROLLBACK;
    ELSE
      COMMIT;
    END IF;
  END IF;
END//

-- Commits or rolls back XA transaction 'xt1' of vsql_textsearch_txn when it
-- is left prepared by a killed server or a closed session; its locks would
-- make the checks time out.
CREATE PROCEDURE p_tx_xa_end()
BEGIN
  DECLARE CONTINUE HANDLER FOR 1397 BEGIN END;
  IF RAND() < 0.5 THEN
    XA COMMIT 'xt1';
  ELSE
    XA ROLLBACK 'xt1';
  END IF;
END//

DELIMITER ;

-- One row per p_tx_chk or p_tx_lchk call; init/vsql_textsearch_check.sql
-- reports them after every restart and marks them seen.
CREATE TABLE tx_chk (
  id INT AUTO_INCREMENT PRIMARY KEY,
  src VARCHAR(8) NOT NULL,
  t VARCHAR(4) NOT NULL,
  q VARCHAR(200),
  lim INT NOT NULL,
  filt INT NOT NULL,
  lck VARCHAR(32),
  iso VARCHAR(32),
  full_cmp INT,
  n_exp INT,
  c_idx INT,
  dups INT,
  ordered INT,
  extra INT,
  missing INT,
  bad_text INT,
  note VARCHAR(200),
  k_idx MEDIUMTEXT,
  seen INT NOT NULL DEFAULT 0
);

DELIMITER //

-- A random query of one to three vocabulary words.
CREATE FUNCTION f_tx_query(t VARCHAR(4)) RETURNS VARCHAR(200) READS SQL DATA
BEGIN
  DECLARE n INT DEFAULT FLOOR(1 + POW(RAND(), 2) * 3);
  DECLARE q VARCHAR(200) DEFAULT f_tx_word(t);
  WHILE n > 1 DO
    SET q = CONCAT(q, ' ', f_tx_word(t)), n = n - 1;
  END WHILE;
  RETURN q;
END//

-- REGEXP condition on txt: contains a word of q, as the simple analyzer
-- splits text (letters, digits and _ form words).
CREATE FUNCTION f_tx_match(q VARCHAR(200)) RETURNS VARCHAR(2000) NO SQL
  RETURN CONCAT('REGEXP_LIKE(txt, ''(^|[^a-z0-9_])(',
                REPLACE(TRIM(q), ' ', '|'), ')([^a-z0-9_]|$)'')')//

-- Checks one ranked read of t with query q (random if NULL).
-- lck = '': a consistent read in a REPEATABLE READ snapshot, compared with
-- the rows whose txt has a query word in the same snapshot, so it is exact
-- under load. Every read of it is a plain SELECT: INSERT ... SELECT reads the
-- latest rows with locks, not the snapshot. Otherwise a locking read
-- (' FOR SHARE', ' FOR UPDATE', ' FOR UPDATE SKIP LOCKED') at the session's
-- isolation level; each row returned is re-read by key with FOR SHARE, and
-- with full_cmp = 1 (quiescent use only) the expected rows are read with the
-- same lock.
-- Every read: no key twice (dups), distances non-decreasing (ordered), and
-- the text returned equal to txt of the row (bad_text). Membership, on the
-- simple-analyzer tables: no row without a query word or gone (extra) and,
-- with lim = 0 or as many rows as the limit allows, none missing (missing).
-- tx2 (english analyzer) checks dups, order and text only; tx4 (no key)
-- checks counts only. lim = 0 reads every match; filt = 1 adds a filter.
-- Commits the caller's transaction first.
CREATE PROCEDURE p_tx_chk(t VARCHAR(4), q0 VARCHAR(200), lim INT, filt INT, lck VARCHAR(32), full_cmp INT)
BEGIN
  DECLARE iso VARCHAR(32) DEFAULT @@SESSION.transaction_isolation;
  DECLARE q VARCHAR(200) DEFAULT IFNULL(q0, f_tx_query(t));
  DECLARE kc VARCHAR(64) DEFAULT 'id AS a, '''' AS b';
  DECLARE kj VARCHAR(64) DEFAULT 'x.id = g.a';
  DECLARE ki VARCHAR(64) DEFAULT 'i.a = x.id';
  DECLARE w VARCHAR(64) DEFAULT 'TRUE';
  DECLARE lmn INT DEFAULT IF(lim = 0, 1000000, lim);
  DECLARE lm VARCHAR(16) DEFAULT lmn;
  DECLARE memb INT DEFAULT t <> 'tx2';
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET SESSION transaction_isolation = iso;
    RESIGNAL;
  END;
  CASE t
    WHEN 'tx3' THEN SET kc = 'a, b', kj = 'x.a = g.a AND x.b = g.b', ki = 'i.a = x.a AND i.b = x.b';
    WHEN 'tx4' THEN SET kc = 'NULL AS a, NULL AS b', kj = NULL, ki = NULL;
    ELSE BEGIN END;
  END CASE;
  IF filt THEN
    SET w = IF(t = 'tx3', 'MOD(a, 7) = 0', IF(t = 'tx4', 'LENGTH(txt) % 7 = 0', 'MOD(id, 7) = 0'));
  END IF;
  COMMIT;
  IF lck = '' OR iso = 'SERIALIZABLE' THEN
    -- SERIALIZABLE reads do not use the index scan.
    SET SESSION transaction_isolation = 'REPEATABLE-READ';
  END IF;
  SET SESSION group_concat_max_len = 16 * 1024 * 1024;
  -- Created each time: TRUNCATE turns the doc column of a temporary table
  -- into VARBINARY.
  DROP TEMPORARY TABLE IF EXISTS vsql.tx_tmp_i;
  CREATE TEMPORARY TABLE vsql.tx_tmp_i (
    seq INT AUTO_INCREMENT PRIMARY KEY, a INT, b VARCHAR(40), d DOUBLE, cv doc);
  IF lck = '' THEN
    START TRANSACTION WITH CONSISTENT SNAPSHOT;
  ELSE
    START TRANSACTION;
  END IF;

  SET @p_tx_q = q;
  SET @p_tx_knn = CONCAT('SELECT ', kc, ', bm25_distance(body, ?) AS d, body AS cv FROM vsql.', t,
                         ' WHERE ', w, ' ORDER BY bm25_distance(body, ?) LIMIT ', lm);
  IF lck = '' THEN
    -- The derived table keeps the scan order, so JSON_ARRAYAGG lists the rows
    -- in the order the index returned them.
    SET @s = CONCAT('SELECT JSON_ARRAYAGG(JSON_ARRAY(a, b, d)) INTO @p_tx_j FROM (', @p_tx_knn, ') k');
    PREPARE p_tx_s FROM @s;
    EXECUTE p_tx_s USING @p_tx_q, @p_tx_q;
    DEALLOCATE PREPARE p_tx_s;
    INSERT INTO vsql.tx_tmp_i (a, b, d)
      SELECT a, b, d FROM JSON_TABLE(IFNULL(@p_tx_j, '[]'), '$[*]' COLUMNS (
        n FOR ORDINALITY, a INT PATH '$[0]', b VARCHAR(40) PATH '$[1]', d DOUBLE PATH '$[2]')) jt
      ORDER BY n;
  ELSE
    SET @s = CONCAT('INSERT INTO vsql.tx_tmp_i (a, b, d, cv) ', @p_tx_knn, lck);
    PREPARE p_tx_s FROM @s;
    EXECUTE p_tx_s USING @p_tx_q, @p_tx_q;
    DEALLOCATE PREPARE p_tx_s;
  END IF;

  SELECT COUNT(*), GROUP_CONCAT(d ORDER BY seq) <=> GROUP_CONCAT(d ORDER BY d),
         IF(kj IS NULL, 0, COUNT(*) - COUNT(DISTINCT a, b))
    INTO @p_tx_ci, @p_tx_ord, @p_tx_dups
    FROM vsql.tx_tmp_i;

  -- Rows returned without a query word or with other text (wrong), and rows
  -- that are not there (gone): in the snapshot, with the index read done
  -- again, or re-read with a lock after the locking read.
  SET @p_tx_extra = 0, @p_tx_bad = 0, @p_tx_gone = 0;
  SET @p_tx_wk = NULL, @p_tx_gk = NULL, @p_tx_mk = NULL;
  IF kj IS NOT NULL THEN
    SET @s = CONCAT('SELECT IFNULL(SUM(NOT ok), 0), IFNULL(SUM(NOT same), 0), ',
                    'GROUP_CONCAT(IF(ok AND same, NULL, CONCAT(a, '':'', b)) SEPARATOR '' '') ',
                    'INTO @p_tx_extra, @p_tx_bad, @p_tx_wk FROM (',
                    'SELECT MAX(g.a) AS a, MAX(g.b) AS b, MAX(', IF(memb, f_tx_match(q), 'TRUE'), ') IS TRUE AS ok, ',
                    'GROUP_CONCAT(g.cv) <=> MAX(x.txt) AS same FROM ',
                    IF(lck = '', CONCAT('(', @p_tx_knn, ') g'), 'vsql.tx_tmp_i g'),
                    ' STRAIGHT_JOIN vsql.', t, ' x ON ', kj,
                    IF(lck = '', ' GROUP BY g.a, g.b', ' GROUP BY g.seq FOR SHARE OF x'), ') z');
    PREPARE p_tx_s FROM @s;
    IF lck = '' THEN
      EXECUTE p_tx_s USING @p_tx_q, @p_tx_q;
    ELSE
      EXECUTE p_tx_s;
    END IF;
    DEALLOCATE PREPARE p_tx_s;
    SET @s = CONCAT('SELECT COUNT(*), GROUP_CONCAT(CONCAT(g.a, '':'', g.b) SEPARATOR '' '') ',
                    'INTO @p_tx_gone, @p_tx_gk FROM vsql.tx_tmp_i g ',
                    'WHERE NOT EXISTS (SELECT 1 FROM vsql.', t, ' x WHERE ', kj, ')');
    PREPARE p_tx_s FROM @s;
    EXECUTE p_tx_s;
    DEALLOCATE PREPARE p_tx_s;
    SET @p_tx_extra = @p_tx_extra + @p_tx_gone;
  END IF;

  -- The rows that have a query word.
  SET @p_tx_n = NULL, @p_tx_miss = NULL, @p_tx_ki = NULL;
  IF memb AND (lck = '' OR full_cmp) THEN
    IF ki IS NULL THEN
      SET @s = CONCAT('SELECT COUNT(*) INTO @p_tx_n FROM (SELECT 1 FROM vsql.', t,
                      ' WHERE ', w, ' AND ', f_tx_match(q), lck, ') x');
      PREPARE p_tx_s FROM @s;
      EXECUTE p_tx_s;
      DEALLOCATE PREPARE p_tx_s;
      SET @p_tx_miss = GREATEST(LEAST(@p_tx_n, lmn) - @p_tx_ci, 0);
      SET @p_tx_extra = GREATEST(@p_tx_ci - LEAST(@p_tx_n, lmn), 0);
    ELSE
      SET @s = CONCAT('SELECT COUNT(*), IFNULL(SUM(m), 0), GROUP_CONCAT(IF(m, k, NULL) SEPARATOR '' '') ',
                      'INTO @p_tx_n, @p_tx_miss, @p_tx_mk FROM (SELECT CONCAT(',
                      IF(t = 'tx3', 'x.a, '':'', x.b', 'x.id, '':'''), ') AS k, ',
                      'NOT EXISTS (SELECT 1 FROM vsql.tx_tmp_i i WHERE ', ki, ') AS m FROM vsql.', t,
                      ' x WHERE ', w, ' AND ', f_tx_match(q), lck, ') z');
      PREPARE p_tx_s FROM @s;
      EXECUTE p_tx_s;
      DEALLOCATE PREPARE p_tx_s;
      -- A limit below the number of matches leaves the rest out.
      SET @p_tx_miss = @p_tx_miss - (@p_tx_n - LEAST(@p_tx_n, lmn));
      IF lim <> 0 THEN
        SET @p_tx_mk = NULL;
      END IF;
    END IF;
  END IF;

  IF @p_tx_dups > 0 OR NOT @p_tx_ord OR @p_tx_extra > 0 OR @p_tx_bad > 0 OR @p_tx_miss <> 0 THEN
    SELECT GROUP_CONCAT(CONCAT(a, ':', b, '@', s) SEPARATOR ' ') INTO @p_tx_dk
      FROM (SELECT a, b, GROUP_CONCAT(seq ORDER BY seq) AS s FROM vsql.tx_tmp_i
            GROUP BY a, b HAVING COUNT(*) > 1) x;
    -- The rows at fault go first, so the report's truncation cannot hide
    -- them: returned twice, without a query word or with other text, gone,
    -- and (lim = 0) missing.
    SELECT CONCAT_WS(' ', CONCAT('twice ', @p_tx_dk), CONCAT('wrong ', @p_tx_wk),
                     CONCAT('gone ', @p_tx_gk), CONCAT('missing ', @p_tx_mk), 'all',
                     GROUP_CONCAT(CONCAT(a, ':', b, '=', ROUND(d, 6)) ORDER BY seq SEPARATOR ' '))
      INTO @p_tx_ki FROM vsql.tx_tmp_i;
  END IF;

  INSERT INTO vsql.tx_chk (src, t, q, lim, filt, lck, iso, full_cmp, n_exp, c_idx, dups,
                           ordered, extra, missing, bad_text, k_idx)
  VALUES (IF(lck = '', 'chk', 'lchk'), t, q, lim, filt, TRIM(lck),
          @@SESSION.transaction_isolation, full_cmp, @p_tx_n, @p_tx_ci, @p_tx_dups,
          @p_tx_ord, @p_tx_extra, @p_tx_miss, @p_tx_bad, @p_tx_ki);
  COMMIT;
  SET SESSION transaction_isolation = iso;
END//

-- p_tx_chk of every vocabulary word on t, reading every match.
CREATE PROCEDURE p_tx_words(t VARCHAR(4))
BEGIN
  DECLARE i INT DEFAULT 1;
  DECLARE w VARCHAR(16);
  WHILE i <= 40 DO
    SELECT tx_words.w INTO w FROM vsql.tx_words WHERE n = i;
    CALL p_tx_chk(t, w, 0, 0, '', 0);
    SET i = i + 1;
  END WHILE;
END//

-- Reads every match of a random query on t (tx1, tx3, tx5 or tx6) twice in
-- one REPEATABLE READ snapshot, secs seconds apart while other sessions write
-- and the index writes out segments, then the rows that have a query word.
-- All three key lists must be equal. Commits the caller's transaction first.
CREATE PROCEDURE p_tx_snap(t VARCHAR(4), secs INT)
BEGIN
  DECLARE iso VARCHAR(32) DEFAULT @@SESSION.transaction_isolation;
  DECLARE q VARCHAR(200) DEFAULT f_tx_query(t);
  DECLARE k VARCHAR(64) DEFAULT IF(t = 'tx3', 'CONCAT(a, '':'', b)', 'id');
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET SESSION transaction_isolation = iso;
    RESIGNAL;
  END;
  COMMIT;
  SET SESSION transaction_isolation = 'REPEATABLE-READ';
  SET SESSION group_concat_max_len = 16 * 1024 * 1024;
  START TRANSACTION WITH CONSISTENT SNAPSHOT;
  SET @p_tx_q = q;
  SET @s = CONCAT('SELECT COUNT(*) - COUNT(DISTINCT k), GROUP_CONCAT(k ORDER BY k) INTO @p_tx_d1, @p_tx_k1 FROM (SELECT ',
                  k, ' AS k FROM vsql.', t, ' ORDER BY bm25_distance(body, ?) LIMIT 1000000) x');
  PREPARE p_tx_s FROM @s;
  EXECUTE p_tx_s USING @p_tx_q;
  DEALLOCATE PREPARE p_tx_s;
  DO SLEEP(secs);
  SET @s = REPLACE(REPLACE(@s, '@p_tx_d1', '@p_tx_d2'), '@p_tx_k1', '@p_tx_k2');
  PREPARE p_tx_s FROM @s;
  EXECUTE p_tx_s USING @p_tx_q;
  DEALLOCATE PREPARE p_tx_s;
  SET @s = CONCAT('SELECT COUNT(*), GROUP_CONCAT(k ORDER BY k) INTO @p_tx_n, @p_tx_k3 FROM (SELECT ',
                  k, ' AS k FROM vsql.', t, ' WHERE ', f_tx_match(q), ') x');
  PREPARE p_tx_s FROM @s;
  EXECUTE p_tx_s;
  DEALLOCATE PREPARE p_tx_s;
  COMMIT;
  SET SESSION transaction_isolation = iso;
  INSERT INTO vsql.tx_chk (src, t, q, lim, filt, iso, n_exp, c_idx, dups, ordered, extra, missing,
                           bad_text, note, k_idx)
  VALUES ('snap', t, q, 0, 0, 'REPEATABLE-READ', @p_tx_n,
          IFNULL(LENGTH(@p_tx_k2) - LENGTH(REPLACE(@p_tx_k2, ',', '')) + 1, 0),
          @p_tx_d1 + @p_tx_d2, 1, NOT (@p_tx_k1 <=> @p_tx_k2), NOT (@p_tx_k2 <=> @p_tx_k3), 0,
          NULLIF(CONCAT_WS('; ', IF(@p_tx_k1 <=> @p_tx_k2, NULL, CONCAT('the reads ', secs, 's apart differ')),
                           IF(@p_tx_k2 <=> @p_tx_k3, NULL, 'the index differs from REGEXP')), ''),
          IF(@p_tx_k1 <=> @p_tx_k2 AND @p_tx_k2 <=> @p_tx_k3, NULL,
             CONCAT('first ', LEFT(@p_tx_k1, 300), ' second ', LEFT(@p_tx_k2, 300), ' regexp ', LEFT(@p_tx_k3, 300))));
END//

-- Drops tx6 and creates it again with memtable_docs = 1, then inserts n
-- rows: a burst of segment writes for kill -9 to interrupt. One burst runs
-- at a time; a call while another runs does nothing.
CREATE PROCEDURE p_tx_burst(n INT)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    DO RELEASE_LOCK('vsql_tx_burst');
    RESIGNAL;
  END;
  IF GET_LOCK('vsql_tx_burst', 0) THEN
    DROP TABLE IF EXISTS vsql.tx6;
    CREATE TABLE vsql.tx6 (
      id INT PRIMARY KEY,
      body doc,
      txt VARCHAR(3000),
      INDEX ib (body) USING EXTENDED(vsql_textsearch.bm25) WITH (analyzer = 'simple', memtable_docs = 1, segments_per_level = 2)
    );
    CALL p_tx_ins('tx6', n, 100000);
    DO RELEASE_LOCK('vsql_tx_burst');
  END IF;
END//

-- The checks of tx6, when it exists.
CREATE PROCEDURE p_tx_chk6()
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'vsql' AND table_name = 'tx6') THEN
    CALL p_tx_words('tx6');
    CALL p_tx_chk('tx6', NULL, 10, 1, ' FOR SHARE', 1);
  END IF;
END//

-- The loaded bm25 indexes of the vsql tables, from bm25_indexes(). An index
-- is loaded when its table is first opened after a restart.
CREATE VIEW tx_idx AS
  SELECT SUBSTRING_INDEX(it.NAME, '/', -1) AS t, j.id, j.memtable_docs, j.segments_per_level,
         j.live_versions, j.memtable, j.segments
    FROM JSON_TABLE(bm25_indexes(), '$[*]' COLUMNS (
           id VARCHAR(32) PATH '$.id', space INT PATH '$.space', memtable_docs INT PATH '$.memtable_docs',
           segments_per_level INT PATH '$.segments_per_level', live_versions INT PATH '$.live_versions',
           memtable INT PATH '$.memtable', segments JSON PATH '$.segments')) j
    JOIN INFORMATION_SCHEMA.INNODB_TABLES it ON it.SPACE = j.space
   WHERE it.NAME LIKE 'vsql/tx_'//

-- Spills (kind 1) or merges (kind 2) the index of t now, as a write would.
CREATE PROCEDURE p_tx_maint(t VARCHAR(4), kind INT)
BEGIN
  DECLARE i VARCHAR(32);
  SELECT id INTO i FROM vsql.tx_idx WHERE tx_idx.t = t LIMIT 1;
  IF i IS NOT NULL THEN
    IF kind = 1 THEN
      DO bm25_spill(i);
    ELSE
      DO bm25_merge(i);
    END IF;
  END IF;
END//

-- Procedures must not return result sets: pstress reads only the first result
-- of a CALL, which leaves its connection out of sync for the rest of the run.
CREATE PROCEDURE p_tx_rank(t VARCHAR(4), lim INT)
BEGIN
  SET @p_tx_q = f_tx_query(t);
  SET @s = CONCAT('INSERT INTO vsql.tx_log (src, ref, r) SELECT ''rank'', ',
                  IF(t = 'tx3', 'a', IF(t = 'tx4', 'NULL', 'id')),
                  ', bm25_distance(body, ?) FROM vsql.', t,
                  ' ORDER BY bm25_distance(body, ?) LIMIT ', lim);
  PREPARE p_tx_s FROM @s;
  EXECUTE p_tx_s USING @p_tx_q, @p_tx_q;
  DEALLOCATE PREPARE p_tx_s;
END//

DELIMITER ;

CALL p_tx_ins('tx1', 4000, 6000);
CALL p_tx_ins('tx2', 2500, 3000);
CALL p_tx_ins('tx3', 1500, 3000);
CALL p_tx_ins('tx4', 2000, 3000);
CALL p_tx_ins('tx5', 2500, 3000);
CALL p_tx_burst(300);
