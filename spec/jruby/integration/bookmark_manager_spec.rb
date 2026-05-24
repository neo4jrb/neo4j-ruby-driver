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

  it 'seeds the manager with initial_bookmarks' do
    # Produce a real bookmark from a vanilla session, then hand it to a
    # second manager as initial_bookmarks. The consumer should still
    # observe the bookmark set after a write that follows. This exercises
    # the `initial_bookmarks` → java.util.Set conversion path that
    # testkit's stub bookmark_manager tests use; without it the splat in
    # config_converter would feed a single Bookmark where a Set is
    # required and JRuby would fail to coerce.
    bookmark =
      driver.session do |session|
        session.execute_write { |tx| tx.run('CREATE (:BookmarkManagerSpec)') }
        session.last_bookmarks.first
      end
    expect(bookmark).not_to be_nil

    consumed = nil
    manager = Neo4j::Driver::BookmarkManagers.default_manager(
      initial_bookmarks: Set[bookmark],
      bookmarks_consumer: ->(bookmarks) { consumed = bookmarks }
    )

    driver.session(bookmark_manager: manager) do |session|
      session.execute_write { |tx| tx.run('CREATE (:BookmarkManagerSpec)') }
    end

    expect(consumed).to be_a(Set)
    expect(consumed.map(&:value)).to all(be_a(String)).and be_present
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
