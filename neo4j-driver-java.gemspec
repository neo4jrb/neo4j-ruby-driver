# frozen_string_literal: true

require_relative 'build/gemspec_common'

Gem::Specification.new do |spec|
  spec.platform = 'java'
  common_gemspec(spec, 'jruby')
end
