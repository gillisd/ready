# `ready`: cold vs. warm startup across Ruby CLIs

Benchmark of 8 non-interactive Ruby CLIs, each run **cold** (a fresh Ruby boot
per invocation, through an instrumented copy of its real rubygems stub) versus
**ready** (a zsh function stub dispatching to a warm, persistent `by-server`).
Each CLI's readyfile preloads that CLI's own library so the warm server is
actually warm.

Every number here is **verified**: the harness tees each run's stdout+stderr to
`log/bench.log` and aborts the whole benchmark if any run exits non-zero or
records no exit status. A CLI that fails silently (see [exclusions](#what-ready-cant-run-honest-exclusions))
can no longer masquerade as a fast "success."

## TL;DR

- Warm dispatch has a **flat ~26–46 ms floor** regardless of how heavy the cold
  tool is (rdoc cold 404 ms → warm 29 ms; ronin cold 503 ms → warm 46 ms). The
  exception is a tool that does heavy *per-invocation* work (rubocop, ~406 ms
  warm) — that work isn't startup, so `ready` can't remove it.
- Speedups run **3.0×–16.1×**; the biggest *absolute* win is `rubocop`
  (~1.0 s saved per invocation).
- The cold breakdown: a shared **~10 ms VM boot** (both cold *and* ready pay it —
  ready's `by` client boots a VM too), a **~40 ms rubygems load** on top of it
  (cold only), a **dependency-resolution cost that scales with graph size**
  (`activate deps`: 29 ms racc → **351 ms ronin**), and **the tool's own code
  load** (5 ms erb → 1281 ms rubocop). `ready` keeps the boot and eliminates
  everything above it.

## How it's measured

| | |
|---|---|
| Host | GitHub Codespace, Linux x86_64 (shared runner) |
| Ruby | 4.0.1 (+PRISM), via rbenv |
| Tool | `bin/bench` (this repo), 5 measured rounds + 1 warmup, order-alternating |
| Statistic | **floor (minimum across rounds)** — the structural cost; medians run ~10–30% higher |
| Workload | `--version` (isolates startup) — except `ri TCPServer`, a real doc lookup, because `ri --version` short-circuits before loading the doc store |
| Preload | each CLI's readyfile preloads its own library (see [reproduce](#reproduce)) |
| Verification | each run must exit 0 with output, or the benchmark aborts |

> **On "cold".** These are the directly-measured **in-shell** cold full (boot +
> rubygems + dependency activation + the tool), pty-cross-checked to within
> ~50 ms. The rbenv shim is reported [separately](#the-rbenv-shim-reported-separately)
> because this box's rbenv is pathologically slow and noisy.

## Speedup (in-shell cold vs. warm), by ratio

| CLI | workload | in-shell cold (ms) | ready (ms) | speedup | saved (ms) |
|---|---|--:|--:|--:|--:|
| `ri` | `ri TCPServer` | 550 | 34 | **16.1×** | 516 |
| `rdoc` | `rdoc --version` | 404 | 29 | **14.1×** | 375 |
| `ronin` | `ronin --version` | 503 | 46 | **10.8×** | 456 |
| `nokogiri` | `nokogiri --version` | 185 | 29 | **6.4×** | 156 |
| `rake` | `rake --version` | 131 | 26 | **5.1×** | 105 |
| `erb` | `erb --version` | 112 | 31 | **3.7×** | 82 |
| `rubocop` | `rubocop --version` | 1404 | 406 | **3.5×** | **998** |
| `racc` | `racc --version` | 126 | 42 | **3.0×** | 84 |

## Where the cold startup goes (ms, floor)

| CLI | shell | ruby vm boot | rubygems | activate deps | the tool | **in-shell cold** | ready |
|---|--:|--:|--:|--:|--:|--:|--:|
| `erb` | 6 | 13 | 46 | 29 | 5 | **112** | 31 |
| `racc` | 5 | 10 | 44 | 29 | 32 | **126** | 42 |
| `rake` | 6 | 12 | 40 | 30 | 38 | **131** | 26 |
| `nokogiri` | 5 | 9 | 39 | 29 | 87 | **185** | 29 |
| `rdoc` | 5 | 10 | 40 | 32 | 298 | **404** | 29 |
| `ronin` | 5 | 9 | 40 | **351** | 79 | **503** | 46 |
| `ri` | 5 | 10 | 42 | 32 | 445 | **550** | 34 |
| `rubocop` | 5 | 9 | 39 | 53 | **1281** | **1404** | 406 |

*(**`ruby vm boot`** is the bare `--disable-gems` VM spawn — a ~10 ms floor **both
cold and ready pay** (ready's `by` client boots a VM too). **`rubygems`** is the
framework load *on top* of the boot, cold-only. `the tool` = loading and running
the executable, including its dependencies' code. Rows sum to at most `in-shell
cold` — the small gap is process reap plus min-of-parts slack.)*

## What the layers mean

**`ruby vm boot` is a shared floor (~9–13 ms) — `ready` does *not* remove it.**
Both arms spawn a Ruby VM (`ruby --disable-gems`): cold via the tool's stub, ready
via its `by` client. It's the price of having a Ruby process at all, so it shows
up on both sides at ~the same cost.

**`rubygems` is the ~40 ms load *on top* of the boot** — `require "rubygems"`,
independent of the tool. This is the cold-only part: `ready`'s booted VM connects
a socket instead of loading rubygems, so the persistent server pays it **once**.
This — not the boot — is what "ready eliminates rubygems" means.

**`activate deps` scales with the *dependency graph*, not the tool's work.** This
span is `Gem.activate_bin_path` — rubygems resolving the transitive gem graph and
prepending each gem's `lib/` onto `$LOAD_PATH`. It loads rubygems' own resolver,
not the dependencies' code (activating `ronin` fires ~135 `$LOAD_PATH` additions
and 278 internal requires, yet loads **zero** ronin source files). Hence 30 ms
for tools with few deps, **351 ms for `ronin`** (~135-gem graph). The gems'
actual code loads later, under `the tool`.

**`the tool` scales with how much code the tool loads and runs** — `erb` (6 ms,
stdlib) to `rubocop` (1282 ms, a large cop library).

**Warm dispatch has a flat ~20 ms floor plus the tool's own per-invocation
work.** `ready`'s dispatch overhead (by-client boot + socket round-trip) is
~20 ms for every tool. Most tools do little else once warm, so they return in
26–46 ms. `rubocop` is the instructive exception: **~20 ms dispatch + ~384 ms
`server_tool_run`** — `rubocop --version` resolves config and initializes its
cop set every invocation, work that is not startup and no preloading removes.
That is the ceiling on `ready`'s win; its cold is so large it's still the biggest
absolute saver.

## The rbenv shim (reported separately)

A real cold invocation also pays the rbenv **shim** on `$PATH` before the Ruby
process starts; `ready` eliminates it (a zsh function — no lookup, fork, or exec).
On this codespace the shim is **pathological** (`~/.rbenv/shims/ruby` ≈ 670 ms
floor, `rbenv exec` swings 50→650 ms — almost certainly its RVM/rbenv `$PATH`
conflict), and the per-CLI probe is correspondingly noisy (40–244 ms). A healthy
rbenv shim is ~20–40 ms. Because it's both large and unstable here, it's excluded
from the tables above rather than folded in; directionally, `ready` removes it and
on a broken setup that alone can be worth hundreds of ms.

## What ready can't run (honest exclusions)

The verification pass turned up three CLIs that **cannot** be benched through
`ready` — caught precisely because the harness now fails on non-zero exit and
logs the output (before, each would have been recorded as a fast phantom
"success"):

| CLI | why it fails through ready |
|---|---|
| `rbs` | Its stub does `$LOAD_PATH << File.join(__dir__, "…")`, but `__dir__` is `nil` under `by`'s `eval` (no source file) → `TypeError`, no output. |
| `rougify` | Same class: `Pathname.new(__FILE__).dirname.parent` — `__FILE__` is bogus under eval, so it can't find `lib/rouge.rb`. |
| `rspec` | The `rspec` executable ships in the **`rspec-core`** gem, so `Gem.bin_path("rspec", "rspec")` raises; ready resolves exe≠gem only via its `GEM_BIN_OVERRIDES` table. |

`ready` already rewrites `require_relative` to absolute paths for the same
fileless-eval reason; `__FILE__`/`__dir__` are the same category but currently
unhandled, so tools that compute their load path from source location don't run.

## Caveats

- **Shared runner noise.** Absolute milliseconds vary run-to-run (±~20–30%); the
  **ratios and layer shapes** are the signal, not the exact ms.
- **`--version` isolates startup.** Real workloads add to `the tool`; they don't
  change `rubygems` or `activate deps`. `ri` uses a real lookup because its
  `--version` skips the doc store entirely.
- **Floor statistic.** These are minimums (structural cost); medians run ~10–30%
  higher.

## Reproduce

Per CLI, a readyfile preloads its library (`gems:` entries are **require paths**,
not gem names — `by-server` `require`s each verbatim), then:

```
bin/bench --readyfile <rf> --rounds 5 --warmups 1 -- <cli> <workload>
```

| CLI | preload (`gems:`) | workload |
|---|---|---|
| `racc` | `racc` | `--version` |
| `erb` | `erb` | `--version` |
| `rake` | `rake` | `--version` |
| `rdoc` | `rdoc` | `--version` |
| `ri` | `rdoc` | `TCPServer` |
| `rubocop` | `rubocop` | `--version` |
| `nokogiri` | `nokogiri` | `--version` |
| `ronin` | `ronin`, `ronin/support` | `--version` |

Excluded: `irb`/`pry` (interactive REPLs); `rbs`, `rougify`, `rspec` (see above);
the 13 `ronin-*` subcommands (each shares ronin's ~135-gem, activation-dominated
profile).
