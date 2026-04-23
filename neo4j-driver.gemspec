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

  spec.required_ruby_version = '>= 3.2.0'

  spec.files = Dir['lib/**/*', 'README.md', 'LICENSE']
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'connection_pool', '~> 3.0'
  spec.add_dependency 'zeitwerk', '~> 2.6'

  # Development dependencies
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rspec-its', '~> 1.3'
end
