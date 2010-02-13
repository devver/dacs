module Dacs
  class DefaultSource
    def initialize(defaults)
      @defaults = defaults
    end

    def to_s
      "defaults"
    end

    def each
      @defaults.each do |key, value|
        yield ConfiguredValue.new(self, key.to_s, value)
      end
    end
  end
end
