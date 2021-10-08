module Neo4j::Driver::Internal::Scheme
  BOLT_URI_SCHEME = 'bolt'
  BOLT_HIGH_TRUST_URI_SCHEME = 'bolt+s'
  BOLT_LOW_TRUST_URI_SCHEME = 'bolt+ssc'
  NEO4J_URI_SCHEME = 'neo4j'
  NEO4J_HIGH_TRUST_URI_SCHEME = 'neo4j+s'
  NEO4J_LOW_TRUST_URI_SCHEME = 'neo4j+ssc'

  def validate_scheme!(scheme)
    unless [BOLT_URI_SCHEME, BOLT_LOW_TRUST_URI_SCHEME, BOLT_HIGH_TRUST_URI_SCHEME, NEO4J_URI_SCHEME,
            NEO4J_LOW_TRUST_URI_SCHEME, NEO4J_HIGH_TRUST_URI_SCHEME].include?(scheme)
      raise ArgumentError, scheme ? "Invalid address format #{scheme}" : 'Scheme must not be null'
    end
  end

  def high_trust_scheme?(scheme)
    [BOLT_HIGH_TRUST_URI_SCHEME, NEO4J_HIGH_TRUST_URI_SCHEME].include?(scheme)
  end

  def low_trust_scheme?(scheme)
    [BOLT_LOW_TRUST_URI_SCHEME, NEO4J_LOW_TRUST_URI_SCHEME].include?(scheme)
  end

  def security_scheme?(scheme)
    [BOLT_LOW_TRUST_URI_SCHEME, NEO4J_LOW_TRUST_URI_SCHEME, BOLT_HIGH_TRUST_URI_SCHEME, NEO4J_HIGH_TRUST_URI_SCHEME]
      .include?(scheme)
  end

  def routing_scheme?(scheme)
    [NEO4J_LOW_TRUST_URI_SCHEME, NEO4J_HIGH_TRUST_URI_SCHEME, NEO4J_URI_SCHEME].include?(scheme)
  end
end
