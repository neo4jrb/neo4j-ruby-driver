# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module RunOverride
        def run(statement, parameters = {})
          java_method(:run, [java.lang.String, java.util.Map]).call(statement, to_neo(parameters))
        rescue Java::OrgNeo4jDriverV1Exceptions::Neo4jException => e
          e.reraise
        end

        private

        def to_neo(object)
          if object.is_a? Hash
            object.map { |key, value| [key.to_s, to_neo(value)] }.to_h
          elsif object.is_a? Date
            Java::JavaTime::LocalDate.of(object.year, object.month, object.day)
          elsif object.is_a? ActiveSupport::Duration
            Java::OrgNeo4jDriverInternal::InternalIsoDuration.new(0, 0, object.to_i, 0)
          else
            object
          end
        end
      end
    end
  end
end
