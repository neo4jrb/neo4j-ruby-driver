# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      class NoSuchRecordException < RuntimeError
        EMPTY = 'Cannot retrieve a single record, because this result is empty.'
        TOO_MANY = 'Expected a result with a single record, but this result ' \
          'contains at least one more. Ensure your query returns only one record.'
        NO_MORE = 'No more records'
        NO_PEEK_PAST = 'Cannot peek past the last record'

        class << self
          def empty
            new(EMPTY)
          end

          def too_many
            new(TOO_MANY)
          end

          def no_more
            new(NO_MORE)
          end

          def no_peek_past
            new(NO_PEEK_PAST)
          end
        end
      end
    end
  end
end
