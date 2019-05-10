# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module StructureValue
        def self.extended(mod)
          code = mod.const_get('CODE').to_s.getbyte(0)
          (@modules ||= {})[code] = mod
          mod.define_singleton_method(:code) { code }
        end

        def self.to_ruby(value)
          @modules[Bolt::Structure.code(value)]&.to_ruby_specific(value)
        end

        def to_ruby_specific(value)
          to_ruby_value(*Array.new(size, &method(:ruby_value).curry.call(value)))
        end

        def to_neo(value, object)
          Bolt::Value.format_as_structure(value, code, size)
          Array(to_neo_values(object)).each_with_index do |elem, index|
            Neo4j::Driver::Value.to_neo(Bolt::Structure.value(value, index), elem)
          end
        end

        private

        def ruby_value(value, index)
          Neo4j::Driver::Value.to_ruby(Bolt::Structure.value(value, index))
        end

        def size
          @size ||= method(:to_ruby_value).arity
        end
      end
    end
  end
end
