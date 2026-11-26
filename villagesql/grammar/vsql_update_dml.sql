SET @vu_id = FLOOR(1 + RAND() * 300)
SET @vu_id = FLOOR(1 + RAND() * 300)
SET @vu_g = FLOOR(RAND() * 10)
SET @vu_s = CAST(FLOOR(RAND() * 500) AS CHAR)
INSERT INTO vupd.ut1 (grp, val) VALUES (FLOOR(RAND() * 10), update_test.COUNTER::from_string(CAST(FLOOR(RAND() * 1000) AS CHAR)))
INSERT INTO vupd.ut1 (grp, val) VALUES (FLOOR(RAND() * 10), update_test.COUNTER::from_string(CAST(FLOOR(RAND() * 1000) AS CHAR)))
INSERT INTO vupd.ut1 (grp, val) VALUES (3, '17'), (4, '42')
INSERT INTO vupd.ut2 (grp, val) VALUES (FLOOR(RAND() * 10), update_schema_test.MYTYPE::from_string(CAST(FLOOR(RAND() * 1000) AS CHAR)))
INSERT INTO vupd.ut3 (f, v) VALUES ('7', '77'), ('12345678', '1234567890')
UPDATE vupd.ut1 SET grp = (grp + 1) % 10 WHERE id = @vu_id
UPDATE vupd.ut1 SET val = update_test.COUNTER::from_string(CAST(id * 3 AS CHAR)) WHERE id = @vu_id
UPDATE vupd.ut2 SET val = update_schema_test.MYTYPE::from_string(CAST(id AS CHAR)) WHERE grp = @vu_g LIMIT 3
UPDATE vupd.ut3 SET v = '424242' WHERE id = @vu_id
DELETE FROM vupd.ut1 WHERE id = @vu_id
DELETE FROM vupd.ut2 WHERE grp = @vu_g LIMIT 2
DELETE FROM vupd.ut3 WHERE id = @vu_id
SELECT id, update_test.COUNTER::to_string(val), update_test.counter_double(val) FROM vupd.ut1 WHERE grp = @vu_g LIMIT 20
SELECT grp, SUM(update_test.counter_double(val)), COUNT(*) FROM vupd.ut1 GROUP BY grp
SELECT update_schema_test.MYTYPE::to_string(val) FROM vupd.ut2 WHERE grp = @vu_g LIMIT 10
SELECT update_schema_test.mytype_to_v2(val) FROM vupd.ut2 WHERE grp = @vu_g LIMIT 5
SELECT update_length_test.FIX::to_string(f), update_length_test.VAR::to_string(v) FROM vupd.ut3 WHERE id = @vu_id
SELECT a.id, update_test.counter_double(a.val) FROM vupd.ut1 a JOIN vupd.ut2 b ON a.id = b.id WHERE a.grp = @vu_g LIMIT 10
SELECT id FROM vupd.ut1 WHERE id BETWEEN @vu_id AND @vu_id + 10 FOR UPDATE
SELECT vupd.f_ut_double('13'), vupd.f_ut_id('13')
SELECT vupd.f_ut_double(val) FROM vupd.ut1 WHERE id = @vu_id
CALL vupd.p_ut_ins('99')
CALL vupd.p_ut_ins(@vu_s)
CALL vupd.p_ut_scan(@vu_g)
PREPARE ps_vu_sel FROM 'SELECT update_test.counter_double(val) FROM vupd.ut1 WHERE id = ?'
EXECUTE ps_vu_sel USING @vu_id
EXECUTE ps_vu_sel USING @vu_id
DEALLOCATE PREPARE ps_vu_sel
PREPARE ps_vu_ins FROM 'INSERT INTO vupd.ut1 (grp, val) VALUES (?, update_test.COUNTER::from_string(?))'
EXECUTE ps_vu_ins USING @vu_g, @vu_s
DEALLOCATE PREPARE ps_vu_ins
SET GLOBAL update_test.threshold = 100
SET GLOBAL update_test.threshold = 900
SELECT @@global.update_test.threshold
SELECT EXTENSION_NAME, EXTENSION_VERSION, PENDING_VERSION FROM INFORMATION_SCHEMA.EXTENSIONS
DELETE FROM vupd.ut_log ORDER BY id LIMIT 100
INSERT INTO vupd.ut_log (src, r) SELECT 'T1', update_test.counter_double(vupd.ut1.val) FROM T1 JOIN vupd.ut1 ON vupd.ut1.id = T1_INT_1 LIMIT 5
CALL vupd.p_ut_lit()
CALL vupd.p_ut_lit()
SELECT vupd.f_ut_double('13') FROM vupd.ut1 LIMIT 20
SELECT vupd.f_ut_id('21') FROM vupd.ut1 LIMIT 20
PREPARE ps_vu_lit_ins FROM 'INSERT INTO vupd.ut1 (grp, val) VALUES (2, ''21'')'
EXECUTE ps_vu_lit_ins
FLUSH TABLES vupd.ut1
EXECUTE ps_vu_lit_ins
DEALLOCATE PREPARE ps_vu_lit_ins
PREPARE ps_vu_lit_sel FROM 'SELECT id FROM vupd.ut1 WHERE val = ''21'' LIMIT 5'
EXECUTE ps_vu_lit_sel
FLUSH TABLES vupd.ut1
EXECUTE ps_vu_lit_sel
DEALLOCATE PREPARE ps_vu_lit_sel
