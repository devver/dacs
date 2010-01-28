require 'forwardable'
require 'singleton'
require 'logger'
require 'pathname'
require 'yaml'

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
    include Singleton

    class << self
      extend Forwardable

      # Delegate a subset of Hash methods to the singleton instance
      def_delegators :instance, :[], :fetch, :key?, :merge, :merge!, :app_name
    end

    def self.init!(app_name, options={})
      @__instance__ = nil
      @@options = options.merge(:app_name => app_name)
      @@options[:app_root]     ||= Pathname(Dir.pwd)
      @@options[:config_path]  ||= @@options[:app_root] + 'config' + "#{app_name}.yml"
      @@options[:logger]       ||= ::Logger.new($stderr)
      @@options[:environment]  ||= :development
      @@options[:defaults]     ||= {}
    end
    
    attr_reader :app_name
    attr_reader :logger
    attr_reader :config_path
    attr_reader :environment

    def initialize
      raise "You must initialize with Dacs::AppConfig.init!()" unless @@options
      @app_name    = @@options[:app_name]
      @config_path = @@options[:config_path]
      @logger      = @@options[:logger]
      @environment = @@options[:environment]
      @defaults    = @@options[:defaults]
      @local_config = if Pathname(config_path).exist?
                        logger.info "Found config file #{config_path}."
                        YAML.load_file(config_path.to_s).fetch(environment.to_s) {{}}
                      else
                        logger.info "#{config_path} does not exist;" +
                          " config will be from environment."
                        {}
                      end

      replace(@defaults)

      # Local config takes priority over defaults
      merge!(@local_config)

      # Environment takes priority over local config
      ENV.keys.grep(/^#{app_name.upcase}_(.*)$/) do |key|
        self[$1.downcase] = ENV[key]
      end
    end
    
  end
end
