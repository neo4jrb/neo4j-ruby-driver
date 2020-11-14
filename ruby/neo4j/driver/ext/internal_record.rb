# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      module InternalRecord
        include MapConverter
        include InternalKeys

        def values
          java_send(:values).map(&:as_ruby_object)
        end

        def [](key)
          case key
          when Integer
            java_method(:get, [Java::int]).call(key)
          else
            java_method(:get, [java.lang.String]).call(key.to_s)
          end.as_ruby_object
        end

        def first
          java_method(:get, [Java::int]).call(0).as_ruby_object
        end
      end
    end
  end
end
