# frozen_string_literal: true

module Bolt
  module Config
    extend Bolt::Library
    typedef :int32_t, :bolt_scheme
    typedef :int32_t, :bolt_transport

    attach_function :create, :BoltConfig_create, [], :auto_pointer
    attach_function :destroy, :BoltConfig_destroy, [:pointer], :void
    attach_function :get_scheme, :BoltConfig_get_scheme, [:pointer], :bolt_scheme
    attach_function :set_scheme, :BoltConfig_set_scheme, %i[pointer bolt_scheme], :int32_t
    attach_function :get_transport, :BoltConfig_get_transport, [:pointer], :bolt_transport
    attach_function :set_transport, :BoltConfig_set_transport, %i[pointer bolt_transport], :int32_t
    attach_function :get_trust, :BoltConfig_get_trust, [:pointer], :pointer
    attach_function :set_trust, :BoltConfig_set_trust, %i[pointer pointer], :int32_t
    attach_function :get_user_agent, :BoltConfig_get_user_agent, [:pointer], :string
    attach_function :set_user_agent, :BoltConfig_set_user_agent, %i[pointer string], :int32
    attach_function :get_routing_context, :BoltConfig_get_routing_context, [:pointer], :pointer
    attach_function :set_routing_context, :BoltConfig_set_routing_context, %i[pointer pointer], :int32_t
    attach_function :get_address_resolver, :BoltConfig_get_address_resolver, [:pointer], :pointer
    attach_function :set_address_resolver, :BoltConfig_set_address_resolver, %i[pointer pointer], :int32_t
    attach_function :get_log, :BoltConfig_get_log, [:pointer], :pointer
    attach_function :set_log, :BoltConfig_set_log, %i[pointer pointer], :int32
    attach_function :get_max_pool_size, :BoltConfig_get_max_pool_size, [:pointer], :int32_t
    attach_function :set_max_pool_size, :BoltConfig_set_max_pool_size, %i[pointer int32_t], :int32_t
    attach_function :get_max_connection_life_time, :BoltConfig_get_max_connection_life_time, [:pointer], :int32_t
    attach_function :set_max_connection_life_time, :BoltConfig_set_max_connection_life_time, %i[pointer int32_t],
                    :int32_t
    attach_function :get_max_connection_acquisition_time, :BoltConfig_get_max_connection_acquisition_time, [:pointer],
                    :int32_t
    attach_function :set_max_connection_acquisition_time, :BoltConfig_set_max_connection_acquisition_time,
                    %i[pointer int32_t], :int32_t
    attach_function :get_socket_options, :BoltConfig_get_socket_options, [:pointer], :pointer
    attach_function :set_socket_options, :BoltConfig_set_socket_options, %i[pointer pointer], :int32_t
  end
end
