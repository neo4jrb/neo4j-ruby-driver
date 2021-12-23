# frozen_string_literal: true

module Neo4j::Driver::Internal::Summary
  # Creating a position from and offset, line number and a column number.
  #
  # @param offset the offset from the start of the string, starting from 0.
  # @param line the line number, starting from 1.
  # @param column the column number, starting from 1.
  class InternalInputPosition < Struct.new(:offset, :line, :column)
    def to_s
      "offset=#{offset}, line=#{line}, column=#{column}"
    end
  end
end
