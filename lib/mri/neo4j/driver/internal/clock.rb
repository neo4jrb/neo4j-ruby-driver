# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # MRI placeholder for the test-clock seam — see the JRuby
      # sibling. Backend:MockTime is JRuby-only for now; this stub
      # raises if testkit-backend hits it accidentally, and is the
      # shape the eventual MRI implementation will fill in.
      module Clock
        module_function

        def install
          raise NotImplementedError, 'Backend:MockTime is not yet supported on the MRI driver'
        end

        def tick(_delta_ms)
          raise NotImplementedError, 'Backend:MockTime is not yet supported on the MRI driver'
        end

        def uninstall
          raise NotImplementedError, 'Backend:MockTime is not yet supported on the MRI driver'
        end

        # Used by testkit-backend's bearer-token expiration math even
        # when no FakeTime is installed; MRI falls back to system time.
        def millis
          (Time.now.to_f * 1000).to_i
        end
      end
    end
  end
end
