#frozen_string_literal: true

# workaround for zeitwerk, without wrapping code in module error:
# expected file ../../neo4j-ruby-driver/lib/platform_requirements.rb to define constant PlatformRequirements, but didn't
# is being thrown
module PlatformRequirements
  unless RUBY_PLATFORM.match?(/java/)
    raise 'In order to use MRI version, SEABOLT_LIB env variable has to be set' if ENV['SEABOLT_LIB']&.length.nil?
  end
end
