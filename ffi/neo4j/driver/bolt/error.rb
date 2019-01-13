# frozen_string_literal: true

module Bolt
  module Error
    extend FFI::Library
    ffi_lib ENV['SEABOLT_LIB']

    # Identifies a successful operation which is defined as 0
    BOLT_SUCCESS = 0
    # Unknown error
    BOLT_UNKNOWN_ERROR = 1
    # Unsupported protocol or address family
    BOLT_UNSUPPORTED = 2
    # Operation interrupted
    BOLT_INTERRUPTED = 3
    # Connection reset by peer
    BOLT_CONNECTION_RESET = 4
    # No valid resolved addresses found to connect
    BOLT_NO_VALID_ADDRESS = 5
    # Operation timed out
    BOLT_TIMED_OUT = 6
    # Permission denied
    BOLT_PERMISSION_DENIED = 7
    # Too may open files
    BOLT_OUT_OF_FILES = 8
    # Out of memory
    BOLT_OUT_OF_MEMORY = 9
    # Too many open ports
    BOLT_OUT_OF_PORTS = 10
    # Connection refused
    BOLT_CONNECTION_REFUSED = 11
    # Network unreachable
    BOLT_NETWORK_UNREACHABLE = 12
    # An unknown TLS error
    BOLT_TLS_ERROR = 13
    # Connection closed by remote peer
    BOLT_END_OF_TRANSMISSION = 15
    # Server returned a FAILURE message, more info available through \ref BoltConnection_failure
    BOLT_SERVER_FAILURE = 16
    # Unsupported bolt transport
    BOLT_TRANSPORT_UNSUPPORTED = 0x400
    # Unsupported protocol usage
    BOLT_PROTOCOL_VIOLATION = 0x500
    # Unsupported bolt type
    BOLT_PROTOCOL_UNSUPPORTED_TYPE = 0x501
    # Unknown pack stream type
    BOLT_PROTOCOL_NOT_IMPLEMENTED_TYPE = 0x502
    # Unexpected marker
    BOLT_PROTOCOL_UNEXPECTED_MARKER = 0x503
    # Unsupported bolt protocol version
    BOLT_PROTOCOL_UNSUPPORTED = 0x504
    # Connection pool is full
    BOLT_POOL_FULL = 0x600
    # Connection acquisition from the connection pool timed out
    BOLT_POOL_ACQUISITION_TIMED_OUT = 0x601
    # Address resolution failed
    BOLT_ADDRESS_NOT_RESOLVED = 0x700
    # Routing table retrieval failed
    BOLT_ROUTING_UNABLE_TO_RETRIEVE_ROUTING_TABLE = 0x800
    # No servers to select for the requested operation
    BOLT_ROUTING_NO_SERVERS_TO_SELECT = 0x801
    # Connection pool construction for server failed
    BOLT_ROUTING_UNABLE_TO_CONSTRUCT_POOL_FOR_SERVER = 0x802
    # Routing table refresh failed
    BOLT_ROUTING_UNABLE_TO_REFRESH_ROUTING_TABLE = 0x803
    # Invalid discovery response
    BOLT_ROUTING_UNEXPECTED_DISCOVERY_RESPONSE = 0x804
    # Error set in connection
    BOLT_CONNECTION_HAS_MORE_INFO = 0xFFE
    # Error set in connection
    BOLT_STATUS_SET = 0xFFF

    attach_function :string, :BoltError_get_string, [:int32_t], :string
  end
end
