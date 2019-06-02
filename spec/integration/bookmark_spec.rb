# frozen_string_literal: true

RSpec.describe 'Bookmark' do
  def create_node_in_tx(session)
    session.write_transaction { |tx| tx.run('CREATE (a:Person)') }
  end

  def preamble(session)
    expect(session.last_bookmark).not_to be_present
    create_and_expect(session)
  end

  def create_and_expect(session)
    create_node_in_tx(session)
    bookmark = session.last_bookmark
    expect(bookmark).to be_present
    bookmark
  end

  it 'receives bookmark on successfull commit' do
    driver.session do |session|
      preamble(session)
      expect(session.last_bookmark).to start_with('neo4j:bookmark:v1:tx')
    end
  end

  it 'raises for invalid bookmark' do
    invalid_bookmark = 'hi, this is an invalid bookmark'
    expect { driver.session(invalid_bookmark, &:begin_transaction) }
      .to raise_error Neo4j::Driver::Exceptions::ClientException
  end

  it 'remain after rollback tx' do
    driver.session do |session|
      bookmark = preamble(session)
      session.begin_transaction do |tx|
        tx.run('CREATE (a:Person)')
        tx.failure
      end
      expect(session.last_bookmark).to eq bookmark
    end
  end

  it 'remains after tx failure' do
    driver.session do |session|
      bookmark = preamble(session)
      tx = session.begin_transaction
      tx.run('RETURN')
      tx.success
      expect { tx.close }.to raise_error Neo4j::Driver::Exceptions::ClientException
      expect(session.last_bookmark).to eq bookmark
    end
  end

  it 'remains after succesful session run' do
    driver.session do |session|
      bookmark = preamble(session)
      session.run('RETURN 1').consume
      expect(session.last_bookmark).to eq bookmark
    end
  end

  it 'remains after failed session run' do
    driver.session do |session|
      bookmark = preamble(session)
      expect { session.run('RETURN').consume }.to raise_error Neo4j::Driver::Exceptions::ClientException
      expect(session.last_bookmark).to eq bookmark
    end
  end

  it 'is updated every committed tx' do
    driver.session do |session|
      expect(session.last_bookmark).not_to be_present
      expect(Array.new(3) { create_and_expect(session) }.to_set.size).to eq 3
    end
  end

  it 'is updated every auto-commit tx' do
    driver.session do |session|
      expect(session.last_bookmark).not_to be_present
      expect(Array.new(3) do
        session.run('CREATE (:Person)')
        session.last_bookmark
      end.to_set.size).to eq 3
    end
  end

  it 'creates session with initial bookmark' do
    bookmark = 'TheBookmark'
    expect(driver.session(bookmark, &:last_bookmark)).to eq bookmark
  end

  it 'creates session with AccessMode and initial bookmark' do
    bookmark = 'TheBookmark'
    expect(driver.session(Neo4j::Driver::AccessMode::WRITE, bookmark, &:last_bookmark)).to eq bookmark
  end
end
