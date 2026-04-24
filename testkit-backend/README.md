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

2. Start a Neo4j (Docker is easiest):

   ```bash
   docker run -p 7687:7687 -e NEO4J_AUTH=neo4j/pass --rm neo4j:5
   ```

3. Start the backend (from this repo's root):

   ```bash
   bundle exec ruby testkit-backend/backend.rb
   ```

4. Run a testkit test against it:

   ```bash
   cd ~/projects/testkit
   export TEST_NEO4J_HOST=localhost
   export TEST_NEO4J_USER=neo4j
   export TEST_NEO4J_PASS=pass
   python3 -m unittest tests.neo4j.test_session_run.TestSessionRun.test_iteration_smaller_than_fetch_size
   ```

Set `TEST_DEBUG_REQRES=1` on testkit's side to log the JSON going back
and forth — handy when adding new handler support.

## Current scope

MVP covers enough for the core session_run and transaction tests:
`NewDriver`, `DriverClose`, `VerifyConnectivity`, `NewSession`,
`SessionClose`, `SessionRun`, `ResultNext/Peek/Single/List/Consume`,
`SessionBeginTransaction`, `TransactionRun/Commit/Rollback/Close`,
`GetFeatures` (empty — all non-mandatory features unsupported),
`StartTest` (run everything).

Known gaps (add as tests require):

- Managed transactions (`SessionExecuteRead`/`Write` with
  `RetryableTry` / `RetryablePositive` / `RetryableNegative`) — needs
  a reentrant callback dance with testkit.
- Stub server tests — require advertising specific features.
- Graph types (`CypherNode`, `CypherRelationship`, `CypherPath`) in
  record values.
- Detailed `Summary` fields beyond counters.
- Bookmark manager, auth token manager, resolver hooks.
