module Dacs
  class PermissiveSchema
    def initialize(defaults={})
      @defaults = defaults.inject({}) { |h, (k,v)|
        h[k.to_s] = v
        h
      }
    end

    def keys
      @defaults.keys
    end

    def optional?(key)
      true
    end

    def required?(key)
      false
    end

    def defined?(key)
      true
    end

    def default_value(key)
      @defaults[key.to_s]
    end

    def defaults
      @defaults
    end
  end
end
