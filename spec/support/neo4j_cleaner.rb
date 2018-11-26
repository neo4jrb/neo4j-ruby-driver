# frozen_string_literal: true

module Neo4jCleaner
  def start
  end

  def clean
    execute 'MATCH (n) DETACH DELETE n'
  end

  def cleaning(&block)
    start
    yield
    clean
  end

  def clean_with(*args)
    clean
  end

  def clean_all
    p 'Cleaning neo4j database'
    execute 'CALL apoc.schema.assert({}, {})'
    clean
  end

  private

  def execute(query)
    driver.session.tap { |session| session.writeTransaction { |tx| tx.run(query) } }.close
  end
end
