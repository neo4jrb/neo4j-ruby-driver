require "bundler/gem_tasks"
require "rspec/core/rake_task"

require 'jars/installer'
task :install_jars do
  Jars::Installer.vendor_jars!
end

RSpec::Core::RakeTask.new(:spec)

task :default => :spec
