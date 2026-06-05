# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # Settable singleton clock seam. The driver's own internals
      # consult `Internal::Clock.now_millis` wherever they need a
      # current epoch reading; production defaults to system time.
      # testkit-backend can replace the seam with a mockable clock —
      # anything responding to `#now_millis` qualifies — to drive
      # Backend:MockTime tests.
      module Clock
        module_function

        def now_millis
          @delegate ? @delegate.now_millis : (Time.now.to_f * 1000).to_i
        end

        def use(clock)
          @delegate = clock
        end

        def reset
          @delegate = nil
        end
      end
    end
  end
end
