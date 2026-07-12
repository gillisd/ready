# Benchmark harness helpers. Source into a controlled `zsh -f` shell.
#
# Marks are "<run_id> <mark_name> <epoch_seconds>" lines appended to
# $READY_MARKS. $EPOCHREALTIME is CLOCK_REALTIME, the same wall clock Ruby's
# Process::CLOCK_REALTIME reads, so zsh and Ruby marks subtract cleanly.
zmodload zsh/datetime

# bench_mark <mark_name>
# Appends one mark for the current run. Called from inside measured regions
# (the generated hot stub marks command_start with it), so it stays a bare
# one-line append -- no option juggling to keep its own cost negligible.
# The timestamp is expanded before the redirection opens the file, so a
# mark's own ~50us write cost always lands in the span it OPENS, never the
# span it closes; instrument self-cost can't inflate the span being reported.
bench_mark() {
  print -r -- "${READY_RUN_ID} $1 ${EPOCHREALTIME}" >> $READY_MARKS
}

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
