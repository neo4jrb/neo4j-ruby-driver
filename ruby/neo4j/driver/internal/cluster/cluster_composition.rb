module Neo4j::Driver
  module Internal
    module Cluster
      class ClusterComposition < Struct.new(:expiration_timestamp, :readers, :writers, :routers, :database_name)
        MAX_TTL = java.lang.Long::MAX_VALUE / 1000
        OF_BOLTSERVERADDRESS = -> (value) { BoltServerAddress.new(value) }

        def has_writers?
          !writers.empty?
        end

        def has_routers_and_readers?
          !routers.empty? && !readers.empty?
        end

        def self.parse(record, now)
          return nil if record.nil?

          result = new(expiration_timestamp(now, record), record['db'])

          record['servers'] do |value|
            result.servers(value['role']).add_all(value['addresses'])
          end

          result
        end

        private

        def self.expiration_timestamp(now, record)
          ttl = record['ttl']
          expiration_timestamp = now + ttl * 1000

          if ttl < 0 || ttl >= MAX_TTL || expiration_timestamp < 0
            expiration_timestamp = java.lang.Long::MAX_VALUE
          end

          expiration_timestamp
        end

        def servers(role)
          case role
          when 'READ'
            readers
          when 'WRITE'
            writers
          when 'ROUTE'
            routers
          else
            raise ArgumentError, "invalid server role: #{role}"
          end
        end
      end
    end
  end
end
