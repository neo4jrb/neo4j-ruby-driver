module Neo4j::Driver::Internal
  module Security
    class SecurityPlanImpl < Struct.new(:requires_encryption, :ssl_context, :requires_hostname_verification,
                                        :revocation_strategy)
      class << self
        def insecure
          new(false, nil, false, RevocationStrategy::NO_CHECKS)
        end
      end
    end
  end
end