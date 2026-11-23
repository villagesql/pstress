ALTER TABLE ci.k4 ADD INDEX iv (v) USING EXTENDED(vsql_knn_index_test.kvec_l2)
CREATE INDEX ic ON ci.k4 (v kvec_profile_cos) USING EXTENDED(vsql_knn_index_test.kvec_cos)
CREATE INDEX iv2 ON ci.k1 (v kvec_profile_cos) USING EXTENDED(vsql_knn_index_test.kvec_cos)
ALTER TABLE ci.k1 ENGINE=InnoDB
ALTER TABLE ci.k1 FORCE
ALTER TABLE ci.k2 ENGINE=InnoDB
ALTER TABLE ci.k3 FORCE
ALTER TABLE ci.k1 ADD COLUMN x INT, ALGORITHM=INPLACE
ALTER TABLE ci.k1 DROP COLUMN x
ALTER TABLE ci.k1 MODIFY s VARCHAR(32)
ALTER TABLE ci.k3 DROP INDEX iw, ADD INDEX iw (w) USING EXTENDED(vsql_knn_index_test.kvec_l2)
ALTER TABLE ci.k3 DROP INDEX iw, ADD INDEX iw (w kvec_profile_cos) USING EXTENDED(vsql_knn_index_test.kvec_cos)
ALTER TABLE ci.k2 DROP PRIMARY KEY, ADD PRIMARY KEY (a, b)
ALTER TABLE ci.k2 ADD INDEX icos (v kvec_profile_cos) USING EXTENDED(vsql_knn_index_test.kvec_cos)
ALTER TABLE ci.k4 ADD KEY k_d ((vsql_knn_index_test.kvec_l2_distance(v, KVECTOR::from_string('[0,0,0,0]'))))
ALTER TABLE ci.d1 ADD INDEX ib (a) USING EXTENDED(dummy_index_hnsw)
ALTER TABLE ci.d1 FORCE
ALTER TABLE ci.e1 FORCE
ALTER TABLE ci.e1 ADD INDEX ia (a) USING EXTENDED(ext_index)
OPTIMIZE TABLE ci.k1
OPTIMIZE TABLE ci.e1
ALTER TABLE ci.k1 MODIFY s VARCHAR(64)
ALTER TABLE ci.k2 DROP INDEX icos
ALTER TABLE ci.e1 DROP INDEX ia
CHECK TABLE ci.k2
INSERT INTO ci.d1 (a) VALUES ('[1,2,3,4]')
UPDATE ci.d1 SET a = '[4,3,2,1]' WHERE id = @id
ALTER TABLE ci.k4 DROP INDEX iv
DROP INDEX ic ON ci.k4
DROP INDEX iv2 ON ci.k1
ALTER TABLE ci.k4 DROP KEY k_d
ALTER TABLE ci.d1 DROP INDEX ib
