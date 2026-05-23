# frozen_string_literal: true

RSpec.describe Neo4j::Driver::Internal::DefaultBookmarkManager do
  next unless Neo4j::Driver::Loader.mri?

  def bm(string) = Neo4j::Driver::Bookmark.from(string)

  describe '#get_bookmarks' do
    it 'returns an empty set by default' do
      expect(described_class.new.get_bookmarks).to eq(Set.new)
    end

    it 'returns the seeded initial_bookmarks' do
      manager = described_class.new(initial_bookmarks: %w[bm:1 bm:2])
      expect(manager.get_bookmarks.map(&:value)).to contain_exactly('bm:1', 'bm:2')
    end

    it 'folds in bookmarks from the supplier on every call' do
      external = ['bm:external']
      manager = described_class.new(
        initial_bookmarks: ['bm:internal'],
        bookmarks_supplier: -> { external }
      )

      expect(manager.get_bookmarks.map(&:value)).to contain_exactly('bm:internal', 'bm:external')

      external << 'bm:external-2'
      expect(manager.get_bookmarks.map(&:value)).to contain_exactly('bm:internal', 'bm:external', 'bm:external-2')
    end

    it 'returns Bookmark instances, not raw strings, when seeded with strings' do
      manager = described_class.new(initial_bookmarks: ['bm:1'])
      expect(manager.get_bookmarks.first).to be_a(Neo4j::Driver::Bookmark)
    end
  end

  describe '#update_bookmarks' do
    it 'drops previous bookmarks and adds the new ones' do
      manager = described_class.new(initial_bookmarks: %w[bm:1 bm:2 bm:3])

      manager.update_bookmarks(%w[bm:1 bm:2], ['bm:4'])

      expect(manager.get_bookmarks.map(&:value)).to contain_exactly('bm:3', 'bm:4')
    end

    it 'is a no-op for previous entries the manager never had (set-difference)' do
      manager = described_class.new(initial_bookmarks: ['bm:keep'])

      manager.update_bookmarks(['bm:never-had'], ['bm:new'])

      expect(manager.get_bookmarks.map(&:value)).to contain_exactly('bm:keep', 'bm:new')
    end

    it 'fires the consumer with the post-update snapshot' do
      snapshots = []
      manager = described_class.new(
        initial_bookmarks: ['bm:1'],
        bookmarks_consumer: ->(set) { snapshots << set.map(&:value).sort }
      )

      manager.update_bookmarks(['bm:1'], ['bm:2'])
      manager.update_bookmarks([], ['bm:3'])

      expect(snapshots).to eq([['bm:2'], ['bm:2', 'bm:3']])
    end

    it 'accepts Bookmark instances or raw strings interchangeably on either side' do
      manager = described_class.new(initial_bookmarks: ['bm:1'])
      manager.update_bookmarks([bm('bm:1')], [bm('bm:2')])
      expect(manager.get_bookmarks.map(&:value)).to eq(['bm:2'])
    end
  end

  describe 'thread safety' do
    it 'serialises concurrent update_bookmarks without losing entries' do
      manager = described_class.new
      threads = 8.times.map do |i|
        Thread.new { 50.times { |j| manager.update_bookmarks([], ["bm:#{i}-#{j}"]) } }
      end
      threads.each(&:join)
      expect(manager.get_bookmarks.size).to eq(8 * 50)
    end
  end
end
