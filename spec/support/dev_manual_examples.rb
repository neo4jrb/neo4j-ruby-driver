############################################################################
# Ruby examples for https://neo4j.com/docs/developer-manual/current/drivers/
############################################################################


######################################
# Example 4.4. Hello World
######################################

driver = Neo4j::Driver::GraphDatabase.driver('bolt://localhost:7687',
                                             Neo4j::Driver::AuthTokens.basic('neo4j', 'password'))
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

driver.close

######################################
# Example 4.6. The driver lifecycle
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password))
# on application exit
driver.close

######################################
# Example 4.8. Basic authentication
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password))

######################################
# Example 4.9. Kerberos authentication
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.kerberos(ticket))

######################################
# Example 4.10. Custom authentication
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.custom(principal, credentials, realm,
                                                                                   scheme, parameters))
######################################
# Example 4.11. Unencrypted
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password), encryption: false)

######################################
# Example 4.12. Trust
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password),
                                             trust_strategy: Neo4j::Driver::Config::TrustStrategy.trust_all_certificates)

######################################
# Example 4.13. Connection pool management
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password),
                                             max_connection_lifetime: 3 * 60 * 60 * 1000, # 3 hours
                                             max_connection_pool_size: 50,
                                             connection_acquisition_timeout: 2 * 60 * 1000) # 120 seconds

######################################
# Example 4.14. Connection timeout
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password),
                                             connection_timeout: 15 * 1000) # 15 seconds

######################################
# Example 4.15. Load balancing strategy
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password),
                                             load_balancing_strategy: Neo4j::Driver::Config::LoadBalancingStrategy::LEAST_CONNECTED)

######################################
# Example 4.16. Max retry time
######################################

driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic(user, password),
                                             max_transaction_retry_time: 15 * 1000) # 15 seconds


######################################
# Example 4.17. Service unavailable
######################################

def add_item
  session = driver.session
  session.write_transaction do |tx|
    tx.run('CREATE (a:Item)')
    true
  end
rescue Neo4j::Driver::Exceptions::ServiceUnavailableException
  false
ensure
  session&.close
end

######################################
# Example 4.18. Session
######################################

def add_person(name)
  session = driver.session
  session.write_transaction do |tx|
    tx.run('CREATE (a:Person {name: $name})', name: name)
  end
ensure
  session&.close
end

######################################
# Example 4.19. Auto-commit transaction
######################################

def add_person(name)
  session = driver.session
  session.run('CREATE (a:Person {name: $name})', name: name)
ensure
  session&.close
end

######################################
# Example 4.20. Transaction function
######################################

def add_person(name)
  session = driver.session
  session.write_transaction { |tx| create_person_node(tx, name) }
ensure
  session&.close
end

def create_person_node(tx, name)
  tx.run('CREATE (a:Person {name: $name})', name: name)
end

######################################
# 4.3.2.3. Explicit transactions
######################################

def add_person(name)
  session = driver.session(Neo4j::Driver::AccessMode::WRITE)
  tx = session.begin_transaction
  tx.run('CREATE (a:Person {name: $name})', name: name)
  tx.success
ensure
  tx.close
  session&.close
end

######################################
# Example 4.21. Passing bookmarks between sessions
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
  result.each do |record|
    puts "#{record['a.name']} knows #{record['b.name']}"
  end
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

######################################
# Example 4.22. Read-write transaction
######################################

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

######################################
# Example 4.24. Map Neo4j types to native language types
######################################

# Neo4j type	  Ruby type
# null          nil
# List          Array
# Map           Hash
# Boolean       TrueClass/FalseClass
# Integer       Integer
# Float         Float
# String        String
# ByteArray     Neo4j::Driver::ByteArray
# Date          Date
# Time          Neo4j::Driver::OffsetTime
# LocalTime     Neo4j::Driver::LocalTime
# DateTime      Neo4j::Driver::ZonedDateTime
# LocalDateTime Neo4j::Driver::LocalDateTime
# Duration      Neo4j::Driver::Duration(optionally ActiveSupport::Duration)
# Point         Neo4j::Driver::Point
# Node          Neo4j::Driver::Node
# Relationship  Neo4j::Driver::Relationship
# Path          Neo4j::Driver::Path

######################################
# Example 4.25. Consuming the stream
######################################

def get_people
  session = driver.session
  session.read_transaction(&method(:match_person_nodes))
ensure
  session&.close
end

def match_person_nodes(tx)
  tx.run("MATCH (a:Person) RETURN a.name ORDER BY a.name").map(&:first)
end

######################################
# Example 4.26. Retain results for further processing
######################################

def add_employees(company_name)
  session = driver.session
  persons = session.read_transaction(&method(:match_person_nodes))

  persons.sum do |person|
    session.writeTransaction do |tx|
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
