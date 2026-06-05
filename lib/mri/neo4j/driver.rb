# frozen_string_literal: true

require 'connection_pool'
require 'neo4j-ruby-driver_loader'
require 'openssl'
require 'set'
require 'socket'
require 'stringio'
require 'tzinfo'

module Neo4j
  module Driver
    Loader.load(:mri)
    AuthTokenManager = Internal::AuthTokenManager
  end
end
