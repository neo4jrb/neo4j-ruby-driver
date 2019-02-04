# frozen_string_literal: true

require 'date'

module Neo4j
  module Driver
    module Ext
      module RubyConverter
        def as_ruby_object
          case type_constructor
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::LIST
            java_method(:asList, [org.neo4j.driver.v1.util.Function]).call(&:as_ruby_object).to_a
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::MAP
            as_map(->(x) { x.as_ruby_object }, nil).to_hash.symbolize_keys
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::DATE
            date = as_local_date
            Date.new(date.year, date.month_value, date.day_of_month)
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::DURATION
            ActiveSupport::Duration.build(as_iso_duration.seconds)
          when Java::OrgNeo4jDriverInternalTypes::TypeConstructor::POINT
            point = as_point
            Neo4j::Driver::Point.new(point.srid, point.x, point.y)
          else
            as_object
          end
        end
      end
    end
  end
end
