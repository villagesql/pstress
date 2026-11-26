CREATE TABLE IF NOT EXISTS vupd2.ut4 (id INT AUTO_INCREMENT PRIMARY KEY, val update_test.COUNTER)
INSERT INTO vupd2.ut4 (val) SELECT val FROM vupd.ut1 ORDER BY id DESC LIMIT 20
DROP TABLE IF EXISTS vupd2.ut4
CREATE TABLE IF NOT EXISTS vupd2.ut5 (id INT AUTO_INCREMENT PRIMARY KEY, v2 update_schema_test.MYTYPE_V2)
INSERT INTO vupd2.ut5 (v2) SELECT update_schema_test.mytype_to_v2(val) FROM vupd.ut2 LIMIT 10
DROP TABLE IF EXISTS vupd2.ut5
CREATE PROCEDURE IF NOT EXISTS vupd2.p_tmp(IN c update_test.COUNTER) SET @vu_x = update_test.counter_double(c)
CALL vupd2.p_tmp('5')
DROP PROCEDURE IF EXISTS vupd2.p_tmp
ALTER TABLE vupd.ut1 ADD COLUMN extra update_test.COUNTER
ALTER TABLE vupd.ut1 DROP COLUMN extra
ALTER TABLE vupd.ut2 FORCE
TRUNCATE TABLE vupd.ut_log
