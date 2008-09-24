require 'rubygems'
require 'test/unit'
require 'shoulda'
require File.dirname(__FILE__) + '/../lib/init'

Thread.abort_on_exception = true

class PoliticalTest < Test::Unit::TestCase
  
  context "nodes" do
    setup do
      @nodes = []
      5.times do
        Object.send(:include, Politics::DiscoverableNode)
        node = Object.new
        @nodes << node
      end
    end
    
    should "start up" do
      processes = @nodes.map do |node|
        fork do
          ['INT', 'TERM'].each { |signal| 
            trap(signal) { exit(0) }
          }
          node.register
          convention = Politics::Convention.new
          convention.elect(node)
        end
      end
      Process.wait
    end
  end
end