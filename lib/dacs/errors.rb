module Dacs
  ConfigurationError = Class.new(Exception)
  class UndefinedKeyError < ConfigurationError
    def initialize(key)
      super("Unknown configuration key '#{key}'")
    end
  end
end
