module Neo4j::Driver
  module Internal
    module Messaging
      module Common
        module CommonValue
          include Packstream::PackStream::Common
          DATE = 'D'
          DATE_STRUCT_SIZE = 1
          TIME = 'T'
          TIME_STRUCT_SIZE = 2
          LOCAL_TIME = 't'
          LOCAL_TIME_STRUCT_SIZE = 1
          LOCAL_DATE_TIME = 'd'
          LOCAL_DATE_TIME_STRUCT_SIZE = 2
          DATE_TIME_WITH_ZONE_OFFSET = 'F'
          DATE_TIME_WITH_ZONE_ID = 'f'
          DATE_TIME_STRUCT_SIZE = 3
          DURATION = 'E'
          DURATION_TIME_STRUCT_SIZE = 4
          POINT_2D_STRUCT_TYPE = 'X'
          POINT_2D_STRUCT_SIZE = 3
          POINT_3D_STRUCT_TYPE = 'Y'
          POINT_3D_STRUCT_SIZE = 4

          EPOCH = Date.parse('1970-01-01')
          NANO_FACTOR = 1_000_000_000
        end
      end
    end
  end
end
