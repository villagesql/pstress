START TRANSACTION
START TRANSACTION
START TRANSACTION WITH CONSISTENT SNAPSHOT
START TRANSACTION WITH CONSISTENT SNAPSHOT
BEGIN
COMMIT
COMMIT
ROLLBACK
ROLLBACK
SAVEPOINT svt
ROLLBACK TO SAVEPOINT svt
RELEASE SAVEPOINT svt
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ
XA START 'xt1'
XA END 'xt1'
XA PREPARE 'xt1'
XA COMMIT 'xt1'
XA ROLLBACK 'xt1'
XA COMMIT 'xt1' ONE PHASE
CALL vsql.p_tx_txn('tx1', 1, 0)
CALL vsql.p_tx_txn('tx1', 1, 1)
CALL vsql.p_tx_txn('tx1', 2, 0)
CALL vsql.p_tx_txn('tx1', 2, 1)
CALL vsql.p_tx_txn('tx1', 3, 0)
CALL vsql.p_tx_txn('tx1', 3, 1)
CALL vsql.p_tx_txn('tx1', 4, 0)
CALL vsql.p_tx_txn('tx1', 4, 1)
CALL vsql.p_tx_txn('tx1', 5, 0)
CALL vsql.p_tx_txn('tx1', 5, 1)
CALL vsql.p_tx_txn('tx2', 1, 1)
CALL vsql.p_tx_txn('tx2', 2, 1)
CALL vsql.p_tx_txn('tx2', 5, 0)
CALL vsql.p_tx_txn('tx3', 1, 0)
CALL vsql.p_tx_txn('tx3', 2, 1)
CALL vsql.p_tx_txn('tx3', 3, 1)
CALL vsql.p_tx_txn('tx3', 4, 1)
CALL vsql.p_tx_txn('tx3', 5, 1)
CALL vsql.p_tx_txn('tx5', 1, 1)
CALL vsql.p_tx_txn('tx5', 2, 0)
CALL vsql.p_tx_txn('tx5', 4, 0)
CALL vsql.p_tx_txn('tx5', 5, 1)
DELETE FROM vsql.tx1 WHERE id = 7001
INSERT INTO vsql.tx1 VALUES (7001, 'apple apple apple', 'apple apple apple')
UPDATE vsql.tx1 SET body = 'apple', txt = 'apple' WHERE id = 7001
UPDATE vsql.tx1 SET body = 'thistle', txt = 'thistle' WHERE id = 7001
DELETE FROM vsql.tx4 ORDER BY bm25_distance(body, 'apple') LIMIT 1
INSERT INTO vsql.tx4 VALUES ('apple river', 'apple river')
SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, 'apple') LIMIT 10
SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, 'thistle') LIMIT 10
SELECT a, b FROM vsql.tx3 ORDER BY bm25_distance(body, 'apple') LIMIT 10
SELECT body FROM vsql.tx4 ORDER BY bm25_distance(body, 'apple') LIMIT 10
DELETE FROM vsql.tx_log WHERE src = 'rank' ORDER BY id LIMIT 1000
CALL vsql.p_tx_txn('tx6', 2, 1)
CALL vsql.p_tx_txn('tx6', 4, 0)
CALL vsql.p_tx_txn('tx6', 5, 1)
CALL vsql.p_tx_txn('tx6', 1, 1)
CALL vsql.p_tx_txn('tx6', 3, 1)
CALL vsql.p_tx_txn('tx3', 1, 1)
CALL vsql.p_tx_txn('tx3', 4, 0)
