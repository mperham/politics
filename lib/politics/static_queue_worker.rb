puts 'hello'
require 'socket'
require 'ipaddr'
require 'uri'
require 'drb'

begin
require 'net/dns/mdns-sd'
require 'net/dns/resolv-mdns'
require 'net/dns/resolv-replace'
rescue LoadError => e
  puts "Unable to load net-mdns, please run `sudo gem install net-mdns`: #{e.message}"
  exit(1)  
end

begin
  require 'memcache'
rescue LoadError => e
  puts "Unable to load memcache client, please run `sudo gem install memcache-client`: #{e.message}"
  exit(1)
end

module Politics
  
  # The StaticQueueWorker mixin allows a processing daemon to "lease" or checkout
  # a portion of a problem space to ensure no other process is processing that same
  # space at the same time.  The processing space is cut into N "buckets", each of
  # which is placed in a queue.  Processes then fetch entries from the queue
  # and process them.  It is up to the application to map the bucket number onto its
  # specific problem space.
  #
  # Note that memcached is used for leader election.  The leader owns the queue during
  # the iteration period and other peers fetch buckets from the current leader during the
  # iteration.
  #
  # The leader hands out buckets in order.  Once all the buckets have been processed, the
  # leader returns nil to the processors which causes them to sleep until the end of the
  # iteration.  Then everyone wakes up, a new leader is elected, and the processing starts
  # all over again.
  #
  # DRb and mDNS are used for peer discovery and communication.
  #
  # Example usage:
  #
  #  class Analyzer
  #    include Politics::StaticQueueWorker
  #    TOTAL_BUCKETS = 16
  #
  #    def start
  #      register_worker(self.class.name, TOTAL_BUCKETS)
  #      process_bucket do |bucket|
  #        puts "Analyzing bucket #{bucket} of #{TOTAL_BUCKETS}"
  #        sleep 5
  #      end
  #    end
  #  end
  #
  # Note: process_bucket never returns i.e. this should be the main loop of your processing daemon.
  #
  module StaticQueueWorker
    
    def self.included(model) #:nodoc:
      model.class_eval do
        attr_accessor :group_name, :iteration_length
      end
    end
    
    # Register this process as able to work on buckets.
    def register_worker(name, bucket_count, config={})
      options = { :iteration_length => 60, :servers => ['127.0.0.1:11211'] }
      options.merge!(config)

      self.group_name = name
      self.iteration_length = options[:iteration_length]
      @memcache_client = client_for(Array(options[:servers]))

      @buckets = []
      @bucket_count = bucket_count
      initialize_buckets

		  register_with_bonjour
		  
		  log.info { "Registered #{self} in group #{group_name} at port #{@port}" }
    end
    
    # Fetch a bucket out of the queue and pass it to the given block to be processed.
    #
    # +bucket+::            The bucket number to process, within the range 0...TOTAL_BUCKETS
    def process_bucket(&block)
      raise ArgumentError, "process_bucket requires a block!" unless block_given?
      raise ArgumentError, "You must call register_worker before processing!" unless @memcache_client

      begin
        nominate
        if leader?
          # Drb thread handles leader duties
          log.info { "#{@uri} has been elected leader" }
          relax until_next_iteration
          initialize_buckets          
        else
          # Get a bucket from the leader and process it
          begin
            bucket_process(*leader.bucket_request, &block)
          rescue DRb::DRbError => dre
            log.error { "Error talking to leader: #{dre.message}" }
            relax until_next_iteration
          end
        end
      end while loop?
    end
    
    def bucket_request
      if leader?
        [@buckets.pop, until_next_iteration]
      else
        :not_leader
      end
    end
    
    private
    
    def bucket_process(bucket, sleep_time)
      case bucket
      when nil
        # No more buckets to process this iteration
        log.info { "No more buckets in this iteration, sleeping for #{sleep_time} sec" }
        sleep sleep_time
      when :not_leader
        # Uh oh, race condition?  Invalid any local cache and check again
        log.warn { "Recv'd NOT_LEADER from peer." }
        relax 1
        @leader_uri = nil
      else
        log.info { "#{@uri} is processing #{bucket}"}
        yield bucket
      end
    end      
    
    def log
      @logger ||= Logger.new(STDOUT)
    end
    
    def initialize_buckets
      @buckets.clear
      @bucket_count.times { |idx| @buckets << idx }
    end

    def replicas
      @replicas ||= []
    end
    
    def leader
      name = leader_uri
      repl = nil
      while replicas.empty? or repl == nil
        repl = replicas.detect { |replica| replica.__drburi == name }
        unless repl
          relax 1
          bonjour_scan do |replica|
            replicas << replica
          end
        end
      end
      repl
    end
    
    def until_next_iteration
      left = iteration_length - (Time.now - @nominated_at)
      left > 0 ? left : 0
    end
    
    def loop?
      true
    end
    
    def token
      "#{group_name}_token"
    end
    
    def cleanup
      at_exit do
        @memcache_client.delete(token) if leader?
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
      @memcache_client.add(token, @uri, iteration_length)
      @nominated_at = Time.now
      @leader_uri = nil
    end

    def leader_uri
      @leader_uri ||= @memcache_client.get(token)
    end
    
    # Check to see if we are leader by looking at the process name
    # associated with the token.
    def leader?
      until_next_iteration > 0 && @uri == leader_uri
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
    
    
		def register_with_bonjour
		  server = DRb.start_service(nil, self)
		  @uri = DRb.uri
		  @port = URI.parse(DRb.uri).port

		  # Register our DRb server with Bonjour.
      handle = Net::DNS::MDNSSD.register("#{self.group_name}-#{local_ip}-#{$$}", 
          "_#{group_name}._tcp", 'local', @port)
          
      ['INT', 'TERM'].each { |signal| 
        trap(signal) do
          handle.stop
          server.stop_service
        end
      }
	  end
		
		def bonjour_scan
      Net::DNS::MDNSSD.browse("_#{group_name}._tcp") do |b|
        Net::DNS::MDNSSD.resolve(b.name, b.type) do |r|
          drburl = "druby://#{r.target}:#{r.port}"
          replica = DRbObject.new(nil, drburl)
          yield replica
        end
      end
	  end
	  
    # http://coderrr.wordpress.com/2008/05/28/get-your-local-ip-address/
    def local_ip
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true # turn off reverse DNS resolution temporarily
 
      UDPSocket.open do |s|
        s.connect '64.233.187.99', 1
        IPAddr.new(s.addr.last).to_i
      end
    ensure
      Socket.do_not_reverse_lookup = orig
    end	  
    
  end
end
