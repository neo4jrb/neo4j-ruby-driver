# frozen_string_literal: true

require 'neo4j-ruby-driver_jars'
require 'neo4j-ruby-driver_loader'

module Neo4j
  module Driver
    Loader.load(:jruby) do |loader|
      impl_root = File.expand_path('..', __dir__)
      loader.ignore(File.expand_path('org', impl_root))
      loader.ignore(File.expand_path('neo4j-ruby-driver_jars.rb', impl_root))
    end

    include_package 'org.neo4j.driver'

    EagerResult = Java::OrgNeo4jDriverInternal::EagerResultValue
    Record = Java::OrgNeo4jDriverInternal::InternalRecord
    Result = Java::OrgNeo4jDriverInternal::InternalResult
    Transaction = Java::OrgNeo4jDriverInternal::DelegatingTransactionContext

    module Internal
      java_import org.neo4j.driver.internal.shaded.bolt.connection.DatabaseName
    end

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
Java::OrgNeo4jDriver::BookmarkManager.include Neo4j::Driver::Ext::BookmarkManager
Java::OrgNeo4jDriver::BookmarkManagers.singleton_class.prepend Neo4j::Driver::Ext::BookmarkManagers
Java::OrgNeo4jDriver::GraphDatabase.singleton_class.prepend Neo4j::Driver::Ext::GraphDatabase
Java::OrgNeo4jDriver::Query.prepend Neo4j::Driver::Ext::Query
Java::OrgNeo4jDriverInternal::EagerResultValue.prepend Neo4j::Driver::Ext::Internal::EagerResultValue
Java::OrgNeo4jDriverInternal::InternalDriver.prepend Neo4j::Driver::Ext::InternalDriver
Java::OrgNeo4jDriverInternal::InternalEntity.include Neo4j::Driver::Ext::InternalEntity
Java::OrgNeo4jDriverInternal::InternalNode.prepend Neo4j::Driver::Ext::InternalNode
Java::OrgNeo4jDriverInternal::InternalNotificationSeverity.include  Neo4j::Driver::Ext::Internal::InternalNotificationSeverity
Java::OrgNeo4jDriverInternal::InternalPath.include Neo4j::Driver::Ext::StartEndNaming
Java::OrgNeo4jDriverInternal::InternalPath::SelfContainedSegment.include Neo4j::Driver::Ext::StartEndNaming
Java::OrgNeo4jDriverInternal::InternalRecord.prepend Neo4j::Driver::Ext::InternalRecord
Java::OrgNeo4jDriverInternal::InternalRelationship.prepend Neo4j::Driver::Ext::InternalRelationship
Java::OrgNeo4jDriverInternal::InternalResult.prepend Neo4j::Driver::Ext::InternalResult
Java::OrgNeo4jDriverInternal::InternalSession.prepend Neo4j::Driver::Ext::InternalSession
Java::OrgNeo4jDriverInternal::InternalTransaction.prepend Neo4j::Driver::Ext::InternalTransaction
Java::OrgNeo4jDriverInternal::DelegatingTransactionContext.prepend Neo4j::Driver::Ext::Internal::AbstractQueryRunner
Java::OrgNeo4jDriverInternalAsync::InternalAsyncSession.prepend Neo4j::Driver::Ext::Internal::Async::InternalAsyncSession
Java::OrgNeo4jDriverInternalShadedBoltConnectionRoutedImplCluster::RoutingTableRegistryImpl.include Neo4j::Driver::Ext::Internal::Cluster::RoutingTableRegistryImpl
# Java::OrgNeo4jDriverInternalCursor::DisposableAsyncResultCursor.prepend Neo4j::Driver::Ext::Internal::Cursor::DisposableAsyncResultCursor
Java::OrgNeo4jDriverObservationMetricsInternal::InternalConnectionPoolMetrics.include Neo4j::Driver::Ext::Internal::Metrics::InternalConnectionPoolMetrics
Java::OrgNeo4jDriverInternalSummary::InternalNotification.prepend Neo4j::Driver::Ext::Internal::Summary::InternalNotification
Java::OrgNeo4jDriverInternalSummary::InternalPlan.prepend Neo4j::Driver::Ext::Internal::Summary::InternalPlan
Java::OrgNeo4jDriverInternalSummary::InternalResultSummary.prepend Neo4j::Driver::Ext::Internal::Summary::InternalResultSummary
Java::OrgNeo4jDriverInternalValue::ValueAdapter.include Neo4j::Driver::Ext::RubyConverter
