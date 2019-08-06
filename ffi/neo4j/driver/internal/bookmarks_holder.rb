# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module BookmarksHolder
        extend ActiveSupport::Concern

        included do
          attr_reader :bookmarks
        end

        def initialize
          @bookmarks = []
        end

        def bookmarks=(bookmarks)
          bookmarks = Array(bookmarks).select(&:present?)
          @bookmarks = bookmarks if bookmarks.present?
        end

        NO_OP = Class.new do
          include BookmarksHolder

          def bookmarks=; end
        end.new
      end
    end
  end
end