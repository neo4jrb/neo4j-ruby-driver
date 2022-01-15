module Neo4j::Driver
  module Internal
    module Svm
      # This substitution avoid having loggers added to the build
      class Target_io_netty_util_internal_logging_InternalLoggerFactory
        def self.new_default_factory(name)
          org.neo4j.driver.internal.shaded.io.netty.util.internal.logging.JdkLoggerFactory::INSTANCE
        end
      end
      # SSL
      # This whole section is mostly about removing static analysis references to openssl/tcnative
      class Target_io_netty_handler_ssl_JdkSslServerContext
        def initialize(provider, trust_cert_collection, trust_manager_factory, key_cert_chain, key, key_password,
                       key_manager_factory, ciphers, cipher_filter, apn, session_cache_size, session_timeout, client_auth,
                       protocols, start_tls, key_store)
        end
      end

      class Target_io_netty_handler_ssl_JdkSslClientContext
        def initialize(ssl_context_provider, trust_cert_collection, trust_manager_factory, key_cert_chain, key, key_password,
                       key_manager_factory, ciphers, cipher_filter, apn, protocols, session_cache_size, session_timeout,
                       key_store_type)
        end
      end

      class Target_io_netty_handler_ssl_SslHandler
        JDK = nil
        def for_engine
          JDK
        end
      end

      class Target_io_netty_handler_ssl_JdkAlpnApplicationProtocolNegotiator_AlpnWrapper
        def wrap_ssl_engine(engine, alloc, application_negotiator, server)
          Target_io_netty_handler_ssl_JdkAlpnSslEngine.new(engine, application_negotiator, server)
        end
      end

      def Target_io_netty_handler_ssl_JdkAlpnApplicationProtocolNegotiator_AlpnWrapperJava8
        def wrap_ssl_engine(engine, alloc, application_negotiator, server)
          if Target_io_netty_handler_ssl_JettyAlpnSslEngine.available?
           return server ? Target_io_netty_handler_ssl_JettyAlpnSslEngine.new_server_engine(engine, application_negotiator) : Target_io_netty_handler_ssl_JettyAlpnSslEngine.new_client_engine(engine, application_negotiator)
          end

          raise RuntimeError, "Unable to wrap SSLEngine of type #{engine.class.name}"
        end
      end

      class Target_io_netty_handler_ssl_JettyAlpnSslEngine
        def self.available?
          false
        end

        def new_client_engine(engine, application_negotiator)
          nil
        end

        def new_server_engine(engine, application_negotiator)
          nil
        end
      end

      class Target_io_netty_handler_ssl_JdkAlpnSslEngine
        def initialize(engine, application_negotiator, server)
        end
      end

      class Target_io_netty_handler_ssl_SslContext
        def new_client_context_internal(provider, ssl_context_provider, trust_cert_collection, trust_manager_factory, key_cert_chain, key, key_password,
                                        key_manager_factory, ciphers, cipher_filter, apn, session_cache_size, session_timeout, client_auth,
                                        protocols, start_tls, enable_ocsp, key_store_type, ctx_options)

          if enable_ocsp
            raise ArgumentError, "OCSP is not supported with this SslProvider: #{provider}"
          else
            Target_io_netty_handler_ssl_JdkSslServerContext.new(ssl_context_provider, trust_cert_collection, trust_manager_factory, key_cert_chain, key, key_password,
                                                                key_manager_factory, ciphers, cipher_filter, apn, session_cache_size, session_timeout, client_auth,
                                                                protocols, start_tls, key_store_type)
          end
        end

        def new_client_context_internal(provider, ssl_context_provider, trust_cert, trust_manager_factory, key_cert_chain,
                                        key, key_password, key_manager_factory, ciphers, cipher_filter, apn, protocols,
                                        session_cache_size, session_timeout, enable_ocsp, key_store_type, options)

          if enable_ocsp
            raise ArgumentError, "OCSP is not supported with this SslProvider: #{provider}"
          else
            Target_io_netty_handler_ssl_JdkSslClientContext.new(ssl_context_provider, trust_cert, trust_manager_factory, key_cert_chain, key, key_password,
                                                                key_manager_factory, ciphers, cipher_filter, apn, protocols, session_cache_size, session_timeout, key_store_type)
          end
        end
      end

      class Target_io_netty_handler_ssl_JdkDefaultApplicationProtocolNegotiator
        INSTANCE = :instance
      end

      class Target_io_netty_handler_ssl_JdkSslContext
        def self.to_negotiator(config, server)
          if config.nil?
            return Target_io_netty_handler_ssl_JdkDefaultApplicationProtocolNegotiator::INSTANCE
          end

          case config.protocol
          when NONE
            Target_io_netty_handler_ssl_JdkDefaultApplicationProtocolNegotiator::INSTANCE
          when ALPN
            if server
              # GRAAL RC9 bug: https://github.com/oracle/graal/issues/813
              #                switch(config.selectorFailureBehavior()) {
              #                case FATAL_ALERT:
              #                 return new JdkAlpnApplicationProtocolNegotiator(true, config.supportedProtocols());
              #                case NO_ADVERTISE:
              #                 return new JdkAlpnApplicationProtocolNegotiator(false, config.supportedProtocols());
              #                default:
              #                  throw new UnsupportedOperationException(new StringBuilder("JDK provider does not support ")
              #      .           append(config.selectorFailureBehavior()).append(" failure behavior").toString());
              #               }
              behavior = config.selector_failure_behavior
              if behavior == org.neo4j.driver.internal.shaded.io.netty.handler.ssl.ApplicationProtocolConfig.SelectorFailureBehavior::FATAL_ALERT
                return org.neo4j.driver.internal.shaded.io.netty.handler.ssl.JdkAlpnApplicationProtocolNegotiator.new(true, config.supported_protocols)
              elsif org.neo4j.driver.internal.shaded.io.netty.handler.ssl.ApplicationProtocolConfig.SelectorFailureBehavior::NO_ADVERTISE
                return org.neo4j.driver.internal.shaded.io.netty.handler.ssl.JdkAlpnApplicationProtocolNegotiator.new(false, config.supported_protocols)
              else
                raise UnsupportedOperationException, "JDK provider does not support #{config.selector_failure_behavior} failure behavior"
              end
            else
              case config.selected_listener_failure_behavior
              when ACCEPT
                org.neo4j.driver.internal.shaded.io.netty.handler.ssl.JdkAlpnApplicationProtocolNegotiator.new(false, config.supported_protocols)
              when FATAL_ALERT
                return org.neo4j.driver.internal.shaded.io.netty.handler.ssl.JdkAlpnApplicationProtocolNegotiator.new(true, config.supported_protocols)
              else
                raise UnsupportedOperationException, "JDK provider does not support #{config.selected_listener_failure_behavior} failure behavior"
              end
            end
          else
            raise UnsupportedOperationException, "JDK provider does not support #{config.protocol} protocol"
          end
        end
      end

      # This one only prints exceptions otherwise we get a useless bogus
      # exception message: https://github.com/eclipse-vertx/vert.x/issues/1657
      class Target_io_netty_bootstrap_AbstractBootstrap
        def initialize(channel)
          @channel_factory = org.neo4j.driver.internal.shaded.io.netty.bootstrap.ChannelFactory.new
        end

        def config
          nil
        end

        def init_and_register
          begin
            channel = @channel_factory.new_channel
            new(channel)
          rescue StandardError => e
            # THE FIX IS HERE:
            t.print_stack_trace
            unless channel.nil?
              # channel can be null if newChannel crashed (eg SocketException("too many open files"))
              channel.unsafe.close_forcibly
            end

            # as the Channel is not registered yet we need to force the usage of the GlobalEventExecutor
            org.neo4j.driver.internal.shaded.io.netty.channel.DefaultChannelPromise.new(channel, io.netty.util.concurrent.GlobalEventExecutor::INSTANCE).set_failure(e)
          end

          reg_future = config.group.register(channel)
          if reg_future.cause
            if channel.registered?
              channel.close
            else
              channel.unsafe.close_forcibly
            end
          end

          # If we are here and the promise is not failed, it's one of the following cases:
          # 1) If we attempted registration from the event loop, the registration has been completed at this point.
          #    i.e. It's safe to attempt bind() or connect() now because the channel has been registered.
          # 2) If we attempted registration from the other thread, the registration request has been successfully
          #    added to the event loop's task queue for later execution.
          #    i.e. It's safe to attempt bind() or connect() now:
          #         because bind() or connect() will be executed *after* the scheduled registration task is executed
          #         because register(), bind(), and connect() are all bound to the same thread.
          reg_future
        end
      end

      class NettySubstitutions
      end
    end
  end
end
