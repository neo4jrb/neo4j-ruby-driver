# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Types::Node do
  context 'date' do
    subject do
      driver.session do |session|
        session.write_transaction do |tx|
          tx.run('CREATE (p:Person{created: $date}) RETURN p', date: date).single.first
        end
      end
    end

    let(:date) { Date.today }

    it { is_expected.to be_a_kind_of described_class }
    its(:labels) { is_expected.to eq(%i[Person]) }
    its(:id) { is_expected.to be_a(Integer) }
    its(:properties) { is_expected.to eq(created: date) }
    its('properties.values.first') { is_expected.to be_a Date }
  end

  context 'array' do
    let(:skills) { %w[java ruby] }
    subject do
      driver.session do |session|
        session.write_transaction do |tx|
          tx.run('CREATE (p:Person{skills: $skills}) RETURN p', skills: skills).single.first[:skills]
        end
      end
    end

    context 'when single element' do
      let(:skills) { 'java' }
      it { is_expected.to eq skills }
    end
    context 'when multiple elements' do
      let(:skills) { %w[java ruby] }
      it { is_expected.to eq skills }
    end
  end
end
