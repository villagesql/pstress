SET @vv_v = CONCAT('[', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ']')
SET @vv_v = CONCAT('[', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ']')
SET @vv_v = CONCAT('[', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ']')
SET @vv_v = CONCAT('[', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ']')
SET @vv_g = FLOOR(RAND() * 10)
SET @vv_v = '[1,0,-1,2,0.5,-0.5,3,-3]'
SET @vv_v = '[1,2,3]'
SET @vv_v = 'not a vector'
SET @vv_v = NULL
SET @vv_g = FLOOR(RAND() * 10)
SET @vv_id = FLOOR(1 + RAND() * 500)
SET @vv_id = FLOOR(1 + RAND() * 500)
SET @vv_id = FLOOR(1 + RAND() * 500)
PREPARE ps_vv1_ins FROM 'INSERT INTO vsql.vv1 (grp, v, s) VALUES (?, ?, ''ps'')'
EXECUTE ps_vv1_ins USING @vv_g, @vv_v
EXECUTE ps_vv1_ins USING @vv_g, @vv_v
EXECUTE ps_vv1_ins USING @vv_g, @vv_v
EXECUTE ps_vv1_ins USING @vv_g, @vv_v
DEALLOCATE PREPARE ps_vv1_ins
PREPARE ps_vv2_ins FROM 'INSERT INTO vsql.vv2 (grp, v) VALUES (?, ?)'
EXECUTE ps_vv2_ins USING @vv_g, @vv_v
EXECUTE ps_vv2_ins USING @vv_g, @vv_v
EXECUTE ps_vv2_ins USING @vv_g, @vv_v
DEALLOCATE PREPARE ps_vv2_ins
PREPARE ps_vv3_ins FROM 'INSERT INTO vsql.vv3 (grp, v) VALUES (?, ?)'
EXECUTE ps_vv3_ins USING @vv_g, @vv_v
EXECUTE ps_vv3_ins USING @vv_g, @vv_v
EXECUTE ps_vv3_ins USING @vv_g, @vv_v
DEALLOCATE PREPARE ps_vv3_ins
PREPARE ps_vv4_ins FROM 'INSERT INTO vsql.vv4 (grp, v, w) VALUES (?, ?, ?)'
EXECUTE ps_vv4_ins USING @vv_g, @vv_v, @vv_v
EXECUTE ps_vv4_ins USING @vv_g, @vv_v, @vv_v
DEALLOCATE PREPARE ps_vv4_ins
PREPARE ps_vv5_ins FROM 'INSERT INTO vsql.vv5 (grp, v, w) VALUES (?, ?, ?)'
EXECUTE ps_vv5_ins USING @vv_g, @vv_v, @vv_v
EXECUTE ps_vv5_ins USING @vv_g, @vv_v, @vv_v
EXECUTE ps_vv5_ins USING @vv_g, @vv_v, @vv_v
DEALLOCATE PREPARE ps_vv5_ins
PREPARE ps_vv4_upd FROM 'UPDATE vsql.vv4 SET v = ? WHERE id = ?'
EXECUTE ps_vv4_upd USING @vv_v, @vv_id
EXECUTE ps_vv4_upd USING @vv_v, @vv_id
DEALLOCATE PREPARE ps_vv4_upd
PREPARE ps_vv1_knn FROM 'SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, ?) LIMIT 10'
EXECUTE ps_vv1_knn USING @vv_v
EXECUTE ps_vv1_knn USING @vv_v
EXECUTE ps_vv1_knn USING @vv_v
DEALLOCATE PREPARE ps_vv1_knn
PREPARE ps_vv2_knn FROM 'SELECT id FROM vsql.vv2 WHERE grp = ? ORDER BY COSINE_DISTANCE(v, ?) LIMIT 5'
EXECUTE ps_vv2_knn USING @vv_g, @vv_v
EXECUTE ps_vv2_knn USING @vv_g, @vv_v
DEALLOCATE PREPARE ps_vv2_knn
PREPARE ps_vv3_knn FROM 'SELECT id FROM vsql.vv3 ORDER BY NEGATIVE_INNER_PRODUCT(v, ?) LIMIT 20'
EXECUTE ps_vv3_knn USING @vv_v
EXECUTE ps_vv3_knn USING @vv_v
DEALLOCATE PREPARE ps_vv3_knn
PREPARE ps_vv1_lit FROM 'SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, ''[0,0,0,0,0,0,0,0.001]'') LIMIT 10'
EXECUTE ps_vv1_lit
EXECUTE ps_vv1_lit
DEALLOCATE PREPARE ps_vv1_lit
INSERT INTO vsql.vv1 (grp, v) VALUES (1, '[1,0,-1,2,0.5,-0.5,3,-3]'), (2, '[0,0,0,0,0,0,0,0.001]'), (3, '[-4,4,-4,4,-4,4,-4,4]')
INSERT INTO vsql.vv5 (grp, v, w) VALUES (4, '[2.5,1.5,0.5,-0.5,-1.5,-2.5,3.5,-3.5]', '[1,0,-1,2,0.5,-0.5,3,-3]')
INSERT INTO vsql.vv2 (grp, v) SELECT grp, v FROM vsql.vv1 ORDER BY id DESC LIMIT 5
INSERT INTO vsql.vv3 (grp, v) SELECT grp, v FROM vsql.vv2 ORDER BY id DESC LIMIT 5
INSERT INTO vsql.vv5 (grp, v, w) SELECT grp, v, v FROM vsql.vv1 ORDER BY id DESC LIMIT 3
INSERT INTO vsql.vv4 (grp, v, w) SELECT grp, v, v FROM vsql.vv1 ORDER BY RAND() LIMIT 3
INSERT INTO vsql.vv1 (id, grp, v) VALUES (FLOOR(1 + RAND() * 500), 1, '[1,0,-1,2,0.5,-0.5,3,-3]') ON DUPLICATE KEY UPDATE s = 'dup'
SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 1
SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 10
SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 100
SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[0,0,0,0,0,0,0,0.001]') LIMIT 1
SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[0,0,0,0,0,0,0,0.001]') LIMIT 10
SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[0,0,0,0,0,0,0,0.001]') LIMIT 100
SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[-4,4,-4,4,-4,4,-4,4]') LIMIT 1
SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[-4,4,-4,4,-4,4,-4,4]') LIMIT 10
SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[-4,4,-4,4,-4,4,-4,4]') LIMIT 100
SELECT id, L2_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]') AS d FROM vsql.vv1 WHERE grp = @vv_g ORDER BY L2_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 10
SELECT id FROM vsql.vv2 ORDER BY COSINE_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 10
SELECT grp, id FROM vsql.vv3 ORDER BY NEGATIVE_INNER_PRODUCT(v, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 10
SELECT id FROM vsql.vv5 ORDER BY L1_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 10
SELECT id, n FROM vsql.vv5 ORDER BY L2_DISTANCE(w, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 10
SELECT id, L2_DISTANCE(v, '[0,0,0,0,0,0,0,0.001]') AS d FROM vsql.vv1 WHERE grp = @vv_g ORDER BY L2_DISTANCE(v, '[0,0,0,0,0,0,0,0.001]') LIMIT 10
SELECT id FROM vsql.vv2 ORDER BY COSINE_DISTANCE(v, '[0,0,0,0,0,0,0,0.001]') LIMIT 10
SELECT grp, id FROM vsql.vv3 ORDER BY NEGATIVE_INNER_PRODUCT(v, '[0,0,0,0,0,0,0,0.001]') LIMIT 10
SELECT id FROM vsql.vv5 ORDER BY L1_DISTANCE(v, '[0,0,0,0,0,0,0,0.001]') LIMIT 10
SELECT id, n FROM vsql.vv5 ORDER BY L2_DISTANCE(w, '[0,0,0,0,0,0,0,0.001]') LIMIT 10
SELECT id, L2_DISTANCE(v, '[-4,4,-4,4,-4,4,-4,4]') AS d FROM vsql.vv1 WHERE grp = @vv_g ORDER BY L2_DISTANCE(v, '[-4,4,-4,4,-4,4,-4,4]') LIMIT 10
SELECT id FROM vsql.vv2 ORDER BY COSINE_DISTANCE(v, '[-4,4,-4,4,-4,4,-4,4]') LIMIT 10
SELECT grp, id FROM vsql.vv3 ORDER BY NEGATIVE_INNER_PRODUCT(v, '[-4,4,-4,4,-4,4,-4,4]') LIMIT 10
SELECT id FROM vsql.vv5 ORDER BY L1_DISTANCE(v, '[-4,4,-4,4,-4,4,-4,4]') LIMIT 10
SELECT id, n FROM vsql.vv5 ORDER BY L2_DISTANCE(w, '[-4,4,-4,4,-4,4,-4,4]') LIMIT 10
SELECT id, L2_DISTANCE(v, '[2.5,1.5,0.5,-0.5,-1.5,-2.5,3.5,-3.5]') AS d FROM vsql.vv1 WHERE grp = @vv_g ORDER BY L2_DISTANCE(v, '[2.5,1.5,0.5,-0.5,-1.5,-2.5,3.5,-3.5]') LIMIT 10
SELECT id FROM vsql.vv2 ORDER BY COSINE_DISTANCE(v, '[2.5,1.5,0.5,-0.5,-1.5,-2.5,3.5,-3.5]') LIMIT 10
SELECT grp, id FROM vsql.vv3 ORDER BY NEGATIVE_INNER_PRODUCT(v, '[2.5,1.5,0.5,-0.5,-1.5,-2.5,3.5,-3.5]') LIMIT 10
SELECT id FROM vsql.vv5 ORDER BY L1_DISTANCE(v, '[2.5,1.5,0.5,-0.5,-1.5,-2.5,3.5,-3.5]') LIMIT 10
SELECT id, n FROM vsql.vv5 ORDER BY L2_DISTANCE(w, '[2.5,1.5,0.5,-0.5,-1.5,-2.5,3.5,-3.5]') LIMIT 10
SELECT id FROM vsql.vv1 WHERE s IS NOT NULL ORDER BY L2_DISTANCE(v, '[2.5,1.5,0.5,-0.5,-1.5,-2.5,3.5,-3.5]') LIMIT 5
SELECT grp, id FROM vsql.vv3 WHERE grp = 5 ORDER BY NEGATIVE_INNER_PRODUCT(v, '[-4,4,-4,4,-4,4,-4,4]') LIMIT 5
SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 10 FOR UPDATE
SELECT id FROM vsql.vv2 ORDER BY COSINE_DISTANCE(v, '[0,0,0,0,0,0,0,0.001]') LIMIT 10 FOR SHARE
SELECT COUNT(*) FROM (SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[-4,4,-4,4,-4,4,-4,4]') LIMIT 50) t
SELECT a.id, b.grp FROM (SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 5) a JOIN vsql.vv2 b ON b.id = a.id
INSERT INTO vsql.vv_log (src, ref, r) SELECT 'knn', id, L2_DISTANCE(v, '[0,0,0,0,0,0,0,0.001]') FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[0,0,0,0,0,0,0,0.001]') LIMIT 5
SET SESSION vsql_vector.ef_search = 1
SET SESSION vsql_vector.ef_search = 10
SET SESSION vsql_vector.ef_search = 40
SET SESSION vsql_vector.ef_search = 200
SET SESSION vsql_vector.ef_search = 2000
SET SESSION vsql_vector.ef_search = DEFAULT
SELECT grp, AVG(VECTOR_NORM(v)), MIN(L1_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]')) FROM vsql.vv1 GROUP BY grp
SELECT a.id, L2_DISTANCE(a.v, b.v) FROM vsql.vv1 a JOIN vsql.vv2 b ON a.id = b.id WHERE a.grp = @vv_g LIMIT 20
SELECT id, INNER_PRODUCT(v, '[2.5,1.5,0.5,-0.5,-1.5,-2.5,3.5,-3.5]'), COSINE_DISTANCE(v, '[2.5,1.5,0.5,-0.5,-1.5,-2.5,3.5,-3.5]') FROM vsql.vv4 ORDER BY 2 DESC LIMIT 5
SELECT id FROM vsql.vv4 ORDER BY L2_DISTANCE(v, '[-4,4,-4,4,-4,4,-4,4]') LIMIT 10
SELECT id, L2_DISTANCE(v, w) FROM vsql.vv4 WHERE v IS NOT NULL AND w IS NOT NULL LIMIT 20
SELECT VECTOR_FORMAT(v, 3), VECTOR_HEX(v), VECTOR_DIMENSION(v) FROM vsql.vv1 WHERE id = @vv_id
SELECT COUNT(*), SUM(VECTOR_NORM(v)) FROM vsql.vv3
SELECT vsql.f_vv_dist(@vv_id, @vv_id + 1)
SELECT id FROM vsql.vv1 WHERE id BETWEEN 100 AND 120 FOR UPDATE
SELECT id, VECTOR_NORM(v) FROM vsql.vv2 WHERE grp = 3 LOCK IN SHARE MODE
CALL vsql.p_vv_insert(FLOOR(RAND() * 10))
CALL vsql.p_vv_insert(FLOOR(RAND() * 10))
CALL vsql.p_vv_knn(FLOOR(RAND() * 10))
CALL vsql.p_vv_norms()
UPDATE vsql.vv1 SET s = CONCAT('u', id) WHERE id = @vv_id
UPDATE vsql.vv1 SET s = CONCAT('g', grp) WHERE grp = @vv_g LIMIT 3
UPDATE vsql.vv1 SET s = NULL WHERE grp = @vv_g LIMIT 5
UPDATE vsql.vv5 SET n = n + 1 WHERE id = @vv_id
UPDATE vsql.vv3 SET v = v WHERE id = @vv_id
DELETE FROM vsql.vv_log ORDER BY id LIMIT 50
DELETE FROM vsql.vv4 WHERE id = @vv_id
UPDATE vsql.vv4 SET w = v, v = w WHERE grp = @vv_g LIMIT 3
UPDATE vsql.vv4 SET v = NULL WHERE id = @vv_id
REPLACE INTO vsql.vv4 (id, grp, v) VALUES (FLOOR(1 + RAND() * 600), 1, '[-4,4,-4,4,-4,4,-4,4]')
DELETE FROM vsql.vv1 WHERE id = @vv_id
DELETE FROM vsql.vv5 WHERE grp = @vv_g LIMIT 1
UPDATE vsql.vv1 SET v = '[0,0,0,0,0,0,0,0.001]' WHERE id = @vv_id
UPDATE vsql.vv1 SET grp = (grp + 1) % 10 WHERE id = @vv_id
UPDATE vsql.vv2 SET id = id + 100000 WHERE id = @vv_id
REPLACE INTO vsql.vv2 (id, grp, v) VALUES (FLOOR(1 + RAND() * 500), 1, '[1,0,-1,2,0.5,-0.5,3,-3]')
INSERT INTO vsql.vv5 (id, grp, v, w) VALUES (FLOOR(1 + RAND() * 300), 1, '[1,0,-1,2,0.5,-0.5,3,-3]', '[0,0,0,0,0,0,0,0.001]') ON DUPLICATE KEY UPDATE v = VALUES(v)
SELECT id FROM vsql.vv1 ORDER BY L2_DISTANCE(v, @vv_v) LIMIT 5
INSERT INTO vsql.vv1 (grp, v) VALUES (1, '[1,2,3]')
SELECT T1_INT_1, vsql.vv1.id FROM T1 JOIN vsql.vv1 ON vsql.vv1.grp = T1_INT_1 % 10 ORDER BY L2_DISTANCE(vsql.vv1.v, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 5
INSERT INTO vsql.vv_log (src, ref, r) SELECT 'T1', T1_INT_1, VECTOR_NORM(vsql.vv1.v) FROM T1 JOIN vsql.vv1 ON vsql.vv1.id = T1_INT_1 LIMIT 5
UPDATE T1 SET T1_VARCHAR_1 = (SELECT LEFT(VECTOR_FORMAT(v, 1), 10) FROM vsql.vv1 ORDER BY RAND() LIMIT 1) LIMIT 3
