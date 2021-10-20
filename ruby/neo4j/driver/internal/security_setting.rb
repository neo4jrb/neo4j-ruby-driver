# frozen_string_literal: true

module Neo4j::Driver::Internal::SecuritySetting
  include Scheme

  attr_reader :encrypted, :trust_strategy
  DEFAULT_ENCRYPTED = false

  def initialize(encrypted, trust_strategy)
    @encrypted = encrypted || DEFAULT_ENCRYPTED
    @trust_strategy = trust_strategy || Neo4j::Driver::Config::TrustStrategy.trust_all_certificates
  end

  def create_security_plan(uri_scheme)
    validate_scheme!(uri_scheme)
    begin
      if security_scheme?(uri_scheme)
        assert_security_settings_not_user_configured(uri_scheme)
        return create_security_plan_from_scheme(uri_scheme)
      else
        return create_security_plan_impl(encrypted, trust_strategy)
      end
    rescue java.security.GeneralSecurityException.GeneralSecurityException, java.io.IOException
      raise Neo4j::Driver::Exceptions::ClientException.new('Unable to establish SSL parameters')
    end
  end

  def create_security_plan_from_scheme(uri_scheme)
    if high_trust_scheme?(uri_scheme)
      org.neo4j.driver.internal.security.SecurityPlanImpl.forSystemCASignedCertificates(
        true, RevocationStrategy.NO_CHECKS
      )
    else
      org.neo4j.driver.internal.security.SecurityPlanImpl.forAllCertificates(false, RevocationStrategy.NO_CHECKS)
    end
  end

  private

  def assert_security_settings_not_user_configured(uri_scheme)
    if customized?
      raise Neo4j::Driver::Exceptions::ClientException.new(
        "Scheme #{uri_scheme} is not configurable with manual encryption and trust settings"
      )
    end
  end

  def customized?
    encrypted != DEFAULT_ENCRYPTED || trust_strategy != DEFAULT_TRUST_STRATEGY
  end

  def create_security_plan_impl(encrypted, trust_strategy)
    return org.neo4j.driver.internal.security.SecurityPlanImpl.insecure() unless encrypted

    hostname_verification_enabled = trust_strategy.hostname_verification_enabled?
    revocation_strategy = trust_strategy.revocation_strategy

    case trust_strategy.strategy
    when Config::TrustStrategy::TRUST_CUSTOM_CA_SIGNED_CERTIFICATES
      return org.neo4j.driver.internal.security.SecurityPlanImpl.forCustomCASignedCertificates(
        trust_strategy.cert_file_to_java, hostname_verification_enabled, revocation_strategy
      )
    when Config::TrustStrategy::TRUST_SYSTEM_CA_SIGNED_CERTIFICATES
      return org.neo4j.driver.internal.security.SecurityPlanImpl.forSystemCASignedCertificates(
        hostname_verification_enabled, revocation_strategy
      )
    when Config::TrustStrategy::TRUST_ALL_CERTIFICATES
      return org.neo4j.driver.internal.security.SecurityPlanImpl.forAllCertificates(
        hostname_verification_enabled, revocation_strategy
      )
    else
      raise ClientException.new("Unknown TLS authentication strategy: #{trust_strategy.strategy}")
    end
  end
end
