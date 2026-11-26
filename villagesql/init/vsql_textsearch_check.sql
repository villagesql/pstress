-- Run by vsql-loop.sh after every restart (CHECK_SQL), before any new DML.
-- Lines starting with FAIL, and any error, are findings; INFO lines go to the
-- loop log.
--
-- Runs p_tx_chk (init/vsql_textsearch_init.sql) on every table: ranked reads
-- of random queries with and without a limit and a filter, locking reads
-- compared with the same locking read by REGEXP, and every vocabulary word
-- on the simple-analyzer tables. Then reports the p_tx_chk rows not reported
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

SELECT CONCAT('FAIL p_tx_chk ', src, IF(lck = '', '', CONCAT(' ', lck)), ' ', iso, ' ', t,
              ' row ', id, ' lim=', lim, ' filt=', filt, IF(src = 'lchk', IF(full_cmp, ' full', ' load'), ''),
              ' q=', q, ': ',
              IF(dups > 0, CONCAT(dups, ' rows returned twice '), ''),
              IF(NOT ordered, 'rows out of distance order ', ''),
              IF(extra > 0, CONCAT(extra, ' rows without a query word or gone '), ''),
              IF(missing <> 0, CONCAT(missing, ' matching rows missing '), ''),
              IF(bad_text > 0, CONCAT(bad_text, ' rows with other text '), ''),
              'index ', c_idx, ' expected ', IFNULL(n_exp, '-'), ' ',
              IF(k_idx IS NULL, '', CONCAT('index k ', LEFT(k_idx, 600))))
  FROM vsql.tx_chk
  WHERE seen = 0 AND (dups > 0 OR NOT ordered OR extra > 0 OR missing <> 0 OR bad_text > 0)
  ORDER BY id LIMIT 5;

SELECT CONCAT('INFO p_tx_chk: ', SUM(src = 'chk'), ' reads, ', SUM(src = 'lchk'), ' locking reads (',
              SUM(full_cmp AND src = 'lchk'), ' full), ',
              IFNULL(SUM(dups > 0 OR NOT ordered OR extra > 0 OR missing <> 0 OR bad_text > 0), 0), ' mismatches')
  FROM vsql.tx_chk WHERE seen = 0;

UPDATE vsql.tx_chk SET seen = 1 WHERE seen = 0;
DELETE FROM vsql.tx_chk WHERE seen = 1 AND id < (SELECT m FROM (SELECT MAX(id) - 100000 AS m FROM vsql.tx_chk) x);
