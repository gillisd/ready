require "erb"
require "pathname"

module Ready
  ##
  # Renders a zsh function that wraps an executable, using the bundled ERB
  # template.
  class ZshFunction
    attr_reader :name, :executable, :environment, :template_path

    DEFAULT_TEMPLATE_PATH = Pathname(__dir__) / "fn.zsh.erb"
    def initialize(name, environment: {}, template_path: DEFAULT_TEMPLATE_PATH)
      @name = name
      @environment = environment
      @executable = Executable.new(name)
      @template_path = Pathname(template_path)
    end

    def to_s
      template = ERB.new(@template_path.read)
      template.result_with_hash(
        name: name,
        ruby: executable.render,
        env: environment,
      )
    end

    private

    def render_environment_string
      return "" if @environment.empty?

      @environment.map { |key, value| "#{key}=#{value}" }.then { |it| it.join(" ") }
    end
  end
end
