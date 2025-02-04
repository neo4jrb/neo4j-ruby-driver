# frozen_string_literal: true

module TimeoutHelper
  def wait_till(timeout = 4, sleep_interval = 0.01, &condition)
    Timeout.timeout(timeout) { sleep(sleep_interval) while(!condition.call) }
  end
end
