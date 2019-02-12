# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Ext::InternalRecord do
  subject(:res) do
    session = driver.session
    session.run("CREATE (p:Person{names: ['Mark', 'Paul']}) RETURN p.names AS names, ID(p) AS id").single
  ensure
    session&.close
  end

  its(:values) { are_expected.to include(%w[Mark Paul]) }
  its(:first) { is_expected.to eq(%w[Mark Paul]) }
  it { expect(res['names']).to eq(%w[Mark Paul]) }
end