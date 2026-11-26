SELECT id FROM vsql.cb1 ORDER BY cube_distance(c, '(50,50)') LIMIT 1
SELECT id FROM vsql.cb1 ORDER BY cube_distance(c, '(12.5,40)') LIMIT 10
SELECT id FROM vsql.cb1 ORDER BY cube_distance(c, '(90,10)') LIMIT 300
SELECT id FROM vsql.cb1 ORDER BY cube_distance(c, '(20,20),(30,35)') LIMIT 10
SELECT id FROM vsql.cb1 WHERE MOD(id, 7) = 0 ORDER BY cube_distance(c, '(50,50)') LIMIT 10
SELECT id FROM vsql.cb1 WHERE id > 3000 ORDER BY cube_distance(c, '(5,95)') LIMIT 300
SELECT id, cube_distance(c, '(50,50)') FROM vsql.cb1 ORDER BY cube_distance(c, '(50,50)') LIMIT 10 FOR UPDATE
SELECT id FROM vsql.cb1 ORDER BY cube_distance(c, '(49,51)') LIMIT 5 FOR SHARE
SELECT id FROM vsql.cb1 ORDER BY cube_distance(c, '(50,50)') LIMIT 3 FOR UPDATE SKIP LOCKED
SELECT COUNT(*) FROM (SELECT id FROM vsql.cb1 ORDER BY cube_distance(c, '(30,60)') LIMIT 50) k
WITH k AS (SELECT id, c FROM vsql.cb1 ORDER BY cube_distance(c, '(70,70)') LIMIT 20) SELECT MAX(cube_distance(c, '(70,70)')) FROM k
SELECT a.id FROM vsql.cb1 a JOIN (SELECT id FROM vsql.cb1 ORDER BY cube_distance(c, '(1,1)') LIMIT 10) b ON a.id = b.id
SELECT id FROM vsql.cb2 ORDER BY cube_distance(c, '(50,50,50)') LIMIT 10
SELECT id FROM vsql.cb2 ORDER BY cube_distance(c, '(10,10)') LIMIT 300
SELECT id FROM vsql.cb2 WHERE id > 2000 ORDER BY cube_distance(c, '(1,2,3),(4,5,6)') LIMIT 10
SELECT id FROM vsql.cb3 ORDER BY cube_taxicab_distance(c, '(50,50)') LIMIT 10
SELECT id FROM vsql.cb3 ORDER BY cube_chebyshev_distance(c, '(50,50)') LIMIT 10
SELECT id FROM vsql.cb3 WHERE MOD(id, 7) = 0 ORDER BY cube_taxicab_distance(c, '(10,80),(15,85)') LIMIT 300
SELECT id FROM vsql.cb3 ORDER BY cube_chebyshev_distance(c, '(99,1)') LIMIT 1 FOR UPDATE
SELECT id FROM vsql.cb4 ORDER BY cube_distance(c, '(5,5,5,5,5,5,5,5,5,5)') LIMIT 10
SELECT id FROM vsql.cb4 WHERE MOD(id, 7) = 0 ORDER BY cube_distance(c, '(1,9,1,9,1,9)') LIMIT 300
SELECT id FROM vsql.cb4 ORDER BY cube_distance(c, '(0)') LIMIT 1
SELECT a, b FROM vsql.cb5 ORDER BY cube_distance(c, '(50,50)') LIMIT 10
SELECT a, b FROM vsql.cb5 WHERE a > 3000 ORDER BY cube_distance(c, '(25,75)') LIMIT 300 FOR SHARE
SELECT c FROM vsql.cb6 ORDER BY cube_distance(c, '(50,50)') LIMIT 10
SELECT COUNT(*) FROM (SELECT c FROM vsql.cb6 ORDER BY cube_distance(c, '(0,0),(10,10)') LIMIT 300) k
SET @cb_q = CONCAT('(', ROUND(RAND() * 100, 2), ',', ROUND(RAND() * 100, 2), ')')
SET @cb_q = CONCAT('(', ROUND(RAND() * 100, 2), ',', ROUND(RAND() * 100, 2), '),(', ROUND(RAND() * 100, 2), ',', ROUND(RAND() * 100, 2), ')')
SET @cb_id = FLOOR(1 + RAND() * 6000)
PREPARE ps_cb1_knn FROM 'SELECT id FROM vsql.cb1 ORDER BY cube_distance(c, ?) LIMIT 10'
EXECUTE ps_cb1_knn USING @cb_q
EXECUTE ps_cb1_knn USING @cb_q
DEALLOCATE PREPARE ps_cb1_knn
PREPARE ps_cb3_knn FROM 'SELECT id FROM vsql.cb3 WHERE id > ? ORDER BY cube_taxicab_distance(c, ?) LIMIT 300'
EXECUTE ps_cb3_knn USING @cb_id, @cb_q
DEALLOCATE PREPARE ps_cb3_knn
PREPARE ps_cb6_knn FROM 'SELECT c FROM vsql.cb6 ORDER BY cube_distance(c, ?) LIMIT 10 FOR UPDATE'
EXECUTE ps_cb6_knn USING @cb_q
DEALLOCATE PREPARE ps_cb6_knn
PREPARE ps_cb1_ins FROM 'INSERT INTO vsql.cb1 VALUES (?, ?)'
EXECUTE ps_cb1_ins USING @cb_id, @cb_q
DEALLOCATE PREPARE ps_cb1_ins
PREPARE ps_cb1_upd FROM 'UPDATE vsql.cb1 SET c = ? WHERE id = ?'
EXECUTE ps_cb1_upd USING @cb_q, @cb_id
DEALLOCATE PREPARE ps_cb1_upd
INSERT INTO vsql.cb1 VALUES (6001, '(50,50)')
INSERT INTO vsql.cb1 VALUES (6002, '(50.5,50.5)'), (6003, '(49.5,49.5),(50.5,50.5)'), (6004, '(0,100)')
INSERT IGNORE INTO vsql.cb2 VALUES (6001, NULL), (6002, '(1,1,1)')
INSERT INTO vsql.cb6 VALUES ('(50,50)'), ('(50,50)'), ('(50,50)')
REPLACE INTO vsql.cb1 VALUES (6001, '(51,51)')
INSERT INTO vsql.cb3 VALUES (6001, '(50,50)') ON DUPLICATE KEY UPDATE c = '(0,0)'
INSERT INTO vsql.cb5 VALUES (6001, 'kxx1', '(50,50)') ON DUPLICATE KEY UPDATE c = '(99,99)'
UPDATE vsql.cb1 SET c = '(0,0)' WHERE id = 6001
UPDATE vsql.cb1 SET c = '(100,100),(100,100)' WHERE id BETWEEN 6001 AND 6004
UPDATE vsql.cb1 SET id = id + 10000 WHERE id BETWEEN 1 AND 20
UPDATE vsql.cb1 SET id = id - 10000 WHERE id BETWEEN 10001 AND 10020
UPDATE vsql.cb3 SET id = id + 10000 WHERE id BETWEEN 100 AND 110
UPDATE vsql.cb3 SET id = id - 10000 WHERE id BETWEEN 10100 AND 10110
UPDATE vsql.cb5 SET b = CONCAT(b, 'y') WHERE a BETWEEN 200 AND 210
UPDATE vsql.cb5 SET b = LEFT(b, CHAR_LENGTH(b) - 1) WHERE a BETWEEN 200 AND 210 AND b LIKE '%y'
UPDATE vsql.cb5 SET a = a + 10000, c = '(1,1)' WHERE a BETWEEN 300 AND 305
UPDATE vsql.cb5 SET a = a - 10000 WHERE a BETWEEN 10300 AND 10305
UPDATE vsql.cb2 SET c = NULL WHERE id BETWEEN 100 AND 110
UPDATE vsql.cb2 SET c = '(5,5,5)' WHERE c IS NULL LIMIT 10
UPDATE vsql.cb1 SET c = '(50,50)' ORDER BY cube_distance(c, '(20,20)') LIMIT 3
UPDATE vsql.cb6 SET c = '(77,77)' ORDER BY cube_distance(c, '(50,50)') LIMIT 5
DELETE FROM vsql.cb1 ORDER BY cube_distance(c, '(50,50)') LIMIT 2
DELETE FROM vsql.cb1 WHERE id BETWEEN 6001 AND 6004
DELETE FROM vsql.cb2 WHERE c IS NULL LIMIT 5
DELETE FROM vsql.cb3 WHERE id IN (SELECT id FROM (SELECT id FROM vsql.cb3 ORDER BY cube_chebyshev_distance(c, '(30,30)') LIMIT 3) t)
DELETE FROM vsql.cb4 WHERE MOD(id, 97) = FLOOR(RAND() * 97) LIMIT 5
DELETE FROM vsql.cb5 WHERE a > 5900
DELETE FROM vsql.cb6 ORDER BY cube_distance(c, '(77,77)') LIMIT 3
CALL vsql.p_cb_ins('cb1', 10, 6000)
CALL vsql.p_cb_ins('cb2', 10, 6000)
CALL vsql.p_cb_ins('cb3', 10, 6000)
CALL vsql.p_cb_ins('cb4', 5, 3000)
CALL vsql.p_cb_ins('cb5', 10, 6000)
CALL vsql.p_cb_ins('cb6', 10, 6000)
CALL vsql.p_cb_move('cb1', 5, 0)
CALL vsql.p_cb_move('cb1', 5, 1)
CALL vsql.p_cb_move('cb2', 5, 1)
CALL vsql.p_cb_move('cb3', 5, 0)
CALL vsql.p_cb_move('cb3', 5, 1)
CALL vsql.p_cb_move('cb4', 3, 1)
CALL vsql.p_cb_move('cb5', 5, 0)
CALL vsql.p_cb_move('cb6', 5, 1)
CALL vsql.p_cb_knn(10)
CALL vsql.p_cb_knn(300)
CALL vsql.p_cb_chk('cb1', 10, 0)
CALL vsql.p_cb_chk('cb1', 300, 1)
CALL vsql.p_cb_chk('cb2', 10, 0)
CALL vsql.p_cb_chk('cb3l1', 10, 0)
CALL vsql.p_cb_chk('cb3linf', 10, 1)
CALL vsql.p_cb_chk('cb4', 10, 0)
CALL vsql.p_cb_chk('cb5', 10, 0)
CALL vsql.p_cb_chk('cb6', 10, 0)
CALL vsql.p_cb_lchk('cb1', 10, 0, 1, 0)
CALL vsql.p_cb_lchk('cb1', 300, 1, 1, 0)
CALL vsql.p_cb_lchk('cb1', 10, 0, 2, 0)
CALL vsql.p_cb_lchk('cb1', 10, 0, 3, 0)
CALL vsql.p_cb_lchk('cb1', 300, 1, 3, 0)
CALL vsql.p_cb_lchk('cb2', 10, 0, 1, 0)
CALL vsql.p_cb_lchk('cb3l1', 10, 0, 1, 0)
CALL vsql.p_cb_lchk('cb3linf', 300, 1, 2, 0)
CALL vsql.p_cb_lchk('cb4', 10, 0, 1, 0)
CALL vsql.p_cb_lchk('cb5', 10, 0, 1, 0)
CALL vsql.p_cb_lchk('cb5', 300, 1, 3, 0)
