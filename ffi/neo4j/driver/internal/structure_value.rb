# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module StructureValue
        def match(cd)
          self if code == cd
        end

        private

        def code
          code_sym.to_s.getbyte(0)
        end
      end
    end
  end
end
