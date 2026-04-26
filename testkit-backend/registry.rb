# frozen_string_literal: true

module TestkitBackend
  # Single per-connection store mapping unique opaque ids to live objects
  # (drivers, sessions, transactions, results). Type info is carried by
  # the calling code: a request that fetches a session simply calls
  # session methods on whatever it gets; a wrong-typed lookup fails
  # naturally on the first method call.
  class Registry
    UnknownHandle = Class.new(KeyError)

    def initialize
      @objects = {}
    end

    # Returns a freshly-minted id for the stored object. The optional
    # prefix is purely cosmetic for log readability.
    def store(object, prefix: short_class_name(object))
      id = "#{prefix}-#{SecureRandom.hex(6)}"
      @objects[id] = object
      id
    end

    def fetch(id)
      @objects.fetch(id) { raise UnknownHandle, "no handle #{id.inspect}" }
    end

    # Look up and remove. Raises if the id isn't known — for callers that
    # genuinely require the object to exist.
    def take(id)
      @objects.delete(id) || raise(UnknownHandle, "no handle #{id.inspect}")
    end

    # Lenient remove. Returns the object or nil. Use for close-style
    # handlers where double-close should be a silent no-op.
    def delete(id)
      @objects.delete(id)
    end

    private

    def short_class_name(object)
      object.class.name&.split('::')&.last&.downcase || 'obj'
    end
  end
end
