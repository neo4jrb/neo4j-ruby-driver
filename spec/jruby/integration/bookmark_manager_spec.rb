# frozen_string_literal: true

# Exercises the JRuby BookmarkManager surface: BookmarkManagers.default_manager
# plus session(bookmark_manager:) wiring. JRuby-only — MRI does not yet
# advertise Feature:API:BookmarkManager.
RSpec.describe 'BookmarkManager' do
  it 'tracks bookmarks across sessions and notifies the consumer on commit' do
    consumed = []
    manager = Neo4j::Driver::BookmarkManagers.default_manager(
      bookmarks_consumer: ->(bookmarks) { consumed = bookmarks.map(&:value) }
    )

    driver.session(bookmark_manager: manager) do |session|
      session.execute_write { |tx| tx.run('CREATE (:BookmarkManagerSpec)') }
    end

    expect(consumed).not_to be_empty
    expect(manager.get_bookmarks.map(&:value)).to match_array(consumed)

    # A fresh session driven by the same manager inherits the tracked
    # bookmark, so this read is causally chained after the write above.
    count = driver.session(bookmark_manager: manager) do |session|
      session.execute_read do |tx|
        tx.run('MATCH (n:BookmarkManagerSpec) RETURN count(n)').single[0]
      end
    end
    expect(count).to eq 1
  end

  it 'consults the registered supplier when a session opens' do
    supplier_called = false
    manager = Neo4j::Driver::BookmarkManagers.default_manager(
      bookmarks_supplier: lambda {
        supplier_called = true
        java.util.HashSet.new
      }
    )

    driver.session(bookmark_manager: manager) do |session|
      session.run('RETURN 1').consume
    end

    expect(supplier_called).to be true
  end
end
