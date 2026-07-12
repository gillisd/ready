# Emitted as the first Ruby user code via RUBYOPT=-r; marks interpreter-up.
File.write(
  ENV.fetch("READY_MARKS"),
  "#{ENV.fetch('READY_RUN_ID')} ruby_up #{Process.clock_gettime(Process::CLOCK_REALTIME)}\n",
  mode: "a",
)
