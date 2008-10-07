begin
  require 'memcache'
rescue LoadError => e
  puts "Unable to load memcache client, please run `sudo gem install memcache-client`: #{e.message}"
  exit(1)
end

module Politics

  # An algorithm to provide leader election between a set of identical processing daemons.
  #
  # Each TokenWorker is an instance which needs to perform some processing.
  # The worker instance must obtain the leader token before performing some task.
  # We use a memcached server as a central token authority to provide a shared,
  # network-wide view for all processors.  This reliance on a single resource means
  # if your memcached server goes down, so do the processors.  Oftentimes, 
  # this is an acceptable trade-off since many high-traffic web sites would 
  # not be useable without memcached running anyhow.
  #
  # Essentially each TokenWorker attempts to elect itself every +:iteration_length+
  # seconds by simply setting a key in memcached to its own name.  Memcached tracks
  # which name got there first.  The key expires after +:iteration_length+ seconds.
  #
  # Example usage:
  #  class Analyzer
  #    include Politics::TokenWorker
  #
  #    def initialize
  #      register_worker 'analyzer', :iteration_length => 120, :servers => ['localhost:11211']
  #    end
  #
  #    def start
  #      process do
  #        # do analysis here, will only be done when this process
  #        # is actually elected leader, otherwise it will sleep for
  #        # iteration_length seconds.
  #      end
  #    end
  #  end
  #
  # Notes:
  # * This will not work with multiple instances in the same Ruby process.
  #   The library is only designed to elect a leader from a set of processes, not instances within
  #   a single process.
  # * The algorithm makes no attempt to keep the same leader during the next iteration.
  #   This can often times be quite beneficial (e.g. leveraging a warm cache from the last iteration)
  #   for performance but is left to the reader to implement.
  module TokenWorker
    
    def self.included(model) #:nodoc:
      model.class_eval do
        attr_accessor :memcache_client, :token, :iteration_length, :worker_name
        class << self
          attr_accessor :worker_instance #:nodoc:
        end
      end
    end

    # Register this instance as a worker.
    #
    # Options:
    # +:iteration_length+::    The length of a processing iteration, in seconds.  The 
    #                          leader's 'reign' lasts for this length of time.
    # +:servers+::             An array of memcached server strings
    def register_worker(name, config={})
      # track the latest instance of this class, there's really only supposed to be
      # a single TokenWorker instance per process.
      self.class.worker_instance = self

      options = { :iteration_length => 60, :servers => ['localhost:11211'] }
      options.merge!(config)

      self.token = "#{name}_token"
      self.memcache_client = client_for(Array(options[:servers]))
      self.iteration_length = options[:iteration_length]
      self.worker_name = "#{Socket.gethostname}:#{$$}"

      cleanup
    end
    
    def process(*args, &block)
      verify_registration

      begin
        # Try to add our name as the worker with the master token.
        # If another process got there first, this is a noop.
        # We add an expiry so that the master token will constantly
        # need to be refreshed (in case the current leader dies).
        nominate

        time = 0
        if leader?
          LOG.info { "I've been elected leader: #{worker_name}" }
          # If we are the master worker, do the work.
          time = time_for do
            result = block.call(*args)
          end
        end
        
        pause_until_expiry(time)
      end while loop?
    end

    private
    
    def verify_registration
      unless self.class.worker_instance
        raise ArgumentError, "Cannot call process without first calling register_worker"
      end
      unless self.class.worker_instance == self
        raise SecurityError, "Only one instance of #{self.class} per process.  Another instance was created after this one."
      end
    end
    
    def loop?
      true
    end
    
    def cleanup
      at_exit do
        memcache_client.delete(token)
      end
    end
    
    def pause_until_expiry(elapsed)
      pause_time = (iteration_length - elapsed).to_f
      if pause_time > 0
        relax(pause_time) 
      else
        raise ArgumentError, "Negative iteration time left.  Assuming the worst and exiting... #{iteration_length}/#{elapsed}"
      end
    end
    
    def relax(time)
      sleep time
    end
    
    # Nominate ourself as leader by contacting the memcached server
    # and attempting to add the token with our name attached.
    def nominate
      memcache_client.add(token, worker_name, iteration_length)
    end

    # Check to see if we are leader by looking at the process name
    # associated with the token.
    def leader?
      master_worker = memcache_client.get(token)
      worker_name == master_worker
    end

    # Easy to mock or monkey-patch if another MemCache client is preferred.
    def client_for(servers)
      MemCache.new(servers)
    end

    def time_for(&block)
      a = Time.now
      yield
      Time.now - a
    end
  end
end