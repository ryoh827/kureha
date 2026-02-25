module Kureha
  class Error < StandardError; end

  class ParseError < Error; end

  class ConfigurationError < Error; end
end
