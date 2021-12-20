# frozen_string_literal: true

module Neo4j::Driver::Internal::Reactive
  module RxUtils
    # The publisher created by this method will either succeed without publishing anything or fail with an error.
    # @param supplier supplies a {@link CompletionStage<Void>}.
    # @return A publisher that publishes nothing on completion or fails with an error.
    def self.create_empty_publisher(&supplier)
      org.neo4j.driver.internal.shaded.reactor.core.publisher.Mono.create do |sink|
        supplier.call.when_complete do |ignore, completion_error|
          error = Neo4j::Driver::Internal::Util::Futures.completion_exception_cause(completion_error);
          error.nil? ? sink.success : sink.error(error)
        end
      end
    end

    # The publisher created by this method will either succeed with exactly one item or fail with an error.
    #
    # @param supplier                    supplies a {@link CompletionStage<T>} that MUST produce a non-null result when completed successfully.
    # @param nullResultThrowableSupplier supplies a {@link Throwable} that is used as an error when the supplied completion stage completes successfully with
    #                                    null.
    # @param <T>                         the type of the item to publish.
    # @return A publisher that succeeds exactly one item or fails with an error.
    def self.create_single_item_publisher(supplier, nil_result_throwable_supplier)
      org.neo4j.driver.internal.shaded.reactor.core.publisher.Mono.create do |sink|
        supplier.when_complete do |item, completion_error|
          if completion_error.nil?
            item.nil? ? sink.error(nil_result_throwable_supplier) : sink.success(item)
          else
            error = Neo4j::Driver::Internal::Util::Futures.completion_exception_cause(completion_error)
            sink.error(error || completion_error)
          end
        end
      end
    end
  end
end
