# frozen_string_literal: true

require 'date'
require 'forwardable'
require 'time'
require 'uri'
require 'zeitwerk'

module Neo4j
  module Driver
    class Loader
      class << self
        # `__dir__` resolves to:
        #   dev:           lib/shared  → shared_root = lib/shared
        #   installed gem: lib         → shared_root = lib (the impl dir is
        #                                       merged in by the staged build, so
        #                                       impl_root below is missing and the
        #                                       conditional push is skipped)
        def load(impl)
          @impl = impl
          shared_root = File.expand_path(__dir__)
          impl_root = File.expand_path("../#{impl}", shared_root)

          loader = Zeitwerk::Loader.new
          loader.tag = 'neo4j-ruby-driver'
          loader.inflector = Zeitwerk::GemInflector.new(File.expand_path('neo4j/driver', __dir__))
          loader.inflector.inflect('packstream' => 'PackStream', 'uuid' => 'UUID')
          loader.push_dir(shared_root)
          loader.push_dir(impl_root) if File.directory?(impl_root)
          yield loader if block_given?
          # ignore the Bundler.require-friendly entry files (neo4j-ruby-driver.rb, neo4j-ruby-driver_loader.rb,
          # neo4j_ruby_driver.rb) since Zeitwerk would otherwise try to
          # autoload them as constants with the wrong names.
          loader.ignore(File.expand_path(__FILE__))
          loader.ignore(File.expand_path('neo4j-ruby-driver.rb', __dir__))
          loader.ignore(File.expand_path('neo4j_ruby_driver.rb', __dir__))
          # JRuby-only workaround (native CRuby is unaffected — see below). Keyed
          # on the runtime engine, not the flavor, so it also covers mri-on-jruby.
          predefine_namespaces(loader, [shared_root, impl_root]) if RUBY_ENGINE == 'jruby'
          loader.setup
          loader.eager_load
        end

        # Work around an upstream SimpleCov 1.1.1 × Zeitwerk bug that only bites on
        # JRuby (simplecov-ruby/simplecov#1273). Zeitwerk manages a directory with
        # no matching file as an *implicit* namespace, autovivifying the module by
        # requiring the directory itself and relying on its Kernel#require
        # decoration to intercept. When SimpleCov 1.1.1 starts before this loader
        # eager-loads, it clobbers that interception on JRuby, so the bare
        # directory reaches Kernel#require and raises
        # `LoadError: cannot load such file -- …/<dir>`. Defining each namespace
        # module up front makes it a normal *explicit* namespace, sidestepping the
        # autovivification path. Remove once the SimpleCov bug is fixed.
        def predefine_namespaces(loader, roots)
          roots.each do |root|
            next unless File.directory?(root)

            Dir.glob('**/', base: root).sort.each do |rel|
              segments = rel.split('/')
              next if segments.first == 'org' # vendored jars — ignored by the loader

              segments.inject(Object) do |parent, segment|
                cname = loader.inflector.camelize(segment, File.join(root, rel)).to_sym
                find_or_define_module(parent, cname)
              end
            end
          end
        end

        def find_or_define_module(parent, cname)
          return parent.const_get(cname, false) if parent.const_defined?(cname, false)

          parent.const_set(cname, Module.new)
        end

        def jruby? = @impl == :jruby

        def mri? = @impl == :mri
      end
    end
  end
end
