# frozen_string_literal: true

# Shared boilerplate for the per-impl gemspecs. Each platform-specific
# gemspec sets `spec.platform` and calls `common_gemspec(spec, impl)`.
#
# Two gemspecs is how the same gem name ships in two flavors (the
# nokogiri pattern). Bundler picks which one to evaluate from a
# `path:` source via standard platform matching; `bundle config set
# --local force_ruby_platform true` forces the ruby variant on JRuby.
def common_gemspec(spec, impl)
  spec.name          = 'neo4j-ruby-driver2'
  spec.version       = '0.1.0'
  spec.authors       = ['Neo4j Driver Team']
  spec.email         = ['drivers@neo4j.com']

  spec.summary       = 'Clean Neo4j Bolt driver implementation for Ruby'
  spec.description   = 'A clean, modern implementation of the Neo4j Bolt protocol driver for Ruby'
  spec.homepage      = 'https://github.com/neo4j/neo4j-ruby-driver2'
  spec.license       = 'Apache-2.0'

  spec.required_ruby_version = '>= 3.4.0'

  # The loader reads this to pick the impl tree at runtime
  # (`Gem.loaded_specs['neo4j-ruby-driver2'].metadata['impl']`). It's
  # how the loader stays in sync with the gemspec Bundler/RubyGems
  # actually selected — including the force_ruby_platform override case.
  spec.metadata['impl'] = impl

  if ENV['STAGED_BUILD'] == '1'
    # Pattern 1 staged build (Rakefile): lib/shared/ and lib/<impl>/
    # have been merged into a flat lib/ inside pkg/stage-*/.
    spec.files = Dir['lib/**/*', 'README.md', 'LICENSE']
    spec.require_paths = ['lib']
  else
    # Dev tree: lib/{shared, mri, jruby}/.
    spec.files = Dir['lib/shared/**/*', "lib/#{impl}/**/*", 'README.md', 'LICENSE']
    spec.require_paths = ['lib/shared', "lib/#{impl}"]
  end

  spec.add_dependency 'connection_pool', '~> 3.0'
  spec.add_dependency 'tzinfo', '~> 2.0'
  spec.add_dependency 'zeitwerk', '~> 2.6'

  # csv was a default gem through Ruby 3.3, became a bundled gem in
  # 3.4, so it needs to be in the Gemfile for the load_csv_spec to
  # require 'csv'.
  spec.add_development_dependency 'csv'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rspec-its', '~> 1.3'
end
