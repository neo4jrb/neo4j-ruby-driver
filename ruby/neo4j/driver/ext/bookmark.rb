# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module Bookmark
        module ClassMethods
          def from(values)
            super(java.util.HashSet.new(values))
          end
        end

        module InstanceMethods
          extend ActiveSupport::Concern
          included do
            delegate :to_set, to: :values
          end
        end
      end
    end
  end
end
