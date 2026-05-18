# frozen_string_literal: true

require 'connection_pool'
require 'forwardable'
require 'neo4j-ruby-driver_loader'
require 'set'
require 'socket'
require 'stringio'
require 'time'
require 'tzinfo'

module Neo4j
  module Driver
    Loader.load(:mri)
  end
end
