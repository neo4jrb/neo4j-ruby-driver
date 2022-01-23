module Neo4j
  module Driver
    # Configuration object containing settings for transactions.
    # Instances are immutable and can be reused for multiple transactions.
    # <p>
    # Configuration is supported for:
    # <ul>
    # <li>queries executed in auto-commit transactions - using various overloads of {@link Session#run(String, TransactionConfig)} and
    # {@link AsyncSession#runAsync(String, TransactionConfig)}</li>
    # <li>transactions started by transaction functions - using {@link Session#readTransaction(TransactionWork, TransactionConfig)},
    # {@link Session#writeTransaction(TransactionWork, TransactionConfig)}, {@link AsyncSession#readTransactionAsync(AsyncTransactionWork, TransactionConfig)} and
    # {@link AsyncSession#writeTransactionAsync(AsyncTransactionWork, TransactionConfig)}</li>
    # <li>unmanaged transactions - using {@link Session#beginTransaction(TransactionConfig)} and {@link AsyncSession#beginTransactionAsync(TransactionConfig)}</li>
    # </ul>
    # <p>
    # Creation of configuration objects can be done using the builder API:
    # <pre>
    # {@code
    # Map<String, Object> metadata = new HashMap<>();
    # metadata.put("type", "update user");
    # metadata.put("application", "my application");
    #  TransactionConfig config = TransactionConfig.builder()
    #                  .withTimeout(Duration.ofSeconds(4))
    #                  .withMetadata(metadata)
    #                  .build();
    #  }
    #  </pre>
    # @see Session
    class TransactionConfig < Hash
      def initialize(**config)
        @timeout = config.timeout
        @metadata = config.metadata
      end

      # Check if this configuration object contains any values.

      # @return {@code true} when no values are configured, {@code false otherwise}.
      def empty?
        timeout.nil? && (metadata.nil? || metadata.empty?)
      end
    end
  end
end
