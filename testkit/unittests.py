"""
Executed in Java driver container.
Responsible for running unit tests.
Assumes driver has been setup by build script prior to this.
"""

import os, subprocess

def run(args):
    subprocess.run(
        args, universal_newlines=True, stderr=subprocess.STDOUT, check=True)

if __name__ == "__main__":
    print("Unit tests not ported to testkit")
