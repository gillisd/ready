# Benchmark envelope + mark helpers. Source in a controlled `zsh -f` shell.
# Marks are "<run_id> <name> <epoch>" appended to $READY_MARKS; $EPOCHREALTIME
# is CLOCK_REALTIME, the same wall clock Ruby's Process::CLOCK_REALTIME reads.
zmodload zsh/datetime

# Append a mark for the current $READY_RUN_ID.
bench_mark() { print -r -- "${READY_RUN_ID} $1 ${EPOCHREALTIME}" >> $READY_MARKS }

# bench_envelope <run_id> -- <cmd...>
# Bare-read envelope_start (write deferred until after return so the ~48us log
# write never lands inside the span), run cmd, read envelope_end first.
bench_envelope() {
  local rid=$1; shift; [[ $1 == -- ]] && shift
  export READY_RUN_ID=$rid
  local __start=${EPOCHREALTIME}
  "$@"
  local __end=${EPOCHREALTIME}
  print -r -- "${rid} envelope_start ${__start}" >> $READY_MARKS
  print -r -- "${rid} envelope_end ${__end}" >> $READY_MARKS
}
