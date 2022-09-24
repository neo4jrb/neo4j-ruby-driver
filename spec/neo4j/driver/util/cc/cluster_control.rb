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
                (output_lines(:core, 20003, 6, 3) + output_lines(:read_replica, 20018, 5, 2)).join("\n")
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

            def version
              ENV['NEO4J_VERSION']
            end

            def output_line(type, base, increment, i)
              "x bolt://127.0.0.1:#{base + i * increment} db/neo4j/test-cluster#{version}/#{type}s/#{type}-#{i}/neo4j-enterprise-#{version}"
            end

            def output_lines(type, base, increment, n)
              n.times.map(&method(:output_line).curry.call(type, base, increment))
            end
          end
        end
      end
    end
  end
end
