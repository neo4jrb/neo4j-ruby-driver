# frozen_string_literal: true

module TestkitBackend
  # Translates testkit protocol requests into neo4j-ruby-driver calls.
  #
  # State (drivers, sessions, transactions, results) is keyed by short
  # string ids minted per object and handed back to testkit. The runner
  # refers to those ids in subsequent requests.
  class Dispatcher
    def initialize(connection)
      @connection = connection
      @drivers = {}
      @sessions = {}
      @transactions = {}
      @results = {}
    end

    def dispatch(request)
      name = request['name']
      data = request['data'] || {}

      handler = "handle_#{name}"
      return response('UnknownTypeError', message: "No handler for request #{name}") unless respond_to?(handler, true)

      begin
        send(handler, data)
      rescue Neo4j::Driver::Exceptions::Neo4jException => e
        driver_error(e)
      rescue ArgumentError => e
        frontend_error(e, type: 'ArgumentError')
      rescue => e
        warn "Backend crash: #{e.class}: #{e.message}"
        warn e.backtrace.first(10).join("\n")
        backend_error(e)
      end
    end

    private

    # -- Meta -----------------------------------------------------------

    def handle_StartTest(_data)
      response('RunTest')
    end

    def handle_StartSubTest(_data)
      response('RunTest')
    end

    # Features the driver actually supports today. Grow this list as we
    # implement more; do NOT advertise something we can't honour — testkit
    # will run the tests expecting it to pass instead of skipping.
    FEATURES = [
      'Feature:API:ConnectionAcquisitionTimeout',
      'Feature:API:Driver.VerifyConnectivity',
      'Feature:API:Result.List',
      'Feature:API:Result.Peek',
      'Feature:API:Result.Single'
    ].freeze

    def handle_GetFeatures(_data)
      response('FeatureList', features: FEATURES)
    end

    # -- Driver ---------------------------------------------------------

    def handle_NewDriver(data)
      id = mint_id('driver')
      options = driver_options(data)
      auth = auth_token(data['authorizationToken'])

      @drivers[id] = Neo4j::Driver::GraphDatabase.driver(data['uri'], auth, **options)
      response('Driver', id: id)
    end

    def handle_DriverClose(data)
      @drivers.delete(data['driverId'])&.close
      response('Driver', id: data['driverId'])
    end

    def handle_VerifyConnectivity(data)
      @drivers.fetch(data['driverId']).verify_connectivity
      response('Driver', id: data['driverId'])
    end

    # -- Session --------------------------------------------------------

    def handle_NewSession(data)
      driver = @drivers.fetch(data['driverId'])
      options = session_options(data)
      session = driver.session(options)
      id = mint_id('session')
      @sessions[id] = session
      response('Session', id: id)
    end

    def handle_SessionClose(data)
      @sessions.delete(data['sessionId'])&.close
      response('Session', id: data['sessionId'])
    end

    def handle_SessionRun(data)
      session = @sessions.fetch(data['sessionId'])
      params = convert_params(data['params'])
      config = run_config(data)

      result = session.run(data['cypher'], params, config)
      result_response(result)
    end

    def handle_SessionLastBookmarks(data)
      session = @sessions.fetch(data['sessionId'])
      bookmarks = session.last_bookmarks.to_a.map(&:value)
      response('Bookmarks', bookmarks: bookmarks)
    end

    def handle_SessionBeginTransaction(data)
      session = @sessions.fetch(data['sessionId'])
      config = run_config(data)

      tx = session.begin_transaction
      id = mint_id('tx')
      @transactions[id] = tx
      response('Transaction', id: id)
    end

    # -- Transaction ----------------------------------------------------

    def handle_TransactionRun(data)
      tx = @transactions.fetch(data['txId'])
      params = convert_params(data['params'])
      result = tx.run(data['cypher'], params)
      result_response(result)
    end

    def handle_TransactionCommit(data)
      @transactions.fetch(data['txId']).commit
      response('Transaction', id: data['txId'])
    end

    def handle_TransactionRollback(data)
      @transactions.fetch(data['txId']).rollback
      response('Transaction', id: data['txId'])
    end

    def handle_TransactionClose(data)
      @transactions.delete(data['txId'])&.close
      response('Transaction', id: data['txId'])
    end

    # -- Result ---------------------------------------------------------

    def handle_ResultNext(data)
      result = @results.fetch(data['resultId'])
      return response('NullRecord') unless result.has_next?

      record_response(result.next)
    end

    def handle_ResultPeek(data)
      result = @results.fetch(data['resultId'])
      return response('NullRecord') unless result.has_next?

      record_response(result.peek)
    end

    def handle_ResultSingle(data)
      result = @results.fetch(data['resultId'])
      record_response(result.single)
    end

    def handle_ResultList(data)
      result = @results.fetch(data['resultId'])
      records = result.to_a.map { |record| record_values(record) }
      response('RecordList', records: records)
    end

    def handle_ResultConsume(data)
      summary = @results.fetch(data['resultId']).consume
      summary_response(summary)
    end

    # -- helpers --------------------------------------------------------

    def response(name, **data)
      { 'name' => name, 'data' => data.transform_keys(&:to_s) }
    end

    def driver_error(exception)
      response(
        'DriverError',
        id: mint_id('error'),
        errorType: exception.class.name,
        code: exception.code,
        msg: exception.message,
        retryable: exception.is_a?(Neo4j::Driver::Exceptions::TransientException)
      )
    end

    def frontend_error(exception, type:)
      response('FrontendError', msg: exception.message, errorType: type)
    end

    def backend_error(exception)
      response('BackendError', msg: "#{exception.class}: #{exception.message}")
    end

    def result_response(result)
      id = mint_id('result')
      @results[id] = result
      response('Result', id: id, keys: result.keys.map(&:to_s))
    end

    def record_response(record)
      response('Record', values: record_values(record))
    end

    def record_values(record)
      record.values.map { |v| Cypher.from_ruby(v) }
    end

    def summary_response(summary)
      response('Summary', **summary_payload(summary))
    end

    def summary_payload(summary)
      database_name = summary.respond_to?(:database) ? safe_call { summary.database&.name } : nil
      server = summary.respond_to?(:server) ? safe_call { summary.server } : nil

      {
        database: database_name,
        query: {
          text: summary.respond_to?(:query) && summary.query.respond_to?(:text) ? summary.query.text : nil,
          parameters: {}
        },
        queryType: summary.respond_to?(:query_type) ? safe_call { summary.query_type } : nil,
        counters: counters_payload(summary),
        notifications: nil,
        plan: nil,
        profile: nil,
        resultAvailableAfter: summary.respond_to?(:result_available_after) ? summary.result_available_after : nil,
        resultConsumedAfter: summary.respond_to?(:result_consumed_after) ? summary.result_consumed_after : nil,
        serverInfo: {
          address: server.respond_to?(:address) ? server.address : nil,
          agent: server.respond_to?(:agent) ? server.agent : nil,
          protocolVersion: server.respond_to?(:protocol_version) ? server.protocol_version : nil
        }
      }
    end

    # Driver getters can raise on edge cases (missing metadata, partial
    # summaries from failure paths). Fall back to nil rather than letting a
    # NoMethodError propagate as a backend crash.
    def safe_call
      yield
    rescue StandardError
      nil
    end

    def counters_payload(summary)
      return {} unless summary.respond_to?(:counters) && summary.counters

      c = summary.counters
      integer_fields = %i[nodes_created nodes_deleted relationships_created relationships_deleted
                          properties_set labels_added labels_removed indexes_added indexes_removed
                          constraints_added constraints_removed system_updates]
      payload = integer_fields.each_with_object({}) do |key, acc|
        acc[camelize(key)] = c.respond_to?(key) ? c.public_send(key) : 0
      end
      payload['containsUpdates']       = c.respond_to?(:contains_updates?) ? c.contains_updates? : false
      payload['containsSystemUpdates'] = c.respond_to?(:contains_system_updates?) ? c.contains_system_updates? : false
      payload
    end

    def camelize(symbol)
      head, *tail = symbol.to_s.split('_')
      (head + tail.map(&:capitalize).join).to_s
    end

    def convert_params(params)
      return {} unless params.is_a?(Hash)

      params.each_with_object({}) do |(k, v), acc|
        acc[k.to_sym] = Cypher.to_ruby(v)
      end
    end

    def auth_token(token)
      return Neo4j::Driver::AuthTokens.none if token.nil?

      scheme = token['scheme'] || (token['data'] && token['data']['scheme'])
      data = token['data'] || token
      case scheme
      when 'basic'
        Neo4j::Driver::AuthTokens.basic(data['principal'], data['credentials'])
      when 'none', nil
        Neo4j::Driver::AuthTokens.none
      else
        Neo4j::Driver::AuthTokens.basic(data['principal'], data['credentials'])
      end
    end

    def driver_options(data)
      opts = {}
      opts[:max_connection_pool_size]       = data['maxConnectionPoolSize'] if data.key?('maxConnectionPoolSize')
      opts[:connection_acquisition_timeout] = data['connectionAcquisitionTimeoutMs'] / 1000.0 if data['connectionAcquisitionTimeoutMs']
      opts[:max_transaction_retry_time]     = data['maxTxRetryTimeMs'] / 1000.0 if data['maxTxRetryTimeMs']
      opts[:connection_timeout]             = data['connectionTimeoutMs'] / 1000.0 if data['connectionTimeoutMs']
      opts
    end

    def session_options(data)
      opts = {}
      opts[:default_access_mode] = data['accessMode'] == 'r' ? Neo4j::Driver::AccessMode::READ : Neo4j::Driver::AccessMode::WRITE if data['accessMode']
      opts[:database] = data['database'] if data['database']
      opts[:bookmarks] = data['bookmarks'] if data['bookmarks']
      # fetchSize currently ignored — driver always does PULL {n: -1}.
      opts
    end

    def run_config(data)
      config = {}
      config[:timeout]  = data['timeout'] / 1000.0 if data['timeout']
      config[:metadata] = convert_params(data['txMeta']) if data['txMeta']
      config
    end

    def mint_id(prefix)
      "#{prefix}-#{SecureRandom.hex(6)}"
    end
  end
end
