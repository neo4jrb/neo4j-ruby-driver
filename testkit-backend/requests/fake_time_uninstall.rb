# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Restore the real clock. See fake_time_install.rb for the
    # driver-side gap.
    class FakeTimeUninstall < Data.define
      include Request

      def execute
        Response::DriverError.not_implemented(
          'FakeTimeUninstall: injectable Clock not implemented (see fake_time_install.rb).'
        )
      end
    end
  end
end
