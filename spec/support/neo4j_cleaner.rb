# frozen_string_literal: true

module Neo4jCleaner
  def start; end

  def clean
    execute 'MATCH (n) DETACH DELETE n'
  end

  def cleaning
    Sync do
      start
      yield
      clean
    end
  end

  def clean_with(*_args)
    clean
  end

  def clean_all
    p 'Cleaning neo4j database'
    execute 'CALL apoc.schema.assert({}, {})'
    clean
  end

  private

  def execute(query)
    driver.session { run(query) }
  end
end
