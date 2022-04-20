module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class NettyDomainNameResolver #< org.neo4j.driver.internal.shaded.io.netty.resolver.InetNameResolver
          def initialize(executor, domain_name_resolver)
            # super(executor)
            @domain_name_resolver = domain_name_resolver
          end

          def doResolve(inet_host, promise)
            promise.set_success(@domain_name_resolver.call(inet_host).first)
          rescue java.net.UnknownHostException => e
            promise.set_failure(e)
          end

          def doResolveAll(inet_host, promise)
            promise.set_success(@domain_name_resolver.call(inet_host))
          rescue java.net.UnknownHostException => e
            promise.set_failure(e)
          end
        end
      end
    end
  end
end
