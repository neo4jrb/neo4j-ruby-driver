require 'neo4j/driver/version'

require 'neo4j-ruby-driver_jars'
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

    module Net
      include_package 'org.neo4j.driver.v1.net'
    end

    module Types
      include_package 'org.neo4j.driver.v1.types'
    end

    module RunOverride
      def run(statement, parameters = {})
        java_method(:run, [java.lang.String, java.util.Map]).call(statement, to_neo(parameters))
      rescue Java::OrgNeo4jDriverV1Exceptions::Neo4jException => e
        raise Neo4j::Driver::Exceptions::Neo4jException, e.message
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
      # puts "****************************************"
      # puts hash.inspect
      # puts "****************************************"
      build = Neo4j::Driver::Config.build
      build2 = hash.reduce(build) { |object, key_value| object.send(*config_method(*key_value)) }
      build2.to_config
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
  def values
    java_send(:values).map(&:as_ruby_object)
  end

  define_method(:[]) do |key|
    java_method(:get, [java.lang.String]).call(key.to_s).as_ruby_object
  end

  def first
    java_method(:get, [Java::int]).call(0).as_ruby_object
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

class Java::OrgNeo4jDriverInternalValue::ValueAdapter
  def as_ruby_object
    case type_constructor
    when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::LIST
      java_method(:asList, [org.neo4j.driver.v1.util.Function]).call(&:as_ruby_object).to_a
    when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::MAP
      as_map(->(x) { x.as_ruby_object }, nil).to_hash.symbolize_keys
    when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::DATE
      date = as_local_date
      Date.new(date.year, date.month_value, date.day_of_month)
    else
      as_object
    end
  end
end
