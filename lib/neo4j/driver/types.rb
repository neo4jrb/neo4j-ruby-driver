# frozen_string_literal: true

require 'time'
require 'date'

module Neo4j
  module Driver
    module Types
      # Represents a Node in the Neo4j graph
      class Node
        attr_reader :id, :labels, :properties, :element_id

        def initialize(id, labels, properties, element_id = nil)
          @id = id
          @labels = labels
          @properties = properties
          @element_id = element_id || id.to_s
        end

        def [](key)
          @properties[key.to_s] || @properties[key.to_sym]
        end

        def ==(other)
          other.is_a?(Node) && other.id == @id
        end
      end

      # Represents a Relationship in the Neo4j graph
      class Relationship
        attr_reader :id, :start_node_id, :end_node_id, :type, :properties, :element_id

        def initialize(id, start_node_id, end_node_id, type, properties, element_id = nil)
          @id = id
          @start_node_id = start_node_id
          @end_node_id = end_node_id
          @type = type
          @properties = properties
          @element_id = element_id || id.to_s
        end

        def [](key)
          @properties[key.to_s] || @properties[key.to_sym]
        end

        def ==(other)
          other.is_a?(Relationship) && other.id == @id
        end
      end

      # Represents an unbound relationship (used in paths before binding to nodes)
      class UnboundRelationship
        attr_reader :id, :type, :properties, :element_id

        def initialize(id, type, properties, element_id = nil)
          @id = id
          @type = type
          @properties = properties
          @element_id = element_id || id.to_s
        end

        def [](key)
          @properties[key.to_s] || @properties[key.to_sym]
        end

        # Bind this relationship to specific start and end nodes
        def bind(start_node_id, end_node_id)
          Relationship.new(@id, start_node_id, end_node_id, @type, @properties, @element_id)
        end
      end

      # Represents a Path in the Neo4j graph
      # A path is a sequence of alternating nodes and relationships
      class Path
        include Enumerable

        attr_reader :nodes, :relationships

        def initialize(nodes, relationships, segments)
          @nodes = nodes
          @relationships = relationships
          @segments = segments
        end

        # Returns the start node of the path
        def start
          @nodes.first
        end
        alias start_node start

        # Returns the end node of the path
        def end
          @nodes.last
        end
        alias end_node end

        # Returns the number of relationships in the path (number of segments)
        def length
          @relationships.length
        end

        # Check if the path contains the given node
        def contains_node?(node)
          @nodes.any? { |n| n.id == node.id }
        end

        # Check if the path contains the given relationship
        def contains_relationship?(relationship)
          @relationships.any? { |r| r.id == relationship.id }
        end

        # Iterate over segments in the path
        # Each segment represents a relationship and its start/end nodes
        def each(&block)
          @segments.each(&block)
        end

        # Represents a segment of a path (a relationship and its start/end nodes)
        class Segment
          attr_reader :start_node, :end_node, :relationship

          def initialize(start_node, end_node, relationship)
            @start_node = start_node
            @end_node = end_node
            @relationship = relationship
          end

          alias start start_node
          alias end end_node
        end
      end

      # Time with timezone offset - Neo4j Time type (time of day with timezone)
      # Wraps nanoseconds since midnight and timezone offset
      class Time
        attr_reader :nanoseconds, :tz_offset_seconds

        def initialize(nanoseconds, tz_offset_seconds)
          @nanoseconds = nanoseconds
          @tz_offset_seconds = tz_offset_seconds
        end

        def self.from_nanos(nanoseconds, tz_offset_seconds)
          new(nanoseconds, tz_offset_seconds)
        end

        def self.parse(string)
          # Parse time string like "12:34:56.123456789+01:00" or "12:34:56Z"
          if string =~ /^(\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?([Z+\-][\d:]*)?$/
            hour = $1.to_i
            minute = $2.to_i
            second = ($3 || 0).to_i
            fraction = $4 || '0'
            offset_str = $5 || 'Z'

            # Pad or truncate fraction to 9 digits (nanoseconds)
            nanos_from_fraction = fraction.ljust(9, '0')[0..8].to_i

            total_nanos = hour * 3_600_000_000_000 +
                         minute * 60_000_000_000 +
                         second * 1_000_000_000 +
                         nanos_from_fraction

            # Parse offset
            tz_offset_seconds = if offset_str == 'Z'
              0
            elsif offset_str =~ /^([+\-])(\d{2}):?(\d{2})?$/
              sign = $1 == '+' ? 1 : -1
              hours = $2.to_i
              mins = ($3 || 0).to_i
              sign * (hours * 3600 + mins * 60)
            else
              raise ArgumentError, "Invalid timezone offset: #{offset_str}"
            end

            new(total_nanos, tz_offset_seconds)
          else
            raise ArgumentError, "Invalid Time format: #{string}"
          end
        end

        def hour
          (@nanoseconds / 3_600_000_000_000) % 24
        end

        def minute
          (@nanoseconds / 60_000_000_000) % 60
        end

        def second
          (@nanoseconds / 1_000_000_000) % 60
        end

        def nanosecond
          @nanoseconds % 1_000_000_000
        end

        def to_s
          offset_hours = @tz_offset_seconds / 3600
          offset_mins = (@tz_offset_seconds % 3600) / 60
          format('%02d:%02d:%02d.%09d%+03d:%02d', hour, minute, second, nanosecond, offset_hours, offset_mins)
        end
      end

      # LocalTime (time of day without timezone)
      class LocalTime
        attr_reader :nanoseconds

        def initialize(nanoseconds)
          @nanoseconds = nanoseconds
        end

        def self.from_nanos(nanoseconds)
          new(nanoseconds)
        end

        def self.parse(string)
          # Parse time string like "12:34:56.123456789"
          if string =~ /^(\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?$/
            hour = $1.to_i
            minute = $2.to_i
            second = ($3 || 0).to_i
            fraction = $4 || '0'

            # Pad or truncate fraction to 9 digits (nanoseconds)
            nanos_from_fraction = fraction.ljust(9, '0')[0..8].to_i

            total_nanos = hour * 3_600_000_000_000 +
                         minute * 60_000_000_000 +
                         second * 1_000_000_000 +
                         nanos_from_fraction

            new(total_nanos)
          else
            raise ArgumentError, "Invalid LocalTime format: #{string}"
          end
        end

        def hour
          (@nanoseconds / 3_600_000_000_000) % 24
        end

        def minute
          (@nanoseconds / 60_000_000_000) % 60
        end

        def second
          (@nanoseconds / 1_000_000_000) % 60
        end

        def nanosecond
          @nanoseconds % 1_000_000_000
        end

        def to_s
          format('%02d:%02d:%02d.%09d', hour, minute, second, nanosecond)
        end
      end

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

      # Duration
      # Neo4j stores durations as months, days, seconds, and nanoseconds
      # All values must be integers (matching Neo4j's Bolt protocol and Java driver)
      class Duration
        attr_reader :months, :days, :seconds, :nanoseconds

        NANOS_PER_SECOND = 1_000_000_000

        def initialize(months, days, seconds, nanoseconds)
          @months = months.to_i
          @days = days.to_i
          @seconds = seconds.to_i
          @nanoseconds = nanoseconds.to_i
          normalize!
        end

        # Parse ISO 8601 duration format
        # Examples: "P1Y2M3DT4H5M6.789S", "P3M", "PT2H30M"
        def self.parse(string)
          unless string =~ /^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$/
            raise ArgumentError, "Invalid ISO 8601 duration format: #{string}"
          end

          years = ($1 || 0).to_i
          months = ($2 || 0).to_i
          days = ($3 || 0).to_i
          hours = ($4 || 0).to_i
          minutes = ($5 || 0).to_i
          seconds_with_fraction = ($6 || 0).to_f

          total_months = years * 12 + months
          whole_seconds = seconds_with_fraction.to_i
          fractional_seconds = seconds_with_fraction - whole_seconds
          nanos = (fractional_seconds * NANOS_PER_SECOND).round
          total_seconds = hours * 3600 + minutes * 60 + whole_seconds

          new(total_months, days, total_seconds, nanos)
        end

        def ==(other)
          return false unless other.is_a?(Duration)
          @months == other.months &&
            @days == other.days &&
            @seconds == other.seconds &&
            @nanoseconds == other.nanoseconds
        end

        def parts
          {
            months: @months,
            days: @days,
            seconds: @seconds,
            nanoseconds: @nanoseconds
          }
        end

        def to_s
          "P#{@months}M#{@days}DT#{@seconds}.#{@nanoseconds}S"
        end

        private

        # Normalize nanoseconds overflow/underflow into seconds
        # e.g., -1ns becomes -1s + 999999999ns
        # e.g., 1_500_000_000ns becomes 1s + 500_000_000ns
        def normalize!
          if @nanoseconds < 0
            # Move negative nanoseconds into seconds
            sec_adjust = (@nanoseconds.abs / NANOS_PER_SECOND.to_f).ceil
            @seconds -= sec_adjust
            @nanoseconds += sec_adjust * NANOS_PER_SECOND
          elsif @nanoseconds >= NANOS_PER_SECOND
            # Move excess nanoseconds into seconds
            sec_adjust = @nanoseconds / NANOS_PER_SECOND
            @seconds += sec_adjust
            @nanoseconds %= NANOS_PER_SECOND
          end
        end
      end

      # Point (2D or 3D)
      class Point
        attr_reader :srid, :x, :y, :z

        # SRID constants for coordinate reference systems
        WGS_84_2D = 4326        # Geographic 2D (longitude, latitude)
        WGS_84_3D = 4979        # Geographic 3D (longitude, latitude, height)
        CARTESIAN_2D = 7203     # Cartesian 2D (x, y)
        CARTESIAN_3D = 9157     # Cartesian 3D (x, y, z)

        def initialize(srid: nil, x: nil, y: nil, z: nil, longitude: nil, latitude: nil, height: nil)
          # Handle longitude/latitude aliases for x/y
          if longitude || latitude
            @x = (longitude || x).to_f
            @y = (latitude || y).to_f
            @z = (height || z)&.to_f
            # Use WGS-84 SRID for geographic coordinates
            @srid = srid || (@z ? WGS_84_3D : WGS_84_2D)
          else
            @x = x.to_f
            @y = y.to_f
            @z = z&.to_f
            # Use Cartesian SRID for x/y/z coordinates
            @srid = srid || (@z ? CARTESIAN_3D : CARTESIAN_2D)
          end
        end

        def dimension
          @z.nil? ? 2 : 3
        end

        def to_s
          if @z
            "Point{srid=#{@srid}, x=#{@x}, y=#{@y}, z=#{@z}}"
          else
            "Point{srid=#{@srid}, x=#{@x}, y=#{@y}}"
          end
        end

        def ==(other)
          other.is_a?(Point) &&
            other.srid == @srid &&
            (other.x - @x).abs < 0.00001 &&
            (other.y - @y).abs < 0.00001 &&
            (@z.nil? || (other.z - @z).abs < 0.00001)
        end
      end
    end
  end
end
