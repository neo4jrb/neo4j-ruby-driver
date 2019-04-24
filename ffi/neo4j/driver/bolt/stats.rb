# frozen_string_literal: true

module Bolt
  module Stats
    extend Bolt::Library

    attach_function :memory_allocation_current, :BoltStat_memory_allocation_current, [], :uint64_t
    attach_function :memory_allocation_peak, :BoltStat_memory_allocation_peak, [], :uint64_t
    attach_function :memory_allocation_events, :BoltStat_memory_allocation_events, [], :uint64_t
  end
end
