#!/usr/bin/env bash
# Runs once after the devcontainer is built. Idempotent — re-runs are
# safe if the user invokes "Rebuild Container" later.

set -euo pipefail

JRUBY_VERSION=10.1.0.0
JRUBY_HOME=/opt/jruby

# ---------------------------------------------------------------- JRuby
# The ruby feature only installs MRI; JRuby drops in via tarball so both
# coexist. Pinned to 10.1.0.0 to match the CI matrix in
# .github/workflows/specs.yml.
if [ ! -d "$JRUBY_HOME" ]; then
  echo ">>> Installing JRuby $JRUBY_VERSION"
  sudo curl -fsSL \
    "https://repo1.maven.org/maven2/org/jruby/jruby-dist/$JRUBY_VERSION/jruby-dist-$JRUBY_VERSION-bin.tar.gz" \
    | sudo tar -xz -C /opt
  sudo ln -sfn "/opt/jruby-$JRUBY_VERSION" "$JRUBY_HOME"
  sudo ln -sfn "$JRUBY_HOME/bin/jruby"  /usr/local/bin/jruby
  sudo ln -sfn "$JRUBY_HOME/bin/jgem"   /usr/local/bin/jgem
  sudo ln -sfn "$JRUBY_HOME/bin/jirb"   /usr/local/bin/jirb
fi

# ----------------------------------------------------------------- testkit
# `bin/run-testkit` and the CI workflows expect testkit cloned at
# $WORKSPACE_PARENT/testkit. The pinned commit matches the workflows so
# baselines stay reproducible.
TESTKIT_REF=a233c3f32c9e7db33d856345c4c98f487d15aabb
TESTKIT_PATH="$(dirname "$(pwd)")/testkit"
if [ ! -d "$TESTKIT_PATH/.git" ]; then
  echo ">>> Cloning testkit at $TESTKIT_REF"
  git init "$TESTKIT_PATH"
  git -C "$TESTKIT_PATH" remote add origin https://github.com/neo4j-drivers/testkit.git
  git -C "$TESTKIT_PATH" fetch --depth 1 origin "$TESTKIT_REF"
  git -C "$TESTKIT_PATH" checkout FETCH_HEAD
  pip install --quiet -Ur "$TESTKIT_PATH/requirements.txt"
fi

# --------------------------------------------------------- bundle install
# Run for the active Ruby (MRI 3.4.9 by default). The user can switch to
# JRuby for a session via PATH manipulation; bundle install will
# re-resolve for that platform.
echo ">>> bundle install (MRI)"
bundle config set --local force_ruby_platform false  # don't force on JRuby host
bundle install --quiet

# ------------------------------------------------------------- Claude Code
# Install via the official npm package. Auth happens interactively the
# first time the user runs `claude` in the codespace.
if ! command -v claude >/dev/null; then
  echo ">>> Installing Claude Code CLI"
  sudo npm install -g @anthropic-ai/claude-code
fi

echo ""
echo "==============================================================="
echo " Setup complete."
echo ""
echo " Run RSpec        : bundle exec rspec"
echo " Run testkit stub : ./bin/run-testkit stub"
echo " Run testkit (db) : start neo4j first (see .devcontainer/README)"
echo " Switch to JRuby  : PATH=\"\$JRUBY_HOME/bin:\$PATH\" bundle install"
echo "==============================================================="
