# Benchmark harness helpers. Source into a controlled `zsh -f` shell.
#
# Marks are "<run_id> <mark_name> <epoch_seconds>" lines appended to
# $READY_MARKS. $EPOCHREALTIME is CLOCK_REALTIME, the same wall clock Ruby's
# Process::CLOCK_REALTIME reads, so zsh and Ruby marks subtract cleanly.
zmodload zsh/datetime

# bench_harness <run_id> -- <cmd...>
# Runs one command under the harness, bracketing it with the harness_start /
# harness_end marks. The clock is read bare on both sides and the log writes
# are deferred until after the run, so the ~48us append never lands inside the
# measured span. Locals are declared up front for the same reason: nothing
# runs between the first clock read and the command but the command itself.
bench_harness() {
  emulate -L zsh
  setopt extendedglob

  local run_id= start_time= end_time=

  run_id=$1
  shift
  [[ $1 = -- ]] && shift
  export READY_RUN_ID=$run_id

  start_time=${EPOCHREALTIME}
  "$@"
  end_time=${EPOCHREALTIME}

  print -r -- "${run_id} harness_start ${start_time}" >> $READY_MARKS
  print -r -- "${run_id} harness_end ${end_time}" >> $READY_MARKS
}
