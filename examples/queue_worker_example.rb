#gem 'mperham-politics'
require 'politics'
require 'politics/static_queue_worker'

# Test this example by starting memcached locally and then in two irb sessions, run this:
#
=begin
 require 'queue_worker_example'
 p = Politics::QueueWorkerExample.new
 p.start
=end
#
# You can then watch as one of them is elected leader.  You can kill the leader and verify
# the backup process is elected after approximately iteration_length seconds.
#
module Politics
  class QueueWorkerExample
    include Politics::StaticQueueWorker
    TOTAL_BUCKETS = 20

    def initialize
      register_worker 'queue-example', TOTAL_BUCKETS, :iteration_length => 60, :servers => memcached_servers
    end
    
    def start
      process_bucket do |bucket|
        puts "PID #{$$} processing bucket #{bucket}/#{TOTAL_BUCKETS} at #{Time.now}..."
        sleep 1.5
      end
    end
    
    def memcached_servers
      ['127.0.0.1:11211']
    end

  end
end
