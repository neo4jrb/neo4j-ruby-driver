module Neo4j::Driver
  module Internal
    EagerResultValue = Struct.new(:keys, :records, :summary)
  end
end
