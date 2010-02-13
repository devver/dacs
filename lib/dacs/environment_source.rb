module Dacs
  class EnvironmentSource
    def initialize(app_name, environment=ENV)
      @app_name    = app_name.to_s.downcase
      @environment = environment
    end
    
    def to_s
      "environment"
    end

    def each
      @environment.each_pair do |key, value|
        if match = /^#{@app_name}_(.*)$/.match(key.downcase)
          yield ConfiguredValue.new(self, match[1], value)
        end
      end
    end
  end
end
