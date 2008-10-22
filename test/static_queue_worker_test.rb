require File.dirname(__FILE__) + '/test_helper'

Thread.abort_on_exception = true

class Worker
  include Politics::StaticQueueWorker
  def initialize
    register_worker 'worker', 10, :iteration_length => 10
  end
  
  def start
    process_bucket do |bucket|
      sleep 1
    end
  end
end

class StaticQueueWorkerTest < Test::Unit::TestCase
  
  context "nodes" do
    setup do
      @nodes = []
      5.times do
        @nodes << nil
      end
    end
    
    should "start up" do
      processes = @nodes.map do
        fork do
          ['INT', 'TERM'].each { |signal| 
            trap(signal) { exit(0) }
          }
          Worker.new.start
        end
      end
      sleep 10
      puts "Terminating"
      Process.kill('INT', *processes)
    end
  end
end