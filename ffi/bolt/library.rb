# frozen_string_literal: true

module Bolt
  module Library
    include FFI::Library
    include Bolt::AutoReleasable

    def self.extended(mod)
      mod.ffi_lib 'libseabolt17'
    end
  end
end
