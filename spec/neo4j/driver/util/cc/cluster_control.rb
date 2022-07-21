# frozen_string_literal: true

module Neo4j
  module Driver
    module Util
      module CC
        class ClusterControl
          class << self
            def install_cluster(neo4j_version, cores, read_replicas, password, port, path)
              execute_command('neoctrl-cluster', 'install', '--cores', cores, '--read-replicas', read_replicas,
                              '--password', password, '--initial-port', port, neo4j_version, path)
            end

            def start_cluster(path)
              if debug?
                <<~END
                  http://127.0.0.1:20010 bolt://127.0.0.1:20009 test-cluster4.4.8/cores/core-1/neo4j-enterprise-4.4.8
                  http://127.0.0.1:20004 bolt://127.0.0.1:20003 test-cluster4.4.8/cores/core-0/neo4j-enterprise-4.4.8
                  http://127.0.0.1:20016 bolt://127.0.0.1:20015 test-cluster4.4.8/cores/core-2/neo4j-enterprise-4.4.8
                  http://127.0.0.1:20024 bolt://127.0.0.1:20023 test-cluster4.4.8/read-replicas/read-replica-1/neo4j-enterprise-4.4.8
                  http://127.0.0.1:20019 bolt://127.0.0.1:20018 test-cluster4.4.8/read-replicas/read-replica-0/neo4j-enterprise-4.4.8
                END
              else
                execute_command('neoctrl-cluster', 'start', path)
              end
            end

            def start_cluster_member(path)
              execute_command('neoctrl-start', path)
            end

            def stop_cluster(path)
              execute_command('neoctrl-cluster', 'stop', path) unless debug?
            end

            def stop_cluster_member(path)
              execute_command('neoctrl-stop', path)
            end

            def kill_cluster(path)
              execute_command('neoctrl-cluster', 'stop', '--kill', path)
            end

            def kill_cluster_member(path)
              execute_command('neoctrl-stop', '--kill', path)
            end

            def boltkit_available?
              execute_command 'neoctrl-cluster --help'
            rescue SystemCallError
              false
            end

            private

            def execute_command(*args)
              `#{args.join ' '}`
            end

            def debug?
              ENV['DEBUG'] == 'true'
            end
          end
        end
      end
    end
  end
end
