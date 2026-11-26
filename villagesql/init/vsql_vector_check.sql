-- Run by vsql-loop.sh after every restart (CHECK_SQL). Lines starting with
-- FAIL, and any error, are findings; INFO lines go to the loop log.
--
-- First runs KNN checks on the recovered HNSW indexes, then reports the
-- p_vv_chk rows not reported yet (init/vsql_vector_init.sql). A row returned
-- twice or rows out of distance order fail. Recall, short results and missed
-- self matches are approximate-index behaviour, so they are only summarized.
--
-- Known issues (villagesql-server mysql-test/suite/knn_review/ISSUES.md) show
-- up in the summary, not as failures: after purge an HNSW query can return
-- wrong or too few rows (KNN-27), and after a restart purge of entries deleted
-- before it leaves rows unreachable (KNN-29), so recall drops after restarts.

SET SESSION vsql_vector.ef_search = 200;
CALL vsql.p_vv_chk('vv1', 1, 10);
CALL vsql.p_vv_chk('vv1', 0, 50);
CALL vsql.p_vv_chk('vv2', 1, 10);
CALL vsql.p_vv_chk('vv5', 1, 10);
CALL vsql.p_vv_chk('vv5w', 1, 10);

SELECT CONCAT('FAIL p_vv_chk ', t, ' row ', id, ': ',
              IF(cd < c, CONCAT(c - cd, ' rows returned twice '), ''),
              IF(NOT ordered, 'rows out of distance order ', ''),
              'q=', q, ' lim=', lim, ' ef=', IFNULL(ef, 'NULL'))
  FROM vsql.vv_chk
  WHERE seen = 0 AND (cd < c OR NOT ordered)
  ORDER BY id LIMIT 5;

SELECT CONCAT('INFO p_vv_chk ', t, ': ', COUNT(*), ' queries, recall ',
              IFNULL(ROUND(SUM(hit) / SUM(LEAST(lim, n_rows)), 3), '-'),
              ', short ', SUM(c < LEAST(lim, n_rows)),
              ', self miss ', SUM(self_q = 1 AND t IN ('vv1', 'vv5', 'vv5w') AND mind > 0),
              ' of ', SUM(self_q = 1 AND t IN ('vv1', 'vv5', 'vv5w')))
  FROM vsql.vv_chk
  WHERE seen = 0
  GROUP BY t ORDER BY t;

UPDATE vsql.vv_chk SET seen = 1 WHERE seen = 0;
DELETE FROM vsql.vv_chk WHERE seen = 1 AND id < (SELECT m FROM (SELECT MAX(id) - 100000 AS m FROM vsql.vv_chk) x);
