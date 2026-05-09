# frozen_string_literal: true

module Neo4j::Driver::Ext
  module AsyncConverter
    include ExceptionMapper

    private

    class Variable
      def initialize(condition = ::Async::Condition.new)
        @condition = condition
        @value = nil
      end

      def resolve(value = true)
        @value = value
        condition = @condition
        @condition = nil

        self.freeze

        condition.signal(value)
      end

      def resolved?
        @condition.nil?
      end

      def value
        @condition&.wait
        return @value
      end

      def wait
        self.value
      end
    end

    def to_future(completion_stage)
      Concurrent::Promises.resolvable_future.tap do |future|
        completion_stage.then_apply(&future.method(:fulfill)).exceptionally { |e| future.reject(mapped_exception(e.cause)) }
      end
    end

    def to_async(completion_stage)
      variable = Variable.new
      completion_stage.when_complete do |value, error|
        variable.resolve([value, error])
      end
      value, error = variable.wait
      raise mapped_exception(e.cause) if error
      value
    end
  end
end
