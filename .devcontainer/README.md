# Devcontainer

Defines the dev environment for GitHub Codespaces. Also usable with VS
Code's Dev Containers extension or JetBrains Gateway locally.

## What's installed

| Tool | Version | Notes |
|------|---------|-------|
| Ruby (MRI) | 3.4.9 | matches the CI matrix |
| JRuby | 10.1.0.0 | at `$JRUBY_HOME=/opt/jruby`; tarball SHA-256 verified |
| Java | OpenJDK 21 (Temurin) | required by JRuby |
| Python | 3.11 | for testkit's Python orchestration |
| Node | 22 | for `npm install -g @anthropic-ai/claude-code` |
| Docker | engine 27 (docker-in-docker) | so testkit can launch a Neo4j container |
| `gh` | 2.60.0 | for PR work |
| Claude Code | latest | installed via npm by `post-create.sh` |

`testkit` is auto-cloned at `/workspaces/testkit` (sibling of the
project) at the same pinned commit the CI workflows use, and
`TESTKIT_PATH` is set in the container env so `bin/run-testkit` finds
it without you exporting anything.

## Launching a Codespace

From the GitHub UI: **Code → Codespaces → Create codespace on `<branch>`**.
First boot runs `post-create.sh` (~3–5 min). Subsequent starts are quick.

## Running things

### RSpec (no Neo4j needed)

```bash
bundle exec rspec
```

Should print `400 examples, 0 failures`.

### Testkit stub suite (no Neo4j needed)

```bash
./bin/run-testkit stub
```

Uses testkit's bundled `boltstub` for protocol-level testing. ~93
should pass; failures/errors past the baseline are the CI gate. The
stub baseline lives at `.github/testkit-stub-baseline-mri.txt`.

### Testkit neo4j suite (needs a running Neo4j)

The container has `docker` (via docker-in-docker) so you start Neo4j
inside the codespace itself:

```bash
docker run -d --name neo4j-test \
  -p 7687:7687 -p 7474:7474 \
  -e NEO4J_AUTH=neo4j/password \
  -e NEO4J_ACCEPT_LICENSE_AGREEMENT=yes \
  neo4j:5.26.21-enterprise

# wait ~10s for Bolt to come up, then:
TEST_NEO4J_HOST=localhost \
TEST_NEO4J_USER=neo4j \
TEST_NEO4J_PASS=password \
TEST_NEO4J_VERSION=5.26 \
./bin/run-testkit neo4j
```

Stop and remove with `docker rm -f neo4j-test` when done. The neo4j
baseline lives at `.github/testkit-baseline-mri.txt`.

### Refreshing a baseline

```bash
bin/refresh-testkit-baseline stub      # writes -mri/-jruby suffix automatically
bin/refresh-testkit-baseline neo4j     # needs Neo4j running (see above)
```

The script detects the active Ruby and writes to the matching baseline
file. Review the diff and commit.

## Switching between MRI and JRuby

The container has both Rubies installed. The default shell uses MRI;
no setup needed for the standard MRI-flavor-on-MRI path. To exercise
the other two flavor combinations, run inside a subshell so PATH
changes don't leak back:

**JRuby flavor on JRuby** (the native JRuby path; will work once
`lib/jruby/` has code):

```bash
(
  export PATH="$JRUBY_HOME/bin:$PATH"
  bundle install              # re-resolves for the java platform
  bundle exec rspec           # currently fails — lib/jruby/ is empty
)
```

**MRI flavor on JRuby** (run the pure-Ruby codebase under the JVM):

```bash
(
  export PATH="$JRUBY_HOME/bin:$PATH"
  export NEO4J_DRIVER_FORCE_MRI=1   # Gemfile pins the MRI gemspec
  bundle install
  bundle exec rspec
)
```

CI exercises all three combinations via matrix rows.

`Gem.loaded_specs['neo4j-ruby-driver'].metadata['impl']` reports the
active flavor — see `lib/shared/neo4j/driver.rb`.

## Notes

- The container is x86_64 (Codespaces default). JRuby is JVM-based so
  it runs anywhere; MRI 3.4 has prebuilt Linux x86_64 binaries.
- `bundle config force_ruby_platform false` is set in `post-create.sh`
  so that on JRuby Bundler picks the `java`-platform variants of deps
  that ship them (e.g. nokogiri-java).
- Claude Code authentication is interactive on first `claude` invocation.
