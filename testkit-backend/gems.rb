source "https://rubygems.org"

# Specify your gem's dependencies in testkit-backend.gemspec
gemspec

gem "rake", "~> 12.0"
gem "rspec", "~> 3.0"
gem "neo4j-ruby-driver", path: '..'
