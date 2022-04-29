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
        ["bin/testkit-backend"],
        stdout=sys.stdout, stderr=sys.stderr
    )
