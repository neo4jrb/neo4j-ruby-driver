# frozen_string_literal: true

module DriverInternalDataAccessor
  def self.channel_pool_from_session(session)
    session.instance_variable_get(:@session).instance_variable_get(:@connection).connection.instance_variable_get :@channel_pool
  end

  def self.channel_pool_from_driver(driver, uri)
    hash = driver.session_factory.connection_provider.instance_variable_get(:@connection_pool).instance_variable_get(:@address_to_pool)
    hash.find { |address, channel_pool| address.uri == uri }.last
  end
end
