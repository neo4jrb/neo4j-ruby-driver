# frozen_string_literal: true

module Neo4j
  module Driver
  end
end

require 'active_support/concern'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/isolated_execution_state' if Gem::Requirement.create('>= 7').satisfied_by?(Gem.loaded_specs["activesupport"].version) # TODO: this should not be necessary https://github.com/rails/rails/issues/43851
require 'active_support/core_ext/numeric/time'
require 'active_support/duration'
require 'active_support/time'
require 'date'
require 'loader'
require 'uri'
