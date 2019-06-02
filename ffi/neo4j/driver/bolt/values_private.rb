# frozen_string_literal: true

module Bolt
  module ValuesPrivate
    extend FFI::Library

    typedef :pointer, :bolt_value
    # typedef BoltData, :bolt_data
    # typedef BoltExtendedValue, :bolt_extended_value
    #
    # class BoltValue < FFI::Struct
    #   layout :type, :int16,
    #          :subtype, :int16,
    #          :size, :int16,
    #          :data_size, :uint64,
    #          :data, :bolt_data
    # end
    #
    # class BoltData < FFI::Union
    #   layout :as_char, [:char, 16],
    #          :as_uint32, [:uint32, 4],
    #          :as_int8, [:int8_t, 16],
    #          :as_int16, [:int16, 8],
    #          :as_int32, [:int32, 4],
    #          :as_int64, [:int64, 2],
    #          :as_double, [:double, 2],
    #          :extended, :bolt_extended_value
    # end

    class BoltExtendedValue < FFI::Union
      layout :as_ptr, :pointer,
             :as_char, :string,
             :as_value, :bolt_value
    end
  end
end
