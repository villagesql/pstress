INSERT INTO vsql.vc1 (grp, c, c2, s) VALUES (FLOOR(RAND() * 10), COMPLEX::from_string(CONCAT('(', ROUND(RAND() * 1000 - 500, 2), ',', ROUND(RAND() * 1000 - 500, 2), ')')), COMPLEX::from_string(CONCAT('(', FLOOR(RAND() * 50), ',-0)')), CONCAT('(', FLOOR(RAND() * 9), ',', FLOOR(RAND() * 9), ')'))
INSERT INTO vsql.vc1 (grp, c, c2, s) SELECT grp, complex_add(c, '(1,1)'), c2, s FROM vsql.vc1 ORDER BY RAND() LIMIT 20
INSERT INTO vsql.vc1 (grp, c) VALUES (3, '(123456789.123456,-98765.4321)'), (3, '(0,0)'), (3, '(-0,-0)'), (3, NULL)
INSERT INTO vsql.vc2 (grp, c) VALUES (FLOOR(RAND() * 10), COMPLEX::from_string(CONCAT('(', ROUND(RAND() * 100, 3), ',', ROUND(RAND() * -100, 3), ')')))
INSERT INTO vsql.vc2 (grp, c) SELECT grp, complex_multiply(c, '(0,1)') FROM vsql.vc1 ORDER BY RAND() LIMIT 10
INSERT INTO vsql.vc3 (id, c) VALUES (FLOOR(RAND() * 100000), COMPLEX2::from_string(CONCAT('(', FLOOR(RAND() * 300), ',', FLOOR(RAND() * 300) * 2, ')'))) ON DUPLICATE KEY UPDATE c = COMPLEX2::from_string(CONCAT('(', FLOOR(RAND() * 1000), ',1)'))
INSERT INTO vsql.vc3 (id, c) VALUES (FLOOR(RAND() * 100000), COMPLEX2::from_string(CONCAT('(', FLOOR(RAND() * 300), ',-0)'))) AS new ON DUPLICATE KEY UPDATE c = new.c
REPLACE INTO vsql.vc3 (id, c) VALUES (FLOOR(RAND() * 300), COMPLEX2::from_string(CONCAT('(', FLOOR(RAND() * 300), ',', FLOOR(RAND() * 300), ')')))
INSERT INTO vsql.vc4 (id, grp, c) VALUES (FLOOR(RAND() * 1000000), FLOOR(RAND() * 10), COMPLEX::from_string(CONCAT('(', ROUND(RAND() * 10, 1), ',', ROUND(RAND() * 10, 1), ')')))
UPDATE vsql.vc1 SET c = complex_add(c, '(1,-1)') WHERE grp = FLOOR(RAND() * 10) ORDER BY id LIMIT 5
UPDATE vsql.vc1 SET c = complex_divide(c, '(2,0)'), c2 = complex_conjugate(c2) WHERE id = FLOOR(1 + RAND() * 600)
UPDATE vsql.vc1 SET s = CONCAT('(', FLOOR(RAND() * 99), ',', FLOOR(RAND() * 99), ')') WHERE c > '(0,0)' ORDER BY c LIMIT 10
UPDATE vsql.vc2 SET c = complex_subtract(c2, c) WHERE r > RAND() * 500 LIMIT 10
UPDATE vsql.vc4 SET c = complex_multiply(c, c) WHERE grp = FLOOR(RAND() * 10) LIMIT 10
DELETE FROM vsql.vc1 WHERE grp = FLOOR(RAND() * 10) ORDER BY c LIMIT 5
DELETE FROM vsql.vc2 ORDER BY RAND() LIMIT 5
DELETE FROM vsql.vc3 WHERE c BETWEEN '(0,0)' AND COMPLEX2::from_string(CONCAT('(', FLOOR(RAND() * 300), ',0)')) LIMIT 5
DELETE FROM vsql.vc4 WHERE id % 7 = FLOOR(RAND() * 7) LIMIT 10
DELETE FROM vsql.vc_log ORDER BY id LIMIT 100
SELECT id, c, complex_real(c), complex_imag(c), complex_abs(c) FROM vsql.vc1 WHERE c = '(10.5,-10.25)'
SELECT id, c FROM vsql.vc1 WHERE c BETWEEN '(-50,0)' AND '(50,0)' ORDER BY c DESC LIMIT 25
SELECT id, c FROM vsql.vc1 FORCE INDEX (k_c) WHERE c > COMPLEX::from_string(CONCAT('(', FLOOR(RAND() * 400), ',0)')) ORDER BY c LIMIT 10
SELECT grp, COUNT(*), complex_sum(c), MIN(c), MAX(c) FROM vsql.vc1 GROUP BY grp
SELECT DISTINCT c FROM vsql.vc4 ORDER BY c LIMIT 30
SELECT c, COUNT(*) FROM vsql.vc1 GROUP BY c HAVING COUNT(*) > 1 LIMIT 10
SELECT a.id, b.id FROM vsql.vc1 a JOIN vsql.vc2 b ON a.c = b.c LIMIT 20
SELECT a.id, complex_abs(complex_subtract(a.c, b.c)) d FROM vsql.vc1 a JOIN vsql.vc4 b ON a.grp = b.grp ORDER BY d LIMIT 10
SELECT id FROM vsql.vc1 WHERE c IN (SELECT c FROM vsql.vc4) LIMIT 20
SELECT id, c, ROW_NUMBER() OVER (ORDER BY c) FROM vsql.vc2 LIMIT 20
SELECT id FROM vsql.vc1 WHERE c BETWEEN '(10,0)' AND '(60,0)' FOR UPDATE
SELECT id FROM vsql.vc3 WHERE c >= '(100,0)' LIMIT 5 FOR SHARE
SELECT vsql.f_vc_abs(s) FROM vsql.vc1 ORDER BY RAND() LIMIT 20
SELECT vsql.f_vc_conj(c) FROM vsql.vc1 ORDER BY RAND() LIMIT 20
SELECT complex_real(vsql.f_vc_conj(c2)) FROM vsql.vc2 LIMIT 50
SELECT COMPLEX::to_string(c), COMPLEX::from_string(COMPLEX::to_string(c)) = c FROM vsql.vc1 LIMIT 20
CALL vsql.p_vc_insert(FLOOR(RAND() * 100000))
CALL vsql.p_vc_scan(FLOOR(RAND() * 10))
CALL vsql.p_vc_sum()
SET @vc_a = CONCAT('(', ROUND(RAND() * 100, 2), ',', ROUND(RAND() * 100, 2), ')')
SET @vc_a = CONCAT('(', ROUND(RAND() * 1e9, 6), ',', ROUND(RAND() * -1e9, 6), ')')
SET @vc_a = COMPLEX::from_string(CONCAT('(', ROUND(RAND() * 100, 2), ',', ROUND(RAND() * -100, 2), ')'))
SET @vc_a = '(1,1)'
SET @vc_a = NULL
SET @vc_a = 'not a complex'
PREPARE ps_vc_sel FROM 'SELECT id, complex_real(c), complex_abs(complex_add(c, ?)) FROM vsql.vc1 WHERE c > ? ORDER BY c LIMIT 10'
EXECUTE ps_vc_sel USING @vc_a, @vc_a
EXECUTE ps_vc_sel USING @vc_a, @vc_a
DEALLOCATE PREPARE ps_vc_sel
PREPARE ps_vc_ins FROM 'INSERT INTO vsql.vc2 (grp, c) VALUES (?, ?)'
EXECUTE ps_vc_ins USING @vc_g, @vc_a
SET @vc_g = FLOOR(RAND() * 10)
PREPARE ps_vc_upd FROM 'UPDATE vsql.vc1 SET c = complex_conjugate(?) WHERE grp = ? LIMIT 3'
EXECUTE ps_vc_upd USING @vc_a, @vc_g
PREPARE ps_vc_agg FROM 'SELECT grp, complex_sum(c) FROM vsql.vc4 WHERE grp <> ? GROUP BY grp'
EXECUTE ps_vc_agg USING @vc_g
SELECT T1_INT_1, complex_abs(COMPLEX::from_string(CONCAT('(', T1_INT_1, ',', T1_INT_2, ')'))) FROM T1 LIMIT 20
SELECT complex_real(COMPLEX::from_string(T1_VARCHAR_1)) FROM T1 LIMIT 10
INSERT INTO vsql.vc2 (grp, c) SELECT T1_INT_1 % 10, COMPLEX::from_string(CONCAT('(', T1_INT_1, ',', T1_INT_2, ')')) FROM T1 LIMIT 10
SELECT T1_INT_1, vsql.vc1.c FROM T1 JOIN vsql.vc1 ON vsql.vc1.grp = T1_INT_1 % 10 ORDER BY vsql.vc1.c LIMIT 20
UPDATE T1 SET T1_VARCHAR_1 = (SELECT COMPLEX::to_string(c) FROM vsql.vc1 ORDER BY RAND() LIMIT 1) LIMIT 3
UPDATE vsql.vc1 SET c = (SELECT COMPLEX::from_string(CONCAT('(', T1_INT_1, ',', T1_INT_2, ')')) FROM T1 LIMIT 1) WHERE grp = FLOOR(RAND() * 10) LIMIT 2
CALL vsql.p_vc_lit()
CALL vsql.p_vc_lit()
SELECT vsql.f_vc_lit(id) FROM vsql.vc1 LIMIT 20
SELECT vsql.f_vc_conj('(1,2)') FROM vsql.vc1 LIMIT 20
SELECT complex_real(vsql.f_vc_conj('(0.5,-1.5)')) FROM vsql.vc2 LIMIT 20
INSERT INTO vsql.vc2 (grp, c) VALUES (FLOOR(RAND() * 10), '(1,2)')
PREPARE ps_vc_lit_ins FROM 'INSERT INTO vsql.vc2 (grp, c) VALUES (3, ''(5.5,6.5)'')'
EXECUTE ps_vc_lit_ins
FLUSH TABLES vsql.vc2
EXECUTE ps_vc_lit_ins
DEALLOCATE PREPARE ps_vc_lit_ins
PREPARE ps_vc_lit_sel FROM 'SELECT id FROM vsql.vc1 WHERE c = ''(1,2)'' OR c IN (''(3,4)'', ''(5,6)'') LIMIT 10'
EXECUTE ps_vc_lit_sel
FLUSH TABLES vsql.vc1
EXECUTE ps_vc_lit_sel
EXECUTE ps_vc_lit_sel
DEALLOCATE PREPARE ps_vc_lit_sel
PREPARE ps_vc_lit_upd FROM 'UPDATE vsql.vc4 SET c = ''(9,9)'' WHERE c = ''(9,9)'' LIMIT 1'
EXECUTE ps_vc_lit_upd
FLUSH TABLES vsql.vc4
EXECUTE ps_vc_lit_upd
DEALLOCATE PREPARE ps_vc_lit_upd
