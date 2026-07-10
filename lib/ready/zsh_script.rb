require "stringio"

module Ready
  ##
  # Assembles a zsh script by rendering one ZshFunction per name, building the
  # functions concurrently.
  class ZshScript
    attr_accessor :names
    attr_reader :environment

    def initialize(names: [], environment: {})
      @names = names
      @environment = environment
      @mutex = Mutex.new
      @script = StringIO.new
    end

    def multithread_process(names)
      threads = names.map do |name|
        Thread.new do
          zsh_body = ZshFunction.new(name, environment: environment).to_s
          @mutex.synchronize do
            @script.puts zsh_body
          end
        end
      end

      threads.each(&:join)
    end

    def set_env(key, value)
      @environment[key] = value
    end

    def add_eager_loading!
      #    @source.puts 'by -e "ActiveSupport.eager_load!"'
    end

    def to_s
      add_eager_loading!
      multithread_process(@names)
      @script.string
    end
  end
end
