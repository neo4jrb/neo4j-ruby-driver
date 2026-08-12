# Releasing

Releases are cut by pushing a version tag; the
[`release`](.github/workflows/release.yml) workflow does the rest.

The gem version tracks the `neo4j-java-driver` version it targets, with a
Ruby-side pre-release token when applicable. Use RubyGems' dot form —
`6.2.1.beta.1`, not the hyphenated `6.2.1-beta.1` (RubyGems rewrites the hyphen
to `.pre.`). The progression is `alpha` → `beta` → `rc` → final.

`CHANGELOG.md` is generated from the commit history with
[git-cliff](https://git-cliff.org) — never hand-edited. Install it once
(`brew install git-cliff`, or see the git-cliff docs).

## Steps

1. **Bump the version** in `lib/shared/neo4j/driver/version.rb`.
2. **Regenerate the changelog**, finalizing the new version's section (this
   moves `[Unreleased]` into a `[<version>]` heading):

   ```bash
   version="$(ruby -r ./lib/shared/neo4j/driver/version -e 'print Neo4j::Driver::VERSION')"
   rake "changelog[v$version]"
   ```

3. **Commit** the version + changelog on `main` (via PR, as usual).
4. **Tag and push just that tag** (not `--tags`, which would push any stray
   local tags):

   ```bash
   git tag "v$version"
   git push origin "v$version"
   ```

(Between releases, `rake changelog` refreshes `[Unreleased]` from merged PRs.)

## What the workflow does

On any `v*` tag:

- Creates a **GitHub Release** whose notes are auto-generated from the pull
  requests merged since the previous tag. Tags with a suffix (`-alpha`/`-beta`/
  `-rc`/…) are marked **pre-release**.
- Builds **both platform gems** and, when the `RUBYGEMS_API_KEY` repository
  secret is set, pushes them to RubyGems — **JRuby (`java`) first, then MRI
  (`ruby`)**. The `ruby` gem is the universal fallback, so publishing it before
  the `java` gem would let a JRuby user install the MRI implementation for that
  version; JRuby-first closes that window. Without the secret the gems are built
  but not pushed, so a tag still smoke-tests the release build.

## Rolling back a release

Run these **manually** — unlike cutting a release, there is no tag or workflow
trigger for a rollback. Yanking a version is permanent, so it stays a deliberate,
hands-on step. You need RubyGems owner credentials and an authenticated `gh`.

A yanked version number **can never be reused** on RubyGems, so a rollback is
really "pull the bad release, then ship a *new* version".

1. **Yank both platform gems** (MRI is the `ruby` platform, JRuby the `java`
   platform — each is a separate published gem):

   ```bash
   gem yank neo4j-ruby-driver -v <version>
   gem yank neo4j-ruby-driver -v <version> --platform java
   ```

   `yank` removes the version from the index so no new install/resolution picks
   it up; it does not uninstall it for anyone who already fetched it.

2. **Delete the GitHub Release and its tag**:

   ```bash
   gh release delete "v<version>" --yes --cleanup-tag
   ```

3. **Fix, then release a new version** — bump `version.rb` (e.g. the next
   `.beta.N`), update the CHANGELOG, and tag/push as above. You cannot reuse the
   yanked number.

> Only need to re-run a *failed publish* (not a version change)? Re-push the same
> tag — the release step is idempotent — but note the gem push will still fail on
> a duplicate version, so anything version-affecting means a bump.

## One-time setup

Add a **`RUBYGEMS_API_KEY`** repository secret (Settings → Secrets and variables
→ Actions) with a RubyGems API key scoped to push `neo4j-ruby-driver`. Until
then, `gem push` is skipped and you can publish manually with
`rake build && gem push pkg/*.gem`.
