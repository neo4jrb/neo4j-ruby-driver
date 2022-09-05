module Neo4j::Driver
  module Internal
    module Util
      class ResultHolder
        attr :error

        def self.successful(result = nil)
          new.tap { |holder| holder.succeed(result) }
        end

        def self.failed(error)
          new.tap { |holder| holder.fail(error) }
        end

        def succeed(result = nil)
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
        rescue => error
          ResultHolder.failed(error)
        end

        def side
          yield(@result, @error)
          self
        end

        def copy_to(result_holder)
          if @error
            result_holder.fail(@error)
          else
            result_holder.succeed(@result)
          end
        end
      end
    end
  end
end
