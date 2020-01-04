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
              execute_command('neoctrl-cluster', 'start', path)
            end

            def start_cluster_member(path)
              execute_command('neoctrl-start', path)
            end

            def stop_cluster(path)
              execute_command('neoctrl-cluster', 'stop', path)
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
          end
        end
      end
    end
  end
end
