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
  gem 'ffaker'
  gem 'nio4r'
  gem 'ostruct'
  gem 'rspec', '~> 3.12'
  gem 'rspec-its', '~> 1.3'
  gem 'rubocop', '~> 1.89.0', require: false
  gem 'rubocop-performance', '~> 1.26.0', require: false
end
