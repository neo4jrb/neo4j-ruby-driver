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
        completion_stage.then_apply(&future.method(:fulfill)).exceptionally { |e| future.reject(mapped_exception_with_cause(e.cause)) }
      end
    end

    def to_async(completion_stage)
      variable = Variable.new
      completion_stage.when_complete do |value, error|
        variable.resolve([value, error])
      end
      value, error = variable.wait
      if error
        # This raise is outside any rescue, so set cause explicitly (the
        # backtrace is correctly captured here, unlike the value-handoff
        # helper). Guard the unmapped passthrough — `cause: original` when
        # mapped == original is a self-cause.
        original = error.cause || error
        mapped = mapped_exception(original)
        raise mapped if mapped.equal?(original)

        raise mapped, cause: original
      end
      value
    end
  end
end
