CREATE TABLE IF NOT EXISTS vlc.lb (id INT AUTO_INCREMENT PRIMARY KEY, b BYTEARRAY, s VARCHAR(64))
CREATE TABLE IF NOT EXISTS vlc.lt (id INT AUTO_INCREMENT PRIMARY KEY, v TVECTOR(3), w TVECTOR(3))
CREATE TABLE IF NOT EXISTS vlc.lt2 (id INT AUTO_INCREMENT PRIMARY KEY, v TVECTOR(3)) SELECT v FROM vlc.lt LIMIT 20
CREATE TRIGGER IF NOT EXISTS vlc.lb_bi BEFORE INSERT ON vlc.lb FOR EACH ROW SET NEW.b = rot13(NEW.b)
DROP TABLE IF EXISTS vlc.lb
DROP TABLE IF EXISTS vlc.lt, vlc.lt2
DROP TABLE IF EXISTS vlc.lb, vlc.lt, vlc.lt2
INSERT INTO vlc.lb (b, s) VALUES ('hello', 'a'), ('VillageSQL', 'b'), ('abcdefgh', 'c')
INSERT INTO vlc.lb (b, s) SELECT rot13(b), s FROM vlc.lb ORDER BY id DESC LIMIT 5
INSERT INTO vlc.lt (v, w) VALUES ('[1,2,3]', '[0.5,0.5,0.5]'), ('[4.5,5.5,6.5]', '[-1,0,1]')
INSERT INTO vlc.lt (v, w) SELECT vsql_tvector.tvector_add(v, w), w FROM vlc.lt ORDER BY id DESC LIMIT 5
INSERT INTO vlc.lt2 (v) SELECT w FROM vlc.lt LIMIT 5
UPDATE vlc.lt SET v = vsql_tvector.tvector_add(v, v) WHERE id % 3 = 0
UPDATE vlc.lb SET b = rot13(b) WHERE id % 2 = 0
DELETE FROM vlc.lt ORDER BY id LIMIT 2
SELECT id, rot13(b), even_chars(b), odd_chars(b), ba_concat(b, b) FROM vlc.lb LIMIT 10
SELECT ba_concat_all(b, b, b), ba_len() FROM vlc.lb LIMIT 5
SELECT id, vsql_tvector.tvector_dot_product(v, w), vsql_tvector.tvector_max_element(v), vsql_tvector.tvector_dim(v) FROM vlc.lt LIMIT 10
SELECT a.id FROM vlc.lt a JOIN vlc.lt2 b ON a.v = b.v LIMIT 10
SELECT v, COUNT(*) FROM vlc.lt GROUP BY v ORDER BY v LIMIT 10
SELECT rot13('abc'), ba_len()
PREPARE ps_lb FROM 'SELECT rot13(b) FROM vlc.lb WHERE id > ?'
SET @lc_id = FLOOR(RAND() * 20)
EXECUTE ps_lb USING @lc_id
DEALLOCATE PREPARE ps_lb
PREPARE ps_lt FROM 'INSERT INTO vlc.lt (v, w) VALUES (TVECTOR::from_string(?), ?)'
SET @lc_v = CONCAT('[', FLOOR(RAND() * 9), ',', FLOOR(RAND() * 9), ',', FLOOR(RAND() * 9), ']')
EXECUTE ps_lt USING @lc_v, @lc_v
DEALLOCATE PREPARE ps_lt
CREATE FUNCTION IF NOT EXISTS vlc.f_rot(n INT) RETURNS INT READS SQL DATA RETURN (SELECT COUNT(*) FROM vlc.lb WHERE id > n AND rot13(b) IS NOT NULL)
CREATE FUNCTION IF NOT EXISTS vlc.f_dot(x TVECTOR(3)) RETURNS DOUBLE DETERMINISTIC RETURN vsql_tvector.tvector_dot_product(x, x)
CREATE PROCEDURE IF NOT EXISTS vlc.p_ins() INSERT INTO vlc.lt (v, w) SELECT w, v FROM vlc.lt ORDER BY id DESC LIMIT 3
SELECT vlc.f_rot(3)
SELECT vlc.f_dot('[1,2,3]')
CALL vlc.p_ins()
DROP FUNCTION IF EXISTS vlc.f_rot
DROP FUNCTION IF EXISTS vlc.f_dot
DROP PROCEDURE IF EXISTS vlc.p_ins
CREATE OR REPLACE VIEW vlc.lv AS SELECT id, vsql_tvector.tvector_dot_product(v, w) AS d FROM vlc.lt
SELECT MAX(d) FROM vlc.lv
DROP VIEW IF EXISTS vlc.lv
UNINSTALL EXTENSION vsql_simple
UNINSTALL EXTENSION vsql_simple
INSTALL EXTENSION vsql_simple
UNINSTALL EXTENSION vsql_tvector
UNINSTALL EXTENSION vsql_tvector
INSTALL EXTENSION vsql_tvector
UNINSTALL EXTENSION vsql_complex
SELECT * FROM INFORMATION_SCHEMA.EXTENSIONS
