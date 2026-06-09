#!/usr/bin/env bash
# Runs once after the devcontainer is built. Idempotent on re-run
# ("Rebuild Container" or postCreate retries) — checks installed
# versions and updates them when they drift from the pinned values.

set -euo pipefail

JRUBY_VERSION=10.1.0.0
JRUBY_HOME=/opt/jruby
JRUBY_TARBALL=jruby-dist-$JRUBY_VERSION-bin.tar.gz
JRUBY_URL=https://repo1.maven.org/maven2/org/jruby/jruby-dist/$JRUBY_VERSION/$JRUBY_TARBALL
# SHA-256 from Maven Central:
#   $JRUBY_URL.sha256
# Update both this constant and JRUBY_VERSION together.
JRUBY_SHA256=9c14a0ce81f3a312fd98c415986982132e91d36b12cb8d74a3dfdae93fe984ac

# ---------------------------------------------------------------- JRuby
# Reinstall when the pinned version doesn't match what's already in
# /opt/jruby — guards against stale tarballs from a previous build.
if ! [ -x "$JRUBY_HOME/bin/jruby" ] \
   || ! "$JRUBY_HOME/bin/jruby" -v 2>/dev/null | grep -q "^jruby $JRUBY_VERSION "; then
  echo ">>> Installing JRuby $JRUBY_VERSION"
  sudo rm -rf "$JRUBY_HOME" "/opt/jruby-$JRUBY_VERSION"

  cd /tmp
  curl -fsSL "$JRUBY_URL" -o "$JRUBY_TARBALL"
  # Verify the checksum before letting tar touch root-owned dirs.
  echo "$JRUBY_SHA256  $JRUBY_TARBALL" | sha256sum --check --status
  sudo tar -xz -C /opt -f "$JRUBY_TARBALL"
  rm -f "$JRUBY_TARBALL"

  sudo ln -sfn "/opt/jruby-$JRUBY_VERSION" "$JRUBY_HOME"
  sudo ln -sfn "$JRUBY_HOME/bin/jruby" /usr/local/bin/jruby
  sudo ln -sfn "$JRUBY_HOME/bin/jgem"  /usr/local/bin/jgem
  sudo ln -sfn "$JRUBY_HOME/bin/jirb"  /usr/local/bin/jirb

  cd - >/dev/null
fi

# ----------------------------------------------------------------- testkit
# Source of truth is testkit/testkit.json (same uri + ref the CI workflows
# pin), so a re-point (e.g. the temporary fork) only has to change one file.
# Always fetch + checkout the pinned ref; init first if the clone is fresh,
# otherwise re-point the remote in case an older build used a different one.
TESTKIT_PATH="$(dirname "$(pwd)")/testkit"
TESTKIT_URI=$(python3 -c "import json; print(json.load(open('testkit/testkit.json'))['testkit']['uri'])")
TESTKIT_REF=$(python3 -c "import json; print(json.load(open('testkit/testkit.json'))['testkit']['ref'])")

if [ ! -d "$TESTKIT_PATH/.git" ]; then
  echo ">>> Initialising testkit clone at $TESTKIT_PATH"
  git init "$TESTKIT_PATH"
  git -C "$TESTKIT_PATH" remote add origin "$TESTKIT_URI"
else
  git -C "$TESTKIT_PATH" remote set-url origin "$TESTKIT_URI"
fi
echo ">>> Pinning testkit to $TESTKIT_REF ($TESTKIT_URI)"
git -C "$TESTKIT_PATH" fetch --depth 1 origin "$TESTKIT_REF"
git -C "$TESTKIT_PATH" checkout --quiet --detach FETCH_HEAD
pip install --quiet -Ur "$TESTKIT_PATH/requirements.txt"

# --------------------------------------------------------- bundle install
# Run for the active Ruby (MRI 3.4.9 by default). Switching to JRuby is
# documented in .devcontainer/README.md.
echo ">>> bundle install (MRI)"
bundle config set --local force_ruby_platform false  # don't force on JRuby host
bundle install --quiet

# ------------------------------------------------------------- Claude Code
# Install via the official npm package. Auth happens interactively on
# first `claude` invocation.
#
# No sudo: the devcontainer Node feature (NVM-based) puts npm's prefix
# under /usr/local/share/nvm/... which is writable by the dev user.
# `sudo npm` strips PATH and fails with "npm: command not found" because
# root's secure_path doesn't include the NVM dir.
if ! command -v claude >/dev/null; then
  echo ">>> Installing Claude Code CLI"
  npm install -g @anthropic-ai/claude-code
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
