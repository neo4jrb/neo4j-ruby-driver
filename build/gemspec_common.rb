# frozen_string_literal: true

# Shared boilerplate for the per-impl gemspecs. Each platform-specific
# gemspec sets `spec.platform` and calls `common_gemspec(spec, impl)`.
#
# Two gemspecs is how the same gem name ships in two flavors (the
# nokogiri pattern). Bundler picks which one to evaluate from a
# `path:` source via standard platform matching; `bundle config set
# --local force_ruby_platform true` forces the ruby variant on JRuby.
def common_gemspec(spec, impl)
  # Single source of truth for the version. In the staged build lib/ is flat
  # (lib/neo4j/…); in the dev tree it's lib/shared/neo4j/….
  require_relative(ENV['STAGED_BUILD'] == '1' ? '../lib/neo4j/driver/version' : '../lib/shared/neo4j/driver/version')

  spec.name          = 'neo4j-ruby-driver'
  spec.version       = Neo4j::Driver::VERSION
  spec.authors       = ['Neo4j Driver Team']
  spec.email         = ['drivers@neo4j.com']

  spec.summary       = 'Clean Neo4j Bolt driver implementation for Ruby'
  spec.description   = 'A clean, modern implementation of the Neo4j Bolt protocol driver for Ruby'
  spec.homepage      = 'https://github.com/neo4jrb/neo4j-ruby-driver'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.4.0'

  if ENV['STAGED_BUILD'] == '1'
    # Pattern 1 staged build (Rakefile): lib/shared/ and lib/<impl>/
    # have been merged into a flat lib/ inside pkg/stage-*/.
    spec.files = Dir['lib/**/*', 'README.md', 'LICENSE.txt']
    spec.require_paths = ['lib']
  else
    # Dev tree: lib/{shared, mri, jruby}/.
    spec.files = Dir['lib/shared/**/*', "lib/#{impl}/**/*", 'README.md', 'LICENSE.txt']
    # Reverted order for jar_dependencies to vendor jars in jruby (the first entry)
    spec.require_paths = ["lib/#{impl}", 'lib/shared']
  end

  spec.add_dependency 'tzinfo', '~> 2.0'
  spec.add_dependency 'zeitwerk', '~> 2.6'

  # csv was a default gem through Ruby 3.3, became a bundled gem in
  # 3.4, so it needs to be in the Gemfile for the load_csv_spec to
  # require 'csv'.
  spec.add_development_dependency 'csv'
  spec.add_development_dependency 'ffaker'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.13'
  spec.add_development_dependency 'rspec-its', '~> 2.0'
  # Pinned to patch level: with a .rubocop_todo.yml baseline, a minor bump can
  # add cops and turn CI red, so bump deliberately and re-run --auto-gen-config.
  spec.add_development_dependency 'rubocop', '~> 1.89.0'
  spec.add_development_dependency 'rubocop-performance', '~> 1.26.0'
end
