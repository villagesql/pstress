START TRANSACTION
START TRANSACTION
BEGIN
COMMIT
COMMIT
ROLLBACK
ROLLBACK
SAVEPOINT svv
ROLLBACK TO SAVEPOINT svv
RELEASE SAVEPOINT svv
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE
XA START 'xv1'
XA START 'xv2'
XA START 'xv3'
XA END 'xv1'
XA END 'xv2'
XA END 'xv3'
XA PREPARE 'xv1'
XA PREPARE 'xv2'
XA PREPARE 'xv3'
XA COMMIT 'xv1'
XA COMMIT 'xv2'
XA ROLLBACK 'xv3'
XA ROLLBACK 'xv1'
XA COMMIT 'xv1' ONE PHASE
XA RECOVER
SET @vv_v = CONCAT('[', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ',', ROUND(RAND() * 10 - 5, 3), ']')
SET @vv_id = FLOOR(1 + RAND() * 600)
SET @vv_g = FLOOR(RAND() * 10)
PREPARE ps_vv1_vupd FROM 'UPDATE vsql.vv1 SET v = ? WHERE id = ?'
EXECUTE ps_vv1_vupd USING @vv_v, @vv_id
EXECUTE ps_vv1_vupd USING @vv_v, @vv_id
DEALLOCATE PREPARE ps_vv1_vupd
PREPARE ps_vv2_vupd FROM 'UPDATE vsql.vv2 SET v = ? WHERE grp = ? LIMIT 3'
EXECUTE ps_vv2_vupd USING @vv_v, @vv_g
DEALLOCATE PREPARE ps_vv2_vupd
PREPARE ps_vv5_vupd FROM 'UPDATE vsql.vv5 SET v = ?, w = ? WHERE id = ?'
EXECUTE ps_vv5_vupd USING @vv_v, @vv_v, @vv_id
DEALLOCATE PREPARE ps_vv5_vupd
DELETE FROM vsql.vv1 WHERE grp = @vv_g ORDER BY id LIMIT 20
DELETE FROM vsql.vv2 WHERE grp = @vv_g ORDER BY id DESC LIMIT 20
DELETE FROM vsql.vv3 WHERE grp = @vv_g LIMIT 20
DELETE FROM vsql.vv5 WHERE grp = @vv_g LIMIT 10
CALL vsql.p_vv_seed(20)
INSERT INTO vsql.vv2 (grp, v) SELECT grp, v FROM vsql.vv1 ORDER BY id DESC LIMIT 20
INSERT INTO vsql.vv3 (grp, v) SELECT grp, v FROM vsql.vv1 ORDER BY id DESC LIMIT 20
INSERT INTO vsql.vv5 (grp, v, w) SELECT grp, v, v FROM vsql.vv1 ORDER BY id DESC LIMIT 10
DELETE FROM vsql.vv1 ORDER BY L2_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 3
UPDATE vsql.vv1 SET v = '[-4,4,-4,4,-4,4,-4,4]' ORDER BY L2_DISTANCE(v, '[0,0,0,0,0,0,0,0.001]') LIMIT 2
DELETE FROM vsql.vv2 WHERE id IN (SELECT id FROM (SELECT id FROM vsql.vv2 ORDER BY COSINE_DISTANCE(v, '[1,0,-1,2,0.5,-0.5,3,-3]') LIMIT 3) t)
CALL vsql.p_vv_chk('vv1', 0, 10)
CALL vsql.p_vv_chk('vv1', 1, 10)
CALL vsql.p_vv_chk('vv1', 0, 50)
CALL vsql.p_vv_chk('vv2', 0, 10)
CALL vsql.p_vv_chk('vv2', 1, 10)
CALL vsql.p_vv_chk('vv5', 1, 10)
CALL vsql.p_vv_chk('vv5w', 1, 10)
CALL vsql.p_vv_chk('vv5w', 0, 20)
