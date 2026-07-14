# `ready`: cold vs. warm startup on real Ruby CLI commands

Benchmark of **6 real, non-trivial commands** (not `--version` probes), each run
**cold** (a fresh Ruby boot per invocation, through an instrumented copy of its
real rubygems stub) versus **ready** (a zsh function stub dispatching to a warm,
persistent `by-server`). Each command's readyfile preloads that CLI's own library
so the warm server is actually warm.

Every number is **verified**: the harness tees each run's stdout+stderr to
`log/bench.log` and aborts the whole benchmark if any run exits non-zero. Every
hot-arm run here was confirmed to produce the same real output as running the
command directly — the `ri` docs, the `colorls` listing, the hex string, the
`youplot` chart, the `kamal` tree, the `codeball` pack — so a command that failed
or no-op'd cannot masquerade as a fast "success."

## TL;DR

- Warm dispatch has a **flat ~29–62 ms floor** regardless of how heavy the cold
  command is (`kamal` cold 485 ms → warm 31 ms; `ri` cold 510 ms → warm 38 ms).
- Speedups run **4.4×–15.5×**; every command saves **140–470 ms per invocation**.
- The cold cost is: a shared **~10 ms VM boot** (ready pays it too — its `by`
  client boots a VM), a **~40 ms rubygems load** on top (cold only), a
  **dependency-resolution cost that scales with graph size** (`activate deps`:
  30 ms for most → **350 ms for `ronin`**), and **the command's real work**
  (83 ms `youplot` → 409 ms `ri`). `ready` keeps the boot and eliminates
  everything above it.

## How it's measured

| | |
|---|---|
| Host | GitHub Codespace, Linux x86_64 (shared runner) |
| Ruby | 4.0.1 (+PRISM), via rbenv |
| Tool | `bin/bench` (this repo), 5 measured rounds + 1 warmup, order-alternating |
| Statistic | **floor (minimum across rounds)** — the structural cost; medians run ~10–30% higher |
| Verification | each run must exit 0; every hot run cross-checked to emit the command's real output |

Three commands were adapted so **both arms do identical work** (the cold and hot
arms run in different working directories, and the harness passes arguments
space-separated):

- **`colorls`** — pinned to a fixed directory (`-l <repo>/lib/ready`) instead of
  the cwd.
- **`youplot`** — the pipeline `seq 1 100 | awk '{print $1,$1^2}'` was pre-rendered
  to a data file, passed as a file argument (not piped); title `y=x^2` (the
  original `"y = x^2"` has spaces the harness can't carry in one argument).
- **`codeball`** — a fixed Ruby file, identical in both arms.

> **On "cold".** These are the directly-measured **in-shell** cold full (boot +
> rubygems + activation + the command). The rbenv shim is reported
> [separately](#the-rbenv-shim-reported-separately) because this box's rbenv is
> pathologically slow and noisy.

## Speedup (in-shell cold vs. warm), by ratio

| command | in-shell cold (ms) | ready (ms) | speedup | saved (ms) |
|---|--:|--:|--:|--:|
| `kamal accessory tree` | 485 | 31 | **15.5×** | 454 |
| `ri --no-pager --format=ansi TCPServer` | 510 | 38 | **13.5×** | 472 |
| `ronin encode --hex --string rubyconf2026` | 523 | 62 | **8.4×** | 461 |
| `codeball pack <ruby file>` | 197 | 29 | **6.7×** | 167 |
| `colorls -l <dir>` | 197 | 30 | **6.5×** | 166 |
| `youplot line … -t y=x^2 <data>` | 184 | 42 | **4.4×** | 142 |

## Where the cold cost goes (ms, floor)

| command | shell | ruby vm boot | rubygems | activate deps | the command | in-shell cold | ready |
|---|--:|--:|--:|--:|--:|--:|--:|
| `youplot` | 5 | 10 | 41 | 30 | 83 | **184** | 42 |
| `colorls` | 5 | 10 | 42 | 34 | 98 | **197** | 30 |
| `codeball` | 4 | 9 | 40 | 30 | 103 | **197** | 29 |
| `kamal` | 5 | 9 | 40 | 49 | 371 | **485** | 31 |
| `ri` | 5 | 9 | 41 | 31 | 409 | **510** | 38 |
| `ronin` | 5 | 9 | 42 | **350** | 103 | **523** | 62 |

*(**`ruby vm boot`** is the bare `--disable-gems` VM spawn — a ~10 ms floor **both
cold and ready pay** (ready's `by` client boots a VM too). **`rubygems`** is the
framework load *on top* of the boot, cold-only. `the command` = loading and doing
the actual work, including `require`-ing its dependencies. Rows sum to at most
`in-shell cold` — the gap is process reap plus min-of-parts slack.)*

## What the layers mean

**`ruby vm boot` is a shared floor (~9–10 ms) — `ready` does *not* remove it.**
Both arms spawn a Ruby VM (`ruby --disable-gems`): cold via the command's stub,
ready via its `by` client. It's the price of having a Ruby process at all.

**`rubygems` is the ~40 ms load *on top* of the boot** — `require "rubygems"`,
constant across commands. This is the cold-only part: `ready`'s booted VM connects
a socket instead of loading rubygems, so the server pays it **once**. This — not
the boot — is what "ready eliminates rubygems" means.

**`activate deps` scales with the *dependency graph*, not the work.** It's
`Gem.activate_bin_path` resolving the transitive gem graph onto `$LOAD_PATH` —
~30 ms for most, but **350 ms for `ronin`** even though `ronin encode` is a tiny
subcommand: the CLI still activates ronin's whole ~135-gem world before running.

**`the command` is the real work** — and with realistic workloads it's the honest
cost, not a `--version` short-circuit: `ri` renders TCPServer's docs in ANSI
(409 ms), `kamal` boots its full CLI (371 ms), `youplot` renders the chart
(83 ms). This is what the warm server has already paid.

**Warm dispatch is a flat ~20 ms floor plus a little residual.** `ready`'s
dispatch overhead (by-client boot + socket round-trip) is ~20 ms for every
command; the rest is whatever per-invocation work the command still does warm
(`ronin` is highest at 62 ms — its command still runs in the worker). Independent
of cold cost, because the server already paid boot, rubygems, activation, and the
command's requires.

## The rbenv shim (reported separately)

A real cold invocation also pays the rbenv **shim** on `$PATH` before the Ruby
process starts; `ready` eliminates it (a zsh function — no lookup, fork, or exec).
On this codespace the shim is **pathological** (`~/.rbenv/shims/ruby` ≈ 670 ms
floor, `rbenv exec` swings 50→650 ms — almost certainly its RVM/rbenv `$PATH`
conflict) and the per-command probe is noisy, so it's excluded from the tables
rather than folded in. A healthy rbenv shim is ~20–40 ms; directionally `ready`
removes it, and on a broken setup that alone is worth hundreds of ms.

## Known limits (from earlier runs)

`ready` can't dispatch a CLI whose stub computes its load path from `__FILE__`/
`__dir__` (bogus under `by`'s `eval` — e.g. `rbs`, `rougify`), or one whose
executable ships in a differently-named gem it can't resolve (`rspec`, from
`rspec-core`). None of the 6 commands above hit these; they're noted because the
exit-check is what surfaces them instead of timing a silent failure.

## Reproduce

Per command, a readyfile preloads its library (`gems:` entries are **require
paths**), then:

```
bin/bench --readyfile <rf> --rounds 5 --warmups 1 -- <command>
```

| command | preload (`gems:`) | exact invocation |
|---|---|---|
| `ri` | `rdoc` | `ri --no-pager --format=ansi TCPServer` |
| `colorls` | `colorls` | `colorls -l <repo>/lib/ready` |
| `ronin` | `ronin`, `ronin/support` | `ronin encode --hex --string rubyconf2026` |
| `youplot` | `youplot` | `youplot line -w 50 -h 15 -t y=x^2 <data>` (data = `seq 1 100 \| awk '{print $1,$1^2}'`) |
| `kamal` | `kamal` | `kamal accessory tree` |
| `codeball` | `codeball` | `codeball pack <ruby file>` |
