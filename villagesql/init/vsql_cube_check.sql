-- Run by vsql-loop.sh after every restart (CHECK_SQL), before any new DML.
-- Lines starting with FAIL, and any error, are findings; INFO lines go to the
-- loop log.
--
-- Runs p_cb_chk (init/vsql_cube_init.sql) on every R-tree index and metric:
-- top 1, 10 and 300, a filtered query, and every row (lim 0). Then reports
-- the p_cb_chk rows not reported yet, from these calls and from the grammar,
-- and the same for the locking reads of p_cb_lchk.
-- The R-tree is exact, so any difference from the full scan fails.

CALL vsql.p_cb_xa_end();

CALL vsql.p_cb_chk('cb1', 10, 0);
CALL vsql.p_cb_chk('cb1', 300, 1);
CALL vsql.p_cb_chk('cb1', 0, 0);
CALL vsql.p_cb_chk('cb2', 10, 0);
CALL vsql.p_cb_chk('cb2', 0, 0);
CALL vsql.p_cb_chk('cb3l1', 10, 0);
CALL vsql.p_cb_chk('cb3l1', 0, 0);
CALL vsql.p_cb_chk('cb3linf', 10, 1);
CALL vsql.p_cb_chk('cb3linf', 0, 0);
CALL vsql.p_cb_chk('cb4', 1, 0);
CALL vsql.p_cb_chk('cb4', 300, 0);
CALL vsql.p_cb_chk('cb4', 0, 0);
CALL vsql.p_cb_chk('cb5', 10, 1);
CALL vsql.p_cb_chk('cb5', 0, 0);
CALL vsql.p_cb_chk('cb6', 10, 0);
CALL vsql.p_cb_chk('cb6', 0, 0);

-- Locking reads with FOR UPDATE and FOR SHARE, compared with the same
-- locking read without the index. The server is quiescent here, apart from
-- the rollback of transactions open at a crash.
CALL vsql.p_cb_lchk('cb1', 10, 0, 1, 1);
CALL vsql.p_cb_lchk('cb1', 300, 1, 1, 1);
CALL vsql.p_cb_lchk('cb1', 0, 0, 1, 1);
CALL vsql.p_cb_lchk('cb2', 10, 0, 1, 1);
CALL vsql.p_cb_lchk('cb3l1', 300, 1, 1, 1);
CALL vsql.p_cb_lchk('cb3linf', 0, 0, 1, 1);
CALL vsql.p_cb_lchk('cb4', 300, 0, 1, 1);
CALL vsql.p_cb_lchk('cb5', 10, 0, 1, 1);
CALL vsql.p_cb_lchk('cb5', 0, 0, 1, 1);
CALL vsql.p_cb_lchk('cb6', 10, 0, 1, 1);
CALL vsql.p_cb_lchk('cb1', 10, 0, 2, 1);
CALL vsql.p_cb_lchk('cb1', 300, 1, 2, 1);
CALL vsql.p_cb_lchk('cb1', 0, 0, 2, 1);
CALL vsql.p_cb_lchk('cb2', 10, 0, 2, 1);
CALL vsql.p_cb_lchk('cb3l1', 300, 1, 2, 1);
CALL vsql.p_cb_lchk('cb3linf', 0, 0, 2, 1);
CALL vsql.p_cb_lchk('cb4', 300, 0, 2, 1);
CALL vsql.p_cb_lchk('cb5', 10, 0, 2, 1);
CALL vsql.p_cb_lchk('cb5', 0, 0, 2, 1);
CALL vsql.p_cb_lchk('cb6', 10, 0, 2, 1);

SELECT CONCAT('FAIL p_cb_chk ', t, ' row ', id, ' ', fn, ' lim=', lim, ' filt=', filt,
              ' q=', LEFT(q, 200), ': ',
              IF(lim = 0 AND c_idx <> n_rows, CONCAT('index returned ', c_idx, ' of ', n_rows, ' rows '), ''),
              IF(NOT same_d, CONCAT('distances differ, index ', LEFT(d_idx, 300), ' full ', LEFT(d_full, 300), ' '), ''),
              IF(NOT same_k, CONCAT('keys differ, index ', LEFT(k_idx, 300), ' full ', LEFT(k_full, 300)), ''))
  FROM vsql.cb_chk
  WHERE seen = 0 AND (NOT same_d OR NOT same_k OR (lim = 0 AND c_idx <> n_rows))
  ORDER BY id LIMIT 5;

SELECT CONCAT('INFO p_cb_chk: ', COUNT(*), ' queries, ', SUM(NOT same_d OR NOT same_k), ' mismatches')
  FROM vsql.cb_chk WHERE seen = 0;

SELECT CONCAT('FAIL p_cb_lchk locking ', lck, ' ', iso, ' ', t, ' row ', id, ' ', fn, ' lim=', lim,
              ' filt=', filt, IF(full_cmp, ' full', ' load'), ' q=', LEFT(q, 200), ': ',
              IF(dups > 0, CONCAT(dups, ' rows returned twice '), ''),
              IF(NOT ordered, 'rows out of distance order ', ''),
              IF(missing > 0, CONCAT(missing, ' rows not found again '), ''),
              IF(full_cmp AND lim = 0 AND c_idx <> n_rows, CONCAT('index returned ', c_idx, ' of ', n_rows, ' rows '), ''),
              IF(full_cmp AND NOT same_d, 'distances differ ', ''),
              IF(full_cmp AND NOT same_k, 'keys differ ', ''),
              IF(d_idx IS NULL, '', CONCAT('index d ', LEFT(d_idx, 300), ' ')),
              IF(d_full IS NULL, '', CONCAT('full d ', LEFT(d_full, 300), ' ')),
              IF(k_idx IS NULL, '', CONCAT('index k ', LEFT(k_idx, 300), ' ')),
              IF(k_full IS NULL, '', CONCAT('full k ', LEFT(k_full, 300))))
  FROM vsql.cb_lchk
  WHERE seen = 0 AND (dups > 0 OR NOT ordered OR missing > 0
                      OR (full_cmp AND (NOT same_d OR NOT same_k OR (lim = 0 AND c_idx <> n_rows))))
  ORDER BY id LIMIT 5;

SELECT CONCAT('INFO p_cb_lchk: ', COUNT(*), ' locking queries (', SUM(full_cmp), ' full), ',
              SUM(dups > 0 OR NOT ordered OR missing > 0 OR (full_cmp AND (NOT same_d OR NOT same_k))), ' mismatches')
  FROM vsql.cb_lchk WHERE seen = 0;

UPDATE vsql.cb_chk SET seen = 1 WHERE seen = 0;
UPDATE vsql.cb_lchk SET seen = 1 WHERE seen = 0;
DELETE FROM vsql.cb_lchk WHERE seen = 1 AND id < (SELECT m FROM (SELECT MAX(id) - 100000 AS m FROM vsql.cb_lchk) x);
DELETE FROM vsql.cb_chk WHERE seen = 1 AND id < (SELECT m FROM (SELECT MAX(id) - 100000 AS m FROM vsql.cb_chk) x);
