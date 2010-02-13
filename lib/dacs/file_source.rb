require 'pathname'
require 'yaml'

module Dacs
  class FileSource
    def initialize(config_path, environment)
      @path        = Pathname(config_path)
      @environment = environment.to_s
    end

    def to_s
      "file #{@path.relative_path_from(Pathname.pwd).to_s}"
    end

    def each
      @path.open('r') do |f|
        environments = YAML.load(f)
        environment = environments.fetch(@environment) do
        raise ConfigurationError, 
          "File #{@path} contains no #{environment} section"
        end
        environment.each_pair do |key, value|
          yield ConfiguredValue.new(self, key.to_s, value)
        end
      end
    end
  end
end
