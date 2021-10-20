# frozen_string_literal: true

module Neo4j::Driver::Internal::RevocationStrategy
  # Don't do any OCSP revocation checks, regardless whether there are stapled revocation statuses or not.
  NO_CHECKS = :no_checks

  # Verify OCSP revocation checks when the revocation status is stapled to the certificate, continue if not.
  VERIFY_IF_PRESENT = :verify_if_present

  # Require stapled revocation status and verify OCSP revocation checks,
  # fail if no revocation status is stapled to the certificate.
  STRICT = :strict

  def self.requires_revocation_checking?(revocation_strategy)
    revocation_strategy == STRICT || revocation_strategy == VERIFY_IF_PRESENT
  end
end
