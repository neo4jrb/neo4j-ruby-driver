# Development Guide

## Setup

```bash
bundle install
```

## Running tests

```bash
bundle exec rspec                                        # full suite
bundle exec rspec spec/shared/integration/session_spec.rb       # one file
bundle exec rspec spec/shared/integration/session_spec.rb:42    # one example
bundle exec rspec './spec/shared/integration/session_spec.rb[1:2:3]'  # nested rspec id
bundle exec rspec --format documentation                 # verbose
```

Environment variables (export or use direnv):

```bash
TEST_NEO4J_URL=bolt://localhost:7687
TEST_NEO4J_USER=neo4j
TEST_NEO4J_PASS=password
```

## Running Neo4j in Docker

```bash
docker run -p 7687:7687 -e NEO4J_AUTH=neo4j/password neo4j:5
```

Swap the tag (`4.4`, `5`, `5.22`, etc.) to test protocol negotiation
against different Bolt versions.

## Pre-commit checks

```bash
bundle exec rspec
git diff | grep -iE "puts |binding\.pry|debugger"   # catch debug artefacts
```

## Reference drivers

When implementing protocol-level code, compare against the official drivers:

- **Java** (authoritative): https://github.com/neo4j/neo4j-java-driver — PackStream at `driver/src/main/java/org/neo4j/driver/internal/packstream/`, messaging at `.../internal/messaging/`, types at `.../internal/value/`
- **Python**: https://github.com/neo4j/neo4j-python-driver — codec at `neo4j/_codec/`
- **JavaScript**: https://github.com/neo4j/neo4j-javascript-driver — TypeScript types useful for graph-type shapes
- **Go**: https://github.com/neo4j/neo4j-go-driver

## Debugging tips

- Hung test: usually a connection stuck on `fetch_response`. Check `@consumed`/`@discarded` on the relevant Result, and whether the server was left in FAILED state without a RESET.
- Wrong type coming back: check the hydration handler in `bolt/connection.rb` and compare the packing in `packstream/packer.rb`.
- Temporal zone issues: see the LOCAL-encoding note in `CLAUDE.md`.

## Spec links

- Bolt protocol: https://neo4j.com/docs/bolt/current/
- PackStream: https://neo4j.com/docs/bolt/current/packstream/
- Bolt 4.x messages: https://7687.org/bolt/bolt-protocol-message-specification-4.html
