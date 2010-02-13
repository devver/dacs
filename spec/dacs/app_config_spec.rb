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
        AppConfig.init!(@app_name, :logger => @logger) do |config|
          config.key :foo, :default => 42
          config.key 'bar'
        end
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

    end

    context "with a mix of default, file, and environment settings" do
      before :each do
        @construct.file("config/foo_app.yml") do |f|
          YAML.dump({
              'development'=>{
                'bar' => 'file_bar',
                'baz' => 'file_buz'
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
