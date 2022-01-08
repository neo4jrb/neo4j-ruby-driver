module Neo4j::Driver
  module Internal
    module Svm
      # This substitution avoid having jcraft zlib added to the build
      # $CLASSPATH<<'target/classes' => ['io.netty.handler.codec.compression.ZlibCodecFactory']
      class Target_org_neo4j_driver_internal_shaded_io_netty_handler_codec_compression_ZlibCodecFactory
        class << self
          def new_zlib_encoder(compression_level)
            io.netty.handler.codec.compression.JdkZlibEncoder.new(compression_level)
          end

          def new_zlib_encoder(compression_level)
            io.netty.handler.codec.compression.JdkZlibEncoder.new(compression_level)
          end

          def new_zlib_encoder(compression_level)
            io.netty.handler.codec.compression.JdkZlibEncoder.new(compression_level)
          end

          def new_zlib_encoder(compression_level)
            io.netty.handler.codec.compression.JdkZlibEncoder.new(compression_level)
          end

          def new_zlib_encoder(compression_level)
            io.netty.handler.codec.compression.JdkZlibEncoder.new(compression_level)
          end

          def new_zlib_encoder(compression_level)
            io.netty.handler.codec.compression.JdkZlibEncoder.new(compression_level)
          end

          def new_zlib_encoder(compression_level)
            io.netty.handler.codec.compression.JdkZlibEncoder.new(compression_level)
          end
        end
      end

      class ZLibSubstitutions
      end
    end
  end
end
