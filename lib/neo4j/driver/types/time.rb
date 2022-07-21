# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      class Time
        include Comparable

        delegate :hash, :to_a, to: :significant

        class << self
          def parse(date)
            new(::Time.parse(date))
          end
        end

        def initialize(time)
          @time = time
        end

        def significant
          self.class.significant_fields.map(&method(:send))
        end

        def <=>(other)
          return unless other.is_a?(self.class)

          self.class.significant_fields.reduce(0) do |acc, elem|
            acc.zero? ? send(elem) <=> other.send(elem) : (break acc)
          end
        end

        def ==(other)
          other.is_a?(self.class) && self.class.significant_fields.all? { |elem| send(elem) == other.send(elem) }
        end

        alias eql? ==

        def +(numeric)
          self.class.new(@time + numeric)
        end
      end
    end
  end
end
