require 'rubygems'
require 'test/unit'

gem 'thoughtbot-shoulda', '>=2.0.2'
require 'shoulda'

begin
  require 'mocha'
rescue LoadError => e
  puts "Please install the mocha gem: gem install mocha"
end

require File.dirname(__FILE__) + '/../lib/init'
Politics::LOG.level = Logger::WARN