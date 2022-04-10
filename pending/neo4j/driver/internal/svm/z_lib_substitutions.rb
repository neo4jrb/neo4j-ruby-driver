module Neo4j::Driver
  module Internal
    module Svm
      # This substitution avoid having jcraft zlib added to the build
      class Target_org_neo4j_driver_internal_shaded_io_netty_handler_codec_compression_ZlibCodecFactory
        class << self
          def new_zlib_encoder(wrapper, compression_level)
            org.neo4j.driver.internal.shaded.io.netty.handler.codec.compression.JdkZlibEncoder.new(wrapper, compression_level)
          end

          def zlib_decoder(wrapper)
            org.neo4j.driver.internal.shaded.io.netty.handler.codec.compression.jdk_zlib_decoder(wrapper)
          end
        end
      end

      class ZLibSubstitutions
      end
    end
  end
end
