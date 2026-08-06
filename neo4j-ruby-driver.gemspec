# frozen_string_literal: true

require_relative 'build/gemspec_common'

Gem::Specification.new do |spec|
  spec.platform = Gem::Platform::RUBY
  common_gemspec(spec, 'mri')
  spec.add_dependency 'connection_pool', '~> 3.0'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
