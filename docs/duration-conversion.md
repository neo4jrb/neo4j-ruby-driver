# Duration Conversion

The driver represents Neo4j durations as `Neo4j::Driver::Types::Duration`, **not**
`ActiveSupport::Duration`, and there is deliberately **no built-in conversion**
between them. This note explains why and gives the two helpers to write yourself
when you must bridge. The decision itself is logged in
[`DECISIONS.md`](../DECISIONS.md) (2026-08-13).

> The helpers below are **illustrative only** — they are not part of the library,
> and both directions are lossy by design.

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
isn't always 86 400 s (DST). `ActiveSupport::Duration` is seconds-based with fuzzy
calendar parts and can't hold that distinction, so it can't faithfully round-trip
a Neo4j value. In this driver, `ActiveSupport::Duration` is accepted *only* as a
duck-typed (`to_f`) **timeout** argument — never as a stored value.

## `ActiveSupport::Duration` → `Types::Duration`

Decompose the ActiveSupport parts into the four Bolt fields. Years fold into
months (×12), weeks into days (×7); the fractional second becomes nanoseconds.

```ruby
def as_to_neo(dur) # dur : ActiveSupport::Duration
  p = dur.parts
  months = (p[:years]  || 0) * 12 + (p[:months] || 0)
  days   = (p[:weeks]  || 0) * 7  + (p[:days]   || 0)
  secs   = (p[:hours]  || 0) * 3600 +
           (p[:minutes]|| 0) * 60   + (p[:seconds]|| 0)
  whole  = secs.to_i
  nanos  = ((secs - whole) * 1_000_000_000).round
  Neo4j::Driver::Types::Duration.new(months, days, whole, nanos)
end
```

**Lossy — parts, not seconds.** This trusts `#parts`, so `3.weeks` stays 21 days
(not folded into a month). A value built purely from seconds (`90.days`) may have
already normalized its parts before you see it — check what your source carries.

## `Types::Duration` → `ActiveSupport::Duration`

There is no lossless target, so collapse to a scalar of seconds using
ActiveSupport's *average* lengths.

```ruby
def neo_to_as(d) # d : Types::Duration — collapses months/days!
  ActiveSupport::Duration.build(
    d.months  * ActiveSupport::Duration::SECONDS_PER_MONTH +
    d.days    * ActiveSupport::Duration::SECONDS_PER_DAY   +
    d.seconds + Rational(d.nanoseconds, 1_000_000_000))
end
```

**Lossy — the dangerous direction.** It commits `months` and `days` to fixed
average lengths (1 month = 2 629 746 s ≈ 30.44 days; 1 day = 86 400 s),
discarding the calendar semantics Neo4j deliberately preserves. Don't use it where
the month/day distinction matters — work from `d.months` / `d.days` / `d.seconds`
directly instead.

## Round-trip behaviour

Chaining the two (`neo → as → neo → …`) reaches a **fixed point after a single
round-trip**. The round-trip is really "re-normalize onto the fixed average
rates," and the total-seconds scalar `T` is invariant:

```
T = months·2 629 746 + days·86 400 + seconds + nanos/1e9
neo → as → neo  ≡  decompose(T) into canonical (months, days < 31, seconds < 86 400, nanos)
```

The first pass may **change** the value (any day-count ≥ ~30.44 spills into
months; months freeze at average length). But the result is already canonical, so
decomposing the same `T` again returns it unchanged — a fixed point, reached
immediately.

```
Types::Duration(0, 45, 0, 0)
  T = 45 × 86 400 = 3 888 000 s
  months = ⌊3 888 000 / 2 629 746⌋ = 1   (rem 1 258 254)
  days   = ⌊1 258 254 / 86 400⌋   = 14  (rem 48 654)
⇒ Types::Duration(1, 14, 48654, 0)   # "1 month, 14 days, 13:30:54"
  run again → same T → same tuple    # fixed point
```

**Precision.** Exact at nanosecond granularity: `ActiveSupport::Duration.build`
does `value.round(9)`, snapping back to `Types::Duration`'s nanosecond grid — so
even routed through a Float it doesn't drift. It just doesn't return to the
original.
