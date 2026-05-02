# Testkit backend

Ruby backend for [testkit](https://github.com/neo4j-drivers/testkit),
the shared integration/conformance test suite for Neo4j drivers.

Testkit's Python test runner talks to a per-driver backend process
over a TCP socket using a line-delimited JSON protocol. This directory
contains that backend for neo4j-ruby-driver2. The `testkit/` directory
one level up holds the Python orchestration scripts that testkit's
Docker runner calls.

## Layout

- `backend.rb` — entry point, TCP server, request framing.
- `dispatcher.rb` — request → driver-API translation and handle maps.
- `cypher.rb` — tagged `CypherValue` ↔ Ruby value conversion.

## Local development

1. Clone testkit somewhere, e.g. `~/projects/testkit`:

   ```bash
   git clone https://github.com/neo4j-drivers/testkit.git ~/projects/testkit
   cd ~/projects/testkit
   python3 -m pip install -Ur requirements.txt
   ```

   `./bin/run-testkit` defaults to `TESTKIT_PATH=$HOME/projects/testkit`.

2. Pick a target:

   - **`tests/neo4j`** (integration suite) — needs a real Neo4j running on `localhost:7687`:

     ```bash
     docker run -d --name neo4j-test -p 7687:7687 -p 7474:7474 \
       -e NEO4J_AUTH=neo4j/password \
       -e NEO4J_ACCEPT_LICENSE_AGREEMENT=yes \
       neo4j:5.26.21-enterprise
     ```

     CI runs against `5.26.21-enterprise`. If you use a different Neo4j version, set `TEST_NEO4J_VERSION` to the matching `major.minor` (e.g. `2026.03`) so the agent-string assertion lines up. Multi-database tests require the enterprise edition.

   - **`tests/stub`** (protocol-level suite) — uses testkit's bundled `boltstub`, no Neo4j needed.

3. Run the suite via the wrapper script (starts the backend, runs the suite, summarises results):

   ```bash
   ./bin/run-testkit neo4j   # integration
   ./bin/run-testkit stub    # protocol
   ```

   Or, to iterate on a single test, hand-start the backend:

   ```bash
   bundle exec ruby testkit-backend/backend.rb
   ```

   then run any `python3 -m unittest tests.neo4j.…` or `tests.stub.…`
   from the testkit checkout. Set `TEST_DEBUG_REQRES=1` to log the
   JSON going back and forth — handy when adding new handler support.

   If the Python frontend complains about `ifaddr`, `boltkit`, or
   similar, re-run the `pip install -Ur requirements.txt` step. A
   venv is recommended on macOS to avoid PEP 668 issues.

## Current scope

Covers `tests/neo4j` end-to-end (88 pass, 0 fail, 0 error). The
`tests/stub` walk-down is just starting — see the parent repo's
`TESTKIT.md` for live status and backlog.
