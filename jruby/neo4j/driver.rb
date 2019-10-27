# frozen_string_literal: true

require 'active_support/core_ext/hash/keys'
require 'active_support/logger'
require 'date'
require 'loader'
require 'neo4j-java-driver_jars'

module Neo4j
  module Driver
    include_package 'org.neo4j.driver.v1'

    module Net
      include_package 'org.neo4j.driver.v1.net'
    end

    module Summary
      include_package 'org.neo4j.driver.v1.summary'
    end

    module Types
      Entity = Java::OrgNeo4jDriverInternal::InternalEntity
      Node = Java::OrgNeo4jDriverInternal::InternalNode
      Path = Java::OrgNeo4jDriverInternal::InternalPath
      Relationship = Java::OrgNeo4jDriverInternal::InternalRelationship
    end

    # Workaround for missing zeitwerk support in jruby-9.2.8.0
    module Ext
      module Internal
        module Summary
        end
      end
    end
    # End workaround
  end
end

Loader.load

ActiveSupport::Logger.prepend Neo4j::Driver::Ext::Logger
Java::OrgNeo4jDriverInternal::InternalDriver.prepend Neo4j::Driver::Ext::InternalDriver
Java::OrgNeo4jDriverInternal::InternalEntity.include Neo4j::Driver::Ext::MapAccessor
Java::OrgNeo4jDriverInternal::InternalNode.prepend Neo4j::Driver::Ext::InternalNode
Java::OrgNeo4jDriverInternal::InternalPath.include Neo4j::Driver::Ext::StartEndNaming
Java::OrgNeo4jDriverInternal::InternalPath::SelfContainedSegment.include Neo4j::Driver::Ext::StartEndNaming
Java::OrgNeo4jDriverInternal::InternalRecord.prepend Neo4j::Driver::Ext::InternalRecord
Java::OrgNeo4jDriverInternal::InternalRelationship.prepend Neo4j::Driver::Ext::InternalRelationship
Java::OrgNeo4jDriverInternal::InternalStatementResult.prepend Neo4j::Driver::Ext::InternalStatementResult
Java::OrgNeo4jDriverInternal::ExplicitTransaction.prepend Neo4j::Driver::Ext::RunOverride
Java::OrgNeo4jDriverInternal::NetworkSession.prepend Neo4j::Driver::Ext::RunOverride
Java::OrgNeo4jDriverInternalSummary::InternalResultSummary.prepend Neo4j::Driver::Ext::Internal::Summary::InternalResultSummary
Java::OrgNeo4jDriverInternalValue::ValueAdapter.include Neo4j::Driver::Ext::RubyConverter
Java::OrgNeo4jDriverV1::AuthTokens.singleton_class.prepend Neo4j::Driver::Ext::AuthTokens
Java::OrgNeo4jDriverV1::GraphDatabase.singleton_class.prepend Neo4j::Driver::Ext::GraphDatabase
Java::OrgNeo4jDriverV1::Statement.prepend Neo4j::Driver::Ext::Statement
Java::OrgNeo4jDriverV1Exceptions::Neo4jException.include Neo4j::Driver::Ext::ExceptionMapper
