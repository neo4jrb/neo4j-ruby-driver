module Neo4j::Driver
  module Internal
    module Cluster
      class ClusterComposition < Struct.new(:expiration_timestamp, :readers, :writers, :routers, :database_name)
        def initialize(expiration_timestamp:, database_name:, readers: [], writers: [], routers: [])
          super(expiration_timestamp, readers, writers, routers, database_name)
        end

        def has_writers?
          writers.present?
        end

        def has_routers_and_readers?
          routers.present? && readers.present?
        end

        def self.parse(record, now)
          return unless record
          new(expiration_timestamp: expiration_timestamp(now, record), database_name: record[:db],
              **record[:servers].to_h do |value|
                [servers(value[:role]),
                 value[:addresses].map { |address| BoltServerAddress.new(uri: BoltServerAddress.uri_from(address)) }]
              end)
        end

        private

        def self.expiration_timestamp(now, record)
          ttl = record['ttl']
          now + (ttl.negative? ? 1000.years : ttl.seconds)
        end

        def self.servers(role)
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
