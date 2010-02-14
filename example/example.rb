#!/usr/bin/env ruby
require 'rubygems'
require File.expand_path('../lib/dacs', File.dirname(__FILE__))
ENV['EXAMPLE_BAR'] = 'env_bar'
Dacs::AppConfig.init!('example', 
  :config_path => File.expand_path('example.yml', File.dirname(__FILE__)),
  :environment => 'development',
  :logger      => Logger.new($stdout)) do |config|
  
  config.key 'foo', :default => 'default_foo'
  config.key 'bar', :default => 'default_bar'
  config.key 'baz', :default => 'default_baz'
end

puts "Running in #{Dacs::AppConfig.environment} mode"
puts "foo: #{Dacs::AppConfig['foo']}"
puts "bar: #{Dacs::AppConfig['bar']}"
puts "baz: #{Dacs::AppConfig['baz']}"
puts Dacs::AppConfig.dump             # => nil
puts Dacs::AppConfig.report           # => nil

# >> I, [2010-02-14T09:45:52.703585 #17437]  INFO -- : Found config file /devver-repos/dacs/example/example.yml.
# >> W, [2010-02-14T09:45:52.704092 #17437]  WARN -- : Unknown configuration key 'fuz' in file example.yml
# >> Running in development mode
# >> foo: file_foo
# >> bar: env_bar
# >> baz: default_baz
# >> +--------------------------------------+
# >> | Key |    Value    |      Source      |
# >> +--------------------------------------+
# >> | baz | default_baz | defaults         |
# >> | foo | file_foo    | file example.yml |
# >> | bar | env_bar     | environment      |
# >> +--------------------------------------+
# >> App name:             example
# >> Environment:          development
# >> Configuration file:   /devver-repos/dacs/example/example.yml
# >> Configuration setup:  -:5
# >> Env var prefix:       EXAMPLE_
# >> +--------------------------------------+
# >> | Key |    Value    |      Source      |
# >> +--------------------------------------+
# >> | baz | default_baz | defaults         |
# >> | foo | file_foo    | file example.yml |
# >> | bar | env_bar     | environment      |
# >> +--------------------------------------+
