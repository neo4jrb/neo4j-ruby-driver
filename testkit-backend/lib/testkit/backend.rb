require 'active_support/inflector'
require 'async/io'
require 'testkit/backend/loader'
require 'neo4j_ruby_driver'

module Testkit
  module Backend
    module Messages
      module Requests
      end
      module Responses
      end
    end
  end
end

Testkit::Backend::Loader.load
