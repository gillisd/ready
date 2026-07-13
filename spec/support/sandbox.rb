require "tmpdir"
require "fileutils"
require "shellwords"
require "bundler"

module Ready
  ##
  # Builds an isolated `ready` runtime in a temp prefix: writes a readyfile,
  # runs `ready up` once (compile stubs + boot by-server), exposes the env a pty
  # needs to attach, and tears it all down (stop server + remove tree).
  class Sandbox
    attr_reader :prefix, :readyfile, :sock_path

    PLUGIN_PATH = Ready.root / "zsh" / "ready" / "ready.plugin.zsh"
    EXE_READY = Ready.root / "exe" / "ready"

    # Tools run through the harness must never page: a pager grabs the pty and
    # can leave a suspended child that wedges shell teardown. Neutralize the
    # common pagers so every benched tool runs to completion non-interactively.
    NON_INTERACTIVE_ENV = { "PAGER" => "cat", "RI_PAGER" => "cat", "GIT_PAGER" => "cat" }.freeze

    def self.build(executables:, gems: [])
      new(executables:, gems:).tap(&:up)
    end

    def initialize(executables:, gems: [])
      @executables = executables
      @gems = gems
      @prefix = Pathname(Dir.mktmpdir("ready-e2e"))
      @readyfile = @prefix / ".readyfile"
      @sock_path = @prefix / "ready.sock"
    end

    # Env a pty must set so the plugin attaches to THIS sandbox's live server.
    # Carries the no-pager env, which build_env inherits, so the by-server
    # (and its forked hot-arm workers) never launch a pager.
    def shell_env
      {
        "READY_PREFIX" => prefix.to_s,
        "READY_SOCK_PATH" => sock_path.to_s,
        "READY_LOG_PATH" => (prefix / "ready.log").to_s,
        "READY_DEBUG" => "0",
      }.merge(NON_INTERACTIVE_ENV)
    end

    def plugin_path
      PLUGIN_PATH
    end

    def up
      FileUtils.mkdir_p(prefix / "builds")
      write_readyfile
      run_up
      assert_built!
      self
    end

    def teardown
      kill_server
      FileUtils.rm_rf(prefix)
    end

    private

    def write_readyfile
      lines = []
      lines += ["gems:", *@gems.map { |g| "  - #{g}" }] unless @gems.empty?
      lines += ["executables:", *@executables.map { |e| "  - #{e}" }]
      readyfile.write("#{lines.join("\n")}\n")
    end

    def run_up
      log = prefix / "up.log"
      ok = Bundler.with_unbundled_env do
        system(build_env, RbConfig.ruby, EXE_READY.to_s, "up",
               chdir: Ready.root.to_s, out: log.to_s, err: %i[child out])
      end
      @build_output = log.read
      raise "ready up failed:\n#{@build_output}" unless ok
    end

    # Runs inside with_unbundled_env, where ENV holds the pre-bundler values. A
    # removed version manager (rvm) can leave GEM_HOME/GEM_PATH pointing at a
    # deleted directory; propagating it breaks gem resolution in the build. Drop
    # such stale vars so exe/ready's bundler/setup resolves from the project
    # bundle (mirrors the working `unset GEM_HOME ...` recipe).
    def build_env
      env = shell_env.merge(
        "READY_READYFILE" => readyfile.to_s,
        "RUBY_HOME" => nil,
        "MY_RUBY_HOME" => nil,
      )
      gem_home = ENV.fetch("GEM_HOME", nil)
      if gem_home && !File.directory?(gem_home)
        env["GEM_HOME"] = nil
        env["GEM_PATH"] = nil
      end
      env
    end

    def assert_built!
      raise "no live socket at #{sock_path}\n#{@build_output}" unless sock_path.socket?
      raise "no builds.zwc in #{prefix}\n#{@build_output}" unless (prefix / "builds.zwc").file?
    end

    # Kill the by-server daemon and every worker it forked, without `by-server
    # stop` (which can itself block). The daemon has no pidfile, but its argv
    # carries the unique temp prefix, so pgrep finds it; SIGKILLing its whole
    # process group reaps the workers too -- they setproctitle to the tool name
    # and so are invisible to a prefix search, but they share the daemon's
    # group. TERM is not enough: by-server ignores it.
    def kill_server
      daemon_pids.each { |pid| kill_process_group(pid) }
    end

    def daemon_pids
      `pgrep -f #{Shellwords.escape(prefix.to_s)}`.split.map(&:to_i).reject { |pid| pid == Process.pid }
    end

    def kill_process_group(pid)
      group = Process.getpgid(pid)
      # Never signal our own group; fall back to the lone pid if it shares ours.
      Process.kill("KILL", group == Process.getpgrp ? pid : -group)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end
  end
end
