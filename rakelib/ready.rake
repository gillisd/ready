require "shellwords"
require "open3"
require "bundler"
require "rake/clean"
require "ready"

configuration = Ready::Configuration.new

PROJECT_DIR = configuration.project_path
EXE_DIR = PROJECT_DIR / "exe"
EXTRA_DIR = PROJECT_DIR / "extra"
READY_PREFIX = configuration.prefix
READY_SOCKET = configuration.sock_path
READY_BUILD_DIR = configuration.build_dir
READYFILE = configuration.readyfile

def run_command(*args, out: $stdout, chdir: Dir.pwd, **kwargs)
  case args
  in Hash => env, *cmd
  in cmd then env = {}
  end

  puts
  puts cmd.join(" ")

  Bundler.with_unbundled_env do
    Open3.popen2(env, *cmd.map(&:to_s), chdir: chdir.to_s, **kwargs) do |sin, sout, wait|
      sin.close
      IO.copy_stream sout, out
      result = wait.value
      raise "Encountered an error while running #{cmd.join(" ").inspect}" unless result.success?
    end
  end
end

def compile_by(target:)
  shell_load_path = [EXE_DIR, ENV.fetch("PATH", "")].join ":"
  env = ENV.to_h.merge(
    "PATH" => shell_load_path,
    "BY_SOCKET" => READY_SOCKET.to_s,
  )
  File.open target, "w" do |f|
    run_command env, "ready", "compile", "by", "--no-rubygems", "--no-yjit", out: f
  end
end

def compile_gem(executable_name, target:)
  shell_load_path = [EXE_DIR, ENV.fetch("PATH", "")].join ":"
  env = ENV.to_h.merge("PATH" => shell_load_path)

  File.open target, "w" do |f|
    run_command env, "ready", "compile", "--environment", "BY_SOCKET=#{READY_SOCKET}", executable_name, out: f
  end
end

namespace :ready do
  directory PROJECT_DIR do
    mkdir_p PROJECT_DIR
  end

  directory READY_PREFIX do
    mkdir_p READY_PREFIX
  end

  directory READY_BUILD_DIR do
    mkdir_p READY_BUILD_DIR
  end

  Rake::Task[READY_BUILD_DIR].invoke

  build_tempdir = READY_PREFIX / "tmp"

  directory build_tempdir do
    mkdir_p build_tempdir
  end

  trace_dir = READY_PREFIX / "traces"

  directory trace_dir do
    mkdir_p trace_dir
  end

  ri_bootstrapper = EXTRA_DIR / "ri.rb"

  file ri_bootstrapper do
    raise "RI patch should already exist at #{ri_bootstrapper.to_s.inspect}"
  end

  file READYFILE do
    touch READYFILE.to_s
  end

  ready_path = EXE_DIR / "ready"

  file ready_path do
    raise "ready executable not found at #{ready_path}"
  end

  extra = READY_PREFIX / "extra.rb"

  CLEAN.include FileList[build_tempdir, READY_BUILD_DIR]
  CLOBBER.include FileList[READY_BUILD_DIR.parent / "**/*"]

  env = {
    "JRUBY_OPTS" => "--dev -J--enable-native-access=ALL-UNNAMED",
    "MINITEST_ACTIVATE_SKIP" => 1,
    "RUBY_YJIT_ENABLE" => 1,
    "BUNDLE_IGNORE_CONFIG" => 1,
    "BY_SOCKET" => READY_SOCKET,
  }.transform_values(&:to_s)

  file extra do
    extra_body = <<~RUBY
      if defined? ActiveSupport
        ActiveSupport.to_time_preserves_timezone = true
        ActiveSupport.deprecator.silenced = true
        ActiveSupport.eager_load!
      end

      if defined? Zeitwerk
        Zeitwerk::Registry.loaders.each { it.eager_load(force: true) }
      end
    RUBY
    File.write extra, extra_body
  end

  file READY_SOCKET => [extra, ri_bootstrapper, READYFILE] do
    puts "Loading server..."
    run_command env, "by-server", *READYFILE.gem_names, ri_bootstrapper.to_s, extra.to_s, chdir: Dir.home
  end

  core_deps = FileList[READY_BUILD_DIR, trace_dir, ready_path]

  desc "Start the ready server"
  task start_server: READY_SOCKET do
    puts "Starting ready server"
  end

  desc "Stop the ready server"
  task :stop_server do
    puts "Stopping ready server"
    rm_f READY_SOCKET
    run_command env, "by-server", "stop"
  end

  desc "Restart the ready server"
  task restart_server: [:stop_server, :start_server]

  namespace :build do
    irb = READY_BUILD_DIR / "ready_irb"

    ready_by = READY_BUILD_DIR / "ready_by"

    file ready_by => core_deps do |task, _|
      compile_by target: task.name
    end

    file irb => core_deps do |task, _|
      compile_gem "irb", target: task.name
    end

    READYFILE.each_executable do |executable|
      file executable.realpath => core_deps do |task, _|
        compile_gem executable.name, target: task.name
      end
    end

    all_executables = FileList[ready_by, *READYFILE.executable_paths]

    compiled = READY_BUILD_DIR.parent / "builds.zwc"

    file compiled => all_executables do |task, _|
      pathname = Pathname(task.name)
      run_command "zsh", "-c",
                  Shellwords.join(["zcompile", "-Uz", pathname.basename.to_s, *all_executables]),
                  chdir: pathname.parent
    end

    CLEAN.import all_executables

    multitask compile: [compiled, *all_executables]
  end

  desc "Compile all ready executables"
  task compile: "build:compile"

  task compile_and_clean: [:compile, :clean]
end

desc "Build and start the ready environment"
multitask ready: ["ready:restart_server", "ready:compile_and_clean"]
