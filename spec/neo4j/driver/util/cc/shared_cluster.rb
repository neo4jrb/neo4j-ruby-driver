# frozen_string_literal: true

require 'neo4j/driver/util/cc/cluster'
require 'neo4j/driver/util/cc/cluster_control'
require 'neo4j/driver/util/cc/cluster_member'

module Neo4j
  module Driver
    module Util
      module CC
        class SharedCluster
          class << self
            def get
              assert_cluster_exists
              @cluster
            end

            def remove
              assert_cluster_exists
              @cluster.close
              @cluster = nil
            end

            def exists?
              @cluster.present?
            end

            def install(neo4j_version, cores, read_replicas, password, port, path)
              assert_cluster_does_not_exist
              if File.directory?(path)
                debug("Found and using cluster installed at `#{path}`.")
              else
                ClusterControl.install_cluster(neo4j_version, cores, read_replicas, password, port, path)
                debug("Downloaded cluster at `#{path}`.")
              end
              @cluster = Cluster.new(path, password);
            end

            def start
              assert_cluster_exists
              output = ClusterControl.start_cluster(@cluster.path)
              members = parse_start_command_output(output)

              @cluster.members = members
              debug("Cluster started: #{members}.")
            end

            def stop
              assert_cluster_exists
              ClusterControl.stop_cluster(@cluster.path)
              debug( "Cluster at `#{@cluster.path}` stopped.")
            end

            private

            def parse_start_command_output(output)
              output.split("\n").reject(&:empty?).map do |line|
                parts = line.split.drop(1)
                raise ArgumentError, "Wrong start command output found. " \
                  "Expected to have 'http_uri bolt_uri path' on each nonempty line. " \
                  "Command output: \n#{output}" if parts.length != 2
                ClusterMember.new(*parts)
              end.tap do |results|
                raise Neo4j::Driver::Exceptions::IllegalStateException, 'No cluster members' if results.empty?
              end
            end

            def assert_cluster_exists
              raise Neo4j::Driver::Exceptions::IllegalStateException, 'Shared cluster does not exist' unless @cluster
            end

            def assert_cluster_does_not_exist
              raise Neo4j::Driver::Exceptions::IllegalStateException, 'Shared cluster already exists' if @cluster
            end

            alias debug puts
          end
        end
      end
    end
  end
end
