module Neo4j::Driver
  module Internal
    module Util
      class Format
        def initialize
          raise java.lang.UnsupportedOperationException
        end

        # formats map using ':' as key-value separator instead of default '='
        class << self
          def format_pairs(entries)
            case entries.size
            when 0
              '{}'
            when 1
              "#{key_value_string(entries.first)}"
            else
              builder = ""
              builder << "{"
              builder << key_value_string(entries.first)

              entries.each do |entry|
                builder << ","
                builder << " "
                builder << key_value_string(entry)
              end

              builder << "}"
            end
          end

          private def key_value_string(entry)
            "#{entry.keys.first}:#{entry.values.first}"
          end

          # Returns the submitted value if it is not null or an empty string if it is.
          def value_or_empty(value)
            value.nil? ? "" : value
          end
        end
      end
    end
  end
end
