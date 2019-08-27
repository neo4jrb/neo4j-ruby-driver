# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'neo4j/driver/version'
require 'platform_requirements'

PlatformRequirements.run_checks!

Gem::Specification.new do |spec|
  ffi = ENV.key?('SEABOLT_LIB')

  spec.name = "neo4j-#{ffi ? :ruby : :java}-driver"
  spec.version = Neo4j::Driver::VERSION
  spec.authors = ['Heinrich Klobuczek']
  spec.email = ['heinrich@mail.com']

  spec.summary = 'neo4j ruby driver'
  spec.homepage = 'https://github.com/neo4jrb/neo4j-ruby-driver'
  spec.license = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org/'

    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/neo4jrb/neo4j-ruby-driver'
    # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  spec.files << Dir[*%w[neo4j-ruby-driver.gemspec Rakefile README.md LICENSE.txt Gemfile lib/neo4j_ruby_driver.rb lib/loader.rb]]

  pdir = ffi ? 'ffi' : 'jruby'
  #jruby = RUBY_PLATFORM.match?(/java/)
  #pdir = if ENV.key?('SEABOLT_LIB')
  #         'ffi'
  #       else
  #         jruby ? 'jruby' : 'ffi'
  #       end

  spec.files << Dir['lib/neo4j/**/*.rb']
  spec.files << Dir["#{pdir}/**/*.rb"]
  spec.files << Dir["#{pdir}/**/*.jar"]

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib', pdir]

  spec.platform = 'java' if RUBY_PLATFORM.match?(/java/)

  if ffi
    spec.add_runtime_dependency 'ffi'
    spec.add_runtime_dependency 'recursive-open-struct'
  else
    spec.add_runtime_dependency 'jar-dependencies'
    spec.requirements << 'jar org.neo4j.driver, neo4j-java-driver, 1.7.5'
    # avoids to install it on the fly when jar-dependencies needs it
    spec.add_development_dependency 'ruby-maven'
  end

  spec.add_runtime_dependency 'activesupport'
  spec.add_runtime_dependency 'zeitwerk'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'ffaker'
  spec.add_development_dependency 'neo4j-rake_tasks', '>= 0.3.0'
  spec.add_development_dependency 'parallel'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec-its'
end
