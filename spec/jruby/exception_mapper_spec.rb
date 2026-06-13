# frozen_string_literal: true

# JRuby-only: exercises the Java->Ruby exception mapping directly, no server
# round-trip. A write against a read-only database surfaces as a driver-
# generated SessionExpiredException (its own code is "N/A") that chains the
# original ForbiddenOnReadOnlyDatabase as its GQL cause. testkit asserts on
# that original code, so the mapper must surface it rather than the wrapper's.
RSpec.describe Neo4j::Driver::Ext::ExceptionMapper do
  subject(:mapper) { Object.new.extend(described_class) }

  let(:forbidden) { 'Neo.ClientError.General.ForbiddenOnReadOnlyDatabase' }

  def client_exception(code, message = 'Unable to write')
    org.neo4j.driver.exceptions.ClientException.new(code, message)
  end

  def session_expired(message, cause = nil)
    klass = org.neo4j.driver.exceptions.SessionExpiredException
    cause ? klass.new(message, cause) : klass.new(message)
  end

  describe '#mapped_exception code' do
    it 'surfaces the original server code from the gql cause of a wrapper' do
      mapped = mapper.mapped_exception(
        session_expired('Server at x no longer accepts writes', client_exception(forbidden))
      )

      expect(mapped).to be_a Neo4j::Driver::Exceptions::SessionExpiredException
      expect(mapped.code).to eq forbidden
    end

    it 'leaves a real top-level code untouched' do
      expect(mapper.mapped_exception(client_exception(forbidden)).code).to eq forbidden
    end

    it 'keeps "N/A" when no cause carries a real code' do
      expect(mapper.mapped_exception(session_expired('Server gone')).code).to eq 'N/A'
    end
  end
end
