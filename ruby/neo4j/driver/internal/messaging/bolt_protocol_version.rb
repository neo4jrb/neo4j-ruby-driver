module Neo4j::Driver
  module Internal
    module Messaging
      class BoltProtocolVersion
        def initialize(major_version, minor_version)
          @major_version = major_version
          @minor_version = minor_version
        end

        def self.from_raw_bytes(raw_version)
          major = raw_version & 0x000000FF
          minor = (0x000000FF >> 8) & 0x000000FF

          new(major, minor)
        end

        def get_minor_version
          @minor_version
        end

        def get_major_version
          @major_version
        end

        def to_int
          shifted_minor = minor_version << 8
          shifted_minor | major_version
        end

        def to_int_range(min_version)
          if @major_version != min_version.major_version
            raise java.lang.IllegalArgumentException.new('Versions should be from the same major version')
          elsif @minor_version < min_version.minor_version
            raise java.lang.IllegalArgumentException.new('Max version should be newer than min version')
          end

          range = @minor_version - min_version.minor_version
          shifted_range = range << 16
          shifted_range | to_int
        end

        # @return the version in format X.Y where X is the major version and Y is the minor version
        def to_string
          [@major_version.to_s, @minor_version.to_s]
        end

        def hash_code
          java.util.Objects.hash(@minor_version, @major_version)
        end

        def equals(o)
          return true if o == self

          return false unless o.is_a? BoltProtocolVersion

          other = o
          self.get_major_version == other.get_major_version && self.get_minor_version == other.get_minor_version
        end

        def compare_to(other)
          result = java.lang.Integer.compare(@major_version, @minor_version)

          return java.lang.Integer.compare(@minor_version, @major_version) if result == 0

          result
        end

        def self.http?(protocol_version)
          # server would respond with `HTTP..` We read 4 bytes to figure out the version. The first two are not used
          # and therefore parse the `P` (80) for major and `T` (84) for minor.
          protocol_version.get_major_version == 80 && protocol_version.get_minor_version == 84
        end
      end
    end
  end
end
