"""Launch the Ruby testkit backend.

Called by testkit's main.py inside the driver Docker container. The
backend runs in the foreground and must stay alive for the integration
test phase.
"""

import os
import subprocess
import sys


def main():
    env = os.environ.copy()
    env.setdefault("TEST_BACKEND_HOST", "0.0.0.0")
    env.setdefault("TEST_BACKEND_PORT", "9876")

    cmd = ["bundle", "exec", "ruby", "testkit-backend/backend.rb"]
    subprocess.check_call(cmd, env=env)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
