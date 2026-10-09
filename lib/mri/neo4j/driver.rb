# frozen_string_literal: true

require 'connection_pool'
require 'neo4j-ruby-driver_loader'
require 'openssl'
require 'socket'
require 'stringio'
require 'tzinfo'

module Neo4j
  # Top-level namespace for the MRI flavour; boots the pure-Ruby Bolt
  # implementation through the shared Zeitwerk loader.
  module Driver
    Loader.load(:mri)
    AuthTokenManager = Internal::InternalAuthTokenManager
  end
end
