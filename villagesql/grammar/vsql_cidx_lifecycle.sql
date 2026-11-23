UNINSTALL EXTENSION vsql_knn_index_test
INSTALL EXTENSION vsql_knn_index_test
UNINSTALL EXTENSION vsql_index_test
INSTALL EXTENSION vsql_index_test
UNINSTALL EXTENSION vsql_ext_index_test
INSTALL EXTENSION vsql_ext_index_test
CREATE TABLE IF NOT EXISTS ci.lk (id INT PRIMARY KEY, v KVECTOR, INDEX iv (v) USING EXTENDED(vsql_knn_index_test.kvec_l2))
INSERT IGNORE INTO ci.lk VALUES (1, '[1,0,0,0]'), (2, '[0,1,0,0]'), (3, '[0,0,1,0]')
SELECT id FROM ci.lk ORDER BY vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[1,0,0,0]')) LIMIT 2
DROP TABLE IF EXISTS ci.lk
CREATE TABLE IF NOT EXISTS ci.ld (id INT PRIMARY KEY, a dummy_type_vector, INDEX ia (a) USING EXTENDED(dummy_index_hnsw))
DROP TABLE IF EXISTS ci.ld
CREATE TABLE IF NOT EXISTS ci.le (id INT PRIMARY KEY, a ext_index_wide_blob, INDEX ia (a) USING EXTENDED(ext_index))
INSERT IGNORE INTO ci.le VALUES (1, 'lifecycle')
DROP TABLE IF EXISTS ci.le
SELECT * FROM INFORMATION_SCHEMA.EXTENSIONS
