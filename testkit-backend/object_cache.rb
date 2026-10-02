# frozen_string_literal: true

module TestkitBackend
  # Process-wide registry mapping object_id to live driver objects (drivers,
  # sessions, transactions, results) so the frontend can reference them by id
  # across requests.
  class ObjectCache < Hash
    cattr_reader :objects, default: new

    class << self
      def fetch(*)
        objects.fetch(*)
      end

      def delete(key)
        objects.delete(key)
      end

      def store(object)
        object.object_id.tap { |key| objects.store(key, object) }
      end
    end
  end
end
