# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Driver do
  next unless Neo4j::Driver::Loader.mri?

  # Not named `driver`: that helper is the shared integration driver the
  # spec_helper's Neo4j cleaner uses, and shadowing it would point the cleaner
  # at this double.
  subject(:query_driver) { described_class.new('bolt://localhost:7687', {}, double('ConnectionProvider')) }

  describe '#execute_query bookmark chaining' do
    # Capture the session options execute_query builds and skip the managed-tx
    # block (and thus all network work) entirely.
    let(:captured) { [] }

    before { allow(query_driver).to receive(:session) { |**opts| captured << opts } }

    it 'hands the session a driver-wide default bookmark manager by default' do
      query_driver.execute_query('RETURN 1')
      expect(captured.last[:bookmark_manager]).not_to be_nil
      expect(captured.last[:bookmark_manager])
        .to be(query_driver.instance_variable_get(:@query_bookmark_manager))
    end

    it 'reuses the same manager across calls so they are causally chained' do
      query_driver.execute_query('RETURN 1')
      query_driver.execute_query('RETURN 2')
      first, second = captured.map { |opts| opts[:bookmark_manager] }
      expect(first).to be(second)
    end

    it 'disables chaining when the caller passes bookmark_manager: nil' do
      query_driver.execute_query('RETURN 1', {}, { bookmark_manager: nil })
      expect(captured.last).to have_key(:bookmark_manager)
      expect(captured.last[:bookmark_manager]).to be_nil
    end
  end
end
