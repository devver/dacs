require 'forwardable'
require 'singleton'
require 'logger'
require 'pathname'
require 'yaml'
require 'ruport'

module Dacs
  # This configuration system is for deployment-specific values, such as AWS keys
  # and API URLs.
  #
  # Configuration values can be accessed anywhere in the app using the AppConfig
  # class, which behaves like a Hash.
  #
  # Note that all keys are strings - not symbols.
  #
  # Configuration keys can be set at three levels: hardcoded defaults, in
  # config/<APPNAME>.yml, or in the environment.
  #
  # 1. Defaults are set below, in the initializer.
  #
  # 2. Defaults will be overridden by config/<APPNAME>.yml. This file is broken into
  #    per-environment sections just like database.yml, so to configure for the
  #    development environment, you'd use something like the following in
  #    config/<APPNAME>.yml:
  #
  #    development:
  #      api_base_uri: http://localhost:4567
  #      authenticate: false
  #      aws_access_key: 'XXX...'
  #      aws_secret_key: 'XXX...'
  #      simpledb_domain: 'my_sandbox_domain'
  #
  # 3. Values in <APPNAME>.yml will be overidden by <APPNAME>_* environment
  #    variables.  For instance, to set key 'foo' = 'bar', set APPNAME_FOO='bar'
  #    in the process environment.
  class AppConfig < Hash

    class << self
      extend Forwardable

      # Delegate a subset of Hash methods to the singleton instance
      def_delegators :instance, :[], :fetch, :key?, :merge, :merge!, :app_name,
                                :source, :dump

      def_delegators :schema, :required?, :optional?, :keys, :default_value
    end

    # Usage:
    #
    #     Dacs::AppConfig.init!('example', 
    #       :environment => 'development',
    #       :logger      => Logger.new($stdout)) do |config|
    #    
    #       config.key 'foo', :default => 'default_foo'
    #       config.key 'bar', :default => 'default_bar'
    #       config.key 'baz', :default => 'default_baz'
    #     end
    def self.init!(app_name, options={})
      @instance = nil
      @@options = options.merge(:app_name => app_name)
      @@options[:app_root]     ||= Pathname(Dir.pwd)
      @@options[:config_path]  ||= @@options[:app_root] + 'config' + "#{app_name}.yml"
      @@options[:logger]       ||= ::Logger.new($stderr)
      @@options[:environment]  ||= :development
      @@options[:defaults]     ||= {}
      if block_given?
        schema = Schema.new
        yield(schema)
        @@schema = schema
      else
        @@schema = PermissiveSchema.new(@@options[:defaults])
      end
      self.instance
    end

    def self.instance
      @instance ||= new
    end

    def self.schema
      @@schema
    end

    def self.environment
      @@options[:environment]
    end
    
    attr_reader :app_name
    attr_reader :logger
    attr_reader :config_path
    attr_reader :environment

    def initialize
      raise "You must initialize with Dacs::AppConfig.init!()" unless @@options
      @app_name     = @@options[:app_name]
      @config_path  = @@options[:config_path]
      @logger       = @@options[:logger]
      @environment  = @@options[:environment]
      @defaults     = self.class.schema.defaults 
      find_or_create_config_file!

      defaults_source = DefaultSource.new(@defaults)
      file_source     = FileSource.new(config_path, @environment)
      env_source      = EnvironmentSource.new(@app_name)

      load_values!(self.class.schema, env_source, file_source, defaults_source)
    end

    def source(key)
      configured_value = Hash.instance_method(:fetch).bind(self).call(key.to_s) do
        raise ConfigurationError, "No such key '#{key}'"
      end
      configured_value.source.to_s
    end

    def [](key)
      super(key).value
    end

    def fetch(key, &block)
      case result = super(key, &block)
      when ConfiguredValue then result.value
      else result
      end
    end

    def dump
      table = Table(%w[Key Value Source])
      each_pair do |key, configured_value|
        table << [key, configured_value.value, configured_value.source.to_s]
      end
      table.as(:text)
    end

    private

    def find_or_create_config_file!
      if Pathname(config_path).exist?
        logger.info "Found config file #{config_path}."
      else
        logger.info "#{config_path} does not exist"
        create_starter_config_file!
      end
    end

    def create_starter_config_file!
      path = Pathname(config_path)
      path.dirname.mkpath
      path.open('w+') do |f|
        f << starter_config_content
      end
      logger.info "Starter config file created at #{config_path}. " +
        "Please customize it to your needs."
    end

    def starter_config_content
      <<END
# This is an auto-generated starter configuration file. Feel free to customize
# it to your needs.

development:
  example_key: example_value

test:
  example_key: example_value

production:
  example_key: example_value

END
    end

    def load_values!(schema, *sources)
      sources.reverse_each do |source|
        source.each do |configured_value|
          if schema.defined?(configured_value.key)
            self[configured_value.key] = configured_value
          else
            key = configured_value.key
            logger.warn "Unknown configuration key '#{key}' in #{source}"
          end
        end
      end
    end
    
  end
end
