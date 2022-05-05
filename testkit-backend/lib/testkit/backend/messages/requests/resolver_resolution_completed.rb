module Testkit::Backend::Messages
  module Requests
    class ResolverResolutionCompleted < Request
      def process
        named_entity('ResolverResolutionRequired', id: requestId, address: address)
      end

      def to_object
        fetch(requestId).resolver(addresses: @command_processor.process(blocking: true).addresses)
      end
    end
  end
end