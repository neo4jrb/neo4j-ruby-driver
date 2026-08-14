# frozen_string_literal: true

RSpec.describe 'Managed transaction context' do
  # execute_read / execute_write hand the work block a run-only context — the
  # driver owns commit/rollback/close for managed functions (auto-commit on
  # clean return, rollback + retry on failure). begin_transaction instead
  # yields an explicit transaction that keeps the full lifecycle. Same shape
  # on both flavours (JRuby's context is Java's DelegatingTransactionContext).
  it 'yields a run-only context to execute_read / execute_write' do
    driver.session do |session|
      session.execute_read do |tx|
        expect(tx).to respond_to(:run)
        expect(tx).not_to respond_to(:commit)
        expect(tx).not_to respond_to(:rollback)
        expect(tx).not_to respond_to(:close)
        expect(tx.run('RETURN 1').single.first).to eq 1
      end
    end
  end

  it 'yields an explicit transaction with commit/rollback to begin_transaction' do
    driver.session do |session|
      tx = session.begin_transaction
      expect(tx).to respond_to(:run, :commit, :rollback, :close)
    ensure
      tx&.close
    end
  end
end
