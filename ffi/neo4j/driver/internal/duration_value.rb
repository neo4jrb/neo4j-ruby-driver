# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module DurationValue
        class << self
          def match(cd)
            self if code == cd
          end

          def to_ruby(value)
            %i[months days seconds].each_with_index.map { |part, index| partial_duration(part, value, index) }.sum +
              partial_duration(:seconds, value, 3) * 1e-9
          end

          def to_neo(value, object)
            Bolt::Value.format_as_structure(value, code, 4)
            Neo4j::Driver::Internal::DurationNormalizer.normalize(object).each_with_index do |elem, index|
              Neo4j::Driver::Value.to_neo(Bolt::Structure.value(value, index), elem)
            end
          end

          private

          def code_sym
            :E
          end

          def code
            code_sym.to_s.getbyte(0)
          end

          def partial_duration(part, value, index)
            ActiveSupport::Duration.send(part, Neo4j::Driver::Value.to_ruby(Bolt::Structure.value(value, index)))
          end
        end
      end
    end
  end
end
