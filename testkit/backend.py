"""
Executed in Ruby driver container.
Assumes driver and backend has been built.
Responsible for starting the test backend.
"""
import os, subprocess

if __name__ == "__main__":
    err = open("/artifacts/backenderr.log", "w")
    out = open("/artifacts/backendout.log", "w")
    subprocess.check_call(
        ['env', 'driver=%s' % os.environ.get("TEST_DRIVER_PLATFORM", 'ruby'), "bin/testkit-backend"], stdout=out, stderr=err)
