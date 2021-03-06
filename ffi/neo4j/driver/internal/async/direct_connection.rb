# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Async
        class DirectConnection
          include ErrorHandling

          attr_reader :protocol
          attr_reader :bolt_connection

          def initialize(connector, mode, config)
            @connector = connector
            @config = config
            @bolt_connection = with_status { |status| Bolt::Connector.acquire(@connector, mode, status) }

            # @protocol = Messaging::BoltProtocol.for_version(Bolt::Connection.server(bolt_connection).first)
            @protocol = Messaging::BoltProtocol.for_version(3)
            @status = Concurrent::AtomicReference.new(:open)
          end

          def write_and_flush(statement, parameters, boomarks_holder, config, run_handler, pull_handler)
            check_error Bolt::Connection.clear_run(bolt_connection)
            check_error Bolt::Connection.set_run_cypher(bolt_connection, statement, statement.bytesize, parameters.size)
            parameters.each_with_index do |(name, object), index|
              name = name.to_s
              Value::ValueAdapter.to_neo(
                Bolt::Connection.set_run_cypher_parameter(bolt_connection, index, name, name.size), object
              )
            end
            set_bookmarks(:set_run_bookmarks, boomarks_holder.bookmarks)
            set_config(:set_run, config)
            register(run_handler, Bolt::Connection.load_run_request(bolt_connection))
            register(pull_handler, Bolt::Connection.load_pull_request(bolt_connection, -1))
            flush
          end

          def flush
            check_error Bolt::Connection.flush(bolt_connection)
          end

          def begin(bookmarks, config, begin_handler)
            check_error Bolt::Connection.clear_begin(bolt_connection)
            set_bookmarks(:set_begin_bookmarks, bookmarks)
            set_config(:set_begin, config)
            register(begin_handler, Bolt::Connection.load_begin_request(bolt_connection))
          end

          def commit(handler)
            register(handler, Bolt::Connection.load_commit_request(bolt_connection))
            flush
          end

          def rollback(handler)
            register(handler, Bolt::Connection.load_rollback_request(bolt_connection))
            flush
          end

          def release
            return unless @status.compare_and_set(:open, :terminated)
            Bolt::Connector.release(@connector, bolt_connection)
            @bolt_connection = nil
          end

          def open?
            @status.get == :open
          end

          def last_bookmark
            Bolt::Connection.last_bookmark(bolt_connection).first.force_encoding(Encoding::UTF_8)
          end

          private

          def register(handler, error_code)
            check_error(error_code)
            handler.request = Bolt::Connection.last_request(bolt_connection)
          end

          def set_bookmarks(method, bookmarks)
            return unless bookmarks.present?
            value = Bolt::Value.create
            Value::ValueAdapter.to_neo(value, bookmarks)
            check_error Bolt::Connection.send(method, bolt_connection, value)
          end

          def set_config(method_prefix, config)
            return unless config
            config.each do |key, value|
              case key
              when :timeout
                check_error Bolt::Connection.send("#{method_prefix}_tx_timeout", bolt_connection,
                                                  DurationNormalizer.milliseconds(value))
              when :metadata
                bolt_value = Bolt::Value.create
                Value::ValueAdapter.to_neo(bolt_value, value)
                check_error Bolt::Connection.send("#{method_prefix}_tx_metadata", bolt_connection, bolt_value)
              end
            end
          end
        end
      end
    end
  end
end
