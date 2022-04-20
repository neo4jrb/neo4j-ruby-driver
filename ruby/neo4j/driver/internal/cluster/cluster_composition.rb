module Neo4j::Driver
  module Internal
    module Cluster
      class ClusterComposition < Struct.new(:expiration_timestamp, :readers, :writers, :routers, :database_name)
        private

        MAX_LONG = 2 ^ 63 - 1
        MAX_TTL = MAX_LONG / 1000

        public

        def initialize(expiration_timestamp:, database_name:, readers: [], writers: [], routers: [])
          super(expiration_timestamp, readers, writers, routers, database_name)
        end

        def has_writers?
          @writers.present?
        end

        def has_routers_and_readers?
          @routers.present? && @readers.present?
        end

        def self.parse(record, now)
          return if record.nil?
          new(expiration_timestamp: expiration_timestamp(now, record), database_name: record['db'],
              **record['servers'].to_h { |value| [servers(value['role']), BoltServerAddress.new(value['addresses'])] })
        end

        private

        def self.expiration_timestamp(now, record)
          ttl = record['ttl']
          expiration_timestamp = now + ttl * 1000

          if ttl < 0 || ttl >= MAX_TTL || expiration_timestamp < 0
            expiration_timestamp = MAX_LONG
          end

          expiration_timestamp
        end

        def servers(role)
          case role
          when 'READ'
            :readers
          when 'WRITE'
            :writers
          when 'ROUTE'
            :routers
          else
            raise ArgumentError, "invalid server role: #{role}"
          end
        end
      end
    end
  end
end
