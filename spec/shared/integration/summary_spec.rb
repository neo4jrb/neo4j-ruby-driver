# frozen_string_literal: true

RSpec.describe 'Summary' do
  it 'contains basic metadata' do
    driver.session do |session|
      statement_text = 'UNWIND [1, 2, 3, 4] AS n RETURN n AS number LIMIT $limit'
      statement_parameters = { limit: 10 }
      result = session.run(statement_text, statement_parameters)
      expect(result).to have_next
      summary = result.consume
      expect(summary.query_type).to eq Neo4j::Driver::Summary::QueryType::READ_ONLY
      expect(summary.query.text).to eq statement_text
      expect(summary.query.parameters).to eq statement_parameters
      expect(summary).not_to have_plan
      expect(summary).not_to have_profile
      expect(summary).to eq result.consume
      expect(summary.server.address).to eq address # address frpm DriverHelper
    end
  end

  it 'contains time information' do
    driver.session do |session|
      summary = session.run('UNWIND range(1,1000) AS n RETURN n AS numbe').consume
      expect(summary.result_available_after).to be >= 0
      expect(summary.result_consumed_after).to be >= 0
    end
  end

  it 'contains correct statistics' do
    driver.session do |session|
      expect(session.run('CREATE (n)').consume.counters.nodes_created).to eq 1
      expect(session.run('MATCH (n) DELETE (n)').consume.counters.nodes_deleted).to eq 1

      expect(session.run('CREATE ()-[:KNOWS]->()').consume.counters.relationships_created).to eq 1
      expect(session.run('MATCH ()-[r:KNOWS]->() DELETE r').consume.counters.relationships_deleted).to eq 1

      expect(session.run('CREATE (n:ALabel)').consume.counters.labels_added).to eq 1
      expect(session.run('CREATE (n {magic: 42})').consume.counters.properties_set).to eq 1
      expect(session.run('CREATE (n {magic: 42})').consume.counters.contains_updates?).to be true
      expect(session.run('MATCH (n:ALabel) REMOVE n:ALabel ').consume.counters.labels_removed).to eq 1

      expect(session.run('CREATE INDEX name FOR (l:ALabel) ON (l.prop)').consume.counters.indexes_added).to eq 1
      expect(session.run('DROP INDEX name').consume.counters.indexes_removed).to eq 1

      expect(session.run('CREATE CONSTRAINT name FOR (book:Book) REQUIRE book.isbn IS UNIQUE')
                    .consume.counters.constraints_added).to eq 1
      expect(session.run('DROP CONSTRAINT name')
                    .consume.counters.constraints_removed).to eq 1
    end
  end

  it 'contain correct statement type' do
    driver.session do |session|
      expect(session.run('MATCH (n) RETURN 1').consume.query_type)
        .to eq Neo4j::Driver::Summary::QueryType::READ_ONLY
      expect(session.run('CREATE (n)').consume.query_type)
        .to eq Neo4j::Driver::Summary::QueryType::WRITE_ONLY
      expect(session.run('CREATE (n) RETURN (n)').consume.query_type)
        .to eq Neo4j::Driver::Summary::QueryType::READ_WRITE
      expect(session.run('CREATE INDEX name FOR (u:User) ON (u.p)').consume.query_type)
        .to eq Neo4j::Driver::Summary::QueryType::SCHEMA_WRITE
      expect(session.run('DROP INDEX name').consume.query_type)
        .to eq Neo4j::Driver::Summary::QueryType::SCHEMA_WRITE
    end
  end

  it 'contains correct plan' do
    driver.session do |session|
      summary = session.run('EXPLAIN MATCH (n) RETURN 1').consume

      expect(summary).to have_plan

      plan = summary.plan
      expect(plan.operator_type).to be_present
      expect(plan.identifiers).to be_present
      expect(plan.arguments).to be_present
      expect(plan.children).to be_present
    end
  end

  it 'contains profile' do
    driver.session do |session|
      summary = session.run('PROFILE RETURN 1').consume

      expect(summary).to have_profile
      # Profile is a superset of plan, so plan should be available as well if profile is available
      expect(summary).to have_plan
      expect(summary.plan).to eq summary.profile

      profile = summary.profile

      expect(profile.db_hits).to eq 0
      expect(profile.records).to eq 1
    end
  end

  it 'contains notifications' do
    driver.session do |session|
      # 'EXPLAIN MATCH (n), (m) RETURN n, m' seems to return notifications randomly. Server issue?
      # summary = session.run('EXPLAIN MATCH (n), (m) RETURN n, m').consume
      # summary = session.run('EXPLAIN MATCH (n), (m) RETURN *').consume
      summary = session.run('EXPLAIN MATCH (n:ThisLabelDoesNotExist) RETURN n').consume

      notifications = summary.notifications
      expect(notifications).to be_present
      expect(notifications.size).to eq 1
      notification = notifications.first
      expect(notification.code).to be_present
      expect(notification.title).to be_present
      expect(notification.description).to be_present
      expect(notification.severity_level).to be_present
      expect(notification.position).to be_present
    end
  end

  it 'contains no notifications' do
    driver.session do |session|
      summary = session.run('RETURN 1').consume

      expect(summary.notifications).to be_empty
    end
  end

  # Ported from neo4j-java-driver SummaryIT.shouldGetSystemUpdates
  # (multi-database + admin command -> needs Neo4j 4+ enterprise).
  it 'reports system updates separately from graph updates', version: '>=4' do
    driver.session(database: 'system') do |session|
      session.run('DROP USER foo IF EXISTS').consume
      counters = session.run("CREATE USER foo SET PASSWORD 'Testing0'").consume.counters
      expect(counters.contains_updates?).to be false
      expect(counters.contains_system_updates?).to be true
    ensure
      session.run('DROP USER foo IF EXISTS').consume rescue nil
    end
  end
end
