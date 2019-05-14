# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      module RubySignature
        class << self
          def session(args)
            [
              args.empty? || args.first.is_a?(String) ? Neo4j::Driver::AccessMode::WRITE : args.shift, #mode
              args #bookmarks
            ]
          end
        end
      end
    end
  end
end
