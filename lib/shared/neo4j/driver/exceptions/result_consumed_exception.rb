# frozen_string_literal: true

module Neo4j
  module Driver
    module Exceptions
      # A user is trying to access resources that are no longer valid due to
      # the resources have already been consumed or
      # the {@link QueryRunner} where the resources are created has already been closed.
      class ResultConsumedException < ClientException
      end
    end
  end
end
