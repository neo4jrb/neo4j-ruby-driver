# frozen_string_literal: true

require_relative 'build/gemspec_common'

Gem::Specification.new do |spec|
  spec.platform = 'java'
  common_gemspec(spec, 'jruby')
  spec.add_dependency 'jar-dependencies', '>= 0.5.5'

  if ENV['STAGED_BUILD'] == '1'
    # Published gem: the jars are vendored into lib/ and pinned by Jars.lock.
    # Declaring NO `requirements` here is deliberate — jar-dependencies' post
    # install hook only runs Maven when `jars?` is true, i.e. requirements are
    # present AND jar-dependencies is a runtime dep (see Jars::Installer#jars?).
    # With no requirements the hook is a no-op, so `gem install` does ZERO Maven
    # / network — the vendored jars load via neo4j-ruby-driver_jars.rb.
    #
    # Ship Jars.lock (JRuby-only) so the published gem pins exact jar versions.
    # (common_gemspec set spec.files for the shared lib/ tree; this appends the
    # jruby-specific lockfile without leaking it into the shared gemspec.)
    spec.files += Dir['Jars.lock']
  else
    # Dev tree: resolve + vendor the jars from Maven (writes Jars.lock and the
    # vendored tree that the staged build then packages).
    spec.add_development_dependency 'ruby-maven', '>= 0'
    spec.requirements << 'jar org.neo4j.driver, neo4j-java-driver-all, 6.2.1'
    spec.requirements << 'jar org.neo4j.driver, neo4j-java-driver-observation-metrics, 6.2.1'
  end
  spec.metadata['rubygems_mfa_required'] = 'true'
end
