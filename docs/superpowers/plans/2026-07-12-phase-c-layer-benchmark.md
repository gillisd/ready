# Phase C — Layered Cold-vs-Hot Startup Benchmark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A benchmark that attributes a rubygems-CLI startup to its layers (shell / rbenv_shim / ruby_boot / rubygems / dep_activate / tool_run / reap) and shows each collapse when served hot by `by-server` — surfaced as `rake bench` (prints the waterfall) and a `:e2e` structural guard.

**Architecture:** Both arms are instrumented with faithful **copies** in temp dirs (zero real-file edits, zero gem-runtime changes). Cold = instrumented rbenv-shim + rubygems-stub copies + a RUBYOPT prelude; hot = a real `Ready::Sandbox` server plus a stub generated from `Ready::Executable#render` with marks injected. Marks are `CLOCK_REALTIME`/`$EPOCHREALTIME` lines in a shared file; pure parsing/aggregation is unit-tested, the arms are `:e2e`. Reuses `Ready::{Sandbox,PtyShell,Executable,Bench::{Marks,Stats,Report}}`.

**Tech Stack:** Ruby 3.4.7+/4.0.1, RSpec, zsh 5.9 (`zmodload zsh/datetime`), rbenv, `by`/`by-server`, `CLOCK_REALTIME`.

## Global Constraints

- **Design ref:** `docs/superpowers/specs/2026-07-12-phase-c-layer-benchmark-design.md` (layer table, marks, numbers). Read it.
- **Zero production-runtime edits.** All instrumentation is generated copies in temp dirs. Do NOT modify `lib/ready/fn.zsh.erb`, `lib/ready/executable.rb`, or any real gem/rbenv file.
- **Zeitwerk under `Ready`.** New classes live in `spec/support/bench/` → `Ready::Bench::*` (autoloaded by the spec/support loader). Committed fixtures go in `bench/`.
- **Clock:** `$EPOCHREALTIME` (zsh, after `zmodload zsh/datetime`) == `Process.clock_gettime(Process::CLOCK_REALTIME)` (Ruby). One shared append-only markfile; lines `"<name> <float>"`.
- **Aggregation policy:** min/floor for process-creation spans (`shell`, `rbenv_shim`, `dispatch_infra`, full envelope), median for in-process spans. ≥15 warm runs; discard warmups (first run inflates ~2×).
- **Isolation:** temp dirs only; unset `GEM_HOME`/`GEM_PATH` when the dir is missing (as `Ready::Sandbox#build_env` does); mandatory teardown (by-server stop + kill by argv + `rm -rf`); assert zero `by-server` + zero temp dirs after.
- **House style / rubocop:** library files (`spec/support/bench/*`) rubocop-clean; specs match existing conventions. Bench classes need no `##` rdoc (spec/** excluded) but add short ones.
- **Target:** `irb` (default rep) via `gems: [irb]` preload; `rake` fallback. Not coupled to any tool.

---

## Task 1: Ready layer span model + aggregation

**Files:**
- Modify: `spec/support/bench/marks.rb` (replace `SPANS` with the ready layer model; keep `parse`/`spans`)
- Create: `spec/support/bench/aggregator.rb` → `Ready::Bench::Aggregator`
- Modify/Test: `spec/bench/marks_spec.rb`; Create `spec/bench/aggregator_spec.rb`

**Interfaces:**
- Produces: `Ready::Bench::Marks::SPANS` (Array of `[label, from, to]` for the ready layers); `Ready::Bench::Marks.parse(path)`, `.spans(marks)` (unchanged signatures).
- Produces: `Ready::Bench::Aggregator.new(span_kind:)` where `span_kind` is a `Hash{label => :min|:median}`; `#combine(list_of_span_hashes) -> {label => ms}` applying min or median per label.

- [ ] **Step 1: Update the marks_spec fixture + expectations to the ready spans** — `spec/bench/marks_spec.rb`: change the fixture log and assertions to the ready layer marks.

```ruby
require "tempfile"

RSpec.describe Ready::Bench::Marks do
  def fixture(contents)
    file = Tempfile.new("marks")
    file.write(contents)
    file.close
    file.path
  end

  let(:cold) do
    fixture(<<~LOG)
      cold.1 envelope_start 1000.000
      cold.1 shim_start 1000.001
      cold.1 ruby_up 1000.050
      cold.1 rubygems_ready 1000.100
      cold.1 dep_activated 1000.140
      cold.1 ruby_exit 1000.243
      cold.1 envelope_end 1000.244
    LOG
  end

  it "parses a run into a mark=>time map" do
    expect(described_class.parse(cold)["cold.1"]["dep_activated"]).to eq(1000.140)
  end

  it "computes ready layer spans in ms" do
    spans = described_class.spans(described_class.parse(cold)["cold.1"])
    aggregate_failures do
      expect(spans["rbenv_shim"]).to be_within(1e-6).of(49.0)   # shim_start->ruby_up
      expect(spans["rubygems"]).to be_within(1e-6).of(50.0)     # ruby_up->rubygems_ready
      expect(spans["dep_activate"]).to be_within(1e-6).of(40.0) # rubygems_ready->dep_activated
      expect(spans["tool_run"]).to be_within(1e-6).of(103.0)    # dep_activated->ruby_exit
      expect(spans["full"]).to be_within(1e-6).of(244.0)        # envelope_start->envelope_end
    end
  end

  it "omits spans whose endpoints are missing (hot arm has no shim)" do
    hot = { "envelope_start" => 1.0, "server_entry" => 1.053, "envelope_end" => 1.072 }
    spans = described_class.spans(hot)
    aggregate_failures do
      expect(spans).not_to have_key("rbenv_shim")
      expect(spans["dispatch_infra"]).to be_within(1e-6).of(53.0)
      expect(spans["full"]).to be_within(1e-6).of(72.0)
    end
  end
end
```

- [ ] **Step 2: Run → fail** — `bundle exec rspec spec/bench/marks_spec.rb` (fails: old SPANS lack these labels).

- [ ] **Step 3: Replace `SPANS`** — `spec/support/bench/marks.rb`, swap the `SPANS` constant (keep `parse`/`spans` bodies):

```ruby
      SPANS = [
        ["shell", "envelope_start", "shim_start"],
        ["rbenv_shim", "shim_start", "ruby_up"],
        ["rubygems", "ruby_up", "rubygems_ready"],
        ["dep_activate", "rubygems_ready", "dep_activated"],
        ["tool_run", "dep_activated", "ruby_exit"],
        ["reap", "ruby_exit", "envelope_end"],
        ["dispatch_infra", "envelope_start", "server_entry"],
        ["server_tool_run", "server_entry", "envelope_end"],
        ["full", "envelope_start", "envelope_end"],
      ].freeze
```

Remove the `preamble` `from ||= ...` fallback line in `.spans` (no longer needed) so `.spans` is just the `each_with_object` over present endpoints.

- [ ] **Step 4: Run → pass** — `bundle exec rspec spec/bench/marks_spec.rb` → 3 pass.

- [ ] **Step 5: Aggregator test** — `spec/bench/aggregator_spec.rb`:

```ruby
RSpec.describe Ready::Bench::Aggregator do
  subject(:agg) { described_class.new(span_kind: { "shell" => :min, "tool_run" => :median }) }

  it "takes the min for process spans and median for in-process spans" do
    runs = [
      { "shell" => 3.0, "tool_run" => 100.0 },
      { "shell" => 1.0, "tool_run" => 110.0 },
      { "shell" => 2.0, "tool_run" => 120.0 },
    ]
    result = agg.combine(runs)
    aggregate_failures do
      expect(result["shell"]).to eq(1.0)
      expect(result["tool_run"]).to eq(110.0)
    end
  end

  it "defaults an unlisted span to median" do
    expect(described_class.new(span_kind: {}).combine([{ "x" => 4.0 }, { "x" => 2.0 }])["x"]).to eq(3.0)
  end
end
```

- [ ] **Step 6: Run → fail** — `bundle exec rspec spec/bench/aggregator_spec.rb`.

- [ ] **Step 7: Implement Aggregator** — `spec/support/bench/aggregator.rb`:

```ruby
module Ready
  module Bench
    ##
    # Collapses many per-run span hashes into one, applying min to
    # process-creation spans (jittery, floor is the structural number) and
    # median to in-process spans.
    class Aggregator
      def initialize(span_kind:)
        @span_kind = span_kind
      end

      def combine(runs)
        labels = runs.flat_map(&:keys).uniq
        labels.each_with_object({}) do |label, out|
          values = runs.filter_map { |r| r[label] }
          next if values.empty?

          out[label] = @span_kind[label] == :min ? values.min : Stats.median(values)
        end
      end
    end
  end
end
```

- [ ] **Step 8: Run → pass; lint; commit**

```bash
bundle exec rspec spec/bench/marks_spec.rb spec/bench/aggregator_spec.rb
bundle exec rubocop spec/support/bench/marks.rb spec/support/bench/aggregator.rb
git add spec/support/bench/marks.rb spec/support/bench/aggregator.rb spec/bench/marks_spec.rb spec/bench/aggregator_spec.rb
git commit -m "bench: ready layer span model + min/median aggregator"
```

---

## Task 2: Committed instrumentation fixtures (prelude + prof.zsh)

**Files:**
- Create: `bench/prelude.rb`, `bench/prof.zsh`
- Test: exercised by the `:e2e` arms (Tasks 3–4); a lightweight loadability check here.

**Interfaces:**
- Produces: `bench/prelude.rb` — a RUBYOPT `-r` target that appends `ruby_up <CLOCK_REALTIME>` to `$READY_MARKS`.
- Produces: `bench/prof.zsh` — defines `bench_mark <name>` (held-fd append to `$READY_MARKS`) and `bench_envelope <run_id> -- <cmd...>` (bare-read `envelope_start`, run cmd, `envelope_end`).

- [ ] **Step 1: Write `bench/prelude.rb`** (single statement; runs as the first Ruby user code):

```ruby
# Emitted as the first Ruby user code via RUBYOPT=-r; marks interpreter-up.
File.write(ENV.fetch("READY_MARKS"), "#{ENV.fetch('READY_RUN_ID')} ruby_up #{Process.clock_gettime(Process::CLOCK_REALTIME)}\n", mode: "a")
```

- [ ] **Step 2: Write `bench/prof.zsh`**:

```zsh
# Benchmark envelope + mark helpers. Source in a controlled `zsh -f` shell.
zmodload zsh/datetime

# Append "<run_id> <name> <epoch>" to $READY_MARKS using a held fd (fast).
bench_mark() { print -r -- "${READY_RUN_ID} $1 ${EPOCHREALTIME}" >> $READY_MARKS }

# bench_envelope <run_id> -- <cmd...>
# Bare-read envelope_start (deferred write), run cmd, read envelope_end first.
bench_envelope() {
  local rid=$1; shift; [[ $1 == -- ]] && shift
  export READY_RUN_ID=$rid
  local __start=${EPOCHREALTIME}
  "$@"
  local __end=${EPOCHREALTIME}
  print -r -- "${rid} envelope_start ${__start}" >> $READY_MARKS
  print -r -- "${rid} envelope_end ${__end}" >> $READY_MARKS
}
```

- [ ] **Step 3: Smoke-check the fixtures load** — run:

```bash
cd /workspaces/ready2
zsh -f -c 'source bench/prof.zsh; READY_RUN_ID=t READY_MARKS=/tmp/m.$$ bench_mark hi; cat /tmp/m.$$; rm -f /tmp/m.$$'
ruby -e 'ENV["READY_MARKS"]="/tmp/p.#{Process.pid}"; ENV["READY_RUN_ID"]="t"; load "bench/prelude.rb"; puts File.read(ENV["READY_MARKS"]); File.delete(ENV["READY_MARKS"])'
```
Expected: `t hi <float>` and `t ruby_up <float>`.

- [ ] **Step 4: Commit**

```bash
git add bench/prelude.rb bench/prof.zsh
git commit -m "bench: RUBYOPT ruby_up prelude + prof.zsh envelope/mark helpers"
```

---

## Task 3: Cold arm — instrumented shim + stub copies

**Files:**
- Create: `spec/support/bench/cold_arm.rb` → `Ready::Bench::ColdArm`
- Test: `spec/bench/cold_arm_spec.rb` (copy-generation, fast), plus `:e2e` run in Task 6.

**Interfaces:**
- Consumes: `bench/prelude.rb`, `Ready.root`.
- Produces: `Ready::Bench::ColdArm.new(exe:, workdir:, marks_path:)`; `#instrument!` writes an instrumented shim copy (`workdir/<exe>`), a direct-shim copy (`workdir/<exe>_direct`), and an instrumented stub copy into `workdir`, returning nothing; `#command(run_id:, direct: false) -> Array` the argv to run the arm under a shell that has `READY_MARKS`/`READY_RUN_ID`/`RUBYOPT`/`PATH` set; `#real_shim -> Pathname` (`~/.rbenv/shims/<exe>`), `#real_stub -> Pathname` (`rbenv which <exe>`).
- The instrumented stub inserts marks by string-matching the standard rubygems stub lines (`require 'rubygems'`, `Gem.use_gemdeps`, the `Gem.activate_and_load_bin_path`/`load Gem.activate_bin_path` line) — the same shape verified across `irb`/`rake`/`rdoc`/`erb`.

- [ ] **Step 1: Copy-generation test** — `spec/bench/cold_arm_spec.rb` (uses a synthetic stub so it's hermetic/fast):

```ruby
require "tmpdir"

RSpec.describe Ready::Bench::ColdArm do
  it "injects marks into a rubygems-stub copy at the standard boundaries" do
    Dir.mktmpdir do |dir|
      stub = File.join(dir, "src_stub")
      File.write(stub, <<~RUBY)
        #!/usr/bin/ruby
        require 'rubygems'
        Gem.use_gemdeps
        version = ">= 0.a"
        Gem.activate_and_load_bin_path('irb', 'irb', version)
      RUBY
      out = described_class.instrument_stub(File.read(stub), name: "irb")
      aggregate_failures do
        expect(out).to match(/at_exit\b.*ruby_exit/m)
        expect(out).to match(/Gem\.use_gemdeps\n.*rubygems_ready/m)
        expect(out).to match(/dep_activated.*\n\s*Gem\.activate_and_load_bin_path/m)
      end
    end
  end
end
```

- [ ] **Step 2: Run → fail.** `bundle exec rspec spec/bench/cold_arm_spec.rb`.

- [ ] **Step 3: Implement `ColdArm`** — `spec/support/bench/cold_arm.rb`. Core `instrument_stub` (pure, tested) + the copy/command plumbing:

```ruby
require "fileutils"

module Ready
  module Bench
    ##
    # Generates faithful, mark-instrumented COPIES of the real rbenv shim and
    # rubygems stub for a gem executable, so a cold invocation can be attributed
    # per layer without touching any real file.
    class ColdArm
      MARK = %(__m=->(n){File.write(ENV.fetch("READY_MARKS"),"#{ENV.fetch('READY_RUN_ID')} \#{n} #{'#{Process.clock_gettime(Process::CLOCK_REALTIME)}'}\\n",mode:"a")})

      def self.instrument_stub(src, name:)
        helper = %(at_exit{File.write(ENV.fetch("READY_MARKS"),"\#{ENV.fetch('READY_RUN_ID')} ruby_exit \#{Process.clock_gettime(Process::CLOCK_REALTIME)}\\n",mode:"a")}\n) +
                 %(def __bmark(n);File.write(ENV.fetch("READY_MARKS"),"\#{ENV.fetch('READY_RUN_ID')} \#{n} \#{Process.clock_gettime(Process::CLOCK_REALTIME)}\\n",mode:"a");end\n)
        out = src.sub(/\A(#!.*\n)?/) { "#{Regexp.last_match(1)}#{helper}" }
        out = out.sub(/(Gem\.use_gemdeps\s*\n)/) { "#{Regexp.last_match(1)}__bmark('rubygems_ready')\n" }
        out.sub(/^(\s*)(load Gem\.activate_bin_path|Gem\.activate_and_load_bin_path)/) do
          "#{Regexp.last_match(1)}__bmark('dep_activated')\n#{Regexp.last_match(1)}#{Regexp.last_match(2)}"
        end
      end

      def initialize(exe:, workdir:, marks_path:)
        @exe = exe
        @workdir = Pathname(workdir)
        @marks_path = marks_path
      end

      def real_shim = Pathname(File.expand_path("~/.rbenv/shims/#{@exe}"))
      def real_stub = Pathname(`rbenv which #{@exe}`.strip)

      def instrument!
        FileUtils.mkdir_p(@workdir)
        write_shim(@workdir / @exe, rbenv: true)
        write_shim(@workdir / "#{@exe}_direct", rbenv: false)
        (@workdir / "stub").write(self.class.instrument_stub(real_stub.read, name: @exe))
      end

      # env a shell must export before running #command
      def env(run_id:)
        {
          "READY_MARKS" => @marks_path.to_s,
          "READY_RUN_ID" => run_id,
          "RUBYOPT" => "-r#{Ready.root / 'bench' / 'prelude.rb'}",
          "PATH" => "#{@workdir}:#{ENV['PATH']}",
        }
      end

      private

      def write_shim(path, rbenv:)
        target = rbenv ? "exec rbenv exec \"#{@exe}\" \"$@\"" : "exec ruby \"#{@workdir / 'stub'}\" \"$@\""
        path.write(<<~SH)
          #!/usr/bin/env bash
          set -e
          printf '%s shim_start %s\\n' "$READY_RUN_ID" "$EPOCHREALTIME" >> "$READY_MARKS"
          export RBENV_ROOT="$HOME/.rbenv"
          #{target}
        SH
        path.chmod(0o755)
      end
    end
  end
end
```

Note: the direct variant execs the instrumented `stub` copy under the version ruby (no rbenv) so it works where rbenv is absent (CI reduced cold arm); the rbenv variant runs the real `rbenv exec <exe>` chain, and the RUBYOPT prelude marks `ruby_up` regardless. `PATH` puts `@workdir/<exe>` first so the instrumented shim wins.

- [ ] **Step 4: Run → pass; lint; commit**

```bash
bundle exec rspec spec/bench/cold_arm_spec.rb
bundle exec rubocop spec/support/bench/cold_arm.rb
git add spec/support/bench/cold_arm.rb spec/bench/cold_arm_spec.rb
git commit -m "bench: ColdArm — mark-instrumented rbenv-shim + rubygems-stub copies"
```

---

## Task 4: Hot arm — render-based instrumented stub over a live sandbox

**Files:**
- Create: `spec/support/bench/hot_arm.rb` → `Ready::Bench::HotArm`
- Test: `spec/bench/hot_arm_spec.rb` (stub-generation, fast), `:e2e` run in Task 6.

**Interfaces:**
- Consumes: `Ready::Sandbox`, `Ready::Executable`, `Ready::PtyShell`, `Ready::Bench::ColdArm::…` (none), `bench/prof.zsh`.
- Produces: `Ready::Bench::HotArm.new(exe:, exe_path:, sandbox:, marks_path:)`; `.instrument_source(rendered, name:) -> String` (pure: injects `server_entry` at top + `pre_tool` before the tool's `IRB.start`-style call); `#stub_function(run_id:) -> String` a `ready_<exe>` zsh function whose inlined source carries the marks; `#dispatch(shell:, run_id:)` runs it in a `Ready::PtyShell` and appends to the markfile.
- The sandbox is built with `gems: [<lib>]` (so the server preloads it) — see Task 6 for wiring. `exe_path` is the on-disk gem exe (contains `exe`, so `Ready::Executable.new(exe_path).render` inlines without a resolver change).

- [ ] **Step 1: Source-instrumentation test** — `spec/bench/hot_arm_spec.rb`:

```ruby
RSpec.describe Ready::Bench::HotArm do
  it "prepends a server_entry mark and injects pre_tool before the tool start" do
    rendered = <<~RUBY
      Process.setproctitle "irb"
      require 'irb'
      IRB.start(__FILE__)
    RUBY
    out = described_class.instrument_source(rendered, name: "irb")
    aggregate_failures do
      expect(out).to match(/\At=Process\.clock_gettime.*server_entry/m)
      expect(out).to match(/pre_tool.*\n\s*IRB\.start/m)
    end
  end
end
```

- [ ] **Step 2: Run → fail.** `bundle exec rspec spec/bench/hot_arm_spec.rb`.

- [ ] **Step 3: Implement `HotArm`** — `spec/support/bench/hot_arm.rb`:

```ruby
module Ready
  module Bench
    ##
    # Runs a gem executable through the warm by-server and marks the dispatch
    # infra vs the (preloaded) tool_run, using the REAL Ready::Executable render
    # output with marks injected — no gem-runtime edit.
    class HotArm
      def self.mark(name)
        %(File.open(ENV.fetch("READY_MARKS"),"a"){|f| f.puts "\#{ENV.fetch('READY_RUN_ID')} #{name} \#{Process.clock_gettime(Process::CLOCK_REALTIME)}"})
      end

      def self.instrument_source(rendered, name:)
        out = "t=#{mark('server_entry')}\n#{rendered}"
        out.sub(/^(\s*)([A-Z][\w:]*\.(?:start|run)\b|main\b)/) do
          "#{Regexp.last_match(1)}#{mark('pre_tool')}\n#{Regexp.last_match(1)}#{Regexp.last_match(2)}"
        end
      end

      def initialize(exe:, exe_path:, sandbox:, marks_path:)
        @exe = exe
        @exe_path = exe_path
        @sandbox = sandbox
        @marks_path = marks_path
      end

      # A faithful ready_<exe> zsh function (mirrors fn.zsh.erb) whose inlined
      # source carries the marks. Escaped for `ready_by -e`.
      def stub_function
        source = self.class.instrument_source(Ready::Executable.new(@exe_path.to_s).render, name: @exe)
        <<~ZSH
          ready_#{@exe}() {
            emulate -L zsh
            autoload -Uz ready_by
            BY_SOCKET=#{@sandbox.sock_path} ready_by -e #{Shellwords.escape(source)} "$@"
          }
        ZSH
      end

      # Prepend to the pty shell env so marks land in our file.
      def shell_setup(run_id:)
        "export READY_MARKS=#{@marks_path} READY_RUN_ID=#{run_id}"
      end
    end
  end
end
```

- [ ] **Step 4: Run → pass; lint; commit**

```bash
bundle exec rspec spec/bench/hot_arm_spec.rb
bundle exec rubocop spec/support/bench/hot_arm.rb
git add spec/support/bench/hot_arm.rb spec/bench/hot_arm_spec.rb
git commit -m "bench: HotArm — render-based instrumented stub over the warm server"
```

---

## Task 5: Runner + `rake bench`

**Files:**
- Create: `spec/support/bench/runner.rb` → `Ready::Bench::Runner`
- Modify: `Rakefile` (add `bench` task)
- Test: `:e2e` in Task 6 (the Runner drives real processes).

**Interfaces:**
- Consumes: `Ready::{Sandbox,PtyShell}`, `Ready::Bench::{ColdArm,HotArm,Marks,Aggregator,Report}`.
- Produces: `Ready::Bench::Runner.new(exe: "irb", lib: "irb", runs: 15, warmups: 3)`; `#call -> Ready::Bench::Report` after building the sandbox, interleaving arms, aggregating; `#render` prints it; `#teardown`.

- [ ] **Step 1: Implement `Runner`** — `spec/support/bench/runner.rb`. It: (a) builds `Ready::Sandbox` with a readyfile carrying `gems: [lib]` + `executables: [rake]` (rake gives a compilable name so `ready up` builds the server; the target is dispatched via HotArm's own stub); (b) resolves the target's on-disk gem exe via `Gem::Specification.find_by_name(lib).bin_file(exe)` inside `Bundler.with_unbundled_env`; (c) instruments ColdArm; (d) for each run id, runs cold (direct + rbenv when available) and hot in interleaved order, collecting per-run spans via `Marks`; (e) aggregates with `Aggregator` (min for `shell`/`rbenv_shim`/`dispatch_infra`/`full`, median else); (f) returns a `Report`.

```ruby
require "bundler"

module Ready
  module Bench
    ##
    # Orchestrates the interleaved cold/hot benchmark and builds a Report.
    class Runner
      PROCESS_SPANS = %w[shell rbenv_shim dispatch_infra full].freeze

      def initialize(exe: "irb", lib: "irb", runs: 15, warmups: 3, rbenv: nil)
        @exe = exe
        @lib = lib
        @runs = runs
        @warmups = warmups
        @rbenv = rbenv.nil? ? system("command -v rbenv >/dev/null 2>&1") : rbenv
      end

      def call
        build
        (1..(@runs + @warmups)).each { |i| one_round(i) }
        cold = @cold_runs.drop(@warmups)
        hot = @hot_runs.drop(@warmups)
        agg = Aggregator.new(span_kind: PROCESS_SPANS.to_h { |s| [s, :min] })
        Report.new({ "cold" => [agg.combine(cold)], "hot" => [agg.combine(hot)] },
                   { "cold" => cold.map { |s| s["full"] / 1000.0 }, "hot" => hot.map { |s| s["full"] / 1000.0 } })
      ensure
        teardown
      end

      def teardown
        @sandbox&.teardown
        FileUtils.rm_f(@marks) if @marks
      end

      private

      def build
        @marks = Pathname(Dir.mktmpdir("bench")) / "marks"
        @marks.write("")
        @sandbox = Ready::Sandbox.build(executables: ["rake"], gems: [@lib])
        @exe_path = Bundler.with_unbundled_env { Gem::Specification.find_by_name(@lib).bin_file(@exe) }
        @cold = ColdArm.new(exe: @exe, workdir: @marks.dirname / "cold", marks_path: @marks)
        @cold.instrument!
        @hot = HotArm.new(exe: @exe, exe_path: Pathname(@exe_path), sandbox: @sandbox, marks_path: @marks)
        @cold_runs = []
        @hot_runs = []
      end

      def one_round(i)
        order = i.even? ? %i[cold hot] : %i[hot cold]
        order.each { |arm| run_arm(arm, "#{arm}.#{i}") }
      end

      def run_arm(arm, run_id)
        before = @marks.read.lines.size
        arm == :cold ? run_cold(run_id) : run_hot(run_id)
        marks = Marks.parse(@marks.to_s)[run_id] || {}
        (arm == :cold ? @cold_runs : @hot_runs) << Marks.spans(marks)
      end

      def run_cold(run_id)
        shell = Ready::PtyShell.new(@cold.env(run_id:))
        shell.run("source #{Ready.root / 'bench' / 'prof.zsh'}")
        cmd = @rbenv ? @exe : "#{@exe}_direct"
        shell.run("bench_envelope #{run_id} -- #{cmd} --version >/dev/null 2>&1")
      ensure
        shell&.close
      end

      def run_hot(run_id)
        shell = Ready::PtyShell.new(@sandbox.shell_env)
        shell.run("source #{@sandbox.plugin_path}")
        shell.run("source #{Ready.root / 'bench' / 'prof.zsh'}")
        shell.run(@hot.shell_setup(run_id:))
        shell.run(@hot.stub_function.gsub("\n", "; "))
        shell.run("bench_envelope #{run_id} -- ready_#{@exe} --version >/dev/null 2>&1")
      ensure
        shell&.close
      end
    end
  end
end
```

- [ ] **Step 2: Add `gems:` support to `Ready::Sandbox`** — `spec/support/sandbox.rb`: `self.build(executables:, gems: [])`, `initialize(executables:, gems: [])`, and `write_readyfile` emits a `gems:` block when non-empty. (Needed so the server preloads the target lib.)

```ruby
    def self.build(executables:, gems: [])
      new(executables:, gems:).tap(&:up)
    end

    def initialize(executables:, gems: [])
      @executables = executables
      @gems = gems
      # ... unchanged temp-dir setup ...
    end

    def write_readyfile
      lines = []
      lines += ["gems:", *@gems.map { |g| "  - #{g}" }] unless @gems.empty?
      lines += ["executables:", *@executables.map { |e| "  - #{e}" }]
      readyfile.write("#{lines.join("\n")}\n")
    end
```

- [ ] **Step 3: Add the `bench` rake task** — `Rakefile`:

```ruby
desc "Print the cold-vs-hot startup waterfall (needs zsh + rbenv + by-server)"
task :bench do
  require_relative "spec/support/pty_shell"
  require_relative "spec/support/sandbox"
  Dir[File.expand_path("spec/support/bench/*.rb", __dir__)].sort.each { |f| require f }
  require "ready"
  Ready::Bench::Runner.new(exe: ENV.fetch("BENCH_EXE", "irb"), lib: ENV.fetch("BENCH_LIB", "irb")).call.render
end
```

- [ ] **Step 4: Run it and observe the waterfall** — `bundle exec rake bench 2>&1 | tail -20`. Expected: a printed waterfall with cold ≫ hot on `rbenv_shim`/`rubygems`/`dep_activate`, hot `dispatch_infra` populated. Iterate on mark-parsing until every canonical span is present for at least the median run. Confirm teardown (no `by-server`, no temp dirs).

- [ ] **Step 5: Lint; commit**

```bash
bundle exec rubocop spec/support/bench/runner.rb spec/support/sandbox.rb
git add spec/support/bench/runner.rb spec/support/sandbox.rb Rakefile
git commit -m "bench: Runner + rake bench (interleaved cold/hot waterfall)"
```

---

## Task 6: `:e2e` structural guard

**Files:**
- Create: `spec/e2e/benchmark_spec.rb`

**Interfaces:**
- Consumes: `Ready::Bench::Runner`.

- [ ] **Step 1: Write the guard** — `spec/e2e/benchmark_spec.rb` (reduced cold arm via `rbenv: false` so it needs no rbenv; structural asserts, no tight timing):

```ruby
RSpec.describe "ready startup benchmark", :e2e do
  it "shows the hot arm eliminating the rubygems + dep_activate layers and beating cold" do
    report = Ready::Bench::Runner.new(exe: "irb", lib: "irb", runs: 5, warmups: 2, rbenv: false).call
    cold = report.instance_variable_get(:@runs)["cold"].first
    hot = report.instance_variable_get(:@runs)["hot"].first
    aggregate_failures do
      expect(cold["rubygems"]).to be > 5.0          # cold pays rubygems boot
      expect(cold["dep_activate"]).to be > 5.0       # ...and gem activation
      expect(hot["full"]).to be < cold["full"]       # hot is faster, wide margin
      expect(hot).not_to have_key("rbenv_shim")      # reduced cold arm / hot has none
    end
  end
end
```

- [ ] **Step 2: Run → pass** — `READY_E2E=1 bundle exec rspec spec/e2e/benchmark_spec.rb 2>&1 | tail`. Expected: 1 example passes; no orphaned `by-server` after.

- [ ] **Step 3: Full e2e + orphan check** — `bundle exec rake spec:e2e` (now 5 examples incl. benchmark); `pgrep -af by-server | grep -v grep || echo clean`.

- [ ] **Step 4: Lint; commit; push; update PR #2**

```bash
bundle exec rubocop spec/e2e/benchmark_spec.rb
git add spec/e2e/benchmark_spec.rb
git commit -m "test: e2e — benchmark structural guard (hot eliminates rubygems/dep layers)"
git push
```

---

## Verification (end-to-end)
1. Fast loop: `bundle exec rake spec` → Phase B + new bench unit specs pass; no e2e; rubocop clean on `spec/support/bench/*`.
2. `bundle exec rake bench` → prints a waterfall; cold ≫ hot on the boot layers; teardown leaves zero `by-server`/temp dirs.
3. `bundle exec rake spec:e2e` → dispatch + benchmark guards pass.
4. Zero production-runtime files changed: `git diff --stat <base>..HEAD -- lib/ zsh/` is empty except none.

## Self-review notes
- **Spec coverage:** layer span model → T1; fixtures → T2; cold instrumentation → T3; hot render-based marks → T4; interleave/aggregate/report + `rake bench` → T5; `:e2e` guard + CI (reduced cold arm) → T6. Preload cliff → sandbox `gems:` in T5. Zero-runtime-edit constraint → all copies, verified in Verification step 4.
- **Types:** `Marks::SPANS`/`.spans`, `Aggregator#combine`, `ColdArm.instrument_stub`/`#env`, `HotArm.instrument_source`/`#stub_function`/`#shell_setup`, `Runner#call -> Report`, `Sandbox.build(executables:, gems:)` are used consistently across tasks.
- **Empirical note:** the process-spawning tasks (T3–T6) need on-machine iteration to get every mark parsed on the noisy container (mark-regex robustness, run counts); the `rake bench` step (T5.4) is the iteration point. This is expected for a measurement harness and is not a placeholder.
