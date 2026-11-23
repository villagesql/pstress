SET @kv = CONCAT('[', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ']')
SET @kv = CONCAT('[', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ']')
SET @kv = CONCAT('[', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ']')
SET @kv = CONCAT('[', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ',', ROUND(RAND() * 4 - 2, 2), ']')
SET @kv = '[1,0,0,0]'
SET @kv = '[0,0,0,0]'
SET @kv = '[1,2,3]'
SET @kv = 'not a vector'
SET @kv = NULL
SET @g = FLOOR(RAND() * 10)
SET @g = FLOOR(RAND() * 10)
SET @id = FLOOR(1 + RAND() * 320)
SET @id = FLOOR(1 + RAND() * 320)
SET @id = FLOOR(1 + RAND() * 320)
SET @a = FLOOR(1 + RAND() * 320)
SET @b = ELT(1 + FLOOR(RAND() * 3), 'x', 'y', 'z')
PREPARE ps_k1_ins FROM 'INSERT INTO ci.k1 (grp, v, s) VALUES (?, ?, ''ps'')'
EXECUTE ps_k1_ins USING @g, @kv
EXECUTE ps_k1_ins USING @g, @kv
EXECUTE ps_k1_ins USING @g, @kv
EXECUTE ps_k1_ins USING @g, @kv
DEALLOCATE PREPARE ps_k1_ins
PREPARE ps_k1_upd FROM 'UPDATE ci.k1 SET v = ? WHERE id = ?'
EXECUTE ps_k1_upd USING @kv, @id
EXECUTE ps_k1_upd USING @kv, @id
EXECUTE ps_k1_upd USING @kv, @id
DEALLOCATE PREPARE ps_k1_upd
PREPARE ps_k2_rep FROM 'REPLACE INTO ci.k2 (a, b, v) VALUES (?, ?, ?)'
EXECUTE ps_k2_rep USING @a, @b, @kv
EXECUTE ps_k2_rep USING @a, @b, @kv
EXECUTE ps_k2_rep USING @a, @b, @kv
DEALLOCATE PREPARE ps_k2_rep
PREPARE ps_k3_ins FROM 'INSERT INTO ci.k3 (v, w) VALUES (?, ?)'
EXECUTE ps_k3_ins USING @kv, @kv
EXECUTE ps_k3_ins USING @kv, @kv
EXECUTE ps_k3_ins USING @kv, @kv
DEALLOCATE PREPARE ps_k3_ins
PREPARE ps_k3_upd FROM 'UPDATE ci.k3 SET w = ? WHERE id = ?'
EXECUTE ps_k3_upd USING @kv, @id
EXECUTE ps_k3_upd USING @kv, @id
DEALLOCATE PREPARE ps_k3_upd
PREPARE ps_k4_ins FROM 'INSERT INTO ci.k4 (id, v) VALUES (?, ?) ON DUPLICATE KEY UPDATE v = VALUES(v)'
EXECUTE ps_k4_ins USING @id, @kv
EXECUTE ps_k4_ins USING @id, @kv
DEALLOCATE PREPARE ps_k4_ins
PREPARE ps_k1_knn FROM 'SELECT id FROM ci.k1 ORDER BY vsql_knn_index_test.kvec_l2_distance(v, ?) LIMIT 10'
EXECUTE ps_k1_knn USING @kv
EXECUTE ps_k1_knn USING @kv
EXECUTE ps_k1_knn USING @kv
DEALLOCATE PREPARE ps_k1_knn
PREPARE ps_k2_knn FROM 'SELECT a, b FROM ci.k2 ORDER BY vsql_knn_index_test.kvec_cos_distance(v, ?) LIMIT 5'
EXECUTE ps_k2_knn USING @kv
EXECUTE ps_k2_knn USING @kv
DEALLOCATE PREPARE ps_k2_knn
INSERT INTO ci.k1 (grp, v, s) VALUES (@g, '[1,1,1,1]', 'lit')
INSERT INTO ci.k1 (grp, v, s) VALUES (@g, '[0,0,0,0]', 'zero'), (@g, '[1,-1,1,-1]', 'two')
INSERT INTO ci.k1 (grp, v, s) SELECT grp, v, 'copy' FROM ci.k1 ORDER BY id DESC LIMIT 5
INSERT INTO ci.k1 (grp, v, s) SELECT 99, v, 'k3' FROM ci.k3 ORDER BY RAND() LIMIT 3
UPDATE ci.k1 SET v = '[0,1,0,1]' WHERE id = @id
UPDATE ci.k1 SET id = id + 1000 WHERE id = @id
UPDATE ci.k1 SET grp = grp + 1 WHERE grp = @g LIMIT 5
UPDATE ci.k1 SET s = CONCAT(s, 'u') WHERE id BETWEEN @id AND @id + 5
DELETE FROM ci.k1 WHERE id = @id
DELETE FROM ci.k1 WHERE grp = @g ORDER BY id LIMIT 3
DELETE FROM ci.k1 WHERE id > 1000 LIMIT 5
REPLACE INTO ci.k1 (id, grp, v, s) VALUES (@id, @g, '[2,0,0,0]', 'rep')
INSERT INTO ci.k1 (id, grp, v) VALUES (@id, @g, '[3,0,0,0]') ON DUPLICATE KEY UPDATE v = VALUES(v), grp = grp + 1
INSERT IGNORE INTO ci.k2 (a, b, v) VALUES (@a, @b, '[0.5,0.5,0.5,0.5]')
UPDATE ci.k2 SET b = ELT(1 + FLOOR(RAND() * 3), 'x', 'y', 'z') WHERE a = @a
UPDATE ci.k2 SET v = NULL WHERE a = @a
UPDATE ci.k2 SET v = '[1,0,1,0]' WHERE a = @a
DELETE FROM ci.k2 WHERE a = @a
UPDATE ci.k3 SET v = w, w = v WHERE id = @id
DELETE FROM ci.k3 WHERE id = @id
UPDATE ci.k4 SET v = '[4,3,2,1]' WHERE id = @id
DELETE FROM ci.k4 WHERE id = @id
DELETE FROM ci.d1 WHERE id = @id
SELECT id FROM ci.d1 ORDER BY dummy_l2_distance(a, '[1,2,3,4]') LIMIT 3
SET @e = REPEAT('w', 1 + FLOOR(RAND() * 12000))
PREPARE ps_e1_ins FROM 'INSERT INTO ci.e1 (a) VALUES (?)'
EXECUTE ps_e1_ins USING @e
EXECUTE ps_e1_ins USING @e
DEALLOCATE PREPARE ps_e1_ins
SET @e = REPEAT('u', 1 + FLOOR(RAND() * 12000))
PREPARE ps_e1_upd FROM 'UPDATE ci.e1 SET a = ? WHERE id = ?'
EXECUTE ps_e1_upd USING @e, @id
DEALLOCATE PREPARE ps_e1_upd
DELETE FROM ci.e1 WHERE id = @id
SELECT id, LENGTH(a) FROM ci.e1 WHERE id = @id
SELECT COUNT(*) FROM ci.e1 FORCE INDEX (ia)
SELECT COUNT(*) FROM ci.k1
SELECT COUNT(*) FROM ci.k2
SELECT vsql_knn_index_test.kvec_scan_begin_count(), vsql_knn_index_test.kvec_insert_count()
BEGIN
BEGIN
COMMIT
COMMIT
ROLLBACK
SAVEPOINT sp1
ROLLBACK TO SAVEPOINT sp1
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE
SELECT id FROM ci.k1 ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 5
SELECT id, s FROM ci.k1 WHERE grp = @g ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 3
SELECT a, b FROM ci.k2 ORDER BY vsql_knn_index_test.kvec_cos_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 7
SELECT id FROM ci.k1 ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[0,1,-1,0.5]')) LIMIT 5
SELECT id, s FROM ci.k1 WHERE grp = @g ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[0,1,-1,0.5]')) LIMIT 3
SELECT a, b FROM ci.k2 ORDER BY vsql_knn_index_test.kvec_cos_distance(v, KVECTOR::from_string('[0,1,-1,0.5]')) LIMIT 7
SELECT id FROM ci.k1 ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[-2,2,0,1]')) LIMIT 5
SELECT id, s FROM ci.k1 WHERE grp = @g ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[-2,2,0,1]')) LIMIT 3
SELECT a, b FROM ci.k2 ORDER BY vsql_knn_index_test.kvec_cos_distance(v, KVECTOR::from_string('[-2,2,0,1]')) LIMIT 7
SELECT id FROM ci.k1 FORCE INDEX (iv) ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 10
SELECT id FROM ci.k1 IGNORE INDEX (iv) ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 10
SELECT a, b FROM ci.k2 ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 4
SELECT id FROM ci.k3 ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 6
SELECT id FROM ci.k3 ORDER BY vsql_knn_index_test.kvec_cos_distance(w, KVECTOR::from_string('[1,0,0,0]')) LIMIT 6
SELECT id FROM ci.k4 ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 3
SELECT id FROM ci.k1 ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 5 FOR UPDATE
SELECT id FROM ci.k1 ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 5 FOR SHARE
SELECT k.id FROM ci.k1 k JOIN ci.k3 t ON t.id = k.id ORDER BY vsql_knn_index_test.kvec_l2_distance(k.v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 5
SELECT id FROM ci.k1 WHERE id IN (SELECT id FROM ci.k3) ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 5
SELECT grp, COUNT(*) FROM (SELECT grp FROM ci.k1 ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 20) d GROUP BY grp
SELECT DISTINCT grp FROM ci.k1 ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 5
UPDATE ci.k1 SET s = 'near' ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 2
DELETE FROM ci.k1 ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 1
