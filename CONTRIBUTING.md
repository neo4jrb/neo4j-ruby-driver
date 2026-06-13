# Contributing

Dev-loop commands are in `DEVELOPMENT.md`; architecture in `JRUBY.md`;
dated decisions in `DECISIONS.md`. This file is about **where code belongs** —
the layering that most review comments end up being about.

## Layering: driver vs backend vs features

Adding a testkit feature touches three layers, with strict ownership. Keep
each concern in its layer.

### 1. Driver — `lib/jruby/**`, `lib/mri/**`

Adapts the underlying implementation (the Java driver on JRuby via `ext/`
mixins prepended onto the Java classes; pure Ruby on MRI) to **one uniform
Ruby interface that both flavors expose identically**.

- This is the **only** place flavor-specific code and `Java::` constants live.
- **Expose only what the underlying type actually has.** Don't invent methods
  the Java type lacks — check with `javap`. A non-notification `GqlStatusObject`
  has no `position`/`severity`; don't add them returning `nil`. Mirror the Java
  API: unwrap `Optional`s (`super.or_else(nil)`), convert Java collections to
  Ruby (`as_ruby_object`).
- **No testkit/wire-format knowledge here.** Return domain values (an
  `InputPosition`, an enum name, a Ruby hash), not testkit-shaped structures.

### 2. testkit-backend — `testkit-backend/**`

Serializes the driver's data into testkit's wire shape.

- **Flavor-agnostic.** No `Neo4j::Driver::Loader.jruby?`, `RUBY_PLATFORM`,
  `RUBY_ENGINE`, or `Java::` constants. (Driver constants such as
  `Neo4j::Driver::Summary::GqlNotification` are fine — they're the driver's API,
  and each flavor defines its own.)
- **Emit every feature unconditionally**, calling the uniform driver interface.
  The driver supplies the data per flavor — JRuby now; MRI stubs the method
  (e.g. returns `[]`) until it implements the feature, so the unconditional call
  doesn't crash.
- **Owns the testkit shape**: field names, the `{column, line, offset}` position
  hash, `UNKNOWN`/`nil` defaults for absent data, key symbolization. If a
  conversion produces testkit-specific structure, it lives here, not in the ext.
- **Distinguish types with `is_a?(Neo4j::Driver::SomeType)`** — the Ruby
  equivalent of Java's `instanceof`, against a driver constant. Don't add a
  predicate method (`notification?`) whose only job is to report its class.

### 3. Feature advertisement — `testkit-backend/requests/get_features.rb`

The **only** place per-flavor gating happens. A flavor advertises a feature
only where its driver implements it; until then the feature's tests skip on
that flavor (and the driver stubs the method so the backend still runs).

So a feature is: implement it per flavor behind a uniform interface → serialize
it once, unconditionally, in the backend → advertise it in `get_features` only
where implemented. `gqlStatusObjects` (summary) is the worked example; it
mirrors how `notifications` was already done — **find the nearest existing
analog and mirror it before inventing a new shape.**

## Before you push

- `grep -rE 'jruby\?|RUBY_PLATFORM|RUBY_ENGINE|Java::' testkit-backend/` → empty
  (driver constants excepted).
- Every new JRuby ext method: does the Java type actually have it? (`javap`)
- Any conversion producing testkit-shaped data — is it in the backend, not the
  ext?
- Run the touched area on **both** flavors.
- Use the Java driver as the **design** oracle (how does it model this?), not
  only the behavior oracle.
