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

## Cutting a release

One command does the whole thing — finalize the changelog, land it on `main`,
and (after a confirmation) tag and trigger the publish:

```bash
rake release            # release the version currently in version.rb
rake "release[6.3.1]"   # bump version.rb to 6.3.1 first, then release
```

It needs an authenticated `gh` and `git-cliff` installed, and a clean `main` in
sync with `origin/main`. It then:

1. Bumps `version.rb` if you passed a version (otherwise uses what's there —
   the version is the single source of truth; the workflow refuses a tag that
   disagrees with it). It also refuses to release a version whose base (without
   any pre-release token) doesn't match the Java-driver pins in
   `neo4j-ruby-driver-java.gemspec`, since the gem version tracks that driver —
   bump the jar requirements in the same step when the target Java version
   changes.
2. Regenerates `CHANGELOG.md`, moving `[Unreleased]` into a `[<version>]`
   heading.
3. Commits both and pushes **straight to `main`**. Pushing to the protected
   `main` is sanctioned by the admin `always` bypass on the branch ruleset — a
   changelog/version commit is paths-ignored by CI and the changelog is
   machine-generated, so a PR would add process without protection.
4. Prompts `Continue? [y/N]` (since the next step publishes to RubyGems and
   can't be undone), then tags `v<version>` and pushes just that tag, firing
   [`release.yml`](.github/workflows/release.yml).

A version already tagged on `origin` is refused: a released number can never be
reused on RubyGems, so bump to a new one. Set `RELEASE_YES=1` to skip the
prompt (e.g. from an automated caller).

(Between releases, `rake changelog` on its own refreshes the `[Unreleased]`
section from merged PRs — no tag argument.)

## What the workflow does

On any `v*` tag:

- Creates a **GitHub Release** whose notes are auto-generated from the pull
  requests merged since the previous tag. Tags carrying a pre-release token
  (`.alpha`/`.beta`/`.rc`/…) are marked **pre-release**.
- Builds **both platform gems** and pushes them to RubyGems — **JRuby (`java`)
  first, then MRI (`ruby`)**. The `ruby` gem is the universal fallback, so
  publishing it before the `java` gem would let a JRuby user install the MRI
  implementation for that version; JRuby-first closes that window. Publishing
  authenticates via [RubyGems Trusted Publishing](https://guides.rubygems.org/trusted-publishing/)
  (OIDC) — each publish job mints a short-lived token, so there is no API key
  to store or rotate.

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

Register a **Trusted Publisher** on rubygems.org (per gem: RubyGems → the gem →
_Trusted publishers_ → GitHub Actions) pointing at this repository and the
`.github/workflows/release.yml` workflow. No repository secret is needed — the
publish jobs authenticate over OIDC.

- The gem name (`neo4j-ruby-driver`) is shared by both platforms, so a single
  trusted-publisher entry covers the `ruby` and `java` pushes.
- For a gem that doesn't exist on RubyGems yet, create a **pending** trusted
  publisher (RubyGems → _Trusted publishers_ → _Register a new one_) so the first
  release can push it.
- If you bound the trusted publisher to a GitHub Actions **environment**, add a
  matching `environment:` to the `publish-*` jobs; leave it out otherwise.
