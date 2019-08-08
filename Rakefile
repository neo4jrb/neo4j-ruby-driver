# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'neo4j/rake_tasks'

if RUBY_PLATFORM.match?(/java/) && ENV.key?('SEABOLT_LIB')
  require 'jars/installer'
  task :install_jars do
    Jars::Installer.vendor_jars!('jruby')
  end
end

RSpec::Core::RakeTask.new(:spec)

task default: :spec
