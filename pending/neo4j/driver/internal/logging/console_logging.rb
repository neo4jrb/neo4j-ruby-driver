module Neo4j::Driver
  module Internal
    module Logging
      # Internal implementation of the console logging.
      # <b>This class should not be used directly.</b> Please use {@link Logging#console(Level)} factory method instead.

      # @see Logging#console(Level)
      class ConsoleLogging
        include Logging
        include java.io.Serializable

        def initialize(level)
          @serial_version_ui_d = 9205935204074879150
          @level = java.util.Objects.require_non_null(level)
        end

        def log(name)
          ConsoleLogger.new(name, @level)
        end

        class ConsoleLogger < JULogger
          def initialize(name, level)
            super(name, level)

            logger = java.util.logging.Logger.get_logger(name)
            logger.set_use_parent_handlers(false)

            # remove all other logging handlers
            handlers = logger.handlers

            handlers.each do |handler_to_remove|
              logger.remove_handler(handler_to_remove)
            end

            handler = java.util.logging.ConsoleHandler.new
            handler.set_formatter(ConsoleFormatter.new)
            handler.set_level(level)
            logger.add_handler(handler)
            logger.set_level(level)
          end
        end

        private

        class ConsoleFormatter < java.util.logging.Formatter
          def format(record)
            "#{java.time.LocalDateTime.now.format(java.time.format.DateTimeFormatter::ISO_LOCAL_DATE_TIME)} #{record.level} #{record.logger_name} - #{format_message(record)}#{format_throwable(record.thrown)}\n"
          end

          def format_throwable(throwable)
            unless throwable.nil?
              sw = java.io.StringWriter.new
              pw = java.io.PrintWriter.new(sw)
              pw.println
              throwable.print_stack_trace(pw)
              pw.close
              throwable_string = sw.to_s
            end

            throwable_string
          end
        end
      end
    end
  end
end
