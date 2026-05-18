# frozen_string_literal: true

require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/object/blank'
require 'connection_pool'
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
