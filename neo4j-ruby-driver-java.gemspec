# frozen_string_literal: true

require_relative 'build/gemspec_common'

Gem::Specification.new do |spec|
  spec.platform = 'java'
  common_gemspec(spec, 'jruby')
  spec.add_dependency 'concurrent-ruby-edge', '>= 0.6.0'
  spec.add_dependency 'jar-dependencies', '>= 0.5.5'
  spec.add_development_dependency 'ruby-maven', '>= 0'
  spec.requirements << 'jar org.neo4j.driver, neo4j-java-driver-all, 6.0.3'
  spec.requirements << 'jar org.neo4j.driver, neo4j-java-driver-observation-metrics, 6.0.3'
  # spec.requirements << 'jar org.neo4j.bolt, neo4j-bolt-connection-pooled, 10.1.0'
end
