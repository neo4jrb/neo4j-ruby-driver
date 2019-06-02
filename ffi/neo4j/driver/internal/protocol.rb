# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module Protocol
        def request(error_code)
          check_error error_code
          requests << Bolt::Connection.last_request(@connection)
        end

        def process(all = false)
          requests = self.requests
          flush unless requests.empty?
          pull = requests.pop unless all
          requests.each(&method(:summary))
          pull
        ensure
          requests.clear
        end

        def flush
          check_error Bolt::Connection.send(@connection)
        end

        private

        def summary(handle)
          n = Bolt::Connection.fetch_summary(@connection, handle)
          return n if Bolt::Connection.summary_success(@connection) == 1
          failure = Neo4j::Driver::Value.to_ruby(Bolt::Connection.failure(@connection))
          raise Neo4j::Driver::Exceptions::ClientException.new(failure[:code], failure[:message])
        end
      end
    end
  end
end
