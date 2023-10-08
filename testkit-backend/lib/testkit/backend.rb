require "active_support/core_ext/module/attribute_accessors"
require 'active_support/inflector'
require 'async/io'
require 'bigdecimal'
require 'neo4j/driver'
require 'nio'
require 'testkit/backend/loader'

Testkit::Backend::Loader.load
