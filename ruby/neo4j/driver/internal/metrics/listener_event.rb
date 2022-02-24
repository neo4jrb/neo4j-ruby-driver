module Neo4j::Driver
  module Internal
    module Metrics
      module ListenerEvent
        DEV_NULL_LISTENER_EVENT = Class.new do
                                    def start
                                    end

                                    def elapsed
                                      0
                                    end
                                  end.new
      end
    end
  end
end
