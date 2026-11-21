-- Run once per fresh datadir, before pstress step 1.
-- Installs the extensions whose types custom_types.json describes. pstress
-- creates the tables itself, in `test`.

INSTALL EXTENSION vsql_complex;
INSTALL EXTENSION vsql_simple;
INSTALL EXTENSION vsql_tvector;
