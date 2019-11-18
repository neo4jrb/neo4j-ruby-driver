# frozen_string_literal: true

require 'rubygems'
require 'hoe'
require 'neo4j/rake_tasks'

Hoe.plugin :bundler
Hoe.plugin :gemspec

def ffi?
  ENV['SEABOLT_LIB']&.length&.positive?
end

def pdir
  ffi? ? 'ffi' : 'jruby'
end

def gem_name
  ffi? ? 'neo4j-ruby-driver' : 'neo4j-java-driver'
end

HOE = Class.new(Hoe) do
  def read_manifest
    Dir[*%w[README.md LICENSE.txt lib/neo4j_ruby_driver.rb lib/loader.rb]] +
      Dir['lib/neo4j/**/*.rb'] +
      Dir["#{pdir}/**/*.rb"]
  end
end.spec gem_name do
  developer 'Heinrich Klobuczek', 'heinrich@mail.com'

  dependency 'activesupport', '>= 0'
  dependency 'ffaker', '>= 0', :dev
  dependency 'hoe', '>= 0', :dev
  dependency 'hoe-bundler', '>= 0', :dev
  dependency 'hoe-gemspec', '>= 0', :dev
  dependency 'neo4j-rake_tasks', '>= 0.3.0', :dev
  dependency 'parallel', '>= 0', :dev
  dependency 'rake', '>= 0', :dev
  dependency 'rspec-its', '>= 0', :dev
  dependency 'rspec-mocks', '>= 0', :dev
  dependency 'zeitwerk', '>= 2.1.10'

  spec_extras[:require_paths] = ['lib', pdir]

  self.clean_globs += %w[Gemfile Gemfile.lock *.gemspec lib/org lib/*_jars.rb]

  if ffi?
    dependency 'ffi', '>= 0'
    dependency 'recursive-open-struct', '>= 0'
  else
    dependency 'jar-dependencies', '>= 0'
    dependency 'ruby-maven', '>= 0', :dev

    spec_extras[:requirements] = ->(requirements) { requirements << 'jar org.neo4j.driver, neo4j-java-driver, 1.7.5' }
    spec_extras[:platform] = 'java'
  end
end

# task default: :spec
