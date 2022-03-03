# frozen_string_literal: true

require 'active_support/core_ext/hash/keys'
require 'active_support/logger'
require 'concurrent-edge'
require 'ione'
require 'date'
require 'loader'
require 'socket'

Loader.load
# Loader.load do |loader|
#   jruby_dir = File.expand_path('jruby', File.dirname(File.dirname(__dir__)))
#   loader.push_dir(jruby_dir)
#   loader.ignore(File.expand_path('neo4j/driver.rb', jruby_dir))
#   # %w[
#   #   internal/bolt_server_address
#   #   net/server_address
#   # ].each {|file| loader.ignore(File.expand_path("neo4j/driver/#{file}.rb", __dir__))}
# end

module Neo4j
  module Driver
    # include_package 'org.neo4j.driver'

    Record = Neo4j::Driver::Internal::InternalRecord
    Result = Neo4j::Driver::Internal::InternalResult
    Transaction = Neo4j::Driver::Internal::InternalTransaction

    # module Net
      # include_package 'org.neo4j.driver.net'
    # end

    # module Summary
      # include_package 'org.neo4j.driver.summary'
    # end

    module Types
      Entity = Neo4j::Driver::Internal::InternalEntity
      Node = Neo4j::Driver::Internal::InternalNode
      Path = Neo4j::Driver::Internal::InternalPath
      Relationship = Neo4j::Driver::Internal::InternalRelationship
    end
  end
end

# Java::OrgNeo4jDriver::Bookmark.singleton_class.prepend Neo4j::Driver::Ext::Bookmark::ClassMethods
# Java::OrgNeo4jDriver::Query.prepend Neo4j::Driver::Ext::Query
# Java::OrgNeo4jDriverInternal::InternalBookmark.include Neo4j::Driver::Ext::Bookmark::InstanceMethods
# Java::OrgNeo4jDriverInternal::InternalEntity.include Neo4j::Driver::Ext::InternalEntity
# Java::OrgNeo4jDriverInternal::InternalNode.prepend Neo4j::Driver::Ext::InternalNode
# Java::OrgNeo4jDriverInternal::InternalPath.include Neo4j::Driver::Ext::StartEndNaming
# Java::OrgNeo4jDriverInternal::InternalPath::SelfContainedSegment.include Neo4j::Driver::Ext::StartEndNaming
# Java::OrgNeo4jDriverInternal::InternalRecord.prepend Neo4j::Driver::Ext::InternalRecord
# Java::OrgNeo4jDriverInternal::InternalRelationship.prepend Neo4j::Driver::Ext::InternalRelationship
# Java::OrgNeo4jDriverInternalAsync::InternalAsyncSession.prepend Neo4j::Driver::Ext::Internal::Async::InternalAsyncSession
# Java::OrgNeo4jDriverInternalCluster::RoutingTableRegistryImpl.include Neo4j::Driver::Ext::Internal::Cluster::RoutingTableRegistryImpl
# Java::OrgNeo4jDriverInternalCursor::DisposableAsyncResultCursor.prepend Neo4j::Driver::Ext::Internal::Cursor::DisposableAsyncResultCursor
# Java::OrgNeo4jDriverInternalSummary::InternalResultSummary.prepend Neo4j::Driver::Ext::Internal::Summary::InternalResultSummary
# Java::OrgNeo4jDriverInternalValue::ValueAdapter.include Neo4j::Driver::Ext::RubyConverter
