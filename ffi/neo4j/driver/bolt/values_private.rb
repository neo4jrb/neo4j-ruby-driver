module Bolt
  module ValuesPrivate
    extend FFI::Library

    typedef :pointer, :bolt_value
    # typedef BoltData, :bolt_data
    # typedef BoltExtendedValue, :bolt_extended_value
    #
    # class BoltValue < FFI::Struct
    #   layout :type, :int16_t,
    #          :subtype, :int16_t,
    #          :size, :int16_t,
    #          :data_size, :uint64_t,
    #          :data, :bolt_data
    # end
    #
    # class BoltData < FFI::Union
    #   layout :as_char, [:char, 16],
    #          :as_uint32, [:uint32_t, 4],
    #          :as_int8, [:int8_t, 16],
    #          :as_int16, [:int16_t, 8],
    #          :as_int32, [:int32_t, 4],
    #          :as_int64, [:int64_t, 2],
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