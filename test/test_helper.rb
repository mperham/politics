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

require File.dirname(__FILE__) + '/../lib/init'
Politics::LOG.level = Logger::WARN