module Testkit::Backend::Messages
  class Response
    extend Conversion

    def initialize(object)
      @object = object
    end

    def name
      self.class.name.split('::').last
    end

    def to_testkit
      named_entity(name, **data)
    end

    def named_entity(name, **hash)
      self.class.named_entity(name, **hash)
    end

    def self.named_entity(name, **hash)
      { name: name }.tap do |entity|
        entity[:data] = hash unless hash.empty?
      end
    end

    def value_entity(name, object)
      named_entity(name, value: object)
    end
  end
end
