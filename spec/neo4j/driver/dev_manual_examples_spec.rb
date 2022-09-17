# frozen_string_literal: true

RSpec.describe Neo4j::Driver do
  it 'Example 1.4. Hello World' do
    greeting = nil
    driver.session do |session|
      greeting = session.write_transaction do |tx|
        result = tx.run("CREATE (a:Greeting) SET a.message = $message RETURN a.message + ', from node ' + id(a)",
                        message: 'hello, world')
        result.single.first
      end
      puts greeting
    end

    expect(greeting).to match(/hello, world, from node \d+/)
  end

  context '2. Client applications' do
    subject do
      driver2.session { |session| session.run('RETURN 1').single.first == 1 }
    end

    after { driver2.close }

    let(:driver2) { Neo4j::Driver::GraphDatabase.driver(uri, auth_tokens, **config) }
    let(:neo4j_user) { ENV.fetch('TEST_NEO4J_USER', 'neo4j') }
    let(:neo4j_password) { ENV.fetch('TEST_NEO4J_PASS', 'pass') }
    let(:auth_tokens) { Neo4j::Driver::AuthTokens.basic(neo4j_user, neo4j_password) }
    let(:config) { {} }

    context 'Example 2.1. The driver lifecycle' do
      it { is_expected.to be true }
    end

    context 'No authentication', auth: :none do
      let(:auth_tokens) { Neo4j::Driver::AuthTokens.none }

      it { is_expected.to be true }
    end

    context 'Example 2.4. Basic authentication' do
      it { is_expected.to be true }
    end

    context 'Example 2.5. Kerberos authentication', auth: :none do
      let(:auth_tokens) { Neo4j::Driver::AuthTokens.kerberos('ticket') }

      it { is_expected.to be true }
    end

    context 'Example 2.6. Custom authentication', auth: :none do
      let(:auth_tokens) { Neo4j::Driver::AuthTokens.custom('principal', 'credentials', 'realm', 'scheme', {}) }

      it { is_expected.to be true }
    end

    context 'Example 2.7. Unencrypted' do
      let(:config) { {} }

      it { is_expected.to be true }
    end

    context 'Example 2.8. Trust' do
      let(:config) { { trust_strategy: { strategy: :trust_all_certificates } } }

      it { is_expected.to be true }
    end

    context 'Example 2.9. Connection pool management' do
      let(:config) do
        { max_connection_lifetime: 30.minutes,
          max_connection_pool_size: 50,
          connection_acquisition_timeout: 2.minutes }
      end

      it { is_expected.to be true }
    end

    context 'Example 2.10. Connection timeout' do
      let(:config) { { connection_timeout: 15.seconds } }

      it { is_expected.to be true }
    end

    context 'Example 2.11. Max retry time' do
      let(:config) { { max_transaction_retry_time: 15.seconds } }

      it { is_expected.to be true }
    end
  end

  context 'Example 2.12. Service unavailable' do
    def add_item(driver)
      session = driver.session
      session.write_transaction { |tx| tx.run('CREATE (a:Item)') }
    ensure
      session&.close
    end

    it 'raises exception' do
      expect do
        Neo4j::Driver::GraphDatabase.driver('bolt://localhost:9999', Neo4j::Driver::AuthTokens.none,
                                            max_transaction_retry_time: 0, &method(:add_item))
      end.to raise_error Neo4j::Driver::Exceptions::ServiceUnavailableException
    end
  end

  context '3. Sessions and transactions' do
    subject(:name) do
      driver.session(default_access_mode: Neo4j::Driver::AccessMode::READ) do |session|
        session.read_transaction { |tx| tx.run('MATCH (a:Person) RETURN a.name').single.first }
      end
    end

    before { add_person('John') }

    context 'Example 3.1. Session' do
      def add_person(name)
        driver.session do |session|
          session.write_transaction do |tx|
            tx.run('CREATE (a:Person {name: $name})', name: name)
          end
        end
      end

      it { is_expected.to eq 'John' }
    end

    context 'Example 3.2. Auto-commit transaction' do
      def add_person(name)
        driver.session { |session| session.run('CREATE (a:Person {name: $name})', name: name) }
      end

      it { is_expected.to eq 'John' }
    end

    context 'Example 3.3. Transaction function' do
      def add_person(name)
        session = driver.session
        session.write_transaction { |tx| create_person_node(tx, name) }
      ensure
        session&.close
      end

      def create_person_node(tx, name)
        tx.run('CREATE (a:Person {name: $name})', name: name)
      end

      it { is_expected.to eq 'John' }
    end

    context '3.2.3. Explicit transactions' do
      def add_person(name)
        driver.session(default_access_mode: Neo4j::Driver::AccessMode::WRITE) do |session|
          tx = session.begin_transaction
          tx.run('CREATE (a:Person {name: $name})', name: name)
          tx.commit
        ensure
          tx&.close
        end
      end

      it { is_expected.to eq 'John' }
    end
  end

  it 'Example 3.4. Passing bookmarks between sessions' do
    # Create a company node
    def add_company(tx, name)
      tx.run('CREATE (:Company {name: $name})', name: name)
    end

    # Create a person node
    def add_person(tx, name)
      tx.run('CREATE (:Person {name: $name})', name: name)
    end

    # Create an employment relationship to a pre-existing company node.
    # This relies on the person first having been created.
    def employ(tx, person, company)
      tx.run('MATCH (person:Person {name: $person_name}) ' \
             'MATCH (company:Company {name: $company_name}) ' \
             'CREATE (person)-[:WORKS_FOR]->(company)',
             person_name: person, company_name: company)
    end

    # Create a friendship between two people.
    def make_friends(tx, person1, person2)
      tx.run('MATCH (a:Person {name: $person_1}) ' \
             'MATCH (b:Person {name: $person_2}) ' \
             'MERGE (a)-[:KNOWS]->(b)',
             person_1: person1, person_2: person2)
    end

    # Match and display all friendships.
    def print_friends(tx)
      result = tx.run('MATCH (a)-[:KNOWS]->(b) RETURN a.name, b.name')
      result.map { |record| "#{record['a.name']} knows #{record['b.name']}" }
    end

    def add_employ_and_make_friends
      # To collect the session bookmarks
      saved_bookmarks = []

      # Create the first person and employment relationship.
      driver.session(default_access_mode: Neo4j::Driver::AccessMode::WRITE) do |session1|
        session1.write_transaction { |tx| add_company(tx, 'Wayne Enterprises') }
        session1.write_transaction { |tx| add_person(tx, 'Alice') }
        session1.write_transaction { |tx| employ(tx, 'Alice', 'Wayne Enterprises') }

        saved_bookmarks << session1.last_bookmark
      end

      # Create the second person and employment relationship.
      driver.session(default_access_mode: Neo4j::Driver::AccessMode::WRITE) do |session2|
        session2.write_transaction { |tx| add_company(tx, 'LexCorp') }
        session2.write_transaction { |tx| add_person(tx, 'Bob') }
        session2.write_transaction { |tx| employ(tx, 'Bob', 'LexCorp') }

        saved_bookmarks << session2.last_bookmark
      end

      # Create a friendship between the two people created above.
      driver.session(default_access_mode: Neo4j::Driver::AccessMode::WRITE, bookmarks: saved_bookmarks) do |session3|
        session3.write_transaction { |tx| make_friends(tx, 'Alice', 'Bob') }

        session3.read_transaction(&method(:print_friends))
      end
    end

    expect(add_employ_and_make_friends).to eq(['Alice knows Bob'])
  end

  it 'Example 3.5. Read-write transaction' do
    def add_person(name)
      driver.session do |session|
        session.write_transaction { |tx| create_person_node(tx, name) }
        session.read_transaction { |tx| match_person_node(tx, name) }
      end
    end

    def create_person_node(tx, name)
      tx.run('CREATE (a:Person {name: $name})', name: name)
    end

    def match_person_node(tx, name)
      tx.run('MATCH (a:Person {name: $name}) RETURN id(a)', name: name).single.first.to_i
    end

    expect(add_person('John')).to be_a(Integer)
  end

  context '4.2 Statement Results' do
    before do
      driver.session do |session|
        session.write_transaction { |tx| tx.run("CREATE (:Person{name: 'John'}) CREATE (:Person{name: 'Paul'})") }
      end
    end

    it 'Example 4.2. Consuming the stream' do
      def people
        driver.session { |session| session.read_transaction(&method(:match_person_nodes)) }
      end

      def match_person_nodes(tx)
        tx.run('MATCH (a:Person) RETURN a.name ORDER BY a.name').map(&:first)
      end

      expect(people).to eq %w[John Paul]
    end

    it 'Example 4.3. Retain results for further processing' do
      def add_employees(company_name)
        driver.session do |session|
          persons = session.read_transaction(&method(:match_person_nodes))

          persons.sum do |person|
            session.write_transaction do |tx|
              tx.run('MATCH (emp:Person {name: $person_name}) ' \
                     'MERGE (com:Company {name: $company_name}) ' \
                     'MERGE (emp)-[:WORKS_FOR]->(com)',
                     person_name: person[:name], company_name: company_name)
              1
            end
          end
        end
      end

      def match_person_nodes(tx)
        tx.run('MATCH (a:Person) RETURN a.name AS name').to_a
      end

      expect(add_employees('abc')).to eq(2)
    end
  end
end
