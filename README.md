# Ready

Make Ruby CLIs start instantly. `ready` preloads your Ruby executables into a
persistent [`by`][by] server and installs thin zsh stubs that dispatch to it, so
tools like `irb`, `rails`, or `rspec` skip Ruby's startup cost on every run.

## Requirements

- **zsh** — the only supported shell (bash and fish are not supported)
- **[rbenv]** — the supported Ruby version manager
- **Ruby >= 3.4.7**

## Install

Install `ready` globally as a command-line tool. Do **not** add it to a
project's Gemfile or run `bundle add ready` / `bundle install` for it — `ready`
manages a single machine-wide preloader, not a per-project dependency:

```sh
gem install ready
```

Then load the zsh plugin. `ready init` resolves the plugin's path and prints the
line that sources it — add it to your `~/.zshrc`:

```sh
# ~/.zshrc
eval "$(ready init)"
```

`ready init` on its own just prints that line, so you can paste it directly
instead:

```sh
$ ready init
source /usr/local/.../gems/ready-x.y.z/zsh/ready/ready.plugin.zsh
```

## Usage

List the gems to preload and the executables to compile in `~/.readyfile`:

```yaml
gems:
  - rails
executables:
  - irb
  - rspec
```

Build every stub and start the server:

```sh
ready up
```

`irb`, `rspec`, … are now near-instant. The rest of the commands:

```sh
ready compile irb rspec   # (re)compile stubs for specific CLIs
ready compile by          # (re)compile just the persistent `by` client
ready compile all         # recompile everything
ready clobber             # remove all compiled artifacts
ready help                # full command reference
```

## Configuration

`ready` is configured through environment variables — set them before the zsh
plugin loads:

| Name | Description | Default |
|------|-------------|---------|
| `READY_PREFIX` | Base directory for ready's runtime state (socket, builds, logs) | `/tmp/ready` |
| `READY_SOCK_PATH` | Unix socket for the `by` preloader server | `$READY_PREFIX/ready.sock` |
| `READY_READYFILE` | YAML file listing the gems/executables to preload | `~/.readyfile` |
| `READY_LOG_PATH` | Log file | `$READY_PREFIX/ready.log` |
| `READY_LOGLEVEL` | Minimum log level (`debug`, `info`, `warn`, `error`) | `info` |
| `READY_DEBUG` | Set to `1` to force debug-level logging | `0` |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then run
`rake spec` to run the tests and `rake rubocop` to lint (`rake` runs both).

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).

[by]: https://github.com/jeremyevans/by
[rbenv]: https://github.com/rbenv/rbenv
