module Neo4j::Driver
  module Internal
    module Packstream
      class ByteArrayIncompatiblePacker < PackStream::Packer
        def initialize(out)
          super(out)
        end

        def pack_bytes_header(_size)
          raise PackStream::UnPackable.new('Packing bytes is not supported as the current server this driver connected to does not support unpack bytes.')
        end
      end
    end
  end
end
