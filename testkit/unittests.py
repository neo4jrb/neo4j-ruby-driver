"""Run the driver's own unit test suite. Called by testkit's main.py."""

import os
import subprocess


if __name__ == "__main__":
    # Driver-side RSpec suite needs a reachable Neo4j. When running inside
    # testkit's Docker orchestration TEST_NEO4J_HOST is set automatically;
    # honour that here.
    env = os.environ.copy()
    host = env.get("TEST_NEO4J_HOST")
    port = env.get("TEST_NEO4J_PORT", "7687")
    if host:
        env.setdefault("TEST_NEO4J_URL", f"bolt://{host}:{port}")
    env.setdefault("TEST_NEO4J_USER", env.get("TEST_NEO4J_USER", "neo4j"))
    env.setdefault("TEST_NEO4J_PASS", env.get("TEST_NEO4J_PASS", "pass"))

    subprocess.check_call(["bundle", "exec", "rspec"], env=env)
