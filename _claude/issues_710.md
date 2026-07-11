# Issue log — work on todos_710.md (2026-07-11)

Log of problems found while completing `_claude/todos_710.md`, per "OTHER STUFF" #1.

## Fixed as part of this work

1. **`rake -T` crashes when `~/.readyfile` is absent (P0.2).**
   `Ready::Readyfile.open` called `YAML.parse_file` unconditionally at rakelib
   load time (`rakelib/ready.rake:14`), raising `Errno::ENOENT`. Fixed
   `Readyfile.open` to treat a missing *or empty* readyfile as an empty config
   (`{}`). The dependency tree is unchanged: the `file READYFILE` task and the
   `READY_SOCKET => [..., READYFILE]` prerequisite still enforce creation before
   a build runs.

2. **`Ready::Configuration#prefix` read the wrong env var.**
   It called `fetch_env :ready_prefix`, and `fetch_env` prepends `READY_`, so it
   actually looked up `READY_READY_PREFIX`. The zsh plugin sets `READY_PREFIX`,
   so ruby and zsh disagreed whenever a non-default prefix was set. Changed to
   `fetch_env :prefix` → `READY_PREFIX`.

3. **`Ready::ByExecutable` crashed when `READY_SOCK_PATH` was unset.**
   `initialize` had a `by_sockpath: ENV.fetch("READY_SOCK_PATH")` keyword default
   that was never stored or used (dead code) but was evaluated on every
   `ByExecutable.new`, raising `KeyError` when the var was unset (e.g. running
   `ready compile by` outside the zsh plugin). Removed the dead parameter.

## Fixed after review (stale references from the CLI rename)

6. **`rake ready:compile` aborted on a missing `exe/hydrator` (stale rename).**
   Commit `9e2660c` renamed the old `exe/hydrator` CLI into `exe/ready` but left
   `rakelib/ready.rake` pointing `ready_path` at `EXE_DIR / "hydrator"` (and the
   RI bootstrapper at `EXE_DIR / "ri.rb"`, which the same commit had moved to
   `extra/ri.rb`). Repointed `ready_path → EXE_DIR / "ready"` and
   `ri_bootstrapper → EXTRA_DIR / "ri.rb"` (added an `EXTRA_DIR` constant). Both
   are `file`-task guards, so pointing them at the files that actually exist lets
   the build proceed. `ready compile all` now compiles `builds.zwc` end-to-end.

7. **`RakeCommand` used `bundle exec`, re-polluting the build with Bundler.**
   `bundle exec` injects `RUBYOPT=-rbundler/setup`, which leaked into the
   `ready compile` sub-processes the rake tasks spawn and forced them back into
   the bundle (the generated stubs strip this at runtime, see `fn.zsh.erb`, and
   the zsh `readyup` driver runs rake bundler-free). Replaced with the standard
   entry-point pattern: `exe/ready` requires `bundler/setup` only when a Gemfile
   is present (development), staying bundler-free in production; `RakeCommand`
   just runs rake under the same Ruby and inherits that context.

## Environment: removed rvm (root cause of the gem/subprocess failures)

8. This Codespace shipped **both rvm and rbenv**, with rvm's `GEM_HOME`/`GEM_PATH`
   and a `~/.ruby/current → /usr/local/rvm/...` symlink shadowing rbenv. That
   made `bundle exec ruby` and the compile sub-processes resolve rvm's Ruby 3.4.7
   and fail. Per the maintainer's instruction, **removed rvm**: reinstalled the
   full bundle into rbenv 4.0.1's own gemset, stripped rvm sourcing from
   `/etc/bash.bashrc`, `/etc/zsh/{zshrc,zprofile}`, `/etc/profile.d/rvm.sh`, and
   `/etc/profile.d/00-restore-env.sh` (replacing the rvm loader with an env
   cleaner), repointed `~/.ruby/current → ~/.rbenv/versions/4.0.1`, and deleted
   `/usr/local/rvm`. Fresh bash/zsh login shells now resolve rbenv 4.0.1 with a
   clean `GEM_HOME`, and `ready compile all` compiles end-to-end.
   Note: the already-running Claude session still inherits the old `GEM_HOME`
   (a live process's env can't be rewritten), so commands in this session unset
   it; any new shell is clean.

## Known / pre-existing, out of scope for these todos

4. **`ready up` now works end-to-end** once rvm was removed and the stale rename
   references were fixed: `rake ready` stops the old server, compiles the `by`
   stub, starts `by-server` (with the RI patch from `extra/ri.rb`), compiles
   `builds.zwc`, and leaves the persistent server listening on the socket
   (verified: socket created, `by-server` process running under rbenv 4.0.1).
   What remains is the *runtime* robustness of dispatching through the persistent
   server (random irb failures, SIGINT handling, `/dev/fd` process substitution),
   which is the separate `by`-patching work tracked in `issues.rec` (id 1) — not
   part of `todos_710.md`.

5. **Environment quirk (not a repo bug):** this Codespace has both rvm and rbenv
   active, with a global `GEM_HOME`/`GEM_PATH` pointing only at the rvm gemset
   even though `bundle`/`ruby` resolve to rbenv 4.0.1. Consequences:
   - `bundle exec ruby …` (and therefore `bundle exec ready`) fails to boot with
     `Bundler::GemNotFound` for `json`/`prism`/`rbs`/`racc`, because `bundle exec`
     boots through rvm's rubygems core-ext and can't see the rbenv gemset. This
     pre-dates this work (it failed the same way before any change) and does not
     affect real usage: the gem is installed and run standalone (`ready …` on
     `PATH`), and the rakelib invokes `ready` under `Bundler.with_unbundled_env`.
   - `bundle exec rake` and `bundle exec rspec` DO work, so the spec suite and
     `rake -T`/`rake spec` are fully exercised.
   - Verified the gem loads and eager-loads under **both** rbenv 4.0.1 and the
     Codespace's Ruby 3.4.7, confirming the `>= 3.4.7` support floor.
   - Installed the `by` gem (1.1.0, jeremyevans; ships `by`/`by-server`) to
     satisfy the new gemspec dependency, and rebuilt the `json`/`prism`/`rbs`/
     `racc`/`bigdecimal` native extensions into the rbenv 4.0.1 gemset.
