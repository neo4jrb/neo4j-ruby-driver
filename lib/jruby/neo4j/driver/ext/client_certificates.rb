# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Ruby-friendly surface over org.neo4j.driver.ClientCertificates,
      # prepended onto its singleton class (cf. Ext::GraphDatabase /
      # Ext::BookmarkManagers) rather than shadowing the Java class. Lets the
      # flavour-agnostic testkit backend call
      # ClientCertificates.of(certpath, keypath[, password]) with path strings;
      # the Java factory takes java.io.File, so wrap and delegate via super.
      module ClientCertificates
        def of(certfile, keyfile, password = nil)
          cert = java.io.File.new(certfile.to_s)
          key = java.io.File.new(keyfile.to_s)
          password ? super(cert, key, password) : super(cert, key)
        end
      end
    end
  end
end
