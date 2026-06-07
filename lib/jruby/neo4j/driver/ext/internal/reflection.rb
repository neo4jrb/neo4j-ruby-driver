# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        # Read a private field off a Java object. Used to reach internal
        # driver state the 6.x public API no longer exposes (the routing
        # table registry chain consumed by testkit's GetRoutingTable).
        module Reflection
          def self.field(object, name)
            object.java_class.declared_field(name).tap { |f| f.accessible = true }.get(object)
          end
        end
      end
    end
  end
end
