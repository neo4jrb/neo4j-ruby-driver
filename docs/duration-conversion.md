# Duration Conversion

The driver represents Neo4j durations as `Neo4j::Driver::Types::Duration`, **not**
`ActiveSupport::Duration`, and there is deliberately **no built-in conversion**
between them. This note explains why and gives the two helpers to write yourself
when you must bridge. The decision itself is logged in
[`DECISIONS.md`](../DECISIONS.md) (2026-08-13).

> The helpers below are **illustrative only** — they are not part of the library.
> Map field-to-field and value is exact; the only genuine loss is a fractional
> calendar-month (which has no exact finer form).

## The rule

A Neo4j duration is **four independent integer fields**, mirroring Bolt's
`IsoDuration` struct (`0x45`):

| field | meaning |
|-------|---------|
| `months` | calendar months — variable length |
| `days` | calendar days — DST-variable |
| `seconds` | exact SI seconds |
| `nanoseconds` | sub-second remainder |

They are kept **un-normalized on purpose**: a month isn't 30 days, and a day
isn't always 86 400 s (DST). `ActiveSupport::Duration` carries the *same*
distinction — but in its **parts** (`{months: 3}` vs `{days: 91}` are different
durations), while its `==` and `.to_f` see only the scalar. So map
**field-to-field** (parts ↔ Neo4j fields) and the conversion is faithful; collapse
through `.to_f` and it isn't. In this driver, `ActiveSupport::Duration` is still
accepted *only* as a duck-typed (`to_f`) **timeout** argument — never as a stored
value.

## `ActiveSupport::Duration` → `Types::Duration`

Map each part to its Neo4j field — years/months → `months`, weeks/days → `days`,
hours/minutes/seconds → `seconds`. When a part is *fractional*, keep the whole
units in their calendar field and **cascade the remainder down into seconds**
(rather than truncating it into an integer field, which loses magnitude).

```ruby
def as_to_neo(dur) # dur : ActiveSupport::Duration
  p = dur.parts
  months_f = (p[:years] || 0) * 12 + (p[:months] || 0)
  days_f   = (p[:weeks] || 0) * 7  + (p[:days]   || 0)
  months = months_f.to_i
  days   = days_f.to_i
  secs = (p[:hours]||0)*3600 + (p[:minutes]||0)*60 + (p[:seconds]||0) +
         (months_f - months) * ActiveSupport::Duration::SECONDS_PER_MONTH + # frac month → s
         (days_f   - days)   * ActiveSupport::Duration::SECONDS_PER_DAY     # frac day   → s
  whole = secs.floor
  nanos = ((secs - whole) * 1_000_000_000).round
  Neo4j::Driver::Types::Duration.new(months, days, whole, nanos)
end
```

**Value-preserving, calendar-faithful.** Whole units stay put: `91.days → P91D`,
`3.months → P3M`, `5.weeks → P35D`. Fractional days are exact
(`2.5.days → P2DT12H`). The one soft spot is a fractional *month* — see the caveat
under Round-trip behaviour.

## `Types::Duration` → `ActiveSupport::Duration`

Mirror it — map each Neo4j field back to the matching ActiveSupport unit,
**field-to-field**, not through the scalar. The calendar structure then survives
the return trip.

```ruby
def neo_to_as(d) # d : Types::Duration
  ActiveSupport::Duration.months(d.months) +
    ActiveSupport::Duration.days(d.days) +
    ActiveSupport::Duration.seconds(d.seconds + Rational(d.nanoseconds, 1_000_000_000))
end
```

**Don't route through `.to_f` / `build`.** The tempting one-liner
`build(d.months * SECONDS_PER_MONTH + …)` collapses `months` and `days` into one
scalar and greedily re-buckets it — so `P91D` comes back as
`{months: 2, days: 30, …}` and `date + result ≠ date + 91.days`. Field-to-field
keeps `P91D → 91.days`.

## Round-trip behaviour

With the field-to-field pair, the round-trip is **faithful** — no scalar collapse,
no re-bucketing:

- **Neo4j → AS → Neo4j is exact.** Nothing leaves the four fields; every field
  maps to its AS unit and straight back.
- **AS → Neo4j → AS preserves value *and* calendar behaviour.** The only
  relabeling is AS's finer vocabulary collapsing into Neo4j's fields — years →
  months, weeks → days — which are exactly equal (`1.year` and `12.months`,
  `5.weeks` and `35.days` behave identically; Neo4j simply has no "years"/"weeks").

```
91.days     → M0 D91        → 91.days               # exact
3.months    → M3            → 3.months              # exact
5.weeks     → M0 D35        → 35.days               # weeks relabeled to days
2.5.days    → M0 D2 S43200  → 2.days + 12.hours     # frac day is exact
1.5.months  → M1 S1_314_873 → 1.month + 1_314_873.s # see caveat
```

**The one genuine loss — a fractional month.** Months and days aren't
commensurable (½ a calendar month is not a fixed number of days), so a fractional
month has no exact finer form. The *whole* month stays a month; the fraction
degrades to fixed seconds via AS's own rate (`0.5 × 2 629 746`). **Value is
exact** — only the "it was half a month" intent softens. Everything else
round-trips cleanly.
