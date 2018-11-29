require "neo4j/driver/version"

require 'neo4j-java_driver_jars'
require 'active_support/core_ext/hash/keys'
require 'date'

module Neo4j
  module Driver
    include_package 'org.neo4j.driver.v1'

    module Exceptions
      include_package 'org.neo4j.driver.v1.exceptions'

      class ServiceUnavailableException < Exception
      end
    end

    module Types
      include_package 'org.neo4j.driver.v1.types'
    end

    module RunOverride
      def run(statement, parameters = {})
        java_method(:run, [java.lang.String, java.util.Map]).call(statement, to_neo(parameters))
      rescue Java::OrgNeo4jDriverV1Exceptions::NoSuchRecordException => e
        raise Neo4j::Driver::Exceptions::NoSuchRecordException, e.message
      end

      private

      def to_neo(object)
        if object.is_a? Hash
          object.map { |key, value| [key.to_s, to_neo(value)] }.to_h
        elsif object.is_a? Date
          Java::JavaTime::LocalDate.of(object.year, object.month, object.day)
        else
          object
        end
      end
    end

    module MapAccessor
      def properties
        as_map.to_hash.symbolize_keys
      end
    end
  end
end

class Java::OrgNeo4jDriverV1::GraphDatabase
  class << self
    def driver(uri, auth_token = Neo4j::Driver::AuthTokens.none, config = {})
      java_method(:driver, [java.lang.String, org.neo4j.driver.v1.AuthToken, org.neo4j.driver.v1.Config])
        .call(uri, auth_token, to_java_config(config))
    rescue Java::OrgNeo4jDriverV1Exceptions::ServiceUnavailableException => e
      raise Neo4j::Driver::Exceptions::ServiceUnavailableException, e.message
    end

    private

    def to_java_config(hash)
      hash.reduce(Neo4j::Driver::Config.build) { |object, key_value| object.send(*config_method(*key_value)) }
        .to_config
    end

    def config_method(key, value)
      return :without_encryption if key == :encryption && !value

      [:"with_#{key}", value, (java.util.concurrent.TimeUnit::SECONDS if key.to_s =~ /Time(out)?$/i)].compact
    end
  end
end

class Java::OrgNeo4jDriverInternal::InternalNode
  include Neo4j::Driver::MapAccessor
end

class Java::OrgNeo4jDriverInternal::InternalRelationship
  include Neo4j::Driver::MapAccessor
end

class Java::OrgNeo4jDriverInternal::InternalPath
  include Neo4j::Driver::MapAccessor
end

class Java::OrgNeo4jDriverInternal::InternalRecord
  # java_alias :to_a, :values

  define_method(:[]) do |key|
    wrap_value(java_method(:get, [java.lang.String]).call(key.to_s))
  end

  def first
    wrap_value(java_method(:get, [Java::int]).call(0))
  end

  def wrap_value(value)
    case value.type_constructor
    when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::NODE
      value.as_node
    when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::RELATIONSHIP
      value.as_relationship
    when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::PATH
      value.as_path
    when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::LIST
      value.java_method(:asList, [org.neo4j.driver.v1.util.Function]).call(&method(:wrap_value)).to_a
    when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::MAP
      value.as_map(->(x) { wrap_value(x) }, nil).to_hash.symbolize_keys
    when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::DATE
      date = value.as_local_date
      Date.new(date.year, date.month_value, date.day_of_month)
    else
      value.as_object
    end
  end
end


class Java::OrgNeo4jDriverInternal::ExplicitTransaction
  include Neo4j::Driver::RunOverride

  def run(statement, parameters = {})
    super
  end
end

class Java::OrgNeo4jDriverInternal::NetworkSession
  include Neo4j::Driver::RunOverride

  def run(statement, parameters = {})
    super
  end
end