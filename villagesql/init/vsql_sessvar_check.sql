-- Run by vsql-loop.sh after every restart (CHECK_SQL). The loop starts mysqld
-- with --defaults-file=/dev/null, so mysqld-auto.cnf is read and SET PERSIST
-- values are applied at startup, including those of extensions that are
-- registered later in startup. Lines starting with FAIL, and any error, are
-- findings; INFO lines go to the loop log.

SELECT CONCAT('INFO installed: ',
              IFNULL(GROUP_CONCAT(EXTENSION_NAME ORDER BY EXTENSION_NAME), 'none'),
              '; persisted vsql vars: ',
              (SELECT COUNT(*) FROM performance_schema.persisted_variables
                WHERE VARIABLE_NAME LIKE 'vsql\_%\_test.%'))
  FROM INFORMATION_SCHEMA.EXTENSIONS;

-- A persisted variable of an installed extension starts with its persisted
-- value: nothing has set it since the restart.
SELECT CONCAT('FAIL persisted ', p.VARIABLE_NAME, ' = ''',
              LEFT(p.VARIABLE_VALUE, 40), ''' but the global is ''',
              LEFT(g.VARIABLE_VALUE, 40), '''')
  FROM performance_schema.persisted_variables p
  JOIN performance_schema.global_variables g
    ON g.VARIABLE_NAME = p.VARIABLE_NAME
  WHERE p.VARIABLE_NAME LIKE 'vsql\_%\_test.%'
    AND p.VARIABLE_VALUE <> g.VARIABLE_VALUE;

-- The range clamp extension keeps min_setting <= max_setting. Read through
-- performance_schema: @@ names fail to parse while the extension is not
-- installed.
SELECT CONCAT('FAIL min_setting ', mn, ' > max_setting ', mx)
  FROM (SELECT MAX(IF(VARIABLE_NAME = 'vsql_range_clamp_test.min_setting',
                      VARIABLE_VALUE + 0, NULL)) AS mn,
               MAX(IF(VARIABLE_NAME = 'vsql_range_clamp_test.max_setting',
                      VARIABLE_VALUE + 0, NULL)) AS mx
          FROM performance_schema.global_variables
          WHERE VARIABLE_NAME IN ('vsql_range_clamp_test.min_setting',
                                  'vsql_range_clamp_test.max_setting')) t
  WHERE mn > mx;
