# Phase C — Layered Cold-vs-Hot Startup Benchmark (design)

**Date:** 2026-07-12 · Branch: `e2e-rspec` (extends the Phase A/B harness)

## Context & goal

`ready` eliminates the fixed boot tax a Ruby CLI pays on every invocation. This benchmark **attributes where that time goes, per layer**, and shows how much each layer collapses when the command is served hot by the persistent `by-server`. It is the running artifact behind the RubyConf talk's `ri TCPServer` breakdown (`notes.md`), generalized: the launch layers are **identical for every rubygems CLI**, so the benchmark measures them with a representative executable and is **not coupled to any specific tool**.

Grounded in a measured investigation (6 agents, `irb` on this container, `CLOCK_REALTIME` on both shell and Ruby sides). Absolute ms are environment-specific (this box runs ~4× the quiet floor); **the layer structure and the collapse ratios are the transferable finding.**

## The layer model

An invocation of a rubygems-installed CLI (`irb`, `ri`, `rubocop`, `rake`, …) pays these layers. `ready`'s value = the middle rows collapse to ~0 because the server paid them once.

| span | boundary (from → to) | arm | cold ms (irb, floor) | hot ms | note |
|---|---|---|--:|--:|---|
| `shell` | `envelope_start` → `shim_start`/`stub_enter` | both | ~1.1 | 0.018 | hot: in-process alias→function, no PATH walk / exec |
| `rbenv_shim` | `shim_start` → `ruby_up` (minus ruby_boot) | cold | ~47 (→150+ long PATH) | ~0 | ~11 rbenv-* bash spawns; skipped hot |
| `ruby_boot` | interpreter init (via `--disable-gems` baseline) | cold | ~15 | ~0 | server pre-booted |
| `rubygems` | `ruby_up` → `rubygems_ready` (+ pre-`ruby_up` autoload) | cold | ~50 | ~0 | client runs `--disable-gems`; server warm |
| `dep_activate` | `dep_activated` → `ruby_exit` (combined) or → `tool_entry` (deep) | cold | ~32–43 | ~0 | `Gem.activate_bin_path`; skipped hot (source is `eval`'d) |
| `tool_run` | `tool_entry`/`dep_activated` → `ruby_exit` | both | ~103 (`require` ~85 + `IRB.start` ~18) | 0.23 + ~18 | the `require` collapses (warm CoW) **iff preloaded** |
| `reap` | `ruby_exit` → `envelope_end` | both | ~0.29 | ~0.29 | **retained** — a process still exits, shell still `wait()`s |
| `dispatch_infra` | `envelope_start` → `server_entry` | hot | — | ~53 | **new hot cost**: `by` client Ruby boot (~44) + socket + fork + worker |
| **full envelope** | `envelope_start` → `envelope_end` | both | ~240–520 | ~72 | **≈7×** |

**Headline findings (talk beats):**
- ~183ms of the ~192ms in-process cold boot is tax the server pays once (`rbenv_shim`+`ruby_boot`+`rubygems`+`dep_activate`+`require`).
- The **hot residual is dominated (~44 of 72ms) by the `by` client being a full Ruby boot**, spawned only to hand FDs over the socket — a C/socket client shim could cut hot dispatch from ~53ms toward ~10ms. (Future `ready` optimization; call it out, don't build it here.)
- Validates the talk's numbers: rubygems layer ≈ 82ms = autoload 50 + `activate_bin_path` 32; rbenv ≈ 47ms floor, PATH-length-sensitive up to ~150ms.

### Canonical marks (default mode)
`envelope_start` · `shim_start`(cold)/`stub_enter`(hot) · `ruby_up`(cold) · `rubygems_ready`(cold) · `dep_activated`(cold) · `server_entry`(hot) · `ruby_exit`(both, **`at_exit`**) · `envelope_end`.
Deep mode (opt-in): `bin_path_resolved`, `tool_entry` (TracePoint on `Gem.bin_path(name,name)`), `pre_tool`(hot) to split activation vs tool code.

## Measurement technique — **zero production-runtime changes**

Both arms are instrumented with **faithful copies**, never real system/gem files. Fidelity validated once by comparing an *uninstrumented* copy's wall time to the real thing (192.58 vs 192.36ms).

- **Cold arm** (`Ready::Bench::ColdArm`): generate, in a temp dir, (a) a byte-identical copy of `~/.rbenv/shims/<exe>` (named `<exe>` so `program=<exe>`) that emits `shim_start` (line 1) and injects `RUBYOPT="-r<prelude> $RUBYOPT"` before `exec rbenv exec`; (b) a copy of `$(rbenv which <exe>)` (the rubygems stub) that marks `rubygems_ready` after `require 'rubygems'; Gem.use_gemdeps`, `dep_activated` before `Gem.activate_and_load_bin_path`, and registers an `at_exit` `ruby_exit` **first** (CLIs call `exit`; control never returns). Also generate an `<exe>_direct` shim variant that skips rbenv (`exec $V/bin/<exe>`) so the `rbenv_shim` span is derivable by subtraction **and** so CI can run a reduced cold arm without rbenv.
- **RUBYOPT prelude** (`bench/prelude.rb`, committed): one statement appending `ruby_up <CLOCK_REALTIME>` to `$READY_MARKS`. As `-r` it is the first user code (after interp+rubygems autoload) — so it cannot bracket the autoload from inside; that ~50ms is captured via the external `--disable-gems` baseline delta.
- **Hot arm** (`Ready::Bench::HotArm`): stand up a real `Ready::Sandbox` whose readyfile **preloads the target's library** (`gems: [irb]`) so forks inherit it warm; obtain the *real* inlined stub source via `Ready::Executable.new(<target's on-disk gem exe path>).render` — passing the on-disk exe path (which contains `exe`) hits `Executable`'s direct-path branch, so a default-but-unbundled gem like `irb` inlines faithfully **without any resolver change** (bare `Executable.new("irb")` would fail under bundler via `Gem.bin_path`). Inject `server_entry` (first eval'd statement) + optional `pre_tool` marks into that copy, wrapped in a faithful `ready_<exe>` function; drive it and read the markfile. Uses a **flushed markfile** (clock read first, then `File.open('a')`), never stderr (CLI `--version` exit drops buffered stderr).
- **Envelope** (`bench/prof.zsh`, committed): `zmodload zsh/datetime`; `envelope_start` is a **bare** `$EPOCHREALTIME` read with its log line deferred until after the command returns (mark-write is ~48µs and would swamp sub-ms spans); a held-open-fd helper writes the rest; `envelope_end` read first-thing on return.
- **Clock**: `$EPOCHREALTIME` (zsh) == `Process.clock_gettime(CLOCK_REALTIME)` (Ruby), verified same-domain. Pin/quiesce NTP during a run.

## Deliverables

1. **`rake bench`** — builds the sandbox once, runs interleaved hot/cold (alternating order to cancel drift), aggregates and prints the waterfall via the existing `Ready::Bench::Report`. Reports *this machine's* numbers.
2. **`spec/e2e/benchmark_spec.rb`** (`:e2e`) — a structural regression guard: asserts the hot arm eliminates `rbenv_shim`+`rubygems`+`dep_activate` (each ~0 ± small) and `hot_envelope ≪ cold_envelope`. Won't flake (≈7× with wide margin). Uses the **reduced cold arm** (no rbenv) so it runs in the existing e2e CI job.

Reuses Phase A/B: `Ready::Sandbox`, `Ready::PtyShell`, `Ready::Executable`, `Ready::Bench::{Marks,Stats,Report}`.

## File structure (all additive)

- `bench/prof.zsh` (create) — zsh envelope wrapper + mark helper.
- `bench/prelude.rb` (create) — RUBYOPT `ruby_up` prelude.
- `spec/support/bench/cold_arm.rb` (create) — `Ready::Bench::ColdArm`: generate instrumented shim/stub copies, run, return marks; `direct:` variant.
- `spec/support/bench/hot_arm.rb` (create) — `Ready::Bench::HotArm`: sandbox + render-based instrumented stub, run, return marks.
- `spec/support/bench/runner.rb` (create) — `Ready::Bench::Runner`: warmups + interleaved runs + aggregation (min for process-creation spans, median for in-process), returns `{runs_by_arm, pty_walls}` for `Report`.
- `spec/support/bench/marks.rb` (modify) — update `SPANS` to the ready layer model (keep `parse`/`spans` generic); update `spec/bench/marks_spec.rb`.
- `spec/e2e/benchmark_spec.rb` (create) — the `:e2e` guard.
- `spec/bench/{cold_arm,hot_arm,runner}_spec.rb` (create) — unit-ish specs for the pure logic (mark parsing/aggregation) using fixture marks; the process-spawning paths are exercised by the `:e2e` benchmark.
- `Rakefile` (modify) — `rake bench` task.

## Decisions (chosen)

1. **Target = `irb`** via the `gems:`-preload path (best collapse story; the talk's spirit). `rake` is the bundle-native fallback if a machine can't preload irb.
2. **CI** = the `:e2e` guard runs the **reduced cold arm** (`irb_direct`, no rbenv) so it works in the existing zsh-enabled e2e job; the full `rbenv_shim` span is a local-only addendum that `rake bench` exercises when `rbenv` is present.
3. **Numbers** = the benchmark reports the running machine's measurements each time; the spec/README quote floor numbers with an explicit "environment-specific; structure & ratios are the finding" caveat.

## Risks & mitigations

- **Flakiness** (overlayfs + shared VM → 5–6× swings): report **min/floor for process-creation spans**, **median for in-process spans**; ≥15 warm runs (ideally ≥41), discard warmups (first run inflates `tool_run` ~2×).
- **PATH length multiplier**: each rbenv script PATH-walks for `bash`; pin & record `PATH` in the report.
- **Stale `GEM_HOME`/`GEM_PATH`** (removed rvm): unset when its dir is missing (both arms), as `Ready::Sandbox` already does.
- **Preload cliff (correctness trap)**: `require` is warm only because the readyfile lists the lib under `gems:`. The benchmark **must assert the target is preloaded** or it silently measures a non-preloaded (full-cold-per-call) path.
- **`ruby_exit` must be `at_exit`** (registered first); `at_exit` undershoots true process death by ~2.7ms VM teardown that folds into `reap` — the report states which boundary it uses.
- **Isolation/cleanup**: sandbox + all copies in temp dirs; mandatory teardown (by-server stop + kill by argv + `rm -rf`); assert zero `by-server` and zero temp dirs remain.
- **CI portability**: cold arm needs zsh + Ruby; hot needs by-server + zsh (all in the e2e job). rbenv-dependent full cold arm is gated behind an `rbenv` availability probe and skipped otherwise.

## Out of scope
A non-Ruby `by` client (the ~44ms residual lever) — noted as a finding/future optimization, not built here.
