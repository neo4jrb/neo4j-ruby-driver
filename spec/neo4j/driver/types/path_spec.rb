# frozen_string_literal: true

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

  it { is_expected.to be_a_kind_of described_class }
  it { is_expected.to be_a_kind_of Enumerable }
  its(:length) { is_expected.to eq 1 }
  its(:start_node) { is_expected.to be_a_kind_of Neo4j::Driver::Types::Node }
  its(:end_node) { is_expected.to be_a_kind_of Neo4j::Driver::Types::Node }
  its('relationships.first.type') { is_expected.to eq 'friend_of' }
  its(:first) { is_expected.to be_a_kind_of Neo4j::Driver::Types::Path::Segment }
  its('first.relationship.type') { is_expected.to eq 'friend_of' }
  its('first.relationship.properties') { is_expected.to eq(strength: 1) }
  its('first.start_node') { is_expected.to be_a_kind_of Neo4j::Driver::Types::Node }
  its('first.start_node.properties') { is_expected.to eq(name: 'John') }
  its('first.end_node') { is_expected.to be_a_kind_of Neo4j::Driver::Types::Node }
  its('first.end_node.properties') { is_expected.to eq(name: 'Paul') }
end
