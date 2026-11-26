# AGENTS.md

This is the VillageSQL fork of Percona-QA/pstress. The VillageSQL work is the
stress loop in `villagesql/`: it runs pstress against a VillageSQL server
build with extensions installed (custom types, custom indexes, capabilities,
extension variables, extension updates) and keeps every crash, hang, failed
recovery and failed check. The pstress source also has a few VillageSQL
additions (custom column types, temporary table checks, reconnects).

## Layout

```
villagesql/vsql-loop.sh      the loop; its header documents every variable
villagesql/conf/*.conf       one file per workload, sourced by the loop
villagesql/grammar/*.sql     SQL grammar files, one statement per line
villagesql/init/*_init.sql   run once per fresh datadir (INSTALL EXTENSION, tables, procedures)
villagesql/init/*_check.sql  CHECK_SQL, run after every restart
villagesql/custom_types.json types for pstress --custom-types
build-vsql/                  local pstress build (ignored)
run/                         loop output (ignored)
```

## Build pstress

pstress links against the client library of a VillageSQL server build.

```
cmake -S . -B build-vsql -DMYSQL=ON \
  -DMYSQL_INCLUDE_DIR=<villagesql-server source>/include \
  -DMYSQL_LIBRARY=<server build>/library_output_directory/libmysqlclient.dylib
cmake --build build-vsql -j
```

On Linux the library is `libmysqlclient.so`. The binary is
`build-vsql/src/pstress-ms`, which is the loop's default `PSTRESS_BIN`.
`pstress-ms --help=<option>` explains any option.

VillageSQL options added to pstress:

| Option | What it does |
|---|---|
| `--custom-types=<json>` | random tables get columns of extension types; each type, expression and index is probed at startup and left out if the server refuses it |
| `--custom-type-prob` | percent of new random columns that use a custom type (15) |
| `--select-temp-table` | SELECTs that build internal temporary tables or sorts |
| `--temp-table-settings` | changes temp table and sort settings per session |
| `--temp-table-compare` | runs a query under two settings and compares the results |
| `--reconnect` | worker threads reconnect, reset the connection or change user |

## Server build

`BASEDIR` is a villagesql-server build directory. The loop uses
`$BASEDIR/bin/mysqld`, `$BASEDIR/bin/mysql`, and copies the `.veb` files a
workload needs from `$BASEDIR/veb_output_directory`. An extension built
outside the server tree (vsql_cube, for example) sets `VEB_SRC_DIR` to its
own build directory.

A debug build catches far more (assertions, sync debug); a release build is
faster and finds races that debug timing hides. Sanitizer builds work too;
the loop gives pstress its own `ASAN_OPTIONS`.

## Run a workload

```
BASEDIR=<server build> villagesql/vsql-loop.sh villagesql/conf/<workload>.conf
```

Any variable can also be set in the environment, which wins over the conf
file. Stop with Ctrl-C. On macOS, wrap long runs so the machine does not
sleep: `caffeinate -dimsu villagesql/vsql-loop.sh ...`.

| Conf | Tests | .veb files |
|---|---|---|
| (none) | COMPLEX types: DML, DDL, indexes on custom types, routines | vsql_complex |
| `vsql_types` | random pstress tables with all the custom types in `custom_types.json` | complex, simple, tvector, tarray_test, bitfield_test, storage_test |
| `vsql_lifecycle` | INSTALL/UNINSTALL EXTENSION under load | complex, simple, tvector |
| `vsql_update` | ALTER EXTENSION ... VERSION ... AT RESTART, applied at each restart | update_test, update_schema_test, update_length_test versions |
| `vsql_sessvar` | extension session, global and persisted variables | session_var_test, config_vars_test, range_clamp_test |
| `vsql_caps` | query hooks, status counters, extension threads, MySQL services | slow_query_log, usage_counter, thread_worker_test, lifecycle_test, mysql_services_session_test |
| `vsql_cidx` | custom indexes from the test extensions | knn_index_test, index_test, ext_index_test |
| `vsql_vector` | vsql_vector SVECTOR and HNSW: DML, KNN, transactions | vsql_vector |
| `vsql_cube` | vsql_cube R-tree: exact KNN checks, rollbacks, locking reads | vsql_cube built with `-DVSQL_CUBE_RTREE=ON`; set `VEB_SRC_DIR` to its build directory |
| `vsql_textsearch` | vsql_textsearch bm25: ranked reads checked against a REGEXP on a copy of the text, rollbacks, locking reads | vsql_textsearch built with `-DVTS_BUILD_EXTENSION=ON` |

Each conf file's header says what its grammars cover, which statements are
left out and why (known bugs), and how to add them back.

### Main knobs

| Variable | Default | Meaning |
|---|---|---|
| `RUNDIR` | `run/<workload>` | output directory; give every concurrent loop its own |
| `SIGNAL` | 9 | 9 kills mysqld after each step (crash recovery test), 15 shuts it down |
| `RECOVER` | 1 | 0 starts a fresh datadir after a finding and runs CHECK_SQL at step end |
| `TRIALS` | 0 | number of steps; 0 runs until stopped |
| `STEP_SECONDS` | 60 | length of one pstress step |
| `STEPS_PER_DATADIR` | 5 | steps on one datadir before a fresh one |
| `THREADS` | 16 | pstress threads |
| `GRAMMAR` | per conf | `name:N` repeats a grammar file N times to weight it |
| `GRAMMAR_WEIGHT` | 1000 | weight of grammar lines against pstress's own DML (~2600) |
| `LIFECYCLE_GRAMMAR` | per conf | grammar for the INSTALL/UNINSTALL workers beside pstress |
| `CHECK_SQL` | per conf | SQL run after every restart |
| `ERR_FAIL_PATTERN` | per conf | error log lines matching this regex are findings |
| `MYEXTRA` | per conf | extra mysqld options |
| `PSTRESS_EXTRA` | | extra pstress options |
| `SAVE_DATADIR` | 1 | copy the datadir into each finding |

## Results

`$RUNDIR/loop.log` has one line per step (`trial N (life L step S): ok` or
the finding) and the INFO lines from CHECK_SQL. Findings are kinds `crash`,
`hang`, `shutdown_hang`, `recovery_*` and `check_failed`, each saved in
`$RUNDIR/findings/<time>_<kind>_t<trial>_l<life>_s<step>/`:

- `mysqld.err.trial`: the error log of that step, with the assertion or
  signal and stack
- `run_info.txt`: build, seed, grammar and the pstress command
- `pstress_logs/`: the step's pstress thread logs, the grammar used, and
  `check_step_N.out` for check failures
- `datadir/`: the datadir after the server stopped, to reproduce recovery
- hangs also get `lldb_bt.txt` or `gdb_bt.txt` and server state; on macOS
  crash reports from `~/Library/Logs/DiagnosticReports` are copied in

CHECK_SQL contract: a printed line starting with `FAIL`, or any SQL error, is
a finding; lines starting with `INFO` go to the loop log.

## Adding a workload

The loop has no code for any one extension: a workload is a conf file and
the SQL it names. To stress a new extension or feature, copy the closest
workload and change it.

| Feature | Start from |
|---|---|
| column type | an entry in `custom_types.json`, run with `vsql_types` |
| exact index | `vsql_cube` |
| approximate (ANN) index | `vsql_vector` |
| hook, capability or extension thread | `vsql_caps` |
| system variables | `vsql_sessvar` |
| extension versions | `vsql_update` |

A new column type often needs no other file: describe its column clause,
literals and WHERE and UPDATE expressions in `custom_types.json` (or a copy
passed with `CUSTOM_TYPES`) and pstress uses it in its random tables,
queries and indexes.

Otherwise a workload has four files:

- `conf/vsql_<x>.conf` sets `RUNDIR`, `GRAMMAR`, `INIT_SQL`, `CHECK_SQL`,
  `VEB_FILES` and, as needed, `VEB_SRC_DIR`, `MYEXTRA`, `ERR_FAIL_PATTERN`
  and `LIFECYCLE_GRAMMAR`. Use `${VAR:-default}` so the environment can
  override each one. Its header says what the grammars cover and which
  statements are left out and why.
- `init/vsql_<x>_init.sql` installs the extension, creates and seeds the
  tables, and defines the procedures the grammar and check call.
- `grammar/vsql_<x>_*.sql` has the statements pstress picks from. Keep DML
  and DDL in separate files and weight them in `GRAMMAR`
  (`vsql_x_dml:10 vsql_x_ddl:1`). Lines run in random order, so for random
  values have some lines `SET @var` and others use it (as prepared
  statement parameters, for example), or call a procedure from the init
  file.
- `init/vsql_<x>_check.sql` checks after every restart that the data is
  still right, and prints `FAIL ...` when it is not.

What made the existing workloads find bugs:

- The check finds the bugs that do not crash. Compare the feature with a
  path that does not use it: an index scan with the same query under
  `IGNORE INDEX`, a value through the extension with the stored value. The
  grammar can call the same check under load and store the results in a
  table for CHECK_SQL to report (`p_cb_chk` and `cb_chk` in vsql_cube).
- Keep false FAILs out. A check that fails without a bug teaches people to
  ignore it; a query plan that changes with the isolation level or a column
  too short for the values are typical causes.
- Run with kill -9 and `RECOVER=1`. Rollback of transactions open at the
  crash and redo replay are where custom storage breaks most.
- Cover rollback: transactions that change a row several times and roll
  back, savepoints, primary key changes, XA.
- Leave a known bug's statements out of the grammar and name the bug in the
  conf header, so the loop keeps finding new ones. Put them back once it is
  fixed.
- Set `ERR_FAIL_PATTERN` to the prefix the extension logs its errors with.

## Gotchas

- **New extension build, new datadir.** A datadir keeps the extension
  version it installed (`.veb_expansion_cache`), so replacing the `.veb` and
  restarting still runs the old code. The loop copies `.veb` files at every
  fresh datadir; to test a new build right away, restart the loop.
- **Preview extensions** need `--vsql-allow-preview-extensions=ON` on the
  command line (the confs add it to `MYEXTRA`). mysqld runs with
  `--no-defaults`, which skips `SET PERSIST` values on restart;
  `MYSQLD_DEFAULTS=--defaults-file=/dev/null` keeps them (vsql_sessvar uses
  this).
- **Grammar files** hold one statement per line and no comments. pstress
  picks lines uniformly, so a DDL line that rebuilds a table should be rare
  (put DDL in its own file with weight 1).
- **Socket path** is `$RUNDIR/s.sock` and must stay under 100 characters.
  Keep `RUNDIR` short.
- **Do not edit the init or check SQL of a running loop.** The loop reads
  them at each fresh datadir and restart, and a half-edited file gives false
  findings.
- **Probing by hand:** start your own mysqld on a copy of a finding's datadir,
  with its own socket and port. Never point a probe at a loop's `RUNDIR`.
- **Known bugs** are listed in each conf header and kept out of the
  grammars. Before reporting a finding, check that it is not one of them.
