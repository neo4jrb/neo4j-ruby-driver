# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Internal
        module Summary
          # Ruby-ifies the Java execution plan: its arguments as a Hash of
          # native Ruby values and its identifiers as an Array.
          module InternalPlan
            # Ruby-idiomatic args: Java Map<String, Value> → Hash with
            # native Ruby values. Symmetric with MRI Plan#arguments
            # (which is already a Ruby hash).
            def args
              arguments&.to_h&.transform_values(&:as_ruby_object)
            end

            def identifiers
              super.to_a
            end
          end
        end
      end
    end
  end
end
