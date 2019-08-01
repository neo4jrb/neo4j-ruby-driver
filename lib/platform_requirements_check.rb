unless RUBY_PLATFORM.match?(/java/)
  raise 'In order to use MRI version, SEABOLT_LIB env variable has to be set' if ENV['SEABOLT_LIB']&.length.nil?
end