# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      class NoSuchRecordException < RuntimeError
        EMPTY = 'Cannot retrieve a single record, because this result is empty.'
        TOO_MANY = 'Expected a result with a single record, but this result ' \
          'contains at least one more. Ensure your query returns only one record.'

        class << self
          def empty
            new(EMPTY)
          end

          def too_many
            new(TOO_MANY)
          end
        end
      end
    end
  end
end
