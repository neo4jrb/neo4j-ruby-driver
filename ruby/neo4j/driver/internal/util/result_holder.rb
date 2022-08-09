module Neo4j::Driver
  module Internal
    module Util
      class ResultHolder
        def self.successful(result)
          new.tap { |holder| holder.succeed(result) }
        end

        def self.failed(error)
          new.tap { |holder| holder.fail(error) }
        end

        def succeed(result)
          if @completed
            false
          else
            @result = result
            true
          end
        ensure
          @completed = true
        end

        def fail(error)
          if @completed
            false
          else
            @error = error
            true
          end
        ensure
          @completed = true
        end

        def result!
          raise @error if @error
          @result
        end

        def then
          @error ? self : ResultHolder.successful(yield(@result))
        end

        # &block returns a ResultHolder
        def compose
          @error ? self : yield(@result)
        end

        def chain
          ResultHolder.successful(yield(@result, @error))
        end
      end
    end
  end
end
