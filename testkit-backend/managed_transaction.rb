# frozen_string_literal: true

module TestkitBackend
  # Shared body for SessionReadTransaction / SessionWriteTransaction.
  #
  # Testkit's managed-tx flow is reentrant: after we receive the
  # SessionReadTransaction request, we have to invoke the driver's
  # session.execute_read { |tx| ... } block, write a RetryableTry
  # response upstream from inside the block, and then run a nested
  # request loop (consuming Transaction* / Result* requests against
  # the new tx) until testkit signals RetryablePositive (commit) or
  # RetryableNegative (raise — possibly retry).
  #
  # The two requests differ only in which driver method they invoke
  # (execute_read vs execute_write). Extracted so each request class
  # stays tiny and the loop logic lives in one place.
  module ManagedTransaction
    # Driver session method to invoke. Override in the including class.
    def driver_method
      raise NotImplementedError
    end

    def execute
      registry.fetch(session_id).public_send(driver_method) do |tx|
        run_inner_loop(tx)
      end
      Response::RetryableDone.new
    end

    private

    def run_inner_loop(tx)
      tx_id = registry.store(tx)
      connection.write_response(Response::RetryableTry.new(id: tx_id))

      loop do
        request = connection.read_request
        raise Neo4j::Driver::Exceptions::ClientException, 'connection closed mid-transaction' if request.nil?

        case request['name']
        when 'RetryablePositive'
          # Returning normally lets the driver commit the tx.
          return
        when 'RetryableNegative'
          # Re-raise the original exception (or a generic one if testkit
          # didn't supply an errorId) so the driver's retry path fires.
          raise resolve_negative_error(request['data'] || {})
        else
          connection.write_response(Request.dispatch(request, registry, connection))
        end
      end
    end

    def resolve_negative_error(data)
      error_id = data['errorId']
      return registry.fetch(error_id) if error_id.is_a?(String) && !error_id.empty?

      Neo4j::Driver::Exceptions::ClientException.new('Client-generated error from testkit')
    end
  end
end
