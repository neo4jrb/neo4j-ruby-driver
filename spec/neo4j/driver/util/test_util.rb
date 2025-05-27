# frozen_string_literal: true

module Neo4j
  module Driver
    module Util
      module TestUtil
        def clean_db(driver)
          driver.session do |session|
            clean_db_in_session(session)
            session.last_bookmark
          end
        end

        def count_nodes(driver, bookmark)
          driver.session(bookmarks: bookmark) do |session|
            session.execute_read { |tx| tx.run('MATCH (n) RETURN count(n)').single.first }
          end
        end

        private

        def clean_db_in_session(session)
          nil while delete_batch_of_nodes(session).positive?
        end

        def delete_batch_of_nodes(session)
          session.execute_write do |tx|
            tx.run('MATCH (n) WITH n LIMIT 10000 DETACH DELETE n RETURN count(n)').single.first
          end
        end
      end
    end
  end
end
