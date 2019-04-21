# frozen_string_literal: true

require 'neo4j-ruby-driver_jars'
require 'neo4j/driver/ext/exception_checkable'
require 'neo4j/driver/ext/exception_mapper'
require 'neo4j/driver/ext/graph_database'
require 'neo4j/driver/ext/internal_driver'
require 'neo4j/driver/ext/internal_record'
require 'neo4j/driver/ext/internal_statement_result'
require 'neo4j/driver/ext/map_accessor'
require 'neo4j/driver/ext/ruby_converter'
require 'neo4j/driver/ext/run_override'
require 'neo4j/driver/version'

Java::OrgNeo4jDriverInternal::InternalDriver.prepend Neo4j::Driver::Ext::InternalDriver
Java::OrgNeo4jDriverInternal::InternalNode.include Neo4j::Driver::Ext::MapAccessor
Java::OrgNeo4jDriverInternal::InternalRelationship.include Neo4j::Driver::Ext::MapAccessor
Java::OrgNeo4jDriverInternal::InternalPath.include Neo4j::Driver::Ext::MapAccessor
Java::OrgNeo4jDriverInternal::InternalRecord.prepend Neo4j::Driver::Ext::InternalRecord
Java::OrgNeo4jDriverInternal::InternalStatementResult.prepend Neo4j::Driver::Ext::InternalStatementResult
Java::OrgNeo4jDriverV1Exceptions::Neo4jException.include Neo4j::Driver::Ext::ExceptionMapper
Java::OrgNeo4jDriverInternal::ExplicitTransaction.prepend Neo4j::Driver::Ext::RunOverride
Java::OrgNeo4jDriverInternal::NetworkSession.prepend Neo4j::Driver::Ext::RunOverride
Java::OrgNeo4jDriverInternalValue::ValueAdapter.include Neo4j::Driver::Ext::RubyConverter
Java::OrgNeo4jDriverV1::GraphDatabase.singleton_class.prepend Neo4j::Driver::Ext::GraphDatabase

module Neo4j
  module Driver
    include_package 'org.neo4j.driver.v1'

    module Net
      include_package 'org.neo4j.driver.v1.net'
    end

    module Types
      include_package 'org.neo4j.driver.v1.types'
    end
  end
end
