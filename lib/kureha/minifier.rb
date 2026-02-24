require "prism"
require_relative "visitors/minify_visitor"

module Kureha
  class ParseError < StandardError; end

  class Minifier
    def initialize
    end

    def minify(source)
      # Extract magic comments
      magic_comments = extract_magic_comments(source)

      result = Prism.parse(source)
      if result.failure?
        raise ParseError, "Failed to parse Ruby code"
      end

      visitor = Visitors::MinifyVisitor.new
      minified_code = visitor.visit(result.value)

      # Prepend magic comments if any
      if magic_comments.any?
        magic_comments.join("\n") + "\n" + minified_code
      else
        minified_code
      end
    end

    private

    def extract_magic_comments(source)
      magic_comments = []
      source.lines.each do |line|
        break unless /\A\s*#/.match?(line)
        if /\A\s*#\s*(frozen_string_literal|encoding|coding|warn_indent):/.match?(line)
          magic_comments << line.strip
        end
      end
      magic_comments
    end
  end
end
