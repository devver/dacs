$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'dacs'
require 'spec'
require 'spec/autorun'
require 'construct'

Spec::Runner.configure do |config|
end
