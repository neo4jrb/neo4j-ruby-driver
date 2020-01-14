# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      class InternalResolver
        include ErrorHandling

        class << self
          def register(bolt_config, resolver)
            return unless resolver
            new(bolt_config, resolver)
          end
        end

        def initialize(bolt_config, resolver)
          @address_resolver_func = ->(_ptr, address, set) {
            resolver.call(BoltServerAddress.new(Bolt::Address.host(address).first,
                                                Bolt::Address.port(address).first.to_i)).each do |server_address|
              bolt_address = Bolt::Address.create(server_address.host, server_address.port.to_s)
              check_error Bolt::AddressSet.add(set, bolt_address)
            end
          }

          address_resolver = Bolt::AddressResolver.create(nil, @address_resolver_func)
          check_error Bolt::Config.set_address_resolver(bolt_config, address_resolver)
        end
      end
    end
  end
end
