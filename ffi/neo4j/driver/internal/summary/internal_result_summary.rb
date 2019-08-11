# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Summary
        class InternalResultSummary
          attr_reader :server, :counters, :statement, :result_available_after, :result_consumed_after
          delegate :notifications, :profile, to: :@metadata

          def initialize(statement, result_available_after, bolt_connection)
            @statement = statement
            @result_available_after = result_available_after
            @server = InternalServerInfo.new(bolt_connection)
            @metadata = RecursiveOpenStruct.new(
              underscore_keys(Value::ValueAdapter.to_ruby(Bolt::Connection.metadata(bolt_connection))),
              recurse_over_arrays: true
            )
            puts "metadata=#{@metadata.to_h.inspect}"
            puts "metadata.plan=#{@metadata.plan.inspect}"
            @result_consumed_after = @metadata.result_consumed_after || @metadata.t_last
            @counters = InternalSummaryCounters.new(@metadata.stats)
          end

          def plan
            @metadata.plan || profile
          end

          alias has_plan? plan
          alias has_profile? profile

          def method_missing(method)
            @metadata.send(method)
          end

          private

          def underscore_keys(arg)
            case arg
            when Array
              arg.map(&method(:underscore_keys))
            when Hash
              arg.map { |key, value| [translate_key(key), underscore_keys(value)] }.to_h
            else
              arg
            end
          end

          def translate_key(key)
            case key
            when :type
              :statement_type
            when :args
              :arguments
            when :rows
              :records
            else
              key.to_s.underscore.to_sym
            end
          end
        end
      end
    end
  end
end