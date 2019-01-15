# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalDriver
        extend Neo4j::Driver::Ext::AutoClosable

        auto_closable :session
      end
    end
  end
end
