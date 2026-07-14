require "rdoc/ri"
require "rdoc/ri/driver"

ready_defaults = {
  use_home: false,
  use_site: false,
  use_system: true,
  use_gems: true,
  use_stdout: true,
  formatter: RDoc::Markup::ToAnsi
}

$ri_driver = RDoc::RI::Driver.new
# warm the cache
$ri_driver.classes

RDoc::RI::Driver.define_method :assign_attributes do |initial_options = {}|
  @paging = false

  original_default_options = self.class.default_options.update({})
  default_options = original_default_options.merge(ready_defaults)
  options = default_options.merge(initial_options)
  # quick hack for now, optparse is the real one setting the defaults
  options.merge!(ready_defaults)

  @formatter_klass = options[:formatter]

  require "profile" if options[:profile]

  @names = options[:names]
  @list = options[:list]
  @list_doc_dirs = options[:list_doc_dirs]
  @interactive = options[:interactive]
  @server      = options[:server]
  @use_stdout  = options[:use_stdout]
  @show_all    = options[:show_all]
  @width       = options[:width]
  @expand_refs = options[:expand_refs]
end

RDoc::RI::Driver.define_method :classes_and_includes_and_extends_for do |name|
  klasses = []
  extends = []
  includes = []

  candidate_stores = classes[name] || [] # only stores that actually have `name`

  found = candidate_stores.map do |store|
    begin
      klass = store.load_class name
      klasses  << klass
      extends  << [klass.extends,  store] if klass.extends
      includes << [klass.includes, store] if klass.includes
      [store, klass]
    rescue RDoc::Store::MissingFileError
    end
  end.compact

  extends.reject! do |modules,|
    modules.empty?
  end

  includes.reject! do |modules,|
    modules.empty?
  end

  [found, klasses, includes, extends]
end

RDoc::RI::Driver.define_singleton_method :run do |argv|
  options = process_args argv
  if options[:dump_path]
    dump options[:dump_path]
    return
  end
  $ri_driver.assign_attributes(options)
  $ri_driver.run
end
