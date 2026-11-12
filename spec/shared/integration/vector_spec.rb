# frozen_string_literal: true

RSpec.describe 'VectorSpec' do
  # VECTOR needs Bolt 6.0 (Neo4j 2025.10+) and the Enterprise edition. Ask the
  # server rather than tag `version:` — the suite runs against several servers
  # without NEO4J_VERSION set.
  before do
    server = driver.session do |session|
      session.run("CALL dbms.components() YIELD name, versions, edition WHERE name = 'Neo4j Kernel' " \
                  'RETURN versions[0] AS version, edition').single
    end
    unless Gem::Version.new(server[:version]) >= Gem::Version.new('2025.10') && server[:edition] == 'enterprise'
      skip "VECTOR needs Neo4j 2025.10+ Enterprise, server is #{server[:version]} #{server[:edition]}"
    end
  end

  {
    int8: [-128, 0, 127],
    int16: [-32_768, 1, 32_767],
    int32: [-2_147_483_648, 1, 2_147_483_647],
    int64: [-9_223_372_036_854_775_808, 1, 9_223_372_036_854_775_807],
    float32: [1.5, -0.25, 0.0],
    float64: [Math::PI, -1.0e300, 2.5]
  }.each do |element_type, elements|
    it "echoes a #{element_type} vector" do
      vector = Neo4j::Driver::Types::Vector.new(element_type, elements)

      expect(echo(vector)).to eq(vector)
      expect(echo(vector).to_a).to eq(elements)
    end
  end

  it 'echoes vectors nested in lists and maps' do
    value = { list: [Neo4j::Driver::Types::Vector.new(:int8, [1]), Neo4j::Driver::Types::Vector.new(:float32, [2.0])] }

    expect(echo(value)).to eq(value)
  end

  it 'hydrates a vector built in Cypher' do
    driver.session do |session|
      vector = session.run('RETURN vector([1, 2, 3], 3, INTEGER8 NOT NULL) AS v').single[:v]

      expect(vector).to eq(Neo4j::Driver::Types::Vector.new(:int8, [1, 2, 3]))
    end
  end

  it 'stores a vector as a node property' do
    vector = Neo4j::Driver::Types::Vector.new(:float32, [0.5, -0.5, 0.25])
    driver.session do |session|
      session.run('CREATE (:Doc {embedding: $vector})', vector:).consume

      expect(session.run('MATCH (d:Doc) RETURN d.embedding AS e').single[:e]).to eq(vector)
    end
  end

  def echo(value)
    driver.session { |session| session.run('RETURN $x AS y', x: value).single[:y] }
  end
end
