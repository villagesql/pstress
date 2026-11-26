START TRANSACTION
START TRANSACTION
START TRANSACTION WITH CONSISTENT SNAPSHOT
START TRANSACTION WITH CONSISTENT SNAPSHOT
BEGIN
COMMIT
COMMIT
ROLLBACK
ROLLBACK
SAVEPOINT svc
ROLLBACK TO SAVEPOINT svc
RELEASE SAVEPOINT svc
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE
XA START 'xc1'
XA END 'xc1'
XA PREPARE 'xc1'
XA COMMIT 'xc1'
XA ROLLBACK 'xc1'
XA COMMIT 'xc1' ONE PHASE
CALL vsql.p_cb_txn('cb1', 1, 0)
CALL vsql.p_cb_txn('cb1', 1, 1)
CALL vsql.p_cb_txn('cb1', 2, 1)
CALL vsql.p_cb_txn('cb1', 3, 0)
CALL vsql.p_cb_txn('cb1', 3, 1)
CALL vsql.p_cb_txn('cb1', 4, 0)
CALL vsql.p_cb_txn('cb1', 4, 1)
CALL vsql.p_cb_txn('cb1', 5, 1)
CALL vsql.p_cb_txn('cb2', 1, 1)
CALL vsql.p_cb_txn('cb2', 5, 1)
CALL vsql.p_cb_txn('cb3', 1, 0)
CALL vsql.p_cb_txn('cb3', 2, 1)
CALL vsql.p_cb_txn('cb3', 4, 1)
CALL vsql.p_cb_txn('cb4', 1, 1)
CALL vsql.p_cb_txn('cb4', 3, 1)
CALL vsql.p_cb_txn('cb4', 5, 1)
CALL vsql.p_cb_txn('cb1', 2, 0)
CALL vsql.p_cb_txn('cb1', 5, 0)
CALL vsql.p_cb_txn('cb2', 2, 0)
CALL vsql.p_cb_txn('cb3', 5, 0)
CALL vsql.p_cb_txn('cb4', 2, 0)
CALL vsql.p_cb_txn('cb1', 6, 0)
CALL vsql.p_cb_txn('cb1', 6, 1)
CALL vsql.p_cb_txn('cb3', 6, 0)
CALL vsql.p_cb_txn('cb4', 6, 0)
DELETE FROM vsql.cb5 WHERE a = 6001
INSERT INTO vsql.cb5 VALUES (6001, 'kxx1', '(50,50)')
DELETE FROM vsql.cb6 WHERE cube_distance(c, '(50,50)') = 0 LIMIT 1
INSERT INTO vsql.cb6 VALUES ('(50,50)')
DELETE FROM vsql.cb1 WHERE id = 6001
INSERT INTO vsql.cb1 VALUES (6001, '(50,50)')
UPDATE vsql.cb1 SET c = '(50,50)' WHERE id = 6001
UPDATE vsql.cb1 SET c = '(0,100)' WHERE id = 6001
SELECT id FROM vsql.cb1 ORDER BY cube_distance(c, '(50,50)') LIMIT 10
SELECT id FROM vsql.cb1 ORDER BY cube_distance(c, '(0,100)') LIMIT 10
SELECT c FROM vsql.cb6 ORDER BY cube_distance(c, '(50,50)') LIMIT 10
SELECT a, b FROM vsql.cb5 ORDER BY cube_distance(c, '(50,50)') LIMIT 10
DELETE FROM vsql.cb_log ORDER BY id LIMIT 1000
