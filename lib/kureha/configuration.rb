module Kureha
  class Configuration
    attr_accessor :space_after_operators
    attr_accessor :add_semicolons
    attr_accessor :remove_comments
    attr_accessor :remove_empty_lines

    def initialize
      @space_after_operators = true
      @add_semicolons = true
      @remove_comments = true
      @remove_empty_lines = true
    end
  end
end
