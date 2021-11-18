"""
Executed in Ruby driver container.
Assumes driver and backend has been built.
Responsible for starting the test backend.
"""
import os
import subprocess
import sys

if __name__ == "__main__":
    subprocess.check_call(
        ['env', 'driver=%s' % os.environ.get("TEST_DRIVER_PLATFORM", 'ruby'), "bin/testkit-backend"],
        stdout=sys.stdout, stderr=sys.stderr
    )
