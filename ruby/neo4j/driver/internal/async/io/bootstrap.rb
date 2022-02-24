module Neo4j::Driver
  module Internal
    module Async
      module Io
        class Bootstrap
          attr_accessor :group

          def channel(channel_class) end
        end
      end
    end
  end
end

