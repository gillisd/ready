# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`ready` eliminates Ruby CLI startup cost. Ruby executables (`irb`, `ri`, gem
binaries, etc.) pay a fixed boot tax on every invocation. `ready` pays it once:
it preloads executables into a persistent server (the external `by` /
`by-server` gem, listening on a unix socket) and generates thin **zsh function
stubs** that dispatch to that server instead of spawning a fresh Ruby. Typing
`irb` then hits an already-warm process and returns near-instantly.

The project has two halves that meet at generated code:

1. **A Ruby gem** (`lib/`, `exe/ready`) that *generates* the zsh stubs.
2. **A zsh plugin** (`zsh/ready/`) that *loads and runs* them at shell startup.

`rakelib/ready.rake` is the orchestrator that drives half 1 to produce artifacts
that half 2 consumes.

## Commands

```bash
bin/setup                          # bundle install
bundle exec rake                   # default: spec + rubocop (what CI runs)
bundle exec rake spec              # RSpec suite
bundle exec rspec spec/ready_spec.rb        # one file
bundle exec rspec spec/ready_spec.rb:3      # one example by line number
bundle exec rake rubocop           # lint
bundle exec rubocop -A             # lint + autocorrect
bundle exec rake zeitwerk:validate # verify Zeitwerk naming (eager-loads all of lib/)
bin/console                        # IRB with the gem loaded
```

Building the actual `ready` runtime (`rake ready`, `rake ready:compile`,
`ready:start_server`, …) is separate from developing the gem. It requires **Ruby
4.0.1**, the external `by`/`by-server` gem installed, `rbenv`, and a populated
`~/.readyfile`. The rake build also expects `exe/hydrator` and `exe/ri.rb` to be
present (its file tasks `raise` if they're missing — see `rakelib/ready.rake`).
Don't run the build to validate ordinary gem changes; `rake` (spec + rubocop) is
the dev inner loop.

## Code-generation pipeline (`lib/ready/`)

`exe/ready` pattern-matches `ARGV` and dispatches two subcommands:

- **`ready by [opts]`** → `ByParser` → `ByExecutable#to_alias` — emits one shell
  command line that runs the `by` client under a chosen Ruby with
  `--disable-gems` / `--yjit` toggles.
- **`ready gem <names…> [opts]`** → `GemParser` → `ZshScript` — emits zsh
  function definitions, one per executable name.

Flow for the `gem` path (the interesting one):

```
GemParser ─▶ ZshScript ─▶ ZshFunction ─▶ Executable ─▶ fn.zsh.erb
 (opts)      (per-name,    (renders       (resolves &    (final zsh
             threaded)      1 template)    inlines src)   function text)
```

- **`ZshScript`** holds the names + env and renders one `ZshFunction` per name
  **concurrently** (`Thread` + `Mutex` into a shared `StringIO`).
- **`ZshFunction`** renders `fn.zsh.erb` with `name`, the inlined `ruby` source,
  and `env`.
- **`Executable`** is the core trick: it resolves a name to a concrete file
  (gem bin via `Gem.bin_path`, an on-disk path, or `rbenv which`), reads the
  source, strips the shebang, rewrites `require_relative` → absolute `require`,
  and prepends `Process.setproctitle`. That transformed source is **embedded**
  into the zsh function so the persistent server can `eval` it (`ready_by -e`).
- **`fn.zsh.erb`** is the emitted function: it sanitizes `RUBYOPT` (strips
  `bundler/setup`, which breaks the persistent-server model), applies env, and
  calls `ready_by -e <inlined-source> "$@"`.

Parsers (`ByParser`, `GemParser`) share a convention: `OptionParser`-based,
`private_class_method :new`, entered via a class-level `.parse(*inputs)`.
`ByExecutable` is a fluent builder (`with_/without_rubygems`, `with_/without_yjit`).

## Config & the readyfile

- **`Configuration`** resolves runtime config from `READY_*` env vars with
  conventional fallbacks (`READY_PREFIX` → `/tmp/ready`, `READY_READYFILE` →
  `~/.readyfile`, `READY_SOCK_PATH`, etc.) via `fetch_env`.
- **`Readyfile`** parses that YAML file, which declares `gems:` and
  `executables:` to compile. **`Readyfile::Executable`** maps each declared
  `name` → its compiled path `build_dir/ready_<name>`.

## Build orchestration (`rakelib/ready.rake`)

The `ready:*` tasks are the real driver. `ready:compile` invokes `ready by` /
`ready gem` for every readyfile entry to write per-executable zsh functions into
the build dir, then `zcompile`s them all into a single compiled digest
(`builds.zwc`). `ready:{start,stop,restart}_server` manage `by-server` on the
socket. Top-level `rake ready` = restart server + compile + clean.

## zsh runtime (`zsh/ready/`)

- **`ready.plugin.zsh`** — bootstrap: sets `READY_*`, ensures the prefix dir,
  extends `fpath`; if the socket exists → `readyinit`, else → `readyup`.
- **`readyup`** — runs `rake ready` in the project dir to (re)build, then
  `readyinit`.
- **`readyinit`** — loads `builds.zwc`, defines the `ready_*` functions, aliases
  each bare command (`irb`, `by`, …) to its stub, and wires completions.
- `functions/ready/__ready_{debug,print,datetime}` are logging/util helpers;
  `rizz` is a user-facing `ri` doc viewer built on this stack.

## Conventions & gotchas

- **Zeitwerk-conformant layout is enforced.** `lib/ready.rb` sets up
  `Zeitwerk::Loader.for_gem`; file paths must match constant names
  (`lib/ready/foo_bar.rb` → `Ready::FooBar`). A spec eager-loads everything and
  `rake zeitwerk:validate` checks naming — run it after adding/moving files.
- **Ruby 4.0.1.** The code leans on modern syntax (`case/in` pattern matching,
  the `it` block param, endless methods). CI pins 4.0.1.
- **RuboCop is heavily customized** (see `.rubocop.yml`) via `rubocop-claude`
  (AI guardrails). Match the house style: double quotes, **no** frozen-string
  comment, trailing commas in multiline literals/args, dot-aligned multiline
  method chains, pipeline/`.then`-chaining style, short blocks
  (`Metrics/BlockLength` max 8), and every class carries an rdoc `##` comment
  (`Style/Documentation` is on).
- **`references/command_kit.rb/` is a vendored, read-only reference copy** of an
  external gem (its own git repo). It is not part of this project — don't edit it
  or count it when reasoning about the codebase.
- **The `by`/`by-server` dependency is implicit** — used at runtime and in the
  rake build but not declared in `ready.gemspec` (which only depends on
  `zeitwerk`). It must be installed in the environment.
- `issues.rec` is a GNU recutils database of open design issues; `extra/` holds
  helper scripts (doc formatters, the `ri` patch) used by the runtime.
