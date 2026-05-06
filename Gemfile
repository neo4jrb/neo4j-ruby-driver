# frozen_string_literal: true

source 'https://rubygems.org'

# Default: `gemspec` picks the platform-matching gemspec (MRI on cruby,
# JRuby on java). `NEO4J_DRIVER_FORCE_MRI=1` pins to the MRI gemspec
# regardless of host — used to develop / CI-test the MRI codebase under
# JRuby. (Production consumers use `gem 'neo4j-ruby-driver',
# force_ruby_platform: true` instead; that DSL option exists on `gem`
# but not on `gemspec`, hence the env-var bridge here.)
if ENV['NEO4J_DRIVER_FORCE_MRI'] == '1'
  gemspec name: 'neo4j-ruby-driver'
else
  gemspec
end

group :development, :test do
  gem 'rspec', '~> 3.12'
  gem 'rspec-its', '~> 1.3'
  gem 'async'
  gem 'activesupport'
  gem 'ffaker'
  gem 'bigdecimal'
end
