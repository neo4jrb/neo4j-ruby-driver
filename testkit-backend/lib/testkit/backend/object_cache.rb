module Testkit
  module Backend
    class ObjectCache < Hash
      cattr_reader :objects, default: new

      class << self
        def fetch(*args)
          objects.fetch(*args)
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
end
