# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Types::Path do
  shared_examples 'path' do
    subject do
      driver.session do |session|
        session.write_transaction do |tx|
          tx.run("CREATE p=#{path_fragment} RETURN p").single.first
        end
      end
    end

    def node(name)
      driver.session { |session| session.run('MATCH (s:Person{name: $name}) RETURN s', name: name).single.first }
    end

    let(:start_node) { node(start_node_name) }
    let(:relationship_start) { node('John') }

    it { is_expected.to be_a_kind_of described_class }
    it { is_expected.to be_a_kind_of Enumerable }
    its(:length) { is_expected.to eq 1 }
    its(:start_node) { is_expected.to be_a_kind_of Neo4j::Driver::Types::Node }
    its(:end_node) { is_expected.to be_a_kind_of Neo4j::Driver::Types::Node }
    its('relationships.first') { is_expected.to be_a_kind_of Neo4j::Driver::Types::Relationship }
    its('relationships.first.type') { is_expected.to eq :friend_of }
    its(:first) { is_expected.to be_a_kind_of Neo4j::Driver::Types::Path::Segment }
    its('first.relationship.type') { is_expected.to eq :friend_of }
    its('first.relationship.properties') { is_expected.to eq(strength: 1) }
    its('first.start_node') { is_expected.to be_a_kind_of Neo4j::Driver::Types::Node }
    its('first.start_node.properties') { is_expected.to eq(name: start_node_name) }
    its('first.end_node') { is_expected.to be_a_kind_of Neo4j::Driver::Types::Node }
    its('first.end_node.properties') { is_expected.not_to eq(name: start_node_name) }
    its('nodes.first') { is_expected.to be_a_kind_of Neo4j::Driver::Types::Node }
    its('first.start_node') { is_expected.to eq start_node }
    its('first.relationship.start_node_id') { is_expected.to eq relationship_start.id }
    its('relationships.first.start_node_id') { is_expected.to eq relationship_start.id }
    its('nodes.first') { is_expected.to eq start_node }
  end

  describe 'forward' do
    it_behaves_like 'path' do
      let(:path_fragment) { '(s:Person{name: "John"})-[f:friend_of{strength: 1}]->(e:Person{name: "Paul"})' }
      let(:start_node_name) { 'John' }
    end
  end

  describe 'reverse' do
    it_behaves_like 'path' do
      let(:path_fragment) { '(e:Person{name: "Paul"})<-[f:friend_of{strength: 1}]-(s:Person{name: "John"})' }
      let(:start_node_name) { 'Paul' }
    end
  end
end
