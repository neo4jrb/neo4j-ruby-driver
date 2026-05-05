# Devcontainer

Defines the dev environment for GitHub Codespaces. Also usable with VS
Code's Dev Containers extension or JetBrains Gateway locally.

## What's installed

| Tool | Version | Notes |
|------|---------|-------|
| Ruby (MRI) | 3.4.9 | matches the CI matrix |
| JRuby | 10.1.0.0 | installed at `$JRUBY_HOME=/opt/jruby` |
| Java | OpenJDK 21 (Temurin) | required by JRuby |
| Python | 3.11 | for testkit's Python orchestration |
| Node | LTS | for `npm install -g @anthropic-ai/claude-code` |
| Docker | docker-in-docker | so testkit can launch a Neo4j service container |
| `gh` | latest | for PR work |
| Claude Code | latest | installed via npm in `post-create.sh` |

`testkit` is cloned alongside the project at `../testkit` at the same
pinned commit the CI workflows use, so `bin/run-testkit` works
out-of-the-box.

## Launching a Codespace

From the GitHub UI: **Code → Codespaces → Create codespace on `<branch>`**.
First boot runs `post-create.sh` (~3–5 min). Subsequent starts are quick.

## Running things

```bash
bundle exec rspec                   # MRI specs
./bin/run-testkit stub              # protocol suite, no DB
./bin/run-testkit neo4j             # integration suite — needs a Neo4j (see below)
```

### Starting Neo4j inside the codespace

Docker is available via docker-in-docker. To run testkit against a
real DB:

```bash
docker run -d --name neo4j-test \
  -p 7687:7687 -p 7474:7474 \
  -e NEO4J_AUTH=neo4j/password \
  -e NEO4J_ACCEPT_LICENSE_AGREEMENT=yes \
  neo4j:5.26.21-enterprise

# Then:
TEST_NEO4J_HOST=localhost TEST_NEO4J_USER=neo4j \
  TEST_NEO4J_PASS=password TEST_NEO4J_VERSION=5.26 \
  ./bin/run-testkit neo4j
```

### Switching to JRuby for a session

```bash
export PATH="$JRUBY_HOME/bin:$PATH"
bundle install                      # re-resolves for the java platform
bundle exec rspec
```

`Gem.loaded_specs['neo4j-ruby-driver'].metadata['impl']` will report
`jruby` after the switch — see `lib/shared/neo4j/driver.rb`.

## Notes

- The container is x86_64 (Codespaces default). JRuby is JVM-based so
  it runs anywhere; MRI 3.4 has prebuilt Linux x86_64 binaries.
- `bundle config force_ruby_platform false` is set in `post-create.sh`
  so that on JRuby Bundler picks the `java`-platform variants of deps
  that ship them (e.g. nokogiri-java).
- Claude Code authentication is interactive on first `claude` invocation.
