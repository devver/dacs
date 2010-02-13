module Dacs
  class Schema

    # Add a key definition
    def key(name, options={})
      key_defs << { :name => name.to_s }.merge(options)
    end

    def keys
      key_defs.map{|d| d[:name]}
    end

    def required?(key)
      assert_key_defined!(key)
      kd = key_def(key.to_s)
      kd && !kd.key?(:default)
    end

    def optional?(key)
      !required?(key.to_s)
    end

    def defined?(key)
      !!key_def(key)
    end

    def default_value(key)
      assert_key_defined!(key)
      key_def(key.to_s)[:default]
    end

    def defaults
      key_defs.inject({}) { |h, key_def|
        h[key_def[:name]] = key_def[:default]
        h
      }
    end

    private

    def assert_key_defined!(key)
      !!key_def(key) or raise ConfigurationError, "No configuration key '#{key}' is defined"
    end

    def key_defs
      @key_defs ||= []
    end

    def key_def(key)
      key_defs.detect{|kd| kd[:name] == key.to_s}
    end
  end
end
