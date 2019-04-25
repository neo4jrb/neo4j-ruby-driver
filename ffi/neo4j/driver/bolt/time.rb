# frozen_string_literal: true

module Bolt
  module Time
    extend Bolt::Library

    attach_function :get_time, :BoltTime_get_time, %i[pointer], :int
    attach_function :get_time_ms, :BoltTime_get_time_ms, [], :int64_t
    attach_function :get_time_ms_from, :BoltTime_get_time_ms_from, %i[pointer], :int64_t
    attach_function :diff_time, :BoltTime_diff_time, %i[pointer pointer pointer], :void
  end
end

