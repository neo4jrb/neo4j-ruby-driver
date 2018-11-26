RSpec.describe Neo4j::Driver do
  it 'Example 4.4. Hello World' do
    begin
      session = driver.session
      greeting = session.write_transaction do |tx|
        result = tx.run("CREATE (a:Greeting) SET a.message = $message RETURN a.message + ', from node ' + id(a)",
                        message: 'hello, world')
        result.single.first
      end
      puts greeting
    ensure
      session&.close
    end

    expect(greeting).to match(/hello, world, from node \d+/)
  end

  context '4.2. Client applications' do
    let(:driver2) { Neo4j::Driver::GraphDatabase.driver(uri, auth_tokens, config) }
    let(:auth_tokens) { Neo4j::Driver::AuthTokens.basic('neo4j', 'password') }
    let(:config) { {} }
    after(:example) { driver2.close }
    subject do
      session = driver2.session
      session.run("RETURN 1").single.first == 1
    ensure
      session&.close
    end

    context 'Example 4.6. The driver lifecycle' do
      it { is_expected.to be true }
    end

    context 'Example 4.8. Basic authentication' do
      it { is_expected.to be true }
    end

    context 'Example 4.9. Kerberos authentication' do
      let(:auth_tokens) { Neo4j::Driver::AuthTokens.kerberos('ticket') }
      it { is_expected.to be true }
    end

    context 'Example 4.10. Custom authentication' do
      let(:auth_tokens) { Neo4j::Driver::AuthTokens.custom('principal', 'credentials', 'realm', 'scheme', {}) }
      it { is_expected.to be true }
    end

    context 'Example 4.11. Unencrypted' do
      let(:config) { { encryption: false } }
      it { is_expected.to be true }
    end

    context 'Example 4.12. Trustd' do
      let(:config) { { trust_strategy: Neo4j::Driver::Config::TrustStrategy.trust_all_certificates } }
      it { is_expected.to be true }
    end

    context 'Example 4.13. Connection pool management' do
      let(:config) { {
        max_connection_lifetime: 3 * 60 * 60 * 1000, # 3 hours
        max_connection_pool_size: 50,
        connection_acquisition_timeout: 2 * 60 * 1000 } } # 120 seconds
      it { is_expected.to be true }
    end

    context 'Example 4.14. Connection timeout' do
      let(:config) { { connection_timeout: 15 * 1000 } } # 15 seconds
      it { is_expected.to be true }
    end

    context 'Example 4.15. Load balancing strategy' do
      let(:config) { { load_balancing_strategy: Neo4j::Driver::Config::LoadBalancingStrategy::LEAST_CONNECTED } }
      it { is_expected.to be true }
    end

    context 'Example 4.16. Max retry time' do
      let(:config) { { max_transaction_retry_time: 15 * 1000 } } # 15 seconds
      it { is_expected.to be true }
    end
  end

  context 'Example 4.17. Service unavailable' do
    def add_item(driver)
      session = driver.session
      session.write_transaction { |tx| tx.run('CREATE (a:Item)') }
    ensure
      session&.close
    end

    it 'raises exception' do
      expect { add_item(Neo4j::Driver::GraphDatabase.driver('bolt://localhost:7998')) }
        .to raise_error Neo4j::Driver::Exceptions::ServiceUnavailableException
    end
  end

  context '4.3. Sessions and transactions' do
    before(:example) { add_person('John') }
    subject(:name) do
      session = driver.session(Neo4j::Driver::AccessMode::READ)
      session.read_transaction { |tx| tx.run('MATCH (a:Person) RETURN a.name').single.first }
    ensure
      session&.close
    end

    context 'Example 4.18. Session' do
      def add_person(name)
        session = driver.session
        session.write_transaction do |tx|
          tx.run('CREATE (a:Person {name: $name})', name: name)
        end
      ensure
        session&.close
      end

      it { is_expected.to eq 'John' }
    end

    context 'Example 4.19. Auto-commit transaction' do
      def add_person(name)
        session = driver.session
        session.run('CREATE (a:Person {name: $name})', name: name)
      ensure
        session&.close
      end

      it { is_expected.to eq 'John' }
    end

    context 'Example 4.20. Transaction function' do
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

    context '4.3.2.3. Explicit transactions' do
      def add_person(name)
        session = driver.session(Neo4j::Driver::AccessMode::WRITE)
        tx = session.begin_transaction
        tx.run('CREATE (a:Person {name: $name})', name: name)
        tx.success
      ensure
        tx&.close
        session&.close
      end

      it { is_expected.to eq 'John' }
    end
  end

  it 'Example 4.21. Passing bookmarks between sessions' do
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
      tx.run("MATCH (person:Person {name: $person_name}) " +
               "MATCH (company:Company {name: $company_name}) " +
               "CREATE (person)-[:WORKS_FOR]->(company)",
             person_name: person, company_name: company)
    end

    # Create a friendship between two people.
    def make_friends(tx, person1, person2)
      tx.run("MATCH (a:Person {name: $person_1}) " +
               "MATCH (b:Person {name: $person_2}) " +
               "MERGE (a)-[:KNOWS]->(b)",
             person_1: person1, person_2: person2)
    end

    # Match and display all friendships.
    def print_friends(tx)
      result = tx.run("MATCH (a)-[:KNOWS]->(b) RETURN a.name, b.name")
      result.map { |record| "#{record['a.name']} knows #{record['b.name']}" }
    end

    def add_employ_and_make_friends
      # To collect the session bookmarks
      saved_bookmarks = []

      begin
        # Create the first person and employment relationship.
        session1 = driver.session(Neo4j::Driver::AccessMode::WRITE)

        session1.write_transaction { |tx| add_company(tx, "Wayne Enterprises") }
        session1.write_transaction { |tx| add_person(tx, "Alice") }
        session1.write_transaction { |tx| employ(tx, "Alice", "Wayne Enterprises") }

        saved_bookmarks << session1.last_bookmark
      ensure
        session1&.close
      end

      begin
        # Create the second person and employment relationship.
        session2 = driver.session(Neo4j::Driver::AccessMode::WRITE)
        session2.write_transaction { |tx| add_company(tx, "LexCorp") }
        session2.write_transaction { |tx| add_person(tx, "Bob") }
        session2.write_transaction { |tx| employ(tx, "Bob", "LexCorp") }

        saved_bookmarks << session2.last_bookmark
      ensure
        session2&.close
      end

      begin
        # Create a friendship between the two people created above.
        session3 = driver.session(Neo4j::Driver::AccessMode::WRITE, saved_bookmarks)
        session3.write_transaction { |tx| make_friends(tx, "Alice", "Bob") }

        session3.read_transaction(&method(:print_friends))
      ensure
        session3&.close
      end
    end

    expect(add_employ_and_make_friends).to eq(['Alice knows Bob'])
  end

  it 'Example 4.22. Read-write transaction' do
    def add_person(name)
      session = driver.session
      session.write_transaction { |tx| create_person_node(tx, name) }
      session.read_transaction { |tx| match_person_node(tx, name) }
    ensure
      session&.close
    end

    def create_person_node(tx, name)
      tx.run('CREATE (a:Person {name: $name})', name: name)
    end

    def match_person_node(tx, name)
      tx.run('MATCH (a:Person {name: $name}) RETURN id(a)', name: name).single.first.to_i
    end

    expect(add_person('John')).to be_a(Integer)
  end

  context '4.4.2 Statement Results' do
    before(:example) do
      session = driver.session
      session.write_transaction { |tx| tx.run("CREATE (:Person{name: 'John'}) CREATE (:Person{name: 'Paul'})") }
    ensure
      session&.close
    end

    it 'Example 4.25. Consuming the stream' do
      def get_people
        session = driver.session
        session.read_transaction(&method(:match_person_nodes))
      ensure
        session&.close
      end

      def match_person_nodes(tx)
        tx.run("MATCH (a:Person) RETURN a.name ORDER BY a.name").map(&:first)
      end

      expect(get_people).to eq(['John', 'Paul'])
    end


    it 'Example 4.26. Retain results for further processing' do
      def add_employees(company_name)
        session = driver.session
        persons = session.read_transaction(&method(:match_person_nodes))

        persons.sum do |person|
          session.write_transaction do |tx|
            tx.run("MATCH (emp:Person {name: $person_name}) " +
                     "MERGE (com:Company {name: $company_name}) " +
                     "MERGE (emp)-[:WORKS_FOR]->(com)",
                   person_name: person[:name], company_name: company_name)
            1
          end
        end
      ensure
        session&.close
      end

      def match_person_nodes(tx)
        tx.run('MATCH (a:Person) RETURN a.name AS name').to_a
      end

      expect(add_employees('abc')).to eq(2)
    end
  end
end
