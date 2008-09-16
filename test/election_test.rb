require 'rubygems'
require 'test/unit'
require 'shoulda'
require File.dirname(__FILE__) + '/../lib/election/candidate'

class ElectionTest < Test::Unit::TestCase
  
  context "election" do
    setup do
      @politicians = []
      5.times do
        Object.send(:include, Election::Candidate)
        politician = Object.new
        @politicians << politician
      end
    end
    
    should "start up" do
      @politicians.each do |p|
        fork do
          p.register_to_run
          while true
            puts "Running election"
            p.elect
            sleep 5
          end
        end
      end
    end
  end
end