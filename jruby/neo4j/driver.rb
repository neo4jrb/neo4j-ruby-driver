# frozen_string_literal: true

require 'neo4j-ruby-driver_jars'

module Neo4j
  module Driver
    include_package 'org.neo4j.driver.v1'

    module Net
      include_package 'org.neo4j.driver.v1.net'
    end

    module Types
      include_package 'org.neo4j.driver.v1.types'
    end

    def self.after_zeitwerk_load_complete
      Java::OrgNeo4jDriverInternal::InternalDriver.prepend Neo4j::Driver::Ext::InternalDriver
      Java::OrgNeo4jDriverInternal::InternalNode.include Neo4j::Driver::Ext::MapAccessor
      Java::OrgNeo4jDriverInternal::InternalRelationship.include Neo4j::Driver::Ext::MapAccessor
      Java::OrgNeo4jDriverInternal::InternalPath.include Neo4j::Driver::Ext::MapAccessor
      Java::OrgNeo4jDriverInternal::InternalPath.include Neo4j::Driver::Ext::StartEndNaming
      Java::OrgNeo4jDriverInternal::InternalPath::SelfContainedSegment.include Neo4j::Driver::Ext::StartEndNaming
      Java::OrgNeo4jDriverInternal::InternalRecord.prepend Neo4j::Driver::Ext::InternalRecord
      Java::OrgNeo4jDriverInternal::InternalStatementResult.prepend Neo4j::Driver::Ext::InternalStatementResult
      Java::OrgNeo4jDriverV1Exceptions::Neo4jException.include Neo4j::Driver::Ext::ExceptionMapper
      Java::OrgNeo4jDriverInternal::ExplicitTransaction.prepend Neo4j::Driver::Ext::RunOverride
      Java::OrgNeo4jDriverInternal::NetworkSession.prepend Neo4j::Driver::Ext::RunOverride
      Java::OrgNeo4jDriverInternalValue::ValueAdapter.include Neo4j::Driver::Ext::RubyConverter
      Java::OrgNeo4jDriverV1::GraphDatabase.singleton_class.prepend Neo4j::Driver::Ext::GraphDatabase
    end
  end
end
