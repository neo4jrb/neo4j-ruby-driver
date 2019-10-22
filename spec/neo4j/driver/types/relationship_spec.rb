# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Types::Relationship do
  subject do
    session = driver.session
    session.write_transaction { |tx| tx.run('CREATE ()-[f:friend_of{strength: 1}]->() RETURN f').single.first }
  ensure
    session&.close
  end

  it { is_expected.to be_a_kind_of described_class }
  its(:type) { is_expected.to eq :friend_of }
  its(:id) { is_expected.to be_a(Integer) }
  its(:start_node_id) { is_expected.to be_a(Integer) }
  its(:end_node_id) { is_expected.to be_a(Integer) }
  its(:properties) { is_expected.to eq strength: 1 }
end
