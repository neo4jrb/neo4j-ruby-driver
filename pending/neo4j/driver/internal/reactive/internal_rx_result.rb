# frozen_string_literal: true

module Neo4j::Driver::Internal::Reactive
  class InternalRxResult
    IGNORE = org.neo4j.driver.internal.shaded.reactor.core.publisher.FluxSink::OverflowStrategy::IGNORE

    def initialize(&cursor_future)
      @cursor_future_supplier = cursor_future
    end

    def keys
      org.neo4j.driver.internal.shaded.reactor.core.publisher.Mono.defer do
        org.neo4j.driver.internal.shaded.reactor.core.publisher.Mono.from_completion_stage(cursor_future)
           .map(&Cursor::RxResultCursor.method(:keys))
           .on_error_map(&Util::Futures.method(:completion_exception_cause))
      end
    end

    def records
      org.neo4j.driver.internal.shaded.reactor.core.publisher.Flux.create(IGNORE) do |sink|
        cursor_future.when_complete do |cursor, completion_error|
          if cursor
            if cursor.done?
              sink.error(Neo4j::Driver::Internal::Util::ErrorUtil.new_result_consumed_error)
            else
              cursor.install_record_consumer(create_record_consumer(sink))
              sink.on_cancel(&cursor.method(:cancel))
              sink.on_request(&cursor.method(:request))
            end
          else
            error = Neo4j::Driver::Internal::Util::Futures.completion_exception_cause(completion_error)
            sink.error(error)
          end
        end
      end
    end

    def consume
      org.neo4j.driver.internal.shaded.reactor.core.publisher.Mono.create do |sink|
        cursor_future.when_complete do |cursor, completion_error|
          if cursor.nil?
            error = Neo4j::Driver::Internal::Util::Futures.completion_exception_cause(completion_error)
            sink.error(error)
          else
            cursor.summary_async.whenComplete do |summary, summary_completion_error|
              error = Neo4j::Driver::Internal::Util::Futures.completion_exception_cause(summary_completion_error)
              summary.nil? ? sink.error(error) : sink.success(summary)
            end
          end
        end
      end
    end

    private

    # Defines how a subscriber shall consume records.
    # A record consumer holds a reference to a subscriber.
    # A publisher and/or a subscription who holds a reference to this consumer shall release the reference to this object
    # after subscription is done or cancelled so that the subscriber can be garbage collected.
    # @param sink the subscriber
    # @return a record consumer.
    def create_record_consumer(sink)
      lambda do |r, e|
        if !r.nil?
          sink.next(r)
        elsif !e.nil?
          sink.error(e)
        else
          sink.complete
        end
      end
    end

    def cursor_future
      @cursor_future || init_cursor_future
    end

    def init_cursor_future
      # A quick path to return
      return @cursor_future unless @cursor_future.nil?

      # now we obtained lock and we are going to be the one who assigns cursor_future one and only once.
      @cursor_future = @cursor_future_supplie
      @cursor_future_supplier = nil # we no longer need the reference to this object
      @cursor_future
    end
  end
end
