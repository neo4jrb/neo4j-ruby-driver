# frozen_string_literal: true

require 'rubygems'
require 'hoe'

Hoe.plugin :bundler
Hoe.plugin :gemspec

def jruby?
  RUBY_PLATFORM == 'java'
end

HOE = Class.new(Hoe) do
  def read_manifest
    Dir[*%w[README.md LICENSE.txt lib/neo4j_ruby_driver.rb lib/loader.rb]] +
      Dir['lib/neo4j/**/*.rb'] +
      Dir["#{jruby? ? 'jruby' : 'ruby'}/**/*.rb"]
  end
end.spec 'neo4j-ruby-driver' do
  developer 'Heinrich Klobuczek', 'heinrich@mail.com'

  dependency 'activesupport', '>= 0'
  dependency 'async', '>= 0'
  # dependency 'async-rspec', '>= 0', :dev
  dependency 'ffaker', '>= 0', :dev
  dependency 'hoe', '>= 0', :dev
  dependency 'hoe-bundler', '>= 0', :dev
  dependency 'hoe-gemspec', '>= 0', :dev
  dependency 'rake', '>= 0', :dev
  dependency 'rspec-its', '>= 0', :dev
  dependency 'rspec-mocks', '>= 0', :dev
  dependency 'zeitwerk', '>= 2.1.10'

  spec_extras[:require_paths] = ['lib', jruby? ? 'jruby' : 'ruby']

  self.clean_globs += %w[Gemfile Gemfile.lock *.gemspec lib/org lib/*_jars.rb]

  if jruby?
    require_ruby_version '>= 2.6'
    dependency 'concurrent-ruby-edge', '>= 0.6.0'
    dependency 'jar-dependencies', '>= 0'
    dependency 'ruby-maven', '>= 0', :dev

    spec_extras[:requirements] = ->(requirements) { requirements << 'jar org.neo4j.driver, neo4j-java-driver, 4.4.6' }
    spec_extras[:platform] = 'java'
  else
    require_ruby_version '>= 3.1'
    dependency 'async-io', '>= 0'
    dependency 'async-pool', '>= 0'
  end
end

# task default: :spec
