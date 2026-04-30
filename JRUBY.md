# JRuby flavor — design notes

Forward-looking design doc, not yet implemented. Captures decisions
reached during planning so the eventual implementation doesn't have
to re-derive them.

The current driver is pure-Ruby / MRI-only. We want a second flavor
that runs on JRuby and delegates to `org.neo4j.driver` (the official
Java driver) for performance and protocol coverage, while exposing
the same Ruby API.

## Repository layout

Single repo, two platform-specific gem builds. Same gem name; the
runtime decides which to install based on `RUBY_PLATFORM`. This is
the nokogiri pattern.

```
neo4j-ruby-driver/
├── lib/                       # truly shared code (version.rb, entry point)
│   └── neo4j/
│       ├── driver.rb          # entry: picks impl, sets up Zeitwerk
│       └── driver/
│           └── version.rb
├── pure/                      # complete MRI source root
│   └── neo4j/driver/
│       ├── bolt/
│       ├── packstream/
│       ├── session.rb
│       ├── transaction.rb
│       ├── result.rb
│       ├── types/
│       └── exceptions/
├── java/                      # complete JRuby source root
│   └── neo4j/driver/
│       ├── session.rb         # wrapper around org.neo4j.driver.Session
│       ├── transaction.rb
│       ├── result.rb
│       ├── types/             # prepended modules for Java value types
│       └── exceptions/        # modules prepended onto Java exceptions
├── testkit-backend/           # one tree, uses public API only
└── spec/
    ├── shared/                # protocol-level shared examples
    ├── pure/                  # MRI-only specs
    └── java/                  # JRuby-only specs
```

### Why top-level `pure/` and `java/` (not under `lib/`)

Zeitwerk handles them either way (it doesn't care about `lib/` —
only about what you `push_dir`). Top-level keeps the impl roots
visible in `ls` and makes the gem packaging split explicit:

```ruby
# MRI gemspec
spec.files         = Dir['lib/**/*'] + Dir['pure/**/*']
spec.require_paths = %w[lib pure]

# JRuby gemspec
spec.platform      = 'java'
spec.files         = Dir['lib/**/*'] + Dir['java/**/*']
spec.require_paths = %w[lib java]
```

### No `Pure::` / `Java::` namespaces

Files under `pure/neo4j/driver/session.rb` and
`java/neo4j/driver/session.rb` both define `Neo4j::Driver::Session`.
They never load simultaneously, so there's no clash. The directory
is just a load-path organizational device — not a namespace.

This avoids `Neo4j::Driver::Pure::Session` everywhere and keeps the
public API surface identical between the two flavors.

## Loader setup

`lib/neo4j/driver.rb`:

```ruby
require 'zeitwerk'

impl = (RUBY_PLATFORM == 'java') ? 'java' : 'pure'

loader = Zeitwerk::Loader.new
loader.push_dir(File.expand_path('../../lib', __dir__),  namespace: Neo4j)  # if needed
loader.push_dir(File.expand_path("../../#{impl}", __dir__))
loader.setup

module Neo4j
  module Driver
    def self.implementation = (RUBY_PLATFORM == 'java') ? :java : :pure
  end
end
```

Both `pure/` and `java/` follow the standard Zeitwerk
directory-as-namespace mapping rooted at the pushed dir.
`Neo4j::Driver.implementation` is a small introspection helper
for users who want to branch on it.

## Type strategy

Two patterns, picked per type based on whether identity matters.

### Value types: prepend modules onto Java classes

Node, Relationship, Path, all temporal types (`ZonedDateTime`,
`OffsetTime`, `LocalDate`, …), `Point`, `Duration`. These are
already what the Java driver returns from records — wrapping them
would mean copying every value out of every record. Instead:

```ruby
# java/neo4j/driver/types/node.rb
module Neo4j::Driver::Types
  module Node
    def labels
      # :labels is a Java method on org.neo4j.driver.types.Node;
      # this Ruby method wraps it with Ruby-friendly return shape.
      super.map(&:to_sym)
    end

    def [](key)
      get(key.to_s).as_object
    end

    def to_h
      as_map.to_hash
    end
  end
end

org.neo4j.driver.internal.InternalNode.prepend(Neo4j::Driver::Types::Node)
```

The prepended module sits ahead of the Java class in the
method-resolution chain. No copy, no wrap, no allocation per
record. Exposes a Ruby-friendly facade on the same object.

We don't try to make `Neo4j::Driver::Types::Node` a class with
identical structure across pure and java — only a *protocol*: a
shared set of method names with the same contracts. The pure
flavor has its own concrete `Node` class.

### Behavioral types: Ruby wrappers holding a Java field

`Driver`, `Session`, `Transaction`, `Result`, `RxSession`. These
have lifecycle (open/close), state (transaction in flight),
config negotiation, and bookmark management. Ruby wrapping
gives us the right place to put kwargs handling, block forms,
and the ergonomic surface — we just delegate the operations to
the held Java instance.

```ruby
# java/neo4j/driver/session.rb
module Neo4j::Driver
  class Session
    def initialize(java_session)
      @java = java_session
    end

    def run(query, parameters = {}, config = {})
      Result.new(@java.run(query, parameters))
    end

    def begin_transaction(timeout: nil, metadata: nil, &block)
      tx_config = build_tx_config(timeout, metadata)
      java_tx = @java.begin_transaction(tx_config)
      tx = Transaction.new(java_tx)
      return tx unless block
      # default-rollback semantics, same as pure flavor
      ...
    end
  end
end
```

## Exceptions: hybrid design

Empirically (verified in jruby-10.0.3.0):

```ruby
begin
  raise Java::JavaLang::Exception
rescue
  puts '1st rescue'   # ← this fires
rescue Java::JavaLang::Exception
  puts '2nd rescue'
end
# => 1st rescue
```

JRuby wires Java throwables into Ruby's rescue chain — bare
`rescue`, `rescue StandardError`, and `rescue Exception` all
catch Java exceptions. So the original concern that prepend
would leave a "rescue StandardError silently misses" footgun is
**not real**.

`rescue` matches via `Module#===` → `is_a?`, which walks the
ancestors chain. `prepend` extends that chain, so a prepended
Ruby module is a valid catch handle. `rescue PrependedModule`
catches a Java exception whose class has had `PrependedModule`
prepended.

This drives the exception design:

```ruby
# Shared definition (could live in lib/ if both flavors need it,
# or be duplicated under pure/ and java/ — TBD)
module Neo4j::Driver::Exceptions
  module Neo4jException; end
  module ClientException;    include Neo4jException; end
  module TransientException; include Neo4jException; end
  module DatabaseException;  include Neo4jException; end
  # ...
end

# Pure flavor: real raisable classes that include the modules
module Neo4j::Driver::Exceptions
  Neo4jError      = Class.new(StandardError) { include Neo4jException }
  ClientError     = Class.new(Neo4jError)    { include ClientException }
  TransientError  = Class.new(Neo4jError)    { include TransientException }
  DatabaseError   = Class.new(Neo4jError)    { include DatabaseException }
end

# Java flavor: prepend modules onto Java exception classes
org.neo4j.driver.exceptions.ClientException
  .prepend(Neo4j::Driver::Exceptions::ClientException)
org.neo4j.driver.exceptions.TransientException
  .prepend(Neo4j::Driver::Exceptions::TransientException)
org.neo4j.driver.exceptions.DatabaseException
  .prepend(Neo4j::Driver::Exceptions::DatabaseException)
```

User code rescues by **module name**, which works on both flavors:

```ruby
begin
  session.run(query)
rescue Neo4j::Driver::Exceptions::ClientException => e
  # caught on both MRI and JRuby
end
```

### Trade-offs

- **Pro**: no exception copy/wrap layer; the original Java
  exception with its full Java stack is what bubbles up.
- **Pro**: bare `rescue` / `rescue StandardError` still works
  (JRuby integrates Java exceptions into the Ruby rescue chain),
  *and* the specific module name works too — users get both
  conveniences.
- **Con**: pure and java diverge on whether exceptions are
  classes or modules-with-classes — the shared *catch handle* is
  the module name, but the actual `raise` sites differ.
- **Con**: requires metaprogramming on third-party Java classes
  (`org.neo4j.driver.exceptions.*.prepend(...)`), which is
  unusual to read and tied to the Java driver's class names not
  changing.

### Cause preservation

On the JRuby side, expose the underlying Java exception as
`#cause` (Ruby's standard exception-chaining accessor) so power
users can dig into the Java stack if needed. The Java driver's
exceptions already carry rich context.

### Alternative: convert + cause-chain

The opposite trade-off: instead of prepending modules onto Java
exception classes, catch every Java exception at the boundary
and re-raise a real Ruby class, with the original Java exception
attached as the cause.

```ruby
# Pure flavor: real raisable classes (same as before, no modules needed)
module Neo4j::Driver::Exceptions
  class Neo4jError      < StandardError; end
  class ClientError     < Neo4jError; end
  class TransientError  < Neo4jError; end
  class DatabaseError   < Neo4jError; end
end

# Java flavor: wrap at every boundary call
JAVA_TO_RUBY = {
  org.neo4j.driver.exceptions.ClientException    => Neo4j::Driver::Exceptions::ClientError,
  org.neo4j.driver.exceptions.TransientException => Neo4j::Driver::Exceptions::TransientError,
  org.neo4j.driver.exceptions.DatabaseException  => Neo4j::Driver::Exceptions::DatabaseError,
  # ...
}.freeze

def call_java
  yield
rescue java.lang.Throwable => e
  ruby_class = JAVA_TO_RUBY.fetch(e.class) { Neo4j::Driver::Exceptions::Neo4jError }
  raise ruby_class, e.message, cause: e
end
```

Every wrapper method (`Session#run`, `Transaction#commit`, …) goes
through `call_java { … }`. User code rescues real Ruby classes
that inherit from `StandardError`, so `rescue StandardError` and
bare `rescue` work as expected. The original Java exception is
still reachable via `#cause` for the rare case it's needed.

**Pro**:
- Standard Ruby exception semantics — bare `rescue`, `rescue
  StandardError`, and rescue clauses across the codebase Just
  Work. No JRuby gotcha to document.
- Pure and java raise the *same* Ruby classes — the type system
  is genuinely identical, not just the catch handle.
- No metaprogramming on Java classes (no `prepend` on
  `org.neo4j.driver.exceptions.*`), which is friendlier to
  static analysis and to anyone reading the code.

**Con**:
- Allocation per raised exception (one Ruby object wrapping the
  Java one). Negligible in practice since exceptions are by
  definition not in the hot path.
- Boundary discipline: every call into the Java driver must go
  through the wrapper. Easy to forget when adding a new
  delegation method, and the omission is silent until a Java
  exception escapes.
- Stack trace presented to the user is the Ruby one; the Java
  stack is one `.cause` hop away. Slightly less direct.

### Which to pick

With the rescue-chain footgun debunked, the prepend approach is
genuinely attractive: zero allocation, original Java stack
intact, *and* normal Ruby rescue semantics work. The remaining
costs are the metaprogramming on Java classes and a small
divergence in `raise` sites between pure and java.

Leaning toward **prepend** now. Decide for real when
implementing — and at that point, verify the prepend-as-catch-
handle behavior on the actual JRuby + Java-driver combination,
not just on `Java::JavaLang::Exception`.

### Reverse direction: Ruby exceptions raised inside Java callbacks

The discussion above is about Java-throws → Ruby-rescues. The
opposite direction matters too: managed transactions
(`session.execute_read/write { |tx| ... }`) hand a Ruby block to
the Java driver as a `TransactionCallback` (functional
interface). The Java driver's retry logic sits *outside* the
block — when the block raises, Java needs to classify the
exception as transient (retry) vs non-retryable (propagate).

If a Ruby exception escapes the block, JRuby wraps it as
`org.jruby.exceptions.RaiseException` (a Java `RuntimeException`
subclass). The Java driver doesn't recognize it as a Neo4j
exception type, so retry won't fire even when it should.

The exception that crosses the Ruby→Java boundary must be a
**Java exception of the right Neo4j type** for the driver to
classify it correctly.

Implications by approach:

- **Prepend approach**: raise actual Java exceptions from
  inside the block — `raise org.neo4j.driver.exceptions.TransientException, "..."`
  (or re-raise an instance the driver itself produced). The
  prepended Ruby module is just a catch handle; it isn't
  raisable on its own. We may want a thin Ruby helper
  (`Neo4j::Driver.raise_transient(msg)` etc.) to keep call
  sites tidy.

- **Convert approach**: needs an inverse mapping at the
  Ruby-block → Java boundary, mirroring `JAVA_TO_RUBY`:

  ```ruby
  RUBY_TO_JAVA = JAVA_TO_RUBY.invert.freeze

  def wrap_callback
    proc do |java_tx|
      begin
        yield Transaction.new(java_tx)
      rescue Neo4j::Driver::Exceptions::Neo4jError => e
        java_class = RUBY_TO_JAVA.fetch(e.class) { org.neo4j.driver.exceptions.ClientException }
        raise java_class.new(e.message, e.cause)
      end
    end
  end
  ```

  The wrapper sits at every Java method that takes a Ruby block
  (`execute_read`, `execute_write`, anything async/Rx, custom
  bookmark/auth managers).

Either way: the testkit `ClientGeneratedError` flow we already
have on the pure side needs an analog here — when test code or
user code raises a non-driver exception inside a managed-tx
block, the Java retry layer must see something it knows to
*not* retry. Mapping it to a Java `ClientException` (or a
custom non-retryable subclass) is the simplest path.

## testkit-backend

Stays as a single tree under `testkit-backend/`. It only uses the
public driver API, which is identical on both flavors, so there's
nothing to fork. CI runs it on both runtimes.

## Spec organization

- `spec/shared/` — RSpec shared examples that exercise the public
  contract (e.g. "any session implementation should commit
  cleanly", "any Node should expose labels as symbols"). Both
  flavors include these.
- `spec/pure/` — MRI-only tests (PackStream/Bolt internals,
  connection pool behavior).
- `spec/java/` — JRuby-only tests (Java driver delegation,
  prepended-module behavior).
- Existing `spec/integration/` and `spec/neo4j/driver/` move
  under `spec/pure/` (they're testing the pure impl today) and
  the protocol-agnostic ones get lifted into `spec/shared/`.

## CI matrix

```
{mri-3.4, jruby-9.4} × {neo4j-4.4.48-enterprise,
                        neo4j-5.26.21-enterprise,
                        neo4j-2026.01.4-enterprise}
```

testkit gate runs once per runtime (single Neo4j version) — same
baseline mechanism as today, possibly with a separate baseline
file per runtime if coverage diverges.

## Open questions / deferred

- Whether `Neo4j::Driver::Exceptions` module definitions live in
  `lib/` (truly shared) or get duplicated across `pure/` and
  `java/`. Argues for `lib/` — they're identical and
  runtime-independent.
- Whether `Result` should be a wrapper or a prepended module on
  JRuby. Leaning wrapper, because it has lifecycle state we
  manage (consumed/discarded flags, summary materialization).
- Async/reactive surface — the Java driver has `RxSession` /
  `AsyncSession`. Defer until the sync API is solid on both.
- Migration: when we rename this gem to replace the existing
  public `neo4j-ruby-driver`, the JRuby flavor goes out as
  `neo4j-ruby-driver-X.Y.Z-java` alongside the MRI build under
  the same version.
