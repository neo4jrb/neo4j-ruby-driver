# Releasing

Releases are cut by pushing a version tag; the
[`release`](.github/workflows/release.yml) workflow does the rest.

The gem version tracks the `neo4j-java-driver` version it targets, with a
Ruby-side pre-release suffix (e.g. `6.2.1-beta.1`).

## Steps

1. **Bump the version** in `lib/shared/neo4j/driver/version.rb`.
2. **Update `CHANGELOG.md`**: move the entries under `## [Unreleased]` to a new
   `## [<version>]` heading, and leave a fresh empty `[Unreleased]`.
3. **Commit** on `main` (via PR, as usual).
4. **Tag and push**:

   ```bash
   git tag "v$(ruby -r ./lib/shared/neo4j/driver/version -e 'print Neo4j::Driver::VERSION')"
   git push origin --tags
   ```

## What the workflow does

On any `v*` tag:

- Creates a **GitHub Release** whose notes are auto-generated from the pull
  requests merged since the previous tag. Tags with a suffix (`-alpha`/`-beta`/
  `-rc`/…) are marked **pre-release**.
- Builds **both platform gems** (`rake build:mri` on CRuby, `rake build:jruby`
  on JRuby) and, when the `RUBYGEMS_API_KEY` repository secret is set, pushes
  them to RubyGems. Without the secret the gems are built but not pushed, so a
  tag still smoke-tests the release build.

## One-time setup

Add a **`RUBYGEMS_API_KEY`** repository secret (Settings → Secrets and variables
→ Actions) with a RubyGems API key scoped to push `neo4j-ruby-driver`. Until
then, `gem push` is skipped and you can publish manually with
`rake build && gem push pkg/*.gem`.
