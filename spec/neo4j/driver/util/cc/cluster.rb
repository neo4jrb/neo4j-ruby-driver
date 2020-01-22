# frozen_string_literal: true

require 'neo4j/driver/util/test_util'

module Neo4j
  module Driver
    module Util
      module CC
        class Cluster
          include Neo4j::Driver::Util::TestUtil
          attr_accessor :path, :password

          def initialize(path, password)
            self.path = path
            self.password = password
            @drivers = {}
            @offline_members = []
          end

          def members=(members)
            @members = members.map { |member| [member.bolt_uri, member] }.to_h
          end

          def leader
            members_with_role('LEADER').first
          end

          def followers
            members_with_role('FOLLOWER')
          end

          def any_follower
            followers.sample
          end

          def read_replicas
            members_with_role('READ_REPLICA')
          end

          def any_read_replica
            read_replicas.sample
          end

          def cores
            @members.values - read_replicas
          end

          def close
            @drivers.values.each(&:close)
          end

          def delete_data
            bookmark = clean_db(driver(leader.bolt_uri))
            unless bookmark
              raise Neo4j::Driver::Exceptions::IllegalStateException,
                    'Cleanup of the database did not produce a bookmark'
            end

            @members.each_key { |bolt_uri| count_nodes(driver(bolt_uri), bookmark) }
          end

          def stop(member)
            remove_offline_member(member)
            SharedCluster.stop_member(member)
            wait_for_members_to_be_online
          end

          def kill(member)
            remove_offline_member(member)
            SharedCluster.kill_member(member)
            wait_for_members_to_be_online
          end

          def start(member)
            add_offline_member(member)
            SharedCluster.start_member(member)
            wait_for_members_to_be_online
          end

          def start_offline_members
            @offline_members.each(&method(:start))
            wait_for_members_to_be_online
          end

          def version3?
            ENV['NEO4J_VERSION']&.send(:<, '4')
          end

          private

          def wait_for_members_to_be_online
          end

          def remove_offline_member(member)
            raise ArgumentError, "Unknown cluster member #{member}" unless @members.delete(member.bolt_uri)
            @offline_members << member
          end

          def add_offline_member(member)
            raise ArgumentError, "Cluster member is not offline: #{member}" unless @offline_members.delete(member)
            @members[member.bolt_uri] = member
          end

          def members_with_role(role)
            @members.values_at(*find_cluster_overview(driver_to_any_core)[role])
          end

          def driver_to_any_core
            raise ArgumentError, "No members, can't create driver'" if @members.empty?
            @members.each_key do |bolt_uri|
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
              %w[LEADER FOLLOWER].include?(
                session.run("CALL dbms.cluster.role(#{'$database' unless version3?})", database: 'neo4j')
                  .single.first
              )
            end
          end

          def find_cluster_overview(driver)
            driver.session(AccessMode::WRITE) do |session|
              session.run('CALL dbms.cluster.overview()').each_with_object({}) do |record, hash|
                # Version 3.x.x || Version 4.x.x
                (hash[record[:role] || record[:databases][:neo4j]] ||= []) << record[:addresses].first
              end
            end
          end
        end
      end
    end
  end
end
