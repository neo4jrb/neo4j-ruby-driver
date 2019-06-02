# frozen_string_literal: true

module Bolt
  module Connection
    extend Bolt::Library

    typedef :uint64, :bolt_request

    attach_function :flush, :BoltConnection_send, [:pointer], :int32
    attach_function :fetch, :BoltConnection_fetch, %i[pointer bolt_request], :int32
    attach_function :fetch_summary, :BoltConnection_fetch_summary, %i[pointer bolt_request], :int32
    attach_function :clear_begin, :BoltConnection_clear_begin, %i[pointer], :int32
    attach_function :set_begin_bookmarks, :BoltConnection_set_begin_bookmarks, %i[pointer pointer], :int32
    attach_function :set_begin_tx_timeout, :BoltConnection_set_begin_tx_timeout, %i[pointer int64], :int32
    attach_function :set_begin_tx_metadata, :BoltConnection_set_begin_tx_metadata, %i[pointer pointer], :int32
    attach_function :load_begin_request, :BoltConnection_load_begin_request, %i[pointer], :int32
    attach_function :load_commit_request, :BoltConnection_load_commit_request, %i[pointer], :int32
    attach_function :load_rollback_request, :BoltConnection_load_rollback_request, %i[pointer], :int32
    attach_function :clear_run, :BoltConnection_clear_run, %i[pointer], :int32
    attach_function :set_run_bookmarks, :BoltConnection_set_run_bookmarks, %i[pointer pointer], :int32
    attach_function :set_run_tx_timeout, :BoltConnection_set_run_tx_timeout, %i[pointer int64], :int32
    attach_function :set_run_tx_metadata, :BoltConnection_set_run_tx_metadata, %i[pointer pointer], :int32
    attach_function :set_run_cypher, :BoltConnection_set_run_cypher, %i[pointer string uint64 int32], :int32
    attach_function :set_run_cypher_parameter, :BoltConnection_set_run_cypher_parameter,
                    %i[pointer int32 string uint64], :pointer
    attach_function :load_run_request, :BoltConnection_load_run_request, [:pointer], :int32
    attach_function :load_discard_request, :BoltConnection_load_discard_request, %i[pointer int32], :int32
    attach_function :load_pull_request, :BoltConnection_load_pull_request, %i[pointer int32], :int32
    attach_function :load_reset_request, :BoltConnection_load_reset_request, [:pointer], :int32
    attach_function :last_request, :BoltConnection_last_request, [:pointer], :bolt_request
    attach_function :server, :BoltConnection_server, %i[pointer], :strptr
    attach_function :id, :BoltConnection_id, %i[pointer], :strptr
    attach_function :address, :BoltConnection_address, %i[pointer], :pointer
    attach_function :remote_endpoint, :BoltConnection_remote_endpoint, %i[pointer], :pointer
    attach_function :local_endpoint, :BoltConnection_local_endpoint, %i[pointer], :pointer
    attach_function :last_bookmark, :BoltConnection_last_bookmark, %i[pointer], :strptr
    attach_function :summary_success, :BoltConnection_summary_success, [:pointer], :int32
    attach_function :failure, :BoltConnection_failure, [:pointer], :pointer
    attach_function :field_names, :BoltConnection_field_names, [:pointer], :pointer
    attach_function :field_values, :BoltConnection_field_values, [:pointer], :pointer
    attach_function :metadata, :BoltConnection_metadata, %i[pointer], :pointer
    attach_function :status, :BoltConnection_status, [:pointer], :pointer
  end
end
