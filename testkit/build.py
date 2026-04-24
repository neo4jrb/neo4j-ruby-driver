"""Install driver dependencies. Called by testkit's main.py."""

import subprocess


if __name__ == "__main__":
    subprocess.check_call(["bundle", "install"])
