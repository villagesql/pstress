-- Run by vsql-loop.sh after every restart (CHECK_SQL). Lines starting with
-- FAIL, and any error, are findings.
--
-- p_vc_lit, f_vc_lit and the prepared statement ps_vc_lit_log log values
-- taken from text literals that are reused across executions. A literal that
-- keeps bytes freed with an earlier execution's table logs a wrong value.

SELECT CONCAT('FAIL ', src, ' logged r=', IFNULL(r, 'NULL'), ' c=',
              IFNULL(complex_real(c), 'NULL'), ',', IFNULL(complex_imag(c), 'NULL'),
              ' (row ', id, ')')
  FROM vsql.vc_log
  WHERE (src = 'p_vc_lit def'
         AND NOT (r = 1.5 AND complex_real(c) = 1.5 AND complex_imag(c) = 2.5))
     OR (src = 'p_vc_lit set'
         AND NOT (r = 7 AND complex_real(c) = 7 AND complex_imag(c) = 8))
     OR (src = 'p_vc_lit cmp'
         AND NOT (complex_real(c) = 7 AND complex_imag(c) = 8))
     OR (src = 'f_vc_lit' AND NOT (r = 5))
     OR (src = 'ps_vc_lit'
         AND NOT (complex_real(c) = 5.5 AND complex_imag(c) = 6.5))
  ORDER BY id LIMIT 5;
