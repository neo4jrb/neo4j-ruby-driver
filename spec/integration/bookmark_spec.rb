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

  it 'receives bookmark on successfull commit', version: '<4' do
    driver.session do |session|
      preamble(session)
      expect_single_value(session.last_bookmark, 'neo4j:bookmark:v1:tx')
    end
  end

  def expect_single_value(bookmark, value)
    expect(bookmark).to be_present
    expect(bookmark).to be_a Neo4j::Driver::Bookmark
    values = bookmark.values
    expect(values.size).to eq 1
    expect(values.first).to start_with(value)
  end

  # TODO: The version restriction should not be present here!
  it 'raises for invalid bookmark', version: '<=5.7.0' do
    invalid_bookmark = Neo4j::Driver::Bookmark.from(Set['hi, this is an invalid bookmark'])
    expect { driver.session(bookmarks: invalid_bookmark, &:begin_transaction) }
      .to raise_error Neo4j::Driver::Exceptions::ClientException
  end

  it 'remain after rollback tx' do
    driver.session do |session|
      bookmark = preamble(session)
      session.begin_transaction do |tx|
        tx.run('CREATE (a:Person)')
        tx.rollback
      end
      expect(session.last_bookmark).to eq bookmark
    end
  end

  it 'remains after tx failure' do
    driver.session do |session|
      bookmark = preamble(session)
      tx = session.begin_transaction
      expect { tx.run('RETURN') }.to raise_error Neo4j::Driver::Exceptions::ClientException
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

  # bookmarks are ignored for auto-commit transactions in this version (1) of the protocol
  # it 'is updated every auto-commit tx' do
  #   driver.session do |session|
  #     expect(session.last_bookmark).not_to be_present
  #     expect(Array.new(3) do
  #       session.run('CREATE (:Person)')
  #       session.last_bookmark.tap {|bk| puts "bk=#{bk.inspect}"}
  #     end.compact.to_set.size).to eq 3
  #   end
  # end

  it 'creates session with initial bookmark' do
    bookmark = Neo4j::Driver::Bookmark.from('TheBookmark')
    expect(driver.session(bookmarks: bookmark, &:last_bookmark)).to eq bookmark
  end

  it 'fails on invalid bookmark using tx func' do
    bookmark = Neo4j::Driver::Bookmark.from('hi, this is an invalid bookmark')
    driver.session(bookmarks: bookmark) do |session|
      expect { session.read_transaction { |tx| tx.run('RETURN 1').single } }
        .to raise_error Neo4j::Driver::Exceptions::ClientException do |e|
        expect(e.code).to eq 'Neo.ClientError.Transaction.InvalidBookmark'
      end
    end
  end

  it 'creates session with AccessMode and initial bookmark' do
    bookmark = Neo4j::Driver::Bookmark.from('TheBookmark')
    expect(driver.session(default_access_mode: Neo4j::Driver::AccessMode::WRITE, bookmarks: bookmark, &:last_bookmark))
      .to eq bookmark
  end
end
