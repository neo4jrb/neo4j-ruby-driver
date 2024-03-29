# frozen_string_literal: true

require 'active_support/core_ext/array/grouping'
require 'active_support/core_ext/hash/keys'
require 'active_support/logger'
require 'async/io'
require 'async/io/stream'
require 'async/queue'
require 'bigdecimal'
require 'connection_pool'
require 'neo4j-ruby-driver_loader'

module Neo4j
  module Driver
    Loader.load

    Record = Neo4j::Driver::Internal::InternalRecord
    Result = Neo4j::Driver::Internal::InternalResult
    Transaction = Neo4j::Driver::Internal::InternalTransaction

    module Types
      Entity = Neo4j::Driver::Internal::InternalEntity
      Node = Neo4j::Driver::Internal::InternalNode
      Path = Neo4j::Driver::Internal::InternalPath
      Relationship = Neo4j::Driver::Internal::InternalRelationship
    end
  end
end