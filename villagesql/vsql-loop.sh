#!/usr/bin/env bash
# Run pstress against a VillageSQL build in a loop and keep what breaks.
#
# Each datadir lives for STEPS_PER_DATADIR pstress steps. Every step runs the
# random pstress workload plus the VillageSQL grammar, then the server is
# killed (SIGNAL=9) or shut down (SIGNAL=15) and restarted on the same datadir,
# so every restart is also a recovery test. A finding is saved when:
#   crash          mysqld died during a step
#   hang           a query ran longer than STALL_SECS, the server stopped
#                  answering, or pstress ran HANG_GRACE seconds past its time
#   shutdown_hang  SIGNAL=15 shutdown took longer than SHUTDOWN_TIMEOUT
#   recovery_*     restart after a kill/crash died or did not come up
#   check_failed   CHECK_SQL, run after every restart, printed a FAIL line or
#                  an error
# Hangs get stack dumps (macOS: sample + lldb, Linux: gdb) and server state
# before the server is killed with SIGABRT.
#
# Grammar files (grammar/*.sql, one statement per line, no comments). pstress
# picks grammar lines uniformly, so GRAMMAR takes name:N to repeat a file N
# times; DDL rebuilds whole tables under an exclusive MDL and must stay rare.
#   vsql_complex_dml        COMPLEX/COMPLEX2 DML, indexed lookups, VDFs,
#                           aggregates, SP/function/trigger calls, prepared
#                           statement reuse, and statements mixing pstress
#                           tables (T1, T1_INT_n, T1_VARCHAR_n)
#   vsql_complex_ddl        custom-type index/column/partition DDL, rebuilds,
#                           and dropping/recreating SPs, functions, triggers
#   vsql_complex_lifecycle  INSTALL/UNINSTALL EXTENSION under load
#   vsql_lifecycle          for LIFECYCLE_GRAMMAR: create, use and drop
#                           vsql_simple and vsql_tvector objects, and
#                           uninstall/install both extensions
#   vsql_update_dml         DML, routines and prepared statements on columns
#                           of the update_test, update_schema_test and
#                           update_length_test types
#   vsql_update_ddl         short-lived tables and routines of those types
#   vsql_update_ext         ALTER EXTENSION ... VERSION ... AT RESTART to every
#                           version, including ones the precheck rejects
# conf/vsql_update.conf runs these with CHECK_SQL init/vsql_update_check.sql,
# which verifies after every restart that the applied version is the one
# columns and routine parameters render with.
#   vsql_vector_dml         SVECTOR inserts through prepared statements, KNN on
#                           L2/cosine/inner-product/L1 HNSW indexes with
#                           ef_search changes, distance scans, SP/function/
#                           trigger calls, and DML that HNSW tables reject
#   vsql_vector_ddl         create/drop/truncate of HNSW tables, routine and
#                           trigger re-creation; no ALTER TABLE
#   vsql_vector_alter       ALTER TABLE, CREATE INDEX, OPTIMIZE, CHECK on HNSW
#                           tables (crash today; opt in)
# conf/vsql_vector.conf switches the init SQL, .veb and grammar to vsql_vector.
# The other workloads (vsql_types, vsql_lifecycle, vsql_sessvar, vsql_caps,
# vsql_cidx, vsql_cube) describe their grammars in their conf files.
# AGENTS.md has an overview of every workload, the build and the results.
#
# Usage:  BASEDIR=<build dir> villagesql/vsql-loop.sh [config-file]
# Any variable below can be set in the environment or in the config file.
# Stop with Ctrl-C; findings are in $RUNDIR/findings, the log in $RUNDIR/loop.log.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
[ $# -ge 1 ] && . "$1"

BASEDIR=${BASEDIR:?set BASEDIR to the server build directory}
RUNDIR=${RUNDIR:-$SCRIPT_DIR/../run/loop}
PSTRESS_BIN=${PSTRESS_BIN:-$SCRIPT_DIR/../build-vsql/src/pstress-ms}
GRAMMAR=${GRAMMAR:-vsql_complex_dml:10 vsql_complex_ddl:1}
INIT_SQL=${INIT_SQL:-$SCRIPT_DIR/init/vsql_complex_init.sql}
VEB_FILES=${VEB_FILES:-vsql_complex.veb}
THREADS=${THREADS:-16}
STEP_SECONDS=${STEP_SECONDS:-60}
STEPS_PER_DATADIR=${STEPS_PER_DATADIR:-5}
TRIALS=${TRIALS:-0}                      # 0 = run until stopped
SIGNAL=${SIGNAL:-9}                      # 9 = kill, 15 = clean shutdown
GRAMMAR_WEIGHT=${GRAMMAR_WEIGHT:-1000}   # pstress DML weights sum to ~2600
PSTRESS_TABLES=${PSTRESS_TABLES:-20}
PSTRESS_RECORDS=${PSTRESS_RECORDS:-200}
PSTRESS_EXTRA=${PSTRESS_EXTRA:-}
# pstress --reconnect weight: worker threads reconnect, reset the connection
# or change user. 0 = keep one connection per thread for the whole step.
RECONNECT=${RECONNECT:-20}
# Lifecycle workers run beside pstress: each runs random batches of
# LIFECYCLE_BATCH lines from LIFECYCLE_GRAMMAR, one short mysql session per
# batch, so no session keeps an extension pinned. Empty = off.
LIFECYCLE_GRAMMAR=${LIFECYCLE_GRAMMAR:-}
LIFECYCLE_THREADS=${LIFECYCLE_THREADS:-2}
LIFECYCLE_BATCH=${LIFECYCLE_BATCH:-10}
# SQL file run after every restart. Lines it prints starting with FAIL, and
# any error, are a finding; lines starting with INFO go to the loop log. A row
# RENDER<tab>prefix<tab>label<tab>value is a finding unless value starts with
# prefix.
CHECK_SQL=${CHECK_SQL:-}
# Extended regex: error log lines matching it since the last check are a
# finding too, reported by the check. Empty = off.
ERR_FAIL_PATTERN=${ERR_FAIL_PATTERN:-}
# Where VEB_FILES are copied from: an extension built outside the server tree
# has its .veb in its own build directory.
VEB_SRC_DIR=${VEB_SRC_DIR:-}
# 0: after a finding, start a fresh datadir instead of restarting on the
# crashed one (no recovery test), and run CHECK_SQL at the end of each step.
RECOVER=${RECOVER:-1}
MYEXTRA=${MYEXTRA:-}
# How mysqld reads option files. --no-defaults also skips mysqld-auto.cnf, so
# SET PERSIST values are lost on restart; "--defaults-file=/dev/null" reads
# no option file but keeps them.
MYSQLD_DEFAULTS=${MYSQLD_DEFAULTS:---no-defaults}
# Cycles mixing MDL and InnoDB row-lock waits are invisible to both deadlock
# detectors and only break on these timeouts; long ones stall every thread.
LOCK_WAIT_TIMEOUT=${LOCK_WAIT_TIMEOUT:-15}
INNODB_LOCK_WAIT_TIMEOUT=${INNODB_LOCK_WAIT_TIMEOUT:-5}
STALL_SECS=${STALL_SECS:-300}
HANG_GRACE=${HANG_GRACE:-120}
START_TIMEOUT=${START_TIMEOUT:-180}
SHUTDOWN_TIMEOUT=${SHUTDOWN_TIMEOUT:-120}
SAVE_DATADIR=${SAVE_DATADIR:-1}
PORT=${PORT:-$((30000 + RANDOM % 5000))}
# Sanitizer options for a pstress built with ASan or UBSan. They replace the
# environment's, which are meant for mysqld, so a client report does not stop
# the run. Reports go to pstress.out.
PSTRESS_ASAN_OPTIONS=${PSTRESS_ASAN_OPTIONS:-detect_leaks=0}
PSTRESS_UBSAN_OPTIONS=${PSTRESS_UBSAN_OPTIONS:-print_stacktrace=1:halt_on_error=0}

MYSQLD=$BASEDIR/bin/mysqld
MYSQL=$BASEDIR/bin/mysql
SOCK=$RUNDIR/s.sock
ERR=$RUNDIR/mysqld.err
LOG=$RUNDIR/loop.log
MYSQLD_PID=
PSTRESS_PID=
LC_PIDS=
TRIAL=0
LIFE=0
STEP=0
SEED=
N_CRASH=0
N_HANG=0
N_RECOVERY=0
N_CHECK=0
ERR_SCAN_OFF=0

log() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG"; }
die() { log "FATAL: $*"; stop_all; exit 1; }

mtime() {
  if [ "$(uname)" = Darwin ]; then stat -f %m "$1"; else stat -c %Y "$1"; fi
}

# Run "$@" with a time limit; returns 124 on timeout.
run_timeout() {
  local secs=$1; shift
  "$@" &
  local pid=$! waited=0
  while kill -0 $pid 2>/dev/null; do
    if [ $waited -ge $secs ]; then
      kill -9 $pid 2>/dev/null; wait $pid 2>/dev/null
      return 124
    fi
    sleep 1; waited=$((waited + 1))
  done
  wait $pid
}

sql() {
  run_timeout 30 "$MYSQL" -uroot -S "$SOCK" --connect-timeout=10 -Bse "$1" test 2>/dev/null
}

server_alive() { [ -n "$MYSQLD_PID" ] && kill -0 "$MYSQLD_PID" 2>/dev/null; }

err_size() { if [ -f "$ERR" ]; then wc -c < "$ERR" | tr -d ' '; else echo 0; fi; }

stop_all() {
  stop_lifecycle
  [ -n "$PSTRESS_PID" ] && kill -9 "$PSTRESS_PID" 2>/dev/null
  server_alive && kill -9 "$MYSQLD_PID" 2>/dev/null
  PSTRESS_PID=; MYSQLD_PID=
}

trap 'log "interrupted"; stop_all; summary; exit 130' INT TERM

summary() {
  log "trials=$TRIAL crashes=$N_CRASH hangs=$N_HANG recovery_failures=$N_RECOVERY check_failures=$N_CHECK"
}

# Initialize a template datadir once per mysqld binary.
prepare_template() {
  local stamp; stamp=$(mtime "$MYSQLD")
  if [ -f "$RUNDIR/template.stamp" ] && [ "$(cat "$RUNDIR/template.stamp")" = "$stamp" ]; then
    return
  fi
  log "initializing template datadir for $MYSQLD"
  rm -rf "$RUNDIR/template"
  "$MYSQLD" --no-defaults --initialize-insecure --basedir="$BASEDIR" \
    --datadir="$RUNDIR/template" > "$RUNDIR/template-init.log" 2>&1 \
    || die "mysqld --initialize failed, see $RUNDIR/template-init.log"
  echo "$stamp" > "$RUNDIR/template.stamp"
}

# Returns 0 when up, 1 when mysqld exited, 2 when it did not answer in time.
start_server() {
  rm -f "$SOCK"
  "$MYSQLD" $MYSQLD_DEFAULTS --basedir="$BASEDIR" --datadir="$RUNDIR/data" \
    --socket="$SOCK" --port="$PORT" --mysqlx=OFF --core-file \
    --log-error="$ERR" --pid-file="$RUNDIR/mysqld.pid" --veb-dir="$RUNDIR/veb" \
    --lock-wait-timeout="$LOCK_WAIT_TIMEOUT" \
    --innodb-lock-wait-timeout="$INNODB_LOCK_WAIT_TIMEOUT" $MYEXTRA > /dev/null 2>&1 &
  MYSQLD_PID=$!
  local waited=0
  while [ $waited -lt "$START_TIMEOUT" ]; do
    server_alive || return 1
    "$BASEDIR/bin/mysqladmin" -uroot -S "$SOCK" ping > /dev/null 2>&1 && return 0
    sleep 1; waited=$((waited + 1))
  done
  return 2
}

capture_state() {
  local out=$1
  sql "SELECT * FROM performance_schema.processlist" > "$out/processlist.txt"
  sql "SHOW ENGINE INNODB STATUS\\G" > "$out/innodb_status.txt"
  sql "SELECT * FROM performance_schema.metadata_locks" > "$out/metadata_locks.txt"
  sql "SELECT * FROM performance_schema.data_lock_waits" > "$out/data_lock_waits.txt"
}

capture_stacks() {
  local out=$1
  server_alive || return
  if [ "$(uname)" = Darwin ]; then
    run_timeout 60 sample "$MYSQLD_PID" 5 -file "$out/sample.txt" > /dev/null 2>&1
    run_timeout 120 lldb -p "$MYSQLD_PID" --batch -o "thread backtrace all" -o detach \
      > "$out/lldb_bt.txt" 2>&1
    # Debug builds (SAFE_MUTEX) record each mutex's owner thread and the file
    # and line that locked it; print them for the server mutexes a hang
    # usually involves. A release build has no such record and prints errors.
    local owners=() m
    for m in LOCK_global_system_variables LOCK_plugin LOCK_plugin_delete \
      'Persisted_variables_cache::m_instance->m_LOCK_persist_variables'; do
      owners+=(-o "expr -- *($m).m_mutex.m_u.m_safe_ptr")
    done
    run_timeout 60 lldb -p "$MYSQLD_PID" --batch "${owners[@]}" -o detach \
      > "$out/lldb_mutex_owners.txt" 2>&1
  else
    run_timeout 120 gdb -p "$MYSQLD_PID" -batch -ex "thread apply all bt" \
      > "$out/gdb_bt.txt" 2>&1
  fi
}

# SIGABRT so the server's signal handler writes its own stack to the error log.
abort_server() {
  server_alive || return
  kill -ABRT "$MYSQLD_PID" 2>/dev/null
  local waited=0
  while server_alive && [ $waited -lt 20 ]; do sleep 1; waited=$((waited + 1)); done
  server_alive && kill -9 "$MYSQLD_PID" 2>/dev/null
  wait "$MYSQLD_PID" 2>/dev/null
  MYSQLD_PID=
}

new_finding() {
  local dir; dir="$RUNDIR/findings/$(date '+%Y%m%d-%H%M%S')_$1_t${TRIAL}_l${LIFE}_s${STEP}"
  mkdir -p "$dir"
  echo "$dir"
}

# Copy logs and, with the server stopped, the datadir into a finding.
save_finding() {
  local dir=$1 err_off=$2
  cp -R "$RUNDIR/life" "$dir/pstress_logs"
  tail -c +$((err_off + 1)) "$ERR" > "$dir/mysqld.err.trial"
  cp "$ERR" "$dir/mysqld.err.full"
  {
    echo "basedir=$BASEDIR"
    echo "mysqld_version=$("$MYSQLD" --version 2>/dev/null)"
    echo "seed=$SEED life=$LIFE step=$STEP trial=$TRIAL threads=$THREADS"
    echo "grammar=$GRAMMAR weight=$GRAMMAR_WEIGHT signal=$SIGNAL"
    echo "pstress_cmd=$PSTRESS_CMD"
  } > "$dir/run_info.txt"
  if [ "$(uname)" = Darwin ]; then
    find "$HOME/Library/Logs/DiagnosticReports" -name 'mysqld*' -newer "$RUNDIR/.trial_start" \
      -exec cp {} "$dir/" \; 2>/dev/null
  fi
  if [ "$SAVE_DATADIR" = 1 ] && ! server_alive; then
    cp -R "$RUNDIR/data" "$dir/datadir"
  fi
  log "  saved $dir"
}

# Concatenate grammar files "name[:N] ..." (N = repeat count) into $2.
build_grammar() {
  local f name times i
  : > "$2"
  for f in $1; do
    name=${f%%:*}; times=1
    [ "$name" != "$f" ] && times=${f#*:}
    [ -f "$SCRIPT_DIR/grammar/$name.sql" ] || die "missing grammar $name"
    for i in $(seq 1 "$times"); do
      cat "$SCRIPT_DIR/grammar/$name.sql" >> "$2"
    done
  done
}

fresh_datadir() {
  stop_all
  LIFE=$((LIFE + 1)); STEP=0; SEED=$((RANDOM * 32768 + RANDOM))
  rm -rf "$RUNDIR/data" "$RUNDIR/life" "$RUNDIR/veb"
  cp -R "$RUNDIR/template" "$RUNDIR/data"
  mkdir -p "$RUNDIR/life" "$RUNDIR/veb"
  local f
  for f in $VEB_FILES; do
    cp "${VEB_SRC_DIR:-$BASEDIR/veb_output_directory}/$f" "$RUNDIR/veb/" \
      || die "missing $f in ${VEB_SRC_DIR:-$BASEDIR/veb_output_directory}"
  done
  build_grammar "$GRAMMAR" "$RUNDIR/life/grammar.sql"
  [ -n "$LIFECYCLE_GRAMMAR" ] && build_grammar "$LIFECYCLE_GRAMMAR" "$RUNDIR/life/lifecycle.sql"
  start_server || die "fresh server did not start, see $ERR"
  run_timeout 30 "$MYSQL" -uroot -S "$SOCK" -e "CREATE DATABASE IF NOT EXISTS test" \
    || die "cannot create database test"
  run_timeout 300 "$MYSQL" -uroot -S "$SOCK" -e "source $INIT_SQL" > "$RUNDIR/life/init.out" 2>&1 \
    || die "init SQL $INIT_SQL failed, see $RUNDIR/life/init.out"
  log "life $LIFE: fresh datadir, seed $SEED"
}

# Returns 0 when the server is up again.
# Run CHECK_SQL against the restarted server; $1 is the error log offset of
# the restart.
run_check() {
  [ -n "$CHECK_SQL" ] || return 0
  local out="$RUNDIR/life/check_step_$STEP.out"
  run_timeout 60 "$MYSQL" -uroot -S "$SOCK" -N --force -e "source $CHECK_SQL" > "$out" 2>&1
  local rc=$?
  awk -F'\t' '$1 == "RENDER" && index($4, $2) != 1 {
    print "FAIL " $3 " renders as " $4 ", expected prefix " $2 }' "$out" >> "$out.fail"
  if [ -n "$ERR_FAIL_PATTERN" ]; then
    tail -c +$((ERR_SCAN_OFF + 1)) "$ERR" | grep -E "$ERR_FAIL_PATTERN" | head -20 \
      | sed 's/^/FAIL log: /' >> "$out.fail"
    ERR_SCAN_OFF=$(err_size)
  fi
  cat "$out.fail" >> "$out"; rm -f "$out.fail"
  local info; info=$(grep '^INFO ' "$out" | sed 's/^INFO //' | paste -sd ';' -)
  [ -n "$info" ] && log "  check: $info"
  if [ $rc -ne 0 ] || grep -q '^FAIL\|^ERROR' "$out"; then
    N_CHECK=$((N_CHECK + 1))
    local dir; dir=$(new_finding check_failed)
    log "  CHECK FAILED:"
    grep '^FAIL\|^ERROR' "$out" | head -5 | sed 's/^/    /' | tee -a "$LOG"
    cp "$out" "$dir/"
    save_finding "$dir" "$1"
  fi
}

restart_for_recovery() {
  local err_off; err_off=$(err_size)
  start_server
  local rc=$?
  [ $rc -eq 0 ] && { run_check "$err_off"; return 0; }
  N_RECOVERY=$((N_RECOVERY + 1))
  local dir
  if [ $rc -eq 1 ]; then
    dir=$(new_finding recovery_crash)
    log "  RECOVERY CRASH: mysqld exited during restart"
  else
    dir=$(new_finding recovery_hang)
    log "  RECOVERY HANG: no answer after ${START_TIMEOUT}s"
    capture_stacks "$dir"
    abort_server
  fi
  stop_all
  save_finding "$dir" "$err_off"
  return 1
}

# One pstress step; sets RESULT to ok, crash, hang or overrun.
lifecycle_worker() {
  while kill -0 "$PSTRESS_PID" 2>/dev/null; do
    awk -v n="$LIFECYCLE_BATCH" -v seed="$RANDOM$RANDOM" \
      'BEGIN { srand(seed) } { l[NR] = $0 } END { for (i = 0; i < n; i++) print l[int(rand() * NR) + 1] ";" }' \
      "$RUNDIR/life/lifecycle.sql" | "$MYSQL" -uroot -S "$SOCK" --force -vv >> "$1" 2>&1
    [ -S "$SOCK" ] || sleep 1
  done
}

start_lifecycle() {
  LC_PIDS=
  [ -n "$LIFECYCLE_GRAMMAR" ] || return 0
  local i
  for i in $(seq 1 "$LIFECYCLE_THREADS"); do
    lifecycle_worker "$1/lifecycle_$i.log" &
    LC_PIDS="$LC_PIDS $!"
  done
}

# Stop each worker before killing its mysql client, or it starts another.
stop_lifecycle() {
  local p
  for p in ${LC_PIDS:-}; do
    kill -STOP "$p" 2>/dev/null
    pkill -9 -P "$p" 2>/dev/null
    kill -9 "$p" 2>/dev/null
    wait "$p" 2>/dev/null
  done
  LC_PIDS=
}

# "UNINSTALL vsql_x ok/total ..." from the lifecycle worker logs in $1.
lifecycle_summary() {
  cat "$1"/lifecycle_*.log 2>/dev/null | awk '
    /^(UN)?INSTALL EXTENSION / { stmt = $1 " " $3; next }
    stmt != "" && /^(Query OK|ERROR)/ { tot[stmt]++; if (/^Query OK/) ok[stmt]++; stmt = "" }
    END { for (s in tot) printf "%s %d/%d  ", s, ok[s], tot[s] }'
}

run_step() {
  STEP=$((STEP + 1)); TRIAL=$((TRIAL + 1))
  local tdir="$RUNDIR/life/step_$STEP"
  mkdir -p "$tdir"
  touch "$RUNDIR/.trial_start"
  STEP_ERR_OFF=$(err_size)
  PSTRESS_CMD="$PSTRESS_BIN --database=test --threads=$THREADS --seconds=$STEP_SECONDS \
--tables=$PSTRESS_TABLES --records=$PSTRESS_RECORDS --user=root --socket=$SOCK \
--logdir=$tdir --metadata-path=$RUNDIR/life/ --step $STEP --seed $SEED \
--log-all-queries --log-failed-queries --no-encryption \
--grammar-file=$RUNDIR/life/grammar.sql --grammar-sql=$GRAMMAR_WEIGHT \
--reconnect=$RECONNECT $PSTRESS_EXTRA"
  ASAN_OPTIONS=$PSTRESS_ASAN_OPTIONS UBSAN_OPTIONS=$PSTRESS_UBSAN_OPTIONS \
    $PSTRESS_CMD > "$tdir/pstress.out" 2>&1 &
  PSTRESS_PID=$!
  start_lifecycle "$tdir"
  local start; start=$(date +%s)
  local deadline=$((start + STEP_SECONDS + HANG_GRACE))
  local tick=0 noanswer=0 maxt
  RESULT=ok; HANG_REASON=
  while kill -0 "$PSTRESS_PID" 2>/dev/null; do
    sleep 5; tick=$((tick + 1))
    if ! server_alive; then RESULT=crash; break; fi
    if [ $((tick % 3)) -eq 0 ]; then
      maxt=$(sql "SELECT IFNULL(MAX(TIME),0) FROM performance_schema.processlist
                  WHERE COMMAND NOT IN ('Sleep','Daemon','Binlog Dump','Binlog Dump GTID')
                  AND USER NOT IN ('system user','event_scheduler')")
      if [ -z "$maxt" ]; then
        noanswer=$((noanswer + 1))
        if [ $noanswer -ge 3 ]; then RESULT=hang; HANG_REASON="server not answering"; break; fi
      else
        noanswer=0
        if [ "$maxt" -ge "$STALL_SECS" ]; then
          RESULT=hang; HANG_REASON="a statement has run ${maxt}s"; break
        fi
      fi
    fi
    if [ "$(date +%s)" -gt $deadline ]; then
      RESULT=overrun; HANG_REASON="pstress ran ${HANG_GRACE}s past --seconds"; break
    fi
  done
  stop_lifecycle
  if [ "$RESULT" = ok ]; then
    wait "$PSTRESS_PID" 2>/dev/null
    server_alive || RESULT=crash
  fi
}

handle_result() {
  local dir
  case $RESULT in
    ok)
      return 0 ;;
    crash)
      N_CRASH=$((N_CRASH + 1))
      kill -9 "$PSTRESS_PID" 2>/dev/null; PSTRESS_PID=
      wait "$MYSQLD_PID" 2>/dev/null; MYSQLD_PID=
      dir=$(new_finding crash)
      log "  CRASH:"
      tail -c +$((STEP_ERR_OFF + 1)) "$ERR" | grep -m3 -E 'Assertion|got signal|Got signal' | sed 's/^/    /' | tee -a "$LOG"
      ;;
    hang|overrun)
      N_HANG=$((N_HANG + 1))
      dir=$(new_finding "$RESULT")
      log "  HANG ($HANG_REASON): capturing state and stacks"
      capture_state "$dir"
      capture_stacks "$dir"
      kill -9 "$PSTRESS_PID" 2>/dev/null; PSTRESS_PID=
      abort_server
      ;;
  esac
  save_finding "$dir" "$STEP_ERR_OFF"
  return 1
}

end_step() {
  if [ "$SIGNAL" = 15 ]; then
    local err_off; err_off=$(err_size)
    if ! run_timeout "$SHUTDOWN_TIMEOUT" "$BASEDIR/bin/mysqladmin" -uroot -S "$SOCK" shutdown > /dev/null 2>&1; then
      N_HANG=$((N_HANG + 1))
      local dir; dir=$(new_finding shutdown_hang)
      log "  SHUTDOWN HANG after ${SHUTDOWN_TIMEOUT}s"
      capture_state "$dir"; capture_stacks "$dir"; abort_server
      save_finding "$dir" "$err_off"
    fi
    wait "$MYSQLD_PID" 2>/dev/null
  else
    kill -"$SIGNAL" "$MYSQLD_PID" 2>/dev/null
    wait "$MYSQLD_PID" 2>/dev/null
  fi
  MYSQLD_PID=
}

# ---------------------------------------------------------------------------

[ -x "$MYSQLD" ] || { echo "no mysqld at $MYSQLD"; exit 1; }
[ -x "$PSTRESS_BIN" ] || { echo "no pstress at $PSTRESS_BIN"; exit 1; }
mkdir -p "$RUNDIR/findings"
# The server rejects a --veb-dir containing '..' at INSTALL EXTENSION.
RUNDIR=$(cd "$RUNDIR" && pwd -P)
SOCK=$RUNDIR/s.sock
ERR=$RUNDIR/mysqld.err
LOG=$RUNDIR/loop.log
[ ${#SOCK} -lt 100 ] || { echo "socket path too long (${#SOCK}): $SOCK"; exit 1; }

log "start: basedir=$BASEDIR threads=$THREADS step=${STEP_SECONDS}s steps/datadir=$STEPS_PER_DATADIR signal=$SIGNAL grammar=$GRAMMAR"
prepare_template
fresh_datadir

while [ "$TRIAL" -lt "$TRIALS" ] || [ "$TRIALS" -eq 0 ]; do
  run_step
  log "trial $TRIAL (life $LIFE step $STEP): $RESULT"
  [ -n "$LIFECYCLE_GRAMMAR" ] && log "  lifecycle: $(lifecycle_summary "$RUNDIR/life/step_$STEP")"
  if [ "$TRIALS" -ne 0 ] && [ "$TRIAL" -ge "$TRIALS" ]; then
    handle_result
    break
  fi
  if ! handle_result; then
    # Server is down after a finding: try recovery on the same datadir.
    if [ "$RECOVER" = 0 ] || [ ! -f "$RUNDIR/life/step_$STEP.dll" ] || ! restart_for_recovery; then
      fresh_datadir; continue
    fi
  else
    # Without recovery there may be no restart to run CHECK_SQL after, so
    # run it on the live server before the step ends.
    [ "$RECOVER" = 0 ] && run_check "$(err_size)"
    end_step
    if [ "$STEP" -ge "$STEPS_PER_DATADIR" ]; then fresh_datadir; continue; fi
    restart_for_recovery || { fresh_datadir; continue; }
  fi
  [ "$STEP" -ge "$STEPS_PER_DATADIR" ] && fresh_datadir
done

stop_all
summary
