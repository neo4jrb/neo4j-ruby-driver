module Neo4j::Driver
  module Internal
    module Handlers
      # This is the Pull All response handler that handles pull all messages in Bolt v3 and previous protocol versions.
      class LegacyPullAllResponseHandler
        include Spi::ResponseHandler
        include Enumerable
        RECORD_BUFFER_LOW_WATERMARK = ENV['record_buffer_low_watermark']&.to_i || 300
        RECORD_BUFFER_HIGH_WATERMARK = ENV['record_buffer_high_watermark']&.to_i || 1000

        def initialize(query, run_response_handler, connection, metadata_extractor, completion_listener)
          @query = Internal::Validator.require_non_nil!(query)
          @run_response_handler = Internal::Validator.require_non_nil!(run_response_handler)
          @metadata_extractor = Internal::Validator.require_non_nil!(metadata_extractor)
          @connection = Internal::Validator.require_non_nil!(connection)
          @completion_listener = Internal::Validator.require_non_nil!(completion_listener)
          # Not using overrided Queue class here
          # Because this class doesn't call methods (#singal, #async) with Async dependancy
          @records = ::Async::Queue.new
        end

        def can_manage_auto_read?
          true
        end

        def on_success(metadata)
          @finished = true
          @summary = extract_result_summary(metadata)

          @completion_listener.after_success(metadata)

          complete_record_future(nil)
          complete_failure_future(nil)
        end

        def on_failure(error)
          @finished = true
          @summary = extract_result_summary({})

          @completion_listener.after_failure(error)

          failed_record_future = fail_record_future(error)

          if failed_record_future
            # error propagated through the record future
            complete_failure_future(nil)
          else
            completed_failure_future = complete_failure_future(error)

            # error has not been propagated to the user, remember it
            @failure = error unless completed_failure_future
          end
        end

        def on_record(fields)
          if @ignore_records
            complete_record_future(nil)
          else
            record = InternalRecord.new(@run_response_handler.query_keys, fields)
            enqueue_record(record)
            complete_record_future(record)
          end
        end

        def disable_auto_read_management
          @auto_read_management_enabled = false
        end

        def peek_async
          while @records.empty? && !(@ignore_records || @finished)
            @records.wait
          end
          record = @records.items.first

          Util::ResultHolder.successful(record)

          # if record.nil?
          #   return Util::Futures.failed_future(extract_failure) unless @failure.nil?

          #   return Util::Futures.completed_with_null if @ignore_records || @finished

          #   @record_future = java.util.concurrent.CompletableFuture.new if @record_future.nil?

          #   @record_future
          # else
          #   # java.util.concurrent.CompletableFuture.completed_future(record)
          #   record
          # end
        end

        def next_async
          # dequeue_record if peek_async
          peek_async.then { |record| dequeue_record if record }
        end

        def consume_async
          @ignore_records = true
          @records.items.clear

          # if pull_all_failure_async.nil?
          #   # @summary.then(&Util::ResultHolder.method(:successful))
          #   Util::ResultHolder.successful(@summary)
          # else
          #   raise pull_all_failure_async
          # end

          if @failure
            Util::ResultHolder.failed(extract_failure)
          else
            Util::ResultHolder.successful(@summary)
          end

          # pull_all_failure_async do |error|
          #   unless error.nil?
          #     raise Util::Futures.as_completion_exception, error
          #   end

          #   @summary
          # end
        end

        # def list_async(map_function)
        #   pull_all_failure_async.then_apply do |error|
        #     unless error.nil?
        #       raise Util::Futures.as_completion_exception, error
        #     end

        #     records_as_list(map_function)
        #   end
        # end

        def each
          pull_all_failure_async.then do
            unless @finished
              raise Exceptions::IllegalStateException, "Can't get records as list because SUCCESS or FAILURE did not arrive"
            end
            @records.each { |record| yield record }
          end
        end

        def pre_populate_records
          @connection.write_and_flush(Messaging::Request::PullAllMessage::PULL_ALL, self)
        end

        def pull_all_failure_async
          if !@failure.nil?
            return Util::ResultHolder.failed(extract_failure)
            # return java.util.concurrent.CompletableFuture.completed_future(extract_failure)
          elsif @finished
            return nil
            # return Util::Futures.completed_with_null
          else
            if @failure_future.nil?
              # neither SUCCESS nor FAILURE message has arrived, register future to be notified when it arrives
              # future will be completed with null on SUCCESS and completed with Throwable on FAILURE
              # enable auto-read, otherwise we might not read SUCCESS/FAILURE if records are not consumed
              enable_auto_read
              @failure_future = java.util.concurrent.CompletableFuture.new
            end

            @failure_future
          end
        end

        private

        def enqueue_record(record)
          @records << record

          should_buffer_all_records = !@failure_future.nil?

          # when failure is requested we have to buffer all remaining records and then return the error
          # do not disable auto-read in this case, otherwise records will not be consumed and trailing
          # SUCCESS or FAILURE message will not arrive as well, so callers will get stuck waiting for the error
          if !should_buffer_all_records && @records.size > RECORD_BUFFER_HIGH_WATERMARK
            # more than high watermark records are already queued, tell connection to stop auto-reading from network
            # this is needed to deal with slow consumers, we do not want to buffer all records in memory if they are
            # fetched from network faster than consumed
            disable_auto_read
          end
        end

        def dequeue_record
          record = @records.dequeue

          if @records.size < RECORD_BUFFER_LOW_WATERMARK
            # less than low watermark records are now available in the buffer, tell connection to pre-fetch more
            # and populate queue with new records from network
            enable_auto_read
          end

          record
        end

        def records_as_list(map_function)
          unless @finished
            raise Exceptions::IllegalStateException, "Can't get records as list because SUCCESS or FAILURE did not arrive"
          end

          result = []

          @records.each do |record|
            result << map_function.apply(record)
          end

          @records.items.clear
          result
        end

        def extract_failure
          @failure or raise Exceptions::IllegalStateException, "Can't extract failure because it does not exist"
        ensure
          @failure = nil # propagate failure only once
        end

        def complete_record_future(record)
          # unless @record_future.nil?
          #   future = @record_future
          #   @record_future = nil
          #   future.complete(record)
          # end
          @record_future&.succeed(record)
          @record_future = nil
        end

        def fail_record_future(error)
          # unless @record_future.nil?
          #   future = @record_future
          #   @record_future = nil
          #   future.complete_exceptionally(error)
          #   return true
          # end

          # false
            @record_future&.fail(error)
          ensure
            @record_future = nil
        end

        def complete_failure_future(error)
          # unless @failure_future.nil?
          #   future = @failure_future
          #   @failure_future = nil
          #   future.complete(error)
          #   return true
          # end

          # false
          @failure_future&.fail(error)
        ensure
          @failure_future = nil
        end

        def extract_result_summary(metadata)
          result_available_after = @run_response_handler.result_available_after
          @metadata_extractor.extract_summary(@query, @connection, result_available_after, metadata)
        end

        def enable_auto_read
          @connection.enable_auto_read if @auto_read_management_enabled
        end

        def disable_auto_read
          @connection.disable_auto_read if @auto_read_management_enabled
        end
      end
    end
  end
end
