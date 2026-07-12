# Evaluating the PTY/expect harness as an rspec E2E basis for `ready`

**Date:** 2026-07-11 · Branch: `e2e-rspec` (off `cli-polish`)

## Verdict: strong yes — and it's proven, not theoretical

I extracted the harness's core and ran a two-layer proof-of-concept against this
repo:

- **Layer 1** — the `PtyShell` core drives a real `zsh -f -i` under a pty; the
  marker sync correctly handles the command-echo/output double-print; timing is
  captured; clean teardown. (`scratchpad/poc_layer1.rb`)
- **Layer 2 (the real thing)** — built a sandbox (`ready up` with a `.readyfile`
  of `executables: [rake]`), then over the pty: sourced the plugin, confirmed
  `whence -v rake` → `rake is an alias for ready_rake`, ran `rake --version`, and
  got `rake, version 13.4.2` back **through the compiled stub → `ready_by` → the
  live `by-server`** in ~80ms. (`scratchpad/poc_layer2.rb`)

So the approach can test `ready` fully end-to-end from Ruby (hence rspec), and it
simultaneously proved the runtime dispatch actually works.

## Why PTY is the *right* (and only) approach for `ready`

`ready`'s value lives entirely in the zsh runtime: the plugin bootstrap
(`readyinit`), aliasing bare commands to `ready_*` stubs, the stubs' RUBYOPT
sanitization, completions, and dispatch to the persistent `by-server`. None of
that is reachable from a subprocess or a non-interactive shell — it needs a real
interactive zsh with a tty. The existing rspec suite (`spec/ready/`) covers the
*generator* (Ruby that emits stubs); it structurally cannot cover whether a
generated stub, loaded into a live shell, dispatches and returns correct output.
PTY closes exactly that gap.

## Reuse as-is (the gold)

- **`PtyShell` core** — pty spawn + marker-based completion detection. The
  quote-split marker (`DO''NE1`) avoids the command-echo false-match (visible in
  Layer 1's double echo). Keep verbatim as `spec/support/pty_shell.rb`.
- **Loud failure on desync** — `expect!` raises with the parked tail buffer on
  timeout/EOF, so a hung shell fails the example instead of hanging silently.
- **Independent outside clock** — pty-observed wall time enables perf-regression
  assertions (the whole point of `ready`).

## Benchmark-specific (adapt or drop for functional E2E)

`Marks` / `Report` / `Runner`, the `/home/claude/prof` marks log + `prof.zsh`,
`zprof`, and the hardcoded `kamal_hot/cold` arms + `2.12.0` check are profiling
scaffolding. Functional E2E only needs "source plugin → run stub → assert
output/exit". Keep the waterfall machinery for a *separate*, optional
perf-regression spec.

## Mapping into rspec

- `spec/support/pty_shell.rb` — extracted `PtyShell`.
- A sandbox shared context: temp `READY_PREFIX` + `.readyfile`, run `ready up`
  once in `before(:all)`, kill the by-server + rm the socket in `after(:all)`.
  Bring the server up once and reuse it across examples (bring-up is the slow
  part, ~seconds; a stub roundtrip is ~80ms).
- Examples: `source <plugin>`, assert the alias exists, run the stub, assert
  output/exit, optionally `expect(wall_ms).to be < N`. (Exactly the PoC,
  restructured.)

## Risks / caveats (all manageable)

1. **CI needs zsh + a pty.** GitHub Actions ubuntu/macOS have both — add `zsh` to
   the workflow. Not Windows.
2. **`expect` is stdlib but a *bundled* gem now.** Present here
   (`.../4.0.0/expect.rb`); for portability add `gem "expect"` (and `pty` is a
   default gem) to the test group.
3. **Server lifecycle & isolation.** Use a temp `READY_PREFIX`/socket (never
   `/tmp/ready`) and guarantee teardown — an orphaned `by-server` is exactly what
   lingered twice during this PoC. Use `after(:all)` (kill pid + rm socket) plus
   an `at_exit` safety net.
4. **Speed.** Keep E2E to a handful of high-value examples; tag them `:e2e` so
   the fast unit loop can exclude them and CI can run them.
5. **Flakiness.** Marker sync makes it deterministic, but interactive tty timing
   can wobble under CI load. `zsh -f` (no rc, no theme escapes) + a controlled
   `PS1` + generous timeout mitigate. Consider wrapping each example in an overall
   `Timeout.timeout` since IO#expect's timeout is inter-character, not a total
   deadline.
6. **Buildable `ready` assumed.** The PoC needed a working `ready up` (now true
   after the `cli-polish` fixes and the rvm removal). In clean-rbenv CI this holds.

## Recommendation

Adopt it. Extract `PtyShell` into `spec/support/`, add a sandboxed `ready up`
fixture, write a small `:e2e` spec asserting dispatch works (and optionally that
hot latency beats a cold baseline), and keep the `Marks`/`zprof` waterfall as an
optional separate perf harness. This gives `ready` the one test class it lacks:
proof that a generated stub actually works in a live shell.
