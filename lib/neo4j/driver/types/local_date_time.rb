# frozen_string_literal: true

module Neo4j
  module Driver
    module Types
      # LocalDateTime (datetime without timezone)
      # Represents a datetime value without timezone information from Neo4j
      # Preserves type distinction for correct roundtripping
      class LocalDateTime
        include Comparable

        attr_reader :epoch_seconds, :nanoseconds

        def initialize(epoch_seconds, nanoseconds)
          @epoch_seconds = epoch_seconds
          @nanoseconds = nanoseconds
        end

        def self.from_epoch(epoch_seconds, nanoseconds)
          new(epoch_seconds, nanoseconds)
        end

        def self.from_time(time)
          new(time.to_i, (time.to_f - time.to_i) * 1_000_000_000)
        end

        def self.parse(string)
          # Parse datetime string as naive (ignore timezone, just use date/time components)
          # Strip timezone if present
          naive_string = string.sub(/[Z\+\-]\d{2}:?\d{2}?$/, '')
          # Try various formats
          time = begin
            ::Time.strptime(naive_string, '%Y-%m-%d %H:%M:%S.%N')
          rescue ArgumentError
            begin
              ::Time.strptime(naive_string, '%Y-%m-%dT%H:%M:%S.%N')
            rescue ArgumentError
              begin
                ::Time.strptime(naive_string, '%Y-%m-%d %H:%M:%S')
              rescue ArgumentError
                begin
                  ::Time.strptime(naive_string, '%Y-%m-%dT%H:%M:%S')
                rescue ArgumentError
                  ::Time.strptime(naive_string, '%Y-%m-%d %H:%M')
                end
              end
            end
          end
          # Create as UTC to get epoch seconds for the naive datetime
          utc_time = ::Time.utc(time.year, time.month, time.day, time.hour, time.min, time.sec, time.subsec * 1_000_000)
          from_time(utc_time)
        end

        def to_time
          ::Time.at(@epoch_seconds, @nanoseconds.to_i, :nanosecond)
        end

        def <=>(other)
          return nil unless other.is_a?(LocalDateTime)
          cmp = @epoch_seconds <=> other.epoch_seconds
          cmp == 0 ? @nanoseconds <=> other.nanoseconds : cmp
        end

        def ==(other)
          other.is_a?(LocalDateTime) &&
            @epoch_seconds == other.epoch_seconds &&
            @nanoseconds == other.nanoseconds
        end

        alias eql? ==

        def +(seconds)
          # Handle ActiveSupport::Duration or numeric seconds
          secs_to_add = seconds.respond_to?(:to_i) ? seconds.to_i : seconds
          new_time = to_time + secs_to_add
          self.class.from_time(new_time)
        end

        def to_s
          to_time.strftime('%Y-%m-%d %H:%M:%S.%N')
        end
      end
    end
  end
end
