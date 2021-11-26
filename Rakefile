# frozen_string_literal: true

require 'rubygems'
require 'hoe'

Hoe.plugin :bundler
Hoe.plugin :gemspec

def pdir
  case ENV['driver']
  when 'java'
    'jruby'
  when 'ruby'
    'ruby'
  else
    'ffi'
  end
end

def gem_name
  ENV['driver'] == 'java' ? 'neo4j-java-driver' : 'neo4j-ruby-driver'
end

HOE = Class.new(Hoe) do
  def read_manifest
    Dir[*%w[README.md LICENSE.txt lib/neo4j_ruby_driver.rb lib/loader.rb]] +
      Dir['lib/neo4j/**/*.rb'] +
      Dir["#{pdir}/**/*.rb"]
  end
end.spec gem_name do
  developer 'Heinrich Klobuczek', 'heinrich@mail.com'
  require_ruby_version '>= 2.6'

  dependency 'activesupport', '>= 0'
  dependency 'ffaker', '>= 0', :dev
  dependency 'hoe', '>= 0', :dev
  dependency 'bundler', '2.2.31', :dev
  dependency 'hoe-bundler', '>= 0', :dev
  dependency 'hoe-gemspec', '>= 0', :dev
  dependency 'parallel', '>= 0', :dev
  dependency 'rake', '>= 0', :dev
  dependency 'rspec-its', '>= 0', :dev
  dependency 'rspec-mocks', '>= 0', :dev
  dependency 'zeitwerk', '>= 2.1.10'

  spec_extras[:require_paths] = ['lib', pdir]

  self.clean_globs += %w[Gemfile Gemfile.lock *.gemspec lib/org lib/*_jars.rb]

  if pdir == 'ffi'
    dependency 'ffi', '>= 0'
    dependency 'recursive-open-struct', '>= 0'
  elsif RUBY_PLATFORM.match?(/java/)
    dependency 'jar-dependencies', '>= 0'
    dependency 'ruby-maven', '>= 0', :dev

    spec_extras[:requirements] = ->(requirements) { requirements << 'jar org.neo4j.driver, neo4j-java-driver, 4.4.1' }
    spec_extras[:platform] = 'java'
  end
end

# task default: :spec
