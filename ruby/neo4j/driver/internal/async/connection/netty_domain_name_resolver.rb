module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class NettyDomainNameResolver < org.neo4j.driver.internal.shaded.io.netty.resolver.InetNameResolver

          def initialize(executor, domain_name_resolver)
            org.neo4j.driver.internal.shaded.io.netty.resolver.InetNameResolver.new(executor)
            @domain_name_resolver = domain_name_resolver
          end

          def do_resolver(inet_host, promise)
            begin
              promise.set_success(@domain_name_resolver.resolve.first)
            rescue java.net.UnknownHostException => e
              promise.set_failure(e)
            end
          end

          def do_resolve_all(inet_host, promise)
            begin
              promise.set_success([@domain_name_resolver.resolve(inet_host)])
            rescue java.net.UnknownHostException => e
              promise.set_failure(e)
            end
          end
        end
      end
    end
  end
end
