require 'forwardable'
require 'singleton'
require 'logger'
require 'pathname'
require 'yaml'
require 'hirb'

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
                                :source, :dump, :report

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
      @@definition_location    = caller[0]
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

    def self.definition_location
      @@definition_location
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
      @system       = @@options.fetch(:system){Kernel}
      find_or_create_config_file!

      defaults_source = DefaultSource.new(@defaults)
      file_source     = FileSource.new(config_path, @environment)
      env_source      = EnvironmentSource.new(env_var_prefix)
      sources         = []
      sources    << env_source
      sources    << file_source if file_source.readable?
      sources    << defaults_source
      load_values!(self.class.schema, *sources)
      verify_no_missing_required_values!
    end

    def definition_location
      self.class.definition_location
    end

    def env_var_prefix
      app_name.to_s.upcase + "_"
    end

    def source(key)
      assert_key_defined!(key)
      # TODO is there a simpler way?
      Hash.instance_method(:[]).bind(self.class.instance).call(key).source.to_s
    end

    def [](key)
      assert_key_defined!(key)
      super(key).value
    end

    def fetch(key, &block)
      assert_key_defined!(key)
      case result = super(key, &block)
      when ConfiguredValue then result.value
      else result
      end
    end

    def merge(new_values)
      self.clone.merge!(new_values)
    end

    def merge!(new_values)
      new_values.each_pair do |k,v|
        self[k.to_s] = ConfiguredValue.new(
          CodeSource.new,
          k.to_s,
          v)
      end
    end

    def dump
      Hirb::Helpers::AutoTable.render(
        self.values,
        :fields => [:key, :value, :source],
        :headers => {
          :key    => "Key",
          :value  => "Value",
          :source => "Source"
        },
        :description => false) + "\n"
    end

    def report
      text = ""
      text << "%-22s%s\n" % ["App name:",           app_name]
      text << "%-22s%s\n" % ["Environment:",        environment]
      text << "%-22s%s\n" % ["Configuration file:", config_path]
      text << "%-22s%s\n" % ["Configuration setup:", definition_location]
      text << "%-22s%s\n" % ["Env var prefix:", env_var_prefix]
      text << dump
      text
    end

    def verify_no_missing_required_values!
      missing_keys = schema.keys - keys
      missing_required_keys = missing_keys.select{|k| schema.required?(k)}
      unless missing_required_keys.empty?
        logger.fatal "Application not configured; exiting"
        @system.warn "These required configuration keys were missing:"
        missing_required_keys.each do |key|
          @system.warn "    #{key}"
        end
        @system.warn ""
        @system.warn "Please set the required keys in #{config_path} or "\
          "environment and try again."
        @system.exit(1)
      end
    end

    private

    def assert_key_defined!(key)
      unless schema.defined?(key.to_s)
        raise UndefinedKeyError, key, caller(3)
      end
    end

    def schema
      self.class.schema
    end

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
    rescue SystemCallError => error
      # NOTE It is important to catch system call errors here, rather than using
      # path.writable? checks. Read-only filesystems report files as having the
      # "write" bit set even though writing isn't actually
      # permitted. E.g. the filesystem used on Heroku. The first we'll find out
      # that it's a read-only filesystem is when we try to write to it.
      logger.info <<"END"
Unable to write starter config file to #{path}. The error was:
  '#{error.message}'
END
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
          if schema.defined?(configured_value.key.to_s)
            self[configured_value.key.to_s] = configured_value
          else
            key = configured_value.key
            logger.warn "Unknown configuration key '#{key}' in #{source}"
          end
        end
      end
    end
    
  end
end
