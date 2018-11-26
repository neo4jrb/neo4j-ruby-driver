RSpec.describe Neo4j::Driver::Types::Path do
  subject do
    session = driver.session
    session.write_transaction do |tx|
      tx.run('CREATE p=(s:Person{name: "John"})-[f:friend_of{strength: 1}]->(e:Person{name: "Paul"}) RETURN p')
        .single.first
    end
  ensure
    session&.close
  end

  it { is_expected.to be_a_kind_of Neo4j::Driver::Types::Path }
  its(:length) { is_expected.to eq 1 }
  its(:start) { is_expected.to be_a_kind_of Neo4j::Driver::Types::Node }
  its(:end) { is_expected.to be_a_kind_of Neo4j::Driver::Types::Node }
end