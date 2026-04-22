require_relative 'spec/spec_helper'
include DriverHelper::Helper

driver = Neo4j::Driver::GraphDatabase.driver(uri, basic_auth_token)
driver.session do |session|
  result = session.run('PROFILE RETURN 1')
  summary = result.consume
  require 'pp'
  puts "==== PROFILE Metadata ===="
  pp summary.metadata
  puts
  
  result2 = session.run('EXPLAIN MATCH (n:ThisLabelDoesNotExist) RETURN n')
  summary2 = result2.consume
  puts "==== EXPLAIN Metadata ===="
  pp summary2.metadata
end
