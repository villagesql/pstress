SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, 'apple') LIMIT 1
SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, 'river stone') LIMIT 10
SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, 'cloud') LIMIT 300
SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, 'green night quick silver') LIMIT 100000
SELECT id FROM vsql.tx1 WHERE MOD(id, 7) = 0 ORDER BY bm25_distance(body, 'apple') LIMIT 10
SELECT id FROM vsql.tx1 FORCE INDEX (ib) WHERE id > 3000 ORDER BY bm25_distance(body, 'garden copper') LIMIT 300
SELECT id, bm25_distance(body, 'apple river') FROM vsql.tx1 ORDER BY bm25_distance(body, 'apple river') LIMIT 10
SELECT id, body FROM vsql.tx1 ORDER BY bm25_distance(body, 'winter') LIMIT 10
SELECT id, body, txt FROM vsql.tx1 ORDER BY bm25_distance(body, 'amber falcon') LIMIT 10
SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, 'apple') LIMIT 10 FOR UPDATE
SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, 'stone') LIMIT 5 FOR SHARE
SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, 'apple') LIMIT 3 FOR UPDATE SKIP LOCKED
SELECT COUNT(*) FROM (SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, 'harbor') LIMIT 50) k
WITH k AS (SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, 'meadow apple') LIMIT 20) SELECT COUNT(*) FROM k
SELECT a.id FROM vsql.tx1 a JOIN (SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, 'orchid') LIMIT 10) b ON a.id = b.id
SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, 'zebra') LIMIT 10
SELECT id FROM vsql.tx2 ORDER BY bm25_distance(body, 'apples') LIMIT 10
SELECT id FROM vsql.tx2 ORDER BY bm25_distance(body, 'the river and stone') LIMIT 300
SELECT id, body FROM vsql.tx2 ORDER BY bm25_distance(body, 'café straße') LIMIT 10
SELECT id FROM vsql.tx2 WHERE id + 0 > 1500 ORDER BY bm25_distance(body, 'Running gardens') LIMIT 10 FOR SHARE
SELECT a, b FROM vsql.tx3 ORDER BY bm25_distance(body, 'apple') LIMIT 10
SELECT a, b, body FROM vsql.tx3 WHERE MOD(a, 7) = 0 ORDER BY bm25_distance(body, 'river cloud') LIMIT 300
SELECT a, b FROM vsql.tx3 ORDER BY bm25_distance(body, 'stone') LIMIT 10 FOR UPDATE
SELECT body FROM vsql.tx4 ORDER BY bm25_distance(body, 'apple') LIMIT 10
SELECT COUNT(*) FROM (SELECT txt FROM vsql.tx4 ORDER BY bm25_distance(body, 'green') LIMIT 300) k
SELECT id, bm25_distance(body, 'quick silver') FROM vsql.tx5 ORDER BY bm25_distance(body, 'quick silver') LIMIT 10
SELECT id FROM vsql.tx5 WHERE MOD(id, 7) = 0 ORDER BY bm25_distance(body, 'apple') LIMIT 300 FOR SHARE
SET @tx_q = ELT(1 + FLOOR(RAND() * 8), 'apple', 'river', 'stone', 'cloud', 'green', 'night', 'quick', 'thistle')
SET @tx_q = CONCAT('apple ', ELT(1 + FLOOR(RAND() * 4), 'river', 'stone', 'cloud', 'garden'))
SET @tx_id = FLOOR(1 + RAND() * 6000)
SET @tx_v = CONCAT(ELT(1 + FLOOR(RAND() * 4), 'apple', 'river', 'stone', 'cloud'), ' ', ELT(1 + FLOOR(RAND() * 4), 'green', 'night', 'quick', 'silver'))
PREPARE ps_tx1_rank FROM 'SELECT id FROM vsql.tx1 ORDER BY bm25_distance(body, ?) LIMIT 10'
EXECUTE ps_tx1_rank USING @tx_q
EXECUTE ps_tx1_rank USING @tx_q
DEALLOCATE PREPARE ps_tx1_rank
PREPARE ps_tx3_rank FROM 'SELECT a, b FROM vsql.tx3 WHERE a + 0 > ? ORDER BY bm25_distance(body, ?) LIMIT 300'
EXECUTE ps_tx3_rank USING @tx_id, @tx_q
DEALLOCATE PREPARE ps_tx3_rank
PREPARE ps_tx1_ins FROM 'INSERT INTO vsql.tx1 VALUES (?, ?, ?)'
EXECUTE ps_tx1_ins USING @tx_id, @tx_v, @tx_v
DEALLOCATE PREPARE ps_tx1_ins
PREPARE ps_tx1_upd FROM 'UPDATE vsql.tx1 SET body = ?, txt = ? WHERE id = ?'
EXECUTE ps_tx1_upd USING @tx_v, @tx_v, @tx_id
DEALLOCATE PREPARE ps_tx1_upd
INSERT INTO vsql.tx1 VALUES (7001, 'apple apple apple', 'apple apple apple')
INSERT INTO vsql.tx1 VALUES (7002, 'river, stone', 'river, stone'), (7003, '', ''), (7004, NULL, NULL), (7005, 'night-quick; silver', 'night-quick; silver')
INSERT IGNORE INTO vsql.tx2 VALUES (7001, 'The apples and the rivers', 'The apples and the rivers'), (7002, '日本語 café', '日本語 café')
INSERT INTO vsql.tx3 VALUES (7001, 'kx1', 'cloud cloud green', 'cloud cloud green')
INSERT INTO vsql.tx4 VALUES ('apple river', 'apple river'), ('apple river', 'apple river'), ('stone', 'stone')
INSERT INTO vsql.tx5 VALUES (7001, 'garden', 'garden')
REPLACE INTO vsql.tx1 VALUES (7001, 'copper winter', 'copper winter')
INSERT INTO vsql.tx5 VALUES (7001, 'amber', 'amber') ON DUPLICATE KEY UPDATE body = 'falcon', txt = 'falcon'
UPDATE vsql.tx1 SET body = 'harbor meadow', txt = 'harbor meadow' WHERE id = 7001
UPDATE vsql.tx1 SET body = 'apple apple apple', txt = 'apple apple apple' WHERE id = 7001
UPDATE vsql.tx1 SET body = 'apple', txt = 'apple' WHERE id BETWEEN 7001 AND 7005
UPDATE vsql.tx1 SET body = NULL, txt = NULL WHERE id BETWEEN 100 AND 105
UPDATE vsql.tx1 SET body = 'velvet maple', txt = 'velvet maple' WHERE txt IS NULL LIMIT 5
UPDATE vsql.tx1 SET id = id + 10000 WHERE id BETWEEN 1 AND 20
UPDATE vsql.tx1 SET id = id - 10000 WHERE id BETWEEN 10001 AND 10020
UPDATE vsql.tx3 SET a = a + 10000 WHERE a BETWEEN 100 AND 110
UPDATE vsql.tx3 SET a = a - 10000 WHERE a BETWEEN 10100 AND 10110
UPDATE vsql.tx3 SET b = CONCAT(b, 'y') WHERE a BETWEEN 200 AND 210
UPDATE vsql.tx3 SET b = LEFT(b, CHAR_LENGTH(b) - 1) WHERE a BETWEEN 200 AND 210 AND b LIKE '%y'
UPDATE vsql.tx5 SET id = id + 10000 WHERE id BETWEEN 50 AND 60
UPDATE vsql.tx5 SET id = id - 10000 WHERE id BETWEEN 10050 AND 10060
UPDATE vsql.tx1 SET body = 'stone stone', txt = 'stone stone' ORDER BY bm25_distance(body, 'apple') LIMIT 3
UPDATE vsql.tx4 SET body = 'cloud', txt = 'cloud' ORDER BY bm25_distance(body, 'stone') LIMIT 5
DELETE FROM vsql.tx1 ORDER BY bm25_distance(body, 'apple') LIMIT 2
DELETE FROM vsql.tx1 WHERE id BETWEEN 7001 AND 7005
DELETE FROM vsql.tx2 WHERE id > 2900
DELETE FROM vsql.tx3 WHERE a > 2900
DELETE FROM vsql.tx4 ORDER BY bm25_distance(body, 'cloud') LIMIT 3
DELETE FROM vsql.tx5 WHERE MOD(id, 97) = FLOOR(RAND() * 97) LIMIT 5
CALL vsql.p_tx_ins('tx1', 10, 6000)
CALL vsql.p_tx_ins('tx2', 10, 3000)
CALL vsql.p_tx_ins('tx3', 10, 3000)
CALL vsql.p_tx_ins('tx4', 5, 3000)
CALL vsql.p_tx_ins('tx5', 10, 3000)
CALL vsql.p_tx_upd('tx1', 5, 0)
CALL vsql.p_tx_upd('tx1', 5, 1)
CALL vsql.p_tx_upd('tx1', 5, 2)
CALL vsql.p_tx_upd('tx1', 2, 3)
CALL vsql.p_tx_upd('tx1', 2, 4)
CALL vsql.p_tx_upd('tx2', 5, 0)
CALL vsql.p_tx_upd('tx3', 5, 1)
CALL vsql.p_tx_upd('tx4', 3, 0)
CALL vsql.p_tx_upd('tx5', 5, 0)
CALL vsql.p_tx_upd('tx5', 5, 2)
CALL vsql.p_tx_rank('tx1', 10)
CALL vsql.p_tx_rank('tx3', 300)
CALL vsql.p_tx_chk('tx1', NULL, 10, 0, '', 0)
CALL vsql.p_tx_chk('tx1', NULL, 0, 1, '', 0)
CALL vsql.p_tx_chk('tx2', NULL, 10, 0, '', 0)
CALL vsql.p_tx_chk('tx3', NULL, 300, 0, '', 0)
CALL vsql.p_tx_chk('tx4', NULL, 0, 1, '', 0)
CALL vsql.p_tx_chk('tx5', NULL, 10, 1, '', 0)
CALL vsql.p_tx_chk('tx1', NULL, 10, 0, ' FOR UPDATE', 0)
CALL vsql.p_tx_chk('tx1', NULL, 300, 1, ' FOR SHARE', 0)
CALL vsql.p_tx_chk('tx1', NULL, 10, 0, ' FOR UPDATE SKIP LOCKED', 0)
CALL vsql.p_tx_chk('tx2', NULL, 10, 0, ' FOR SHARE', 0)
CALL vsql.p_tx_chk('tx3', NULL, 10, 0, ' FOR UPDATE', 0)
CALL vsql.p_tx_chk('tx3', NULL, 300, 1, ' FOR SHARE', 0)
CALL vsql.p_tx_chk('tx5', NULL, 10, 0, ' FOR SHARE', 0)
CALL vsql.p_tx_ins('tx3', 20, 3000)
CALL vsql.p_tx_burst(300)
CALL vsql.p_tx_burst(300)
CALL vsql.p_tx_burst(600)
CALL vsql.p_tx_ins('tx6', 20, 100000)
CALL vsql.p_tx_ins('tx6', 20, 100000)
SELECT id FROM vsql.tx6 ORDER BY bm25_distance(body, 'apple') LIMIT 10
SELECT id, body FROM vsql.tx6 ORDER BY bm25_distance(body, 'river stone') LIMIT 300 FOR SHARE
DELETE FROM vsql.tx6 ORDER BY bm25_distance(body, 'cloud') LIMIT 5
UPDATE vsql.tx6 SET body = 'quick', txt = 'quick' ORDER BY bm25_distance(body, 'green') LIMIT 5
CALL vsql.p_tx_chk('tx6', NULL, 0, 0, '', 0)
CALL vsql.p_tx_chk('tx6', NULL, 10, 0, ' FOR UPDATE', 0)
CALL vsql.p_tx_snap('tx1', 10)
CALL vsql.p_tx_snap('tx3', 10)
CALL vsql.p_tx_snap('tx5', 5)
CALL vsql.p_tx_snap('tx6', 5)
