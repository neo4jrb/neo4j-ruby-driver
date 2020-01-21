# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Types::Node do
  subject do
    session = driver.session
    session.write_transaction do |tx|
      tx.run('CREATE (p:Person{name: "John", created: $date}) RETURN p', date: Date.today).single.first
    end
  ensure
    session&.close
  end

  it { is_expected.to be_a_kind_of described_class }
  its(:labels) { is_expected.to eq(%i[Person]) }
  its(:id) { is_expected.to be_a(Integer) }
  its(:properties) { is_expected.to eq(name: 'John', created: Date.today) }
end
