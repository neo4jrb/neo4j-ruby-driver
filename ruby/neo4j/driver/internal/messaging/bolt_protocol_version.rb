module Neo4j::Driver
  module Internal
    module Messaging
      class BoltProtocolVersion < Struct.new(:major_version, :minor_version)
        def self.from_raw_bytes(raw_version)
          major = raw_version & 0x000000FF
          minor = (raw_version >> 8) & 0x000000FF
          new(major,minor)
        end

        def to_int
          shifted_minor = minor_version << 8
          shifted_minor | major_version
        end

        def to_int_range(min_version)
          if major_version != min_version.major_version
            raise ArgumentError, 'Versions should be from the same major version'
          elsif minor_version < min_version.minor_version
            raise ArgumentError, 'Max version should be newer than min version'
          end

          range = minor_version - min_version.minor_version
          shifted_range = range << 16
          shifted_range | to_int
        end

        # @return the version in format X.Y where X is the major version and Y is the minor version
        def to_s
          values.join('.')
        end

        def <=>(other)
          result = major_version <=> other.major_version
          result == 0 ? minor_version <=> other.minor_version : result
        end

        def self.http?(protocol_version)
          # server would respond with `HTTP..` We read 4 bytes to figure out the version. The first two are not used
          # and therefore parse the `P` (80) for major and `T` (84) for minor.
          protocol_version.major_version == 80 && protocol_version.minor_version == 84
        end
      end
    end
  end
end
