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
        def to_h = to_map.as_ruby_object
      end
    end
  end
end
