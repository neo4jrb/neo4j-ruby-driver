require_relative 'lib/testkit/backend/version'

Gem::Specification.new do |spec|
  spec.name          = "testkit-backend"
  spec.version       = Testkit::Backend::VERSION
  spec.authors       = ["Heinrich Klobuczek"]
  spec.email         = ["heinrich@mail.com"]

  spec.summary       = %q{testkit backend for neo4j-ruby-driver}
  # spec.description   = %q{TODO: Write a longer description or delete this line.}
  # spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.6")

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  # spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
  #   `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  # end
  spec.files = Dir.glob('{bin,lib,config}/**/*') + %w(README.md Gemfile testkit-backend.gemspec)
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'async-io'
  spec.add_dependency 'nio4r'
  spec.add_dependency 'zeitwerk'
  spec.add_dependency 'activesupport'
  spec.add_development_dependency 'rspec'
  # spec.add_development_dependency "async-rspec", "~> 1.10"
end
