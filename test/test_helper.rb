require 'rubygems'
require 'test/unit'

begin
  gem 'thoughtbot-shoulda', '>=2.0.2'
  require 'shoulda'
rescue GemError, LoadError => e
  puts "Please install shoulda: `sudo gem install thoughtbot-shoulda -s http://gems.github.com`"
end

begin
  require 'mocha'
rescue LoadError => e
  puts "Please install mocha: `sudo gem install mocha`"
end

$:.unshift(File.dirname(__FILE__) + '/../lib')
require File.dirname(__FILE__) + '/../lib/init'
Politics::log.level = Logger::WARN