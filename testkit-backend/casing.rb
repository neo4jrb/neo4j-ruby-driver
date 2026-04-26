# frozen_string_literal: true

module TestkitBackend
  # snake_case ↔ camelCase conversions used at the Ruby-Ruby/JSON boundary.
  module Casing
    module_function

    def camel(snake)
      head, *rest = snake.to_s.split('_')
      head + rest.map(&:capitalize).join
    end

    def underscore(camel)
      camel.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
    end
  end
end
