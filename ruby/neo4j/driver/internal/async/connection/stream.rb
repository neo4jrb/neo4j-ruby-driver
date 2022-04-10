module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class Stream < ::Async::IO::Stream
          include Packstream::PackInput
          include Packstream::PackOutput
        end
      end
    end
  end
end
