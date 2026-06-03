# frozen_string_literal: true

module Neo4j
  module Driver
    module Ext
      # Adds a Ruby-friendly `to_h` to Java's `AuthToken`. The MRI
      # driver's `AuthTokens.basic` etc. already return Hashes (so
      # `.to_h` is the Hash identity); this mirror lets impl-agnostic
      # callers — e.g. testkit-backend's `serialize_auth_token` —
      # consume an AuthToken without poking at Java's `toMap` /
      # `Value#asString`.
      module AuthToken
        def to_h
          map = to_map
          {
            scheme: map['scheme']&.as_string,
            principal: map['principal']&.as_string,
            credentials: map['credentials']&.as_string,
            realm: map['realm']&.as_string,
            parameters: map['parameters']&.as_map
          }.compact
        end
      end
    end
  end
end
