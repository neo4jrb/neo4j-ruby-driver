# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'neo4j-ruby-driver2'
  spec.version       = '0.1.0'
  spec.authors       = ['Neo4j Driver Team']
  spec.email         = ['drivers@neo4j.com']

  spec.summary       = 'Clean Neo4j Bolt driver implementation for Ruby'
  spec.description   = 'A clean, modern implementation of the Neo4j Bolt protocol driver for Ruby'
  spec.homepage      = 'https://github.com/neo4j/neo4j-ruby-driver2'
  spec.license       = 'Apache-2.0'

  spec.required_ruby_version = '>= 3.4.0'

  # Two evaluation modes:
  #   - Dev tree (default): lib/{shared, mri, jruby}/. Bundler reads
  #     this when resolving the gem from a path/git source, and when
  #     loading the gem in development. Picks the impl from RUBY_PLATFORM.
  #   - Staged build (STAGED_BUILD=1): the Rakefile has merged
  #     lib/shared/ and lib/<impl>/ into a flat lib/ inside pkg/stage-*.
  #     `gem build` runs there with this gemspec; we emit a flat-lib
  #     spec so the published .gem looks like a normal one-platform gem.
  #     GEM_TARGET picks the platform suffix (jruby → -java).
  if ENV['STAGED_BUILD']
    spec.files = Dir['lib/**/*', 'README.md', 'LICENSE']
    spec.require_paths = ['lib']
    spec.platform = ENV['GEM_TARGET'] == 'jruby' ? 'java' : Gem::Platform::RUBY
  else
    impl_dir = (RUBY_PLATFORM == 'java') ? 'jruby' : 'mri'
    spec.files = Dir['lib/shared/**/*', "lib/#{impl_dir}/**/*", 'README.md', 'LICENSE']
    spec.require_paths = ['lib/shared', "lib/#{impl_dir}"]
    spec.platform = 'java' if RUBY_PLATFORM == 'java'
  end

  # Runtime dependencies
  spec.add_dependency 'connection_pool', '~> 3.0'
  spec.add_dependency 'tzinfo', '~> 2.0'
  spec.add_dependency 'zeitwerk', '~> 2.6'

  # Development dependencies
  # csv was a default gem through Ruby 3.3, became a bundled gem in
  # 3.4, so it needs to be in the Gemfile for the load_csv_spec to
  # require 'csv'.
  spec.add_development_dependency 'csv'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rspec-its', '~> 1.3'
end
