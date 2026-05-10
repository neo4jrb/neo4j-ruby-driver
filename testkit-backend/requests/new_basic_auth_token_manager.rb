# frozen_string_literal: true

module TestkitBackend
  module Requests
    # Creates a "basic" (password-rotation) auth-token manager. Same gap
    # as NewAuthTokenManager — registers a placeholder so testkit can
    # close it later; no real provider callback wired through.
    #
    # DRIVER GAP: needs an AuthTokenManager interface and a
    # BasicAuthTokenManager helper. See new_auth_token_manager.rb for
    # the full list of required driver-side pieces.
    class NewBasicAuthTokenManager < Data.define
      include Request

      def execute
        placeholder = { type: :basic_auth_token_manager }
        Response::BasicAuthTokenManager.new(id: registry.store(placeholder, prefix: 'authmgr'))
      end
    end
  end
end
