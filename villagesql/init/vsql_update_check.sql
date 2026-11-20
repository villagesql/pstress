-- Run by vsql-loop.sh after every restart (CHECK_SQL). A restart applies any
-- pending ALTER EXTENSION ... AT RESTART. Lines starting with FAIL, and any
-- error, are findings; INFO lines go to the loop log. A custom value can only
-- be rendered by sending it to the client, so rows of the form
-- RENDER, expected prefix, label, value are compared by vsql-loop.sh.
--
-- Each update_test version identifies itself: COUNTER renders as v1:N
-- (1.0.0), v1.1:N (1.1.0) or v2:N (2.0.0), and counter_double multiplies by
-- 2 (1.x) or 3 (2.0.0). A column or routine parameter still bound to another
-- version renders or computes differently from the installed one.

SELECT CONCAT('INFO ', EXTENSION_NAME, '=', EXTENSION_VERSION,
              IF(PENDING_VERSION IS NULL, '',
                 CONCAT(' pending ', PENDING_VERSION, ' (',
                        IFNULL(LEFT(PENDING_LAST_ERROR, 60), 'no error'), ')')))
  FROM INFORMATION_SCHEMA.EXTENSIONS
  WHERE EXTENSION_NAME LIKE 'update%' ORDER BY EXTENSION_NAME;

-- A restart either applies a pending update or records why it could not.
SELECT CONCAT('FAIL pending update not applied: ', EXTENSION_NAME, ' ',
              EXTENSION_VERSION, ' -> ', PENDING_VERSION)
  FROM INFORMATION_SCHEMA.EXTENSIONS
  WHERE PENDING_VERSION IS NOT NULL AND PENDING_LAST_ERROR IS NULL;

SELECT EXTENSION_VERSION INTO @ut_ver FROM INFORMATION_SCHEMA.EXTENSIONS
  WHERE EXTENSION_NAME = 'update_test';
SET @ut_prefix = CASE @ut_ver WHEN '1.0.0' THEN 'v1:' WHEN '1.1.0' THEN 'v1.1:'
                              WHEN '2.0.0' THEN 'v2:' END;
SET @ut_factor = IF(@ut_ver = '2.0.0', 3, 2);

SELECT CONCAT('FAIL update_test ', @ut_ver, ' is not a version this check knows')
  FROM DUAL WHERE @ut_prefix IS NULL;

-- The column's, the function return's and the procedure parameter's type
-- bindings.
SELECT 'RENDER', @ut_prefix, 'column vupd.ut1.val', val
  FROM vupd.ut1 WHERE val IS NOT NULL ORDER BY id LIMIT 1;
SELECT 'RENDER', @ut_prefix, 'function return', vupd.f_ut_id('21');
CALL vupd.p_ut_echo('21');

-- The VDF, called through a routine parameter.
SELECT CONCAT('FAIL update_test ', @ut_ver, ': counter_double(21) = ', d)
  FROM (SELECT vupd.f_ut_double('21') AS d) x
  WHERE d <> 21 * @ut_factor;

-- Every custom column still reads. An error here is a finding.
SELECT COUNT(update_test.counter_double(val)) INTO @ut_n FROM vupd.ut1;
SELECT COUNT(update_schema_test.MYTYPE::to_string(val)) INTO @ut_n FROM vupd.ut2;
SELECT COUNT(update_length_test.FIX::to_string(f)),
       COUNT(update_length_test.VAR::to_string(v)) INTO @ut_n, @ut_m FROM vupd.ut3;
