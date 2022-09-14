# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # While resolving an address using getaddrinfo method of Addrinfo it raises an error of SocketError
      class SocketException < Neo4jException
      end
    end
  end
end
