# frozen_string_literal: true

# Ported from neo4j-java-driver DriverCloseIT.java.
#
# Cross-impl note: MRI raises Neo4j::Driver::Exceptions::ClientException
# ('Driver is closed'); JRuby surfaces Java's IllegalStateException
# ('This driver instance has already been closed' / 'Connection source
# is closed.'). There is no common Ruby exception ancestor across both
# impls today, so these specs assert on the *message* (regex) rather
# than the class. Tightening to a class can happen once the JRuby ext
# wraps these paths into Neo4j::Driver::Exceptions::*.
RSpec.describe 'Driver#close' do
  def new_driver
    Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token)
  end

  it 'close closed driver' do
    d = new_driver
    expect { d.close; d.close; d.close }.not_to raise_error
  end

  it 'session throws for closed driver' do
    d = new_driver
    d.close
    expect { d.session }.to raise_error(/closed/i)
  end

  it 'session with mode throws for closed driver' do
    d = new_driver
    d.close
    expect { d.session(default_access_mode: Neo4j::Driver::AccessMode::WRITE) }.to raise_error(/closed/i)
  end

  it 'use session after driver is closed' do
    d = new_driver
    session = d.session
    d.close
    expect { session.run('RETURN 1').consume }.to raise_error(/closed/i)
  end
end
