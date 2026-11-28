-- Run by vsql-loop.sh after every restart (CHECK_SQL), before any new DML.
-- Lines starting with FAIL, and any error, are findings; INFO lines go to the
-- loop log; DUMP lines are only kept in the finding.
--
-- Runs p_tx_chk (init/vsql_textsearch_init.sql) on every table: ranked reads
-- of random queries with and without a limit and a filter, locking reads
-- compared with the same locking read by REGEXP, and every vocabulary word
-- on the simple-analyzer tables, tx6 included when a burst left it. Then reports the p_tx_chk rows not reported
-- yet, from these calls and from the grammar.

CALL vsql.p_tx_xa_end();

CALL vsql.p_tx_chk('tx1', NULL, 10, 0, '', 0);
CALL vsql.p_tx_chk('tx1', NULL, 300, 1, '', 0);
CALL vsql.p_tx_chk('tx1', NULL, 0, 1, '', 0);
CALL vsql.p_tx_chk('tx2', NULL, 10, 0, '', 0);
CALL vsql.p_tx_chk('tx2', NULL, 0, 0, '', 0);
CALL vsql.p_tx_chk('tx3', NULL, 10, 1, '', 0);
CALL vsql.p_tx_chk('tx3', NULL, 0, 0, '', 0);
CALL vsql.p_tx_chk('tx4', NULL, 10, 0, '', 0);
CALL vsql.p_tx_chk('tx4', NULL, 0, 1, '', 0);
CALL vsql.p_tx_chk('tx5', NULL, 300, 0, '', 0);
CALL vsql.p_tx_chk('tx5', NULL, 0, 1, '', 0);

-- Locking reads, compared with the same locking read by REGEXP. The server
-- is quiescent here, apart from the rollback of transactions open at a crash.
CALL vsql.p_tx_chk('tx1', NULL, 10, 0, ' FOR UPDATE', 1);
CALL vsql.p_tx_chk('tx1', NULL, 0, 1, ' FOR SHARE', 1);
CALL vsql.p_tx_chk('tx2', NULL, 300, 0, ' FOR SHARE', 1);
CALL vsql.p_tx_chk('tx3', NULL, 0, 0, ' FOR UPDATE', 1);
CALL vsql.p_tx_chk('tx3', NULL, 10, 1, ' FOR SHARE', 1);
CALL vsql.p_tx_chk('tx4', NULL, 0, 0, ' FOR SHARE', 1);
CALL vsql.p_tx_chk('tx5', NULL, 300, 1, ' FOR UPDATE', 1);

CALL vsql.p_tx_words('tx1');
CALL vsql.p_tx_words('tx3');
CALL vsql.p_tx_words('tx4');
CALL vsql.p_tx_words('tx5');
CALL vsql.p_tx_chk6();

-- Reading INFORMATION_SCHEMA.INNODB_TABLES can load the index of a table, so
-- take bm25_indexes() before anything reads it.
SET @p_tx_bm25 = bm25_indexes();

-- Every index was opened by the reads above. It must have the
-- memtable_docs and segments_per_level of its CREATE INDEX after a restart.
SELECT CONCAT('FAIL bm25 settings of ', x.t, ': memtable_docs ', x.memtable_docs, ' segments_per_level ',
              x.segments_per_level, ', created with ', o.memtable_docs, ' and ', o.segments_per_level)
  FROM vsql.tx_idx x JOIN vsql.tx_opt o ON o.t = x.t
  WHERE x.memtable_docs <> o.memtable_docs OR x.segments_per_level <> o.segments_per_level;

-- When an index is missing, dump the snapshot and the space of every table
-- into the finding, to tell an index that was not opened from one whose space
-- matches no table.
SET @p_tx_missing = (SELECT GROUP_CONCAT(o.t ORDER BY o.t) FROM vsql.tx_opt o
                      WHERE o.t <> 'tx6' AND NOT EXISTS (
                        SELECT 1 FROM JSON_TABLE(@p_tx_bm25, '$[*]' COLUMNS (space INT PATH '$.space')) j
                          JOIN INFORMATION_SCHEMA.INNODB_TABLES it ON it.SPACE = j.space
                         WHERE it.NAME = CONCAT('vsql/', o.t)));
SELECT CONCAT('FAIL bm25 index of ', o.t, ' not loaded after its reads')
  FROM vsql.tx_opt o WHERE FIND_IN_SET(o.t, @p_tx_missing);
SELECT CONCAT('DUMP bm25_indexes ', @p_tx_bm25) FROM DUAL WHERE @p_tx_missing IS NOT NULL;
SELECT CONCAT('DUMP innodb_tables ', NAME, ' space ', SPACE)
  FROM INFORMATION_SCHEMA.INNODB_TABLES
  WHERE @p_tx_missing IS NOT NULL AND NAME LIKE 'vsql/tx%' ORDER BY NAME;

-- The segments of each index: level:docs/live, newest last.
SELECT CONCAT('INFO bm25 ', SUBSTRING_INDEX(MAX(it.NAME), '/', -1), ' live ', MAX(j.live), ' memtable ',
              MAX(j.mt), ' segments ',
              IFNULL(GROUP_CONCAT(CONCAT('L', s.lvl, ':', s.docs, '/', s.live) ORDER BY s.n SEPARATOR ' '), '-'))
  FROM JSON_TABLE(bm25_indexes(), '$[*]' COLUMNS (space INT PATH '$.space', live INT PATH '$.live_versions',
                  mt INT PATH '$.memtable', segments JSON PATH '$.segments')) j
  JOIN INFORMATION_SCHEMA.INNODB_TABLES it ON it.SPACE = j.space AND it.NAME LIKE 'vsql/tx_'
  LEFT JOIN JSON_TABLE(j.segments, '$[*]' COLUMNS (n FOR ORDINALITY, lvl INT PATH '$.level',
                       docs INT PATH '$.docs', live INT PATH '$.live')) s ON TRUE
  GROUP BY j.space ORDER BY 1;

-- A merge drops segments whose documents are all dead, including those
-- already dead when the index opened.
CALL vsql.p_tx_maint('tx3', 2);
CALL vsql.p_tx_maint('tx6', 2);
SELECT CONCAT('FAIL bm25 ', t, ' keeps ', dead, ' segments without live documents after bm25_merge')
  FROM (SELECT t, (SELECT COUNT(*) FROM JSON_TABLE(bm25_status(id), '$.segments[*]' COLUMNS (live INT PATH '$.live')) s
                    WHERE s.live = 0) AS dead
          FROM vsql.tx_idx WHERE t IN ('tx3', 'tx6')) x
  WHERE dead > 0;

SELECT CONCAT('FAIL p_tx_chk ', src, IF(lck = '', '', CONCAT(' ', lck)), ' ', iso, ' ', t,
              ' row ', id, ' lim=', lim, ' filt=', filt, IF(src = 'lchk', IF(full_cmp, ' full', ' load'), ''),
              ' q=', q, ': ',
              IF(note IS NULL, '', CONCAT(note, ' ')),
              IF(dups > 0, CONCAT(dups, ' rows returned twice '), ''),
              IF(NOT ordered, 'rows out of distance order ', ''),
              IF(extra > 0 AND src <> 'snap', CONCAT(extra, ' rows without a query word or gone '), ''),
              IF(missing <> 0 AND src <> 'snap', CONCAT(missing, ' matching rows missing '), ''),
              IF(bad_text > 0, CONCAT(bad_text, ' rows with other text '), ''),
              'index ', c_idx, ' expected ', IFNULL(n_exp, '-'), ' ',
              IF(k_idx IS NULL, '', CONCAT('index k ', LEFT(k_idx, 600))))
  FROM vsql.tx_chk
  WHERE seen = 0 AND (dups > 0 OR NOT ordered OR extra > 0 OR missing <> 0 OR bad_text > 0)
  ORDER BY id LIMIT 5;

SELECT CONCAT('INFO p_tx_chk: ', SUM(src = 'chk'), ' reads, ', SUM(src = 'lchk'), ' locking reads (',
              SUM(full_cmp AND src = 'lchk'), ' full), ', SUM(src = 'snap'), ' snapshots, ',
              IFNULL(SUM(dups > 0 OR NOT ordered OR extra > 0 OR missing <> 0 OR bad_text > 0), 0), ' mismatches')
  FROM vsql.tx_chk WHERE seen = 0;

UPDATE vsql.tx_chk SET seen = 1 WHERE seen = 0;
DELETE FROM vsql.tx_chk WHERE seen = 1 AND id < (SELECT m FROM (SELECT MAX(id) - 100000 AS m FROM vsql.tx_chk) x);
