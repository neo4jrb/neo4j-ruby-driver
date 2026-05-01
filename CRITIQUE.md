Structure is not a type exposed by the API. It should not be one of the options in pack case statement. That should be handled at a different level.

Why are we creating Structures with signatures for which we don't have handlers. Should rather raise exception.

Constants like TINY_STRING are duplicated

What's wrong bubling up the close time exceptions here:        if block_given?
begin
yield session
ensure
# Block form hands lifecycle to the driver, so close-time
# failures from abandoned results are treated as cancellations.
# Callers who want to observe such errors should manage the
# session explicitly and call #close themselves.
begin
session.close
rescue Exceptions::Neo4jException
end
end
else
session
end
