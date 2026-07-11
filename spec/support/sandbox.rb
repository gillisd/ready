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

    def self.build(executables:)
      new(executables:).tap(&:up)
    end

    def initialize(executables:)
      @executables = executables
      @prefix = Pathname(Dir.mktmpdir("ready-e2e"))
      @readyfile = @prefix / ".readyfile"
      @sock_path = @prefix / "ready.sock"
    end

    # Env a pty must set so the plugin attaches to THIS sandbox's live server.
    def shell_env
      {
        "READY_PREFIX" => prefix.to_s,
        "READY_SOCK_PATH" => sock_path.to_s,
        "READY_LOG_PATH" => (prefix / "ready.log").to_s,
        "READY_DEBUG" => "0",
      }
    end

    def plugin_path = PLUGIN_PATH

    def up
      FileUtils.mkdir_p(prefix / "builds")
      write_readyfile
      run_up
      assert_built!
      self
    end

    def teardown
      stop_server
      FileUtils.rm_rf(prefix)
    end

    private

    def write_readyfile
      lines = ["executables:", *@executables.map { |e| "  - #{e}" }]
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

    def stop_server
      if sock_path.socket?
        system({ "BY_SOCKET" => sock_path.to_s }, "by-server", "stop",
               out: File::NULL, err: File::NULL)
      end
      reap_orphans
    end

    # No pidfile exists; the daemon is found by its argv, which contains the
    # unique temp prefix (<prefix>/extra.rb). Excludes self defensively.
    def reap_orphans
      pids = `pgrep -f #{Shellwords.escape(prefix.to_s)}`.split.map(&:to_i)
      pids.reject { |pid| pid == Process.pid }.each do |pid|
        Process.kill("TERM", pid)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end
