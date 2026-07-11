require "command_kit/command"

module Ready
  class CLI
    ##
    # Compiles ready stubs and prints them to stdout, or compiles everything via
    # rake:
    #
    #   * `ready compile all`       — compile every stub (`rake ready:compile`)
    #   * `ready compile by`        — the persistent `by` client alias
    #   * `ready compile NAME ...`  — a zsh function stub per CLI name
    #
    # The `--rubygems`/`--yjit` flags only apply to `by`; `--environment` only
    # applies to named CLIs.
    class Compile < CommandKit::Command

      include RakeCommand

      usage "[options] {all | by | NAME [NAME ...]}"

      option :environment, short: "-e",
                           value: {
                             type: String,
                             usage: "KEY=VALUE",
                           },
                           desc: "Environment variable to set for the compiled CLI (repeatable)" do |pair|
                             key, value = pair.split("=", 2)
                             @environment[key] = value
                           end

      option :rubygems, long: "--[no-]rubygems",
                        desc: "(by only) Load rubygems. Off by default for a big speed boost" do |value|
                          @rubygems = value
                        end

      option :yjit, long: "--[no-]yjit",
                    desc: "(by only) Enable YJIT. Off by default" do |value|
                      @yjit = value
                    end

      argument :names, required: true,
                       repeats: true,
                       usage: "all | by | NAME",
                       desc: "`all`, `by`, or one or more CLI names to compile"

      description "Compile ready stubs for the given CLI name(s)"

      examples [
        "all",
        "by --yjit",
        "irb rspec",
        "-e RAILS_ENV=production rails",
      ]

      #
      # Initializes the per-invocation accumulators that the option blocks
      # write into.
      #
      def initialize(**kwargs)
        super(**kwargs)

        @environment = {}
        @rubygems    = false
        @yjit        = false
      end

      #
      # Dispatches on the argument(s): `all` compiles everything via rake, `by`
      # prints the persistent-client alias, and anything else is treated as one
      # or more gem/CLI names.
      #
      # @param [Array<String>] names
      #
      def run(*names)
        case names
        in ["all"] then rake("ready:compile")
        in ["by"]  then print by_alias
        else            print gem_script(names)
        end
      end

      private

      def by_alias
        executable = ByExecutable.new
        executable = @rubygems ? executable.with_rubygems : executable.without_rubygems
        executable = @yjit ? executable.with_yjit : executable.without_yjit
        executable.to_alias
      end

      def gem_script(names)
        ZshScript.new(names: names, environment: @environment).to_s
      end

    end
  end
end
