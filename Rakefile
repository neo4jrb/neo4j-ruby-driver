# frozen_string_literal: true

require 'rubygems'
require 'hoe'
require 'stringio'

Hoe.plugin :bundler
Hoe.plugin :gemspec

def jruby?
  RUBY_PLATFORM == 'java'
end

HOE = Class.new(Hoe) do
  def read_manifest
    Dir[*%w[README.md LICENSE.txt lib/neo4j-ruby-driver.rb lib/neo4j_ruby_driver.rb lib/neo4j-ruby-driver_loader.rb]] +
      Dir['lib/neo4j/**/*.rb'] +
      Dir["#{jruby? ? 'jruby' : 'ruby'}/**/*.rb"]
  end
end.spec 'neo4j-ruby-driver' do
  developer 'Heinrich Klobuczek', 'heinrich@mail.com'
  self.urls = { 'home' => 'https://github.com/neo4jrb/neo4j-ruby-driver' }

  active_support_version = ENV['ACTIVE_SUPPORT_VERSION']
  dependency 'activesupport', active_support_version&.length&.positive? ? "~> #{active_support_version}" : '>= 7.1'
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

  require_ruby_version '>= 3.1'

  if jruby?
    dependency 'async', '< 2', :dev
    dependency 'concurrent-ruby-edge', '>= 0.6.0'
    dependency 'jar-dependencies', '>= 0.5.5'
    dependency 'ruby-maven', '>= 0', :dev

    spec_extras[:requirements] = ->(requirements) { requirements << 'jar org.neo4j.driver, neo4j-java-driver-all, 5.28.4' }
    spec_extras[:platform] = 'java'
  else
    dependency 'async', '< 2.13'
    dependency 'async-io', '>= 0'
    dependency 'connection_pool', '>= 0'
    dependency 'csv', '>= 0'
  end
end

# task default: :spec
