module TestkitBackend
  module Requests
    # Stub: introspects a single field of a typed cypher value.
    # Java's TestkitCypherType[Mapper] decomposes things like a
    # CypherDateTime into its parts on demand. The Ruby backend
    # eager-converts cypher values to native Ruby (Date/Time/etc.) at
    # hydration time, so we don't retain a typed-cypher object to
    # introspect later. Tests that need field-level introspection are
    # rare and we don't currently advertise the relevant feature.
    class CypherTypeField < Request
      def process
        named_entity('BackendError',
                     msg: 'CypherTypeField introspection is not implemented; ' \
                          'driver eager-converts cypher values to native Ruby types at hydration time.')
      end
    end
  end
end
