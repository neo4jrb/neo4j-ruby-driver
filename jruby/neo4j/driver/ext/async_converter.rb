# frozen_string_literal: true

module Neo4j::Driver::Ext
  module AsyncConverter
    include ExceptionMapper

    private

    def to_future(completion_stage)
      Concurrent::Promises.resolvable_future.tap do |future|
        completion_stage.then_apply(&future.method(:fulfill)).exceptionally { |e| future.reject(mapped_exception(e)) }
      end
    end
  end
end
