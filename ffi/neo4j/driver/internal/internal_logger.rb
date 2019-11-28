# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class InternalLogger
        include ErrorHandling

        class << self
          def register(bolt_config, logger)
            return unless logger
            new(bolt_config, logger)
          end
        end

        def initialize(bolt_config, logger)
          @logger = logger
          @funcs = []
          bolt_log = Bolt::Log.create(nil)
          %i[error warning info debug].each do |method|
            Bolt::Log.send("set_#{method}_func", bolt_log, func(method))
          end
          check_error Bolt::Config.set_log(bolt_config, bolt_log)
        end

        def func(method)
          Proc.new { |_ptr, message| @logger.send(method, message) }.tap(&@funcs.method(:<<))
        end
      end
    end
  end
end
