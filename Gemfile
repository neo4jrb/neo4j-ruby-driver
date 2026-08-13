# frozen_string_literal: true

source 'https://rubygems.org'

# Default: `gemspec` picks the platform-matching gemspec (MRI on cruby,
# JRuby on java). `NEO4J_DRIVER_FORCE_MRI=1` pins to the MRI gemspec
# regardless of host — used to develop / CI-test the MRI codebase under
# JRuby. (Production consumers use `gem 'neo4j-ruby-driver',
# force_ruby_platform: true` instead; that DSL option exists on `gem`
# but not on `gemspec`, hence the env-var bridge here.)
if ENV['NEO4J_DRIVER_FORCE_MRI'] == '1'
  # Both `name:` and `glob:` are required: `name:` narrows the initial
  # gemspec lookup, but `gemspec` forwards to an implicit path source
  # whose default glob (`{,*,*/*}.gemspec`) would otherwise re-discover
  # neo4j-ruby-driver-java.gemspec — and Bundler's resolver would then
  # pick the java variant on a JRuby host, defeating the override.
  gemspec name: 'neo4j-ruby-driver', glob: 'neo4j-ruby-driver.gemspec'
else
  gemspec
end

group :development, :test do
  gem 'activesupport'
  gem 'async'
  gem 'bigdecimal'
  gem 'concurrent-ruby' # concurrency specs (session_spec: Promises/latches) + testkit-backend fake clock
  # csv was a default gem through Ruby 3.3 and a bundled gem in 3.4, so the
  # load_csv_spec needs it declared to `require 'csv'`.
  gem 'csv'
  gem 'ffaker'
  gem 'nio4r'
  gem 'ostruct'
  gem 'rake', '~> 13.0'
  gem 'rspec', '~> 3.13'
  gem 'rspec-its', '~> 2.0'
  # Pinned to patch level: with a .rubocop_todo.yml baseline, a minor bump can
  # add cops and turn CI red, so bump deliberately and re-run --auto-gen-config.
  gem 'rubocop', '~> 1.89.0', require: false
  gem 'rubocop-performance', '~> 1.26.0', require: false
end
