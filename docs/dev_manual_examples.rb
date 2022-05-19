############################################################################
# Ruby examples for https://neo4j.com/docs/developer-manual/current/drivers/
############################################################################

######################################
# Getting Started
# Example 4. Hello World
######################################

Neo4j::Driver::GraphDatabase.driver('bolt://localhost:7687',
                                    Neo4j::Driver::AuthTokens.basic('neo4j', 'pass')) do |driver|
  driver.session do |session|
    greeting = session.write_transaction do |tx|
      result = tx.run("CREATE (a:Greeting) SET a.message = $message RETURN a.message + ', from node ' + id(a)",
                      message: 'hello, world')
      result.single.first
    end # session auto closed at the end of the block if one given
    puts greeting
  end
end # driver auto closed at the end of the block if one given

######################################
# Client Application
# Example 1. The driver lifecycle
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password))
# on application exit
driver.close

######################################
# Client Application
# Example 2. Custom Address Resolver
######################################

private

def create_driver(virtual_uri, user, password, *addresses, &block)
  config = { resolver: -> { addresses } }
  Neo4j::Driver::GraphDatabase.driver(virtual_uri, Neo4j::Driver::AuthTokens.basic(user, password), config, &block)
end

def add_person(name)
  username = 'neo4j'
  password = 'pass'
  create_driver('bolt+routing://x.acme.com', username, password, ServerAddress.of('a.acme.com', 7676),
                ServerAddress.of('b.acme.com', 8787), ServerAddress.of('c.acme.com', 9898)) do |driver|
    driver.session { |session| session.run('CREATE (a:Person {name: $name})', name: name) }
  end
end

######################################
# Client Application
# Example 3. Connecting to a service
######################################

######################################
# Example 3.1 Neo4j Aura Secured with full certificate
######################################

uri = 'neo4j+s://graph.example.com:7687'

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password))

# If you do not have at least the Ruby Driver 4.0.1 patch installed, you will need this snippet instead:

uri = 'neo4j://graph.example.com:7687'

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password), encryption: true)

######################################
# Example 3.2 Neo4j 4.x Unsecured
######################################

uri = 'neo4j://graph.example.com:7687'

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password))

######################################
# Example 3.3 Neo4j 4.x Secured with full certificate
######################################

uri = 'neo4j+s://graph.example.com:7687'

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password))

# If you do not have at least the Ruby Driver 4.0.1 patch installed, you will need this snippet instead:

uri = 'neo4j://graph.example.com:7687'

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password), encryption: true)

######################################
# Example 3.4 Neo4j 4.x Secured with self-signed certificate
######################################

uri = 'neo4j+ssc://graph.example.com:7687'

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password))

# If you do not have at least the Ruby Driver 4.0.1 patch installed, you will need this snippet instead:

uri = 'neo4j://graph.example.com:7687'

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password),
                                             trust_strategy: Neo4j::Driver::Config::TrustStrategy.trust_all_certificates, encryption: true)

######################################
# Example 3.5 Neo4j 3.x Secured with full certificate
######################################

uri = 'neo4j+s://graph.example.com:7687'

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password))

# If you do not have at least the Ruby Driver 4.0.1 patch installed, you will need this snippet instead:

uri = 'neo4j://graph.example.com:7687'

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password), encryption: true)

######################################
# Example 3.6 Neo4j 3.x Secured with self-signed certificate
######################################

uri = 'neo4j+ssc://graph.example.com:7687'

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password))

# If you do not have at least the Ruby Driver 4.0.1 patch installed, you will need this snippet instead:

uri = 'neo4j://graph.example.com:7687'

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password),
                                             trust_strategy: Neo4j::Driver::Config::TrustStrategy.trust_all_certificates, encryption: true)


######################################
# Example 3.7 Neo4j 3.x Unsecured
######################################

uri = 'neo4j://graph.example.com:7687'

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password))

######################################
# Client Application
# Example 4. Basic authentication
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password))

######################################
# Client Application
# Example 5. Kerberos authentication
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.kerberos(ticket))

######################################
# Client Application
# Example 6. Bearer authentication
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.bearer(bearer_token))

######################################
# Client Application
# Example 7. Custom authentication
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.custom(principal, credentials, realm,
                                                                                   scheme, parameters))

######################################
# Client Application
# Example 8. Configure connection pool
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password),
                                             max_connection_lifetime: 30.minutes,
                                             max_connection_pool_size: 50,
                                             connection_acquisition_timeout: 2.minutes)

######################################
# Client Application
# Example 9. Configure connection timeout
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password),
                                             connection_timeout: 15.seconds)

######################################
# Client Application
# Example 10. Unencrypted configuration
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password), encryption: false)

######################################
# Client Application
# Example 11. Configure maximum retry time
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password),
                                             max_transaction_retry_time: 15.seconds)

######################################
# Client Application
# Example 12. Configure trusted certificates
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password),
                                             trust_strategy: Neo4j::Driver::Config::TrustStrategy.trust_all_certificates)


######################################
# Example 13. Service unavailable
######################################

def add_item
  driver.session do |session|
    session.write_transaction do |tx|
      tx.run('CREATE (a:Item)')
      true
    end
  rescue Neo4j::Driver::Exceptions::ServiceUnavailableException
    false
  end
end

######################################
# Example 3.1. Session
######################################

def add_person(name)
  driver.session do |session|
    session.write_transaction do |tx|
      tx.run('CREATE (a:Person {name: $name})', name: name)
    end
  end
end

######################################
# Example 3.2. Auto-commit transaction
######################################

def add_person(name)
  driver.session do |session|
    session.run('CREATE (a:Person {name: $name})', name: name)
  end
end

######################################
# Example 3.3. Transaction function
######################################

def add_person(name)
  driver.session do |session|
    session.write_transaction { |tx| create_person_node(tx, name) }
  end
end

def create_person_node(tx, name)
  tx.run('CREATE (a:Person {name: $name})', name: name)
end

######################################
# 3.2.3. Explicit transactions
######################################

def add_person(name)
  driver.session(Neo4j::Driver::AccessMode::WRITE) do |session|
    tx = session.begin_transaction
    tx.run('CREATE (a:Person {name: $name})', name: name)
    tx.commit
  ensure
    tx&.close
  end
end

######################################
# Example 3.4. Passing bookmarks between sessions
######################################

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
  result.each do |record|
    puts "#{record['a.name']} knows #{record['b.name']}"
  end
end

def add_employ_and_make_friends
  # To collect the session bookmarks
  saved_bookmarks = []

  # Create the first person and employment relationship.
  driver.session(Neo4j::Driver::AccessMode::WRITE) do |session1|
    session1.write_transaction { |tx| add_company(tx, 'Wayne Enterprises') }
    session1.write_transaction { |tx| add_person(tx, 'Alice') }
    session1.write_transaction { |tx| employ(tx, 'Alice', 'Wayne Enterprises') }

    saved_bookmarks << session1.last_bookmark
  end

  # Create the second person and employment relationship.
  driver.session(Neo4j::Driver::AccessMode::WRITE) do |session2|
    session2.write_transaction { |tx| add_company(tx, 'LexCorp') }
    session2.write_transaction { |tx| add_person(tx, 'Bob') }
    session2.write_transaction { |tx| employ(tx, 'Bob', 'LexCorp') }

    saved_bookmarks << session2.last_bookmark
  end

  # Create a friendship between the two people created above.
  driver.session(Neo4j::Driver::AccessMode::WRITE, *saved_bookmarks) do |session3|
    session3.write_transaction { |tx| make_friends(tx, 'Alice', 'Bob') }

    session3.read_transaction(&method(:print_friends))
  end
end

######################################
# Example 3.5. Read-write transaction
######################################

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

######################################
# Example 4.1. Map Neo4j types to native language types
######################################

# Neo4j type    Ruby type
# null          nil
# List          Enumerable
# Map           Hash (symbolized keys)
# Boolean       TrueClass/FalseClass
# Integer       Integer (String)*
# Float         Float
# String        String (Symbol)* (encoding: UTF-8)
# ByteArray     String (encoding: BINARY)
# Date          Date
# Time          Neo4j::Driver::Types::OffsetTime
# LocalTime     Neo4j::Driver::Types::LocalTime
# DateTime      Time/ActiveSupport::TimeWithZone (DateTime)*
# LocalDateTime Neo4j::Driver::Types::LocalDateTime
# Duration      ActiveSupport::Duration
# Point         Neo4j::Driver::Types::Point
# Node          Neo4j::Driver::Types::Node
# Relationship  Neo4j::Driver::Types::Relationship
# Path          Neo4j::Driver::Types::Path

# * An Integer smaller than -2 ** 63 or lager than 2 ** 63 will always be implicitly converted to String
# * A Symbol passed as a parameter will always be implicitly converted to String. All Strings other then BINARY encoded when stored in neo4j are converte to UTF-8
# * A ruby DateTime passed as a parameter will always be implicitly converted to Time

######################################
# Example 4.2. Consuming the stream
######################################

def people
  driver.session do |session|
    session.read_transaction(&method(:match_person_nodes))
  end
end

def match_person_nodes(tx)
  tx.run('MATCH (a:Person) RETURN a.name ORDER BY a.name').map(&:first)
end

######################################
# Example 4.3. Retain results for further processing
######################################

def add_employees(company_name)
  driver.session do |session|
    persons = session.read_transaction(&method(:match_person_nodes))

    persons.sum do |person|
      session.writeTransaction do |tx|
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
