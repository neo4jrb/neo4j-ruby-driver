# frozen_string_literal: true

module Neo4j
  module Driver
    module Util
      module CC
        class Cluster
          attr_accessor :path, :password

          def initialize(path, password)
            self.path = path
            self.password = password
            @drivers = {}
          end

          def members=(members)
            @members = members.map { |member| [member.bolt_uri, member] }.to_h
          end

          def leader
            members_with_role('LEADER').first
          end

          def any_follower
            members_with_role('FOLLOWER').sample
          end

          def close
            @drivers.values.each(&:close)
          end

          private

          def members_with_role(role)
            @members.values_at(*find_cluster_overview(driver_to_any_core)[role])
          end

          def driver_to_any_core
            raise ArgumentError, "No members, can't create driver'" if @members.empty?
            @members.keys.each do |bolt_uri|
              driver = driver(bolt_uri)
              return driver if core_member?(driver)
            end
            raise Neo4j::Driver::Exceptions::IllegalStateException, "No core members found among: #{@members}"
          end

          def driver(bolt_uri)
            @drivers[bolt_uri] ||= GraphDatabase.driver(bolt_uri, AuthTokens.basic('neo4j', password),
                                                        logger: ActiveSupport::Logger.new(IO::NULL),
                                                        encryption: false,
                                                        max_connection_pool_size: 1,
                                                        connection_liveness_check_timeout: 0)
          end

          def core_member?(driver)
            driver.session(AccessMode::READ) do |session|
              %w[LEADER FOLLOWER].include?(session.run('CALL dbms.cluster.role()').single.first)
            end
          end

          def find_cluster_overview(driver)
            driver.session(AccessMode::WRITE) do |session|
              session.run('CALL dbms.cluster.overview()').each_with_object({}) do |record, hash|
                (hash[record[:role]] ||= []) << record[:addresses].first
              end
            end
          end
        end
      end
    end
  end
end
