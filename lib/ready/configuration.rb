require "pathname"

module Ready
  ##
  # Resolves ready's runtime configuration (paths, prefixes, the readyfile)
  # from the environment, falling back to conventional defaults.
  class Configuration
    def project_path
      Pathname(__dir__).parent.parent.expand_path
    end

    def prefix
      fetched = fetch_env :prefix, default: "/tmp/ready"

      Pathname(fetched).expand_path
    end

    def build_dir
      prefix / "builds"
    end

    def sock_path
      fetched = fetch_env :sock_path do
        prefix / "ready.sock"
      end

      Pathname(fetched)
    end

    def readyfile
      @readyfile ||= open_readyfile
    end

    private

    def open_readyfile
      fetched = fetch_env :readyfile do
        Pathname(Dir.home) / ".readyfile"
      end

      Readyfile.open(fetched, build_dir:)
    end

    def fetch_env(key, default: nil, &block)
      key = key.to_s.upcase
      value = ENV.fetch("READY_#{key}") do
        case [default, block]
        in String, nil then default
        in nil, Proc then yield
        in nil, nil then raise "Expected ENV var #{key} to be found but was not"
        else
          raise ArgumentError "args #{key.inspect}, default: #{default.inspect}, block: #{block.inspect} are invalid"
        end
      end

      raise "Expected value of #{key} to not be empty" if value.empty?

      value
    end
  end
end
