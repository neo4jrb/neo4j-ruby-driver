# frozen_string_literal: true

module Neo4j
  module Driver
    module Internal
      # Driver-level cache mapping a user identity to their most recently
      # resolved home database (Optimization:HomeDatabaseCache). It lets a routed
      # session skip home-database discovery by optimistically guessing the
      # cached database — safe only when every pooled connection advertised
      # server-side routing (`ssr.enabled`), so the server transparently
      # re-routes a wrong guess. Bounded, least-recently-used eviction.
      class HomeDbCache
        DEFAULT_MAX_SIZE = 10_000

        def initialize(max_size: DEFAULT_MAX_SIZE)
          @max_size = max_size
          # Insertion order doubles as LRU recency: a Ruby Hash preserves it, so
          # #get re-inserts the touched key at the end and #set evicts from the
          # front once the cache is full.
          @entries = {}
          @mutex = Mutex.new
        end

        # The cache key for an identity: the impersonated user when set, else the
        # per-session auth token (driver-level auth is nil, so every default-auth
        # session shares one entry — the cache is bound to the identity, not the
        # rotating token). Matches the Java driver: a basic-auth principal is NOT
        # folded into the impersonated-user space
        # (Optimization:HomeDbCacheBasicPrincipalIsImpersonatedUser stays off).
        def compute_key(imp_user, auth) = imp_user || auth

        # The cached database for this key, or nil on a miss. Touches recency.
        def get(key)
          @mutex.synchronize do
            next nil unless @entries.key?(key)

            database = @entries.delete(key)
            @entries[key] = database
            database
          end
        end

        # Remember (or refresh) the resolved home database for this key. A nil
        # database is ignored — there's nothing to guess next time.
        def set(key, database)
          return if database.nil?

          @mutex.synchronize do
            @entries.delete(key)
            @entries[key] = database
            @entries.shift while @entries.size > @max_size
          end
        end
      end
    end
  end
end
