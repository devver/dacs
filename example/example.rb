#!/usr/bin/env ruby
require File.expand_path('../lib/dacs', File.dirname(__FILE__))
ENV['EXAMPLE_BAR'] = 'env_bar'
Dacs::AppConfig.init!('example', 
  :defaults => { 
    'foo' => 'default_foo', 
    'bar' => 'default_bar', 
    'baz' => 'default_baz' },
  :config_path => File.expand_path('example.yml', File.dirname(__FILE__)),
  :environment => 'development',
  :logger      => Logger.new($stdout))

puts "foo: #{Dacs::AppConfig['foo']}"
puts "bar: #{Dacs::AppConfig['bar']}"
puts "baz: #{Dacs::AppConfig['baz']}"

# >> I, [2010-01-27T18:59:15.223408 #23940]  INFO -- : Found config file /devver-repos/dacs/example/example.yml.
# >> foo: file_foo
# >> bar: env_bar
# >> baz: default_baz
