# frozen_string_literal: true

require 'active_support/core_ext/hash/keys'
require 'active_support/logger'
require 'date'
require 'loader'
require 'neo4j-ruby-driver_jars' if RUBY_PLATFORM.match?(/java/)

Loader.load do |loader|
  jruby_dir = File.expand_path('jruby', File.dirname(File.dirname(__dir__)))
  loader.push_dir(jruby_dir)
  loader.ignore(File.expand_path('neo4j/driver.rb', jruby_dir))
end

module Neo4j
  module Driver
    include_package 'org.neo4j.driver'

    Record = Java::OrgNeo4jDriverInternal::InternalRecord
    Result = Neo4j::Driver::Internal::InternalResult
    Transaction = Neo4j::Driver::Internal::InternalTransaction

    module Net
      include_package 'org.neo4j.driver.net'
    end

    module Summary
      include_package 'org.neo4j.driver.summary'
    end

    module Types
      Entity = Java::OrgNeo4jDriverInternal::InternalEntity
      Node = Java::OrgNeo4jDriverInternal::InternalNode
      Path = Java::OrgNeo4jDriverInternal::InternalPath
      Relationship = Java::OrgNeo4jDriverInternal::InternalRelationship
    end
  end
end

Java::OrgNeo4jDriver::AuthTokens.singleton_class.prepend Neo4j::Driver::Ext::AuthTokens
Java::OrgNeo4jDriver::Bookmark.singleton_class.prepend Neo4j::Driver::Ext::Bookmark::ClassMethods
Java::OrgNeo4jDriver::Query.prepend Neo4j::Driver::Ext::Query
Java::OrgNeo4jDriverInternal::InternalBookmark.include Neo4j::Driver::Ext::Bookmark::InstanceMethods
Java::OrgNeo4jDriverInternal::InternalEntity.include Neo4j::Driver::Ext::InternalEntity
Java::OrgNeo4jDriverInternal::InternalNode.prepend Neo4j::Driver::Ext::InternalNode
Java::OrgNeo4jDriverInternal::InternalPath.include Neo4j::Driver::Ext::StartEndNaming
Java::OrgNeo4jDriverInternal::InternalPath::SelfContainedSegment.include Neo4j::Driver::Ext::StartEndNaming
Java::OrgNeo4jDriverInternal::InternalRecord.prepend Neo4j::Driver::Ext::InternalRecord
Java::OrgNeo4jDriverInternal::InternalRelationship.prepend Neo4j::Driver::Ext::InternalRelationship
Java::OrgNeo4jDriverInternalAsync::InternalAsyncSession.prepend Neo4j::Driver::Ext::Internal::Async::InternalAsyncSession
Java::OrgNeo4jDriverInternalCluster::AddressSet.alias_method :to_a, :to_array
Java::OrgNeo4jDriverInternalCluster::RoutingTableRegistryImpl.include Neo4j::Driver::Ext::Internal::Cluster::RoutingTableRegistryImpl
Java::OrgNeo4jDriverInternalCursor::DisposableAsyncResultCursor.prepend Neo4j::Driver::Ext::Internal::Cursor::DisposableAsyncResultCursor
Java::OrgNeo4jDriverInternalSummary::InternalResultSummary.prepend Neo4j::Driver::Ext::Internal::Summary::InternalResultSummary
Java::OrgNeo4jDriverInternalValue::ValueAdapter.include Neo4j::Driver::Ext::RubyConverter
