require File.expand_path('../spec_helper', File.dirname(__FILE__))

module Dacs
  describe AppConfig do
    include Construct::Helpers
    before :each do
      @construct = create_construct
      @start_dir = Dir.pwd
      Dir.chdir(@construct)
      @app_name  = "foo_app"
      @logger    = stub("logger").as_null_object
    end

    after(:each) do
      Dir.chdir(@start_dir)
      @construct.destroy!
    end

    context "when first initialized" do
      it "should write an example config file" do
        AppConfig.init!(@app_name, :logger => @logger)
        AppConfig.instance
        (@construct+'config'+'foo_app.yml').should exist
      end

      it "should know its environment" do
        AppConfig.environment.should be == :development
      end
    end

    def self.it_should_not_choke_on_file_source
      it "should not write an example config file" do
        AppConfig.init!(@app_name, :logger => @logger)
        AppConfig.instance
        (@construct+'config'+'foo_app.yml').should_not exist
      end

      it "should not raise an error" do
        lambda do 
          AppConfig.init!(@app_name, :logger => @logger)
          AppConfig.instance
        end.should_not raise_error
      end
    end

    context "when first initialized in a read-only filesystem" do
      before do
        @construct.chmod(0444)
      end
      
      it_should_not_choke_on_file_source
    end

    context "when first initialized with a read-only config dir" do
      before do
        config_dir = @construct.directory 'config'
        config_dir.chmod(0444)
      end
      
      it_should_not_choke_on_file_source
    end

    context "given a config file lacking the expected environment key" do
      append_before :each do
        @construct.file("config/foo_app.yml") do |f|
          YAML.dump({'production'=>{}}, f)
        end
      end

      it "should raise an error on init" do
        lambda do 
          AppConfig.init!(@app_name, 
            :environment => :development,
            :logger      => @logger)
        end.should raise_error(ConfigurationError)
      end
    end

    context "given a config file with an unknown key" do
      before :each do
        @construct.file("config/foo_app.yml") do |f|
          YAML.dump({'development'=>{'undefined' => 'xyz'}}, f)
        end
      end

      it "should warn the user" do
        @logger.should_receive(:warn).with("Unknown configuration key 'undefined' in file config/foo_app.yml")
        AppConfig.init!(@app_name, :logger => @logger) do |config|
          config.key "foo", :default => 42
        end
      end
    end

    context "given strict definitions and a missing required key" do
      before :each do
        @system = stub("system").as_null_object
      end

      def do_init
        AppConfig.init!(@app_name, :logger => @logger, :system => @system) do |config|
          config.key "foo"
          config.key "bar"
        end
      end
      
      it "should exit the program with an error status" do
        @system.should_receive(:exit).with(1)
        do_init
      end

      it "should warn the user about the missing config keys" do
        @system.should_receive(:warn).with(/foo/)
        @system.should_receive(:warn).with(/bar/)
        @system.should_receive(:warn).any_number_of_times
        do_init
      end
    end

    context "without explicit key definitions" do
      before :each do
        AppConfig.init!(@app_name, 
          :logger   => @logger, 
          :defaults => {
            'foo' => 24,
            'bar' => false,
            'baz' => 3.14
          }
          )
      end

      it "should derive key list from defaults option" do
        AppConfig.keys.sort.should be == ['foo', 'bar', 'baz'].sort
      end

      it "should use defaults provided in options" do
        AppConfig.default_value('foo').should be == 24
        AppConfig.default_value('bar').should be == false
        AppConfig.default_value('baz').should be == 3.14
      end

      it "should consider all keys to be optional" do
        AppConfig.optional?('foo').should be_true
        AppConfig.required?(:foo).should be_false
        AppConfig.optional?('faz').should be_true
      end

    end

    context "with explicit key definitions" do
      before :each do
        ENV['FOO_APP_BAR'] = 'env_bar'
        @def_line = __LINE__ + 1
        AppConfig.init!(@app_name, :logger => @logger) do |config|
          config.key :foo, :default => 42
          config.key 'bar'
        end
      end

      after :each do
        ENV.delete('FOO_APP_BAR')
      end

      it "should be able to list known keys" do
        AppConfig.keys.should == ['foo', 'bar']
      end

      it "should remember defaults provided in definition" do
        AppConfig.default_value('foo').should be == 42
      end

      it "should consider keys with no default to be required" do
        AppConfig.required?('bar').should be_true
        AppConfig.optional?(:bar).should be_false
      end

      it "should consider keys with no default to be optional" do
        AppConfig.required?('foo').should be_false
        AppConfig.optional?(:foo).should be_true
      end

      it "should raise an exception when an undefined key is referenced" do
        lambda do
          AppConfig['faz']
        end.should raise_error(ConfigurationError)
      end

      it "should reference the offending line when an undefined key is referenced" do
        @error_line = __LINE__ + 2
        error = begin
                  AppConfig['faz']
                rescue ConfigurationError => error
                  error
                end
        error.backtrace[0].should match(/#{__FILE__}:#{@error_line}/)
      end

      it "should remember where the keys were defined" do
        AppConfig.definition_location.should match(/#{__FILE__}:#{@def_line}/)
      end
    end

    context "with a mix of default, file, and environment settings" do
      before :each do
        @construct.file("config/foo_app.yml") do |f|
          YAML.dump({
              'development'=>{
                'bar' => 'file_bar',
                'baz' => 'file_baz'
              }
            }, 
            f)
        end
        ENV['FOO_APP_BUZ'] = 'env_buz'
        AppConfig.init!(@app_name, :logger => @logger) do |config|
          config.key :foo,  :default => 42
          config.key 'bar', :default => "baz"
          config.key 'buz', :default => "ribbit"
        end
      end

      after :each do
        ENV.delete('FOO_APP_BUZ')
      end

      it "should have the correct values for each" do
        AppConfig['foo'].should be == 42
        AppConfig['bar'].should be == 'file_bar'
        AppConfig['buz'].should be == 'env_buz'
      end

      it "should be able to tell where each came from" do
        AppConfig.source('foo').should match(/defaults/)
        AppConfig.source('bar').should match(
          /file config\/foo_app.yml/)
        AppConfig.source('buz').should be == 'environment'
      end

      it "should be able to show a table of values" do
        AppConfig.dump.should == <<END
+------------------------------------------+
| Key |  Value   |         Source          |
+------------------------------------------+
| foo |       42 | defaults                |
| buz | env_buz  | environment             |
| bar | file_bar | file config/foo_app.yml |
+------------------------------------------+
END
      end
      
    end
  end
end
