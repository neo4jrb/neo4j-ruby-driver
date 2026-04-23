# frozen_string_literal: true

# Standalone helper for the PuppyGraph integration spec.
# Intentionally avoids loading spec/spec_helper.rb because that helper installs
# a before(:suite) hook that connects to a real Neo4j instance for cleanup.
$LOAD_PATH.unshift File.expand_path('../../ruby', __dir__)
require 'async'
require 'neo4j/driver'
