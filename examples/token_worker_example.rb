#gem 'mperham-politics'
require 'politics'
require 'politics/token_worker'

# Test this example by starting memcached locally and then in two irb sessions, run this:
#
#
# You can then watch as one of them is elected leader.  You can kill the leader and verify
# the backup process is elected after approximately iteration_length seconds.
#
=begin
 require 'token_worker_example'
 p = Politics::TokenWorkerExample.new
 p.start
=end
module Politics
  class TokenWorkerExample
    include Politics::TokenWorker
    
    def initialize
      register_worker 'token-example', :iteration_length => 10, :servers => memcached_servers
    end
    
    def start
      process do
        puts "PID #{$$} processing at #{Time.now}..."
      end
    end
    
    def memcached_servers
      ['localhost:11211']
    end

  end
end
