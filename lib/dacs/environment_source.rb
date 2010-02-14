module Dacs
  class EnvironmentSource
    def initialize(prefix, environment=ENV)
      @prefix      = prefix
      @environment = environment
    end
    
    def to_s
      "environment"
    end

    def each
      @environment.each_pair do |key, value|
        if match = /^#{@prefix.downcase}(.*)$/.match(key.downcase)
          yield ConfiguredValue.new(self, match[1], value)
        end
      end
    end
  end
end
