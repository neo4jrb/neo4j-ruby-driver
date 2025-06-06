module Testkit
  module Backend
    module Messages
      module Responses
        class EagerResult < Response
          alias_method :response_to_testkit, :to_testkit

          include Conversion
          alias_method :value_to_testkit, :to_testkit

          include SummaryHelper

          def to_testkit(*args)
            if args.empty?
              response_to_testkit
            else
              value_to_testkit(*args)
            end
          end

          def data
            {
              keys: @object.records.first&.keys || [],
              records: @object.records.map do |record|
                { values: record.values.map(&method(:to_testkit)) }
              end,
              summary: summary_to_testkit(@object.summary)[:data]
            }
          end
        end
      end
    end
  end
end
