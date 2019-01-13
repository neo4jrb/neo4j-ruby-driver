# frozen_string_literal: true

class InternalStatementResult
  include ErrorHandling

  def initialize(connection, run, pull)
    @connection = connection
    @run = run
    @pull = pull
    return if success?
    raise Exception, check_and_print_error(@connection, Bolt::Connection.status(@connection), 'cypher execution failed')
  end

  def single
    Bolt::Connection.fetch(@connection, @pull)
    InternalRecord.new(@connection)
  end

  private

  def success?
    Bolt::Connection.fetch_summary(@connection, @run) >= 0 && Bolt::Connection.summary_success(@connection)
  end
end
