# frozen_string_literal: true

# Exercises the common BookmarkManager API — BookmarkManagers.default_manager
# plus session(bookmark_manager:) — in Ruby terms only (Set, Bookmark#value).
# Lives under spec/jruby for now only because MRI has not implemented the
# feature yet; the assertions are impl-agnostic and should hold on MRI too.
RSpec.describe 'BookmarkManager' do
  it 'tracks bookmarks across sessions and notifies the consumer on commit' do
    consumed = nil
    manager = Neo4j::Driver::BookmarkManagers.default_manager(
      bookmarks_consumer: ->(bookmarks) { consumed = bookmarks }
    )

    driver.session(bookmark_manager: manager) do |session|
      session.execute_write { |tx| tx.run('CREATE (:BookmarkManagerSpec)') }
    end

    expect(consumed).to be_a(Set)
    expect(consumed.map(&:value)).to all(be_a(String)).and be_present

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
        Set.new
      }
    )

    driver.session(bookmark_manager: manager) do |session|
      session.run('RETURN 1').consume
    end

    expect(supplier_called).to be true
  end
end
