RSpec.describe Neo4j::Driver::Types::Node do
  subject(:node) do
    session = driver.session
    session.write_transaction { |tx| tx.run('CREATE (p:Person{name: "John"}) RETURN p').single.first }
  ensure
    session&.close
  end

  it { is_expected.to be_a_kind_of Neo4j::Driver::Types::Node }
  its(:labels) { is_expected.to eq(['Person']) }
  its(:id) { is_expected.to be_a(Integer) }
  its(:properties) { is_expected.to eq({ name: 'John' }) }
end