# frozen_string_literal: true

module Bolt
  module Connection
    extend FFI::Library
    ffi_lib ENV['SEABOLT_LIB']

    typedef :uint64_t, :bolt_request

    attach_function :set_run_cypher, :BoltConnection_set_run_cypher, %i[pointer string uint64_t int32_t], :int32_t
    attach_function :set_run_cypher_parameter, :BoltConnection_set_run_cypher_parameter,
                    %i[pointer int32_t string uint64_t], :pointer
    attach_function :load_run_request, :BoltConnection_load_run_request, [:pointer], :int32_t
    attach_function :load_discard_request, :BoltConnection_load_discard_request, %i[pointer int32_t], :int32_t
    attach_function :load_pull_request, :BoltConnection_load_pull_request, %i[pointer int32_t], :int32_t
    attach_function :load_reset_request, :BoltConnection_load_reset_request, [:pointer], :int32_t
    attach_function :last_request, :BoltConnection_last_request, [:pointer], :bolt_request
    attach_function :send, :BoltConnection_send, [:pointer], :int32_t
    attach_function :failure, :BoltConnection_failure, [:pointer], :pointer
    attach_function :status, :BoltConnection_status, [:pointer], :pointer
    attach_function :fetch, :BoltConnection_fetch, %i[pointer bolt_request], :int32_t
    attach_function :fetch_summary, :BoltConnection_fetch_summary, %i[pointer bolt_request], :int32_t
    attach_function :summary_success, :BoltConnection_summary_success, [:pointer], :int32_t
    attach_function :field_names, :BoltConnection_field_names, [:pointer], :pointer
    attach_function :field_values, :BoltConnection_field_values, [:pointer], :pointer
  end
end
