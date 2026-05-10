# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Advance the mocked clock by `increment_ms` milliseconds. See
    # fake_time_install.rb for the driver-side gap.
    class FakeTimeTick < Data.define(:increment_ms)
      include Request

      def execute
        Response::DriverError.not_implemented(
          'FakeTimeTick: injectable Clock not implemented (see fake_time_install.rb).'
        )
      end
    end
  end
end
