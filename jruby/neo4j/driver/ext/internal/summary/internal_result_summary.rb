# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          module InternalResultSummary
            %i[result_available_after result_consumed_after].each do |method|
              define_method(method) { super(Java::JavaUtilConcurrent::TimeUnit::MILLISECONDS) }
            end
          end
        end
      end
    end
  end
end
