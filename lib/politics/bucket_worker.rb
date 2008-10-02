require 'starling'

module Politics
  
  # The BucketWorker mixin allows a processing daemon to "lease" or checkout
  # a portion of a problem space to ensure no other process is processing that same
  # space at the same time.  The processing space is cut into N "buckets", each of
  # which is placed in a queue.  Processes then fetch entries from the queue
  # and process them.  It is up to the application to map the bucket number onto its
  # specific problem space.
  #
  # Note that the Starling queue server is the single point of failure with this
  # mechanism.  Only you can decide if this is an acceptable tradeoff for your needs.
  #
  # Example usage:
  #
  #  class Analyzer
  #    include BucketWorker
  #    TOTAL_BUCKETS = 16
  #
  #    def start
  #      register_worker(self.class.name)
  #      create_buckets(TOTAL_BUCKETS) if master?
  #      process_bucket do |bucket|
  #        puts "Analyzing bucket #{bucket} of #{TOTAL_BUCKETS}"
  #        sleep 5
  #      end
  #    end
  #
  #    def master?
  #      # TODO Add your own logic here to demarcate a 'master' process
  #      ARGV.include? '-m'
  #    end
  #  end
  #
  # Note: process_bucket never returns i.e. this should be the main loop of your processing daemon.
  #
  module BucketWorker
    
    def self.included(model) #:nodoc:
      model.class_eval do
        attr_accessor :starling_client, :bucket_count, :queue_name
      end
    end
    
    # Register this process as able to work on buckets.
    #
    # +name+::               The name of the queue to access
    # +servers+::            The starling server(s) to use, defaults to +['localhost:22122']+
    def register_worker(name, servers=['localhost:22122'])
      self.queue_name = name
      self.starling_client = client_for(Array(servers))
    end
    
    # Create the given number of buckets.  Should ONLY be called by a single worker.
    # TODO Obviously a major weakness of this algorithm. Is there a cleaner way?
    #
    # +bucket_count+::       The number of buckets to create
    def create_buckets(bucket_count)
      starling_client.flush(queue_name)
      bucket_count.times do |count|
        starling_client.set(queue_name, count)
      end
    end
    
    # Fetch a bucket out of the queue and pass it to the given block to be processed.
    # Once processing has completed, it will put the bucket back onto the queue for processing
    # by a BucketWorker again, possibly immediately, depending on the number of buckets vs
    # number of workers.
    def process_bucket
      raise ArgumentError, "process_bucket requires a block!" unless block_given?
      raise ArgumentError, "You must call register_worker before processing!" unless starling_client

      begin
        bucket = get_bucket
        yield bucket
      ensure
        push_bucket(bucket)
      end while loop?
    end
    
    private
    
    def get_bucket
      starling_client.get(queue_name)
    end
    
    def push_bucket(bucket)
      starling_client.set(queue_name, bucket)
    end
    
    def client_for(servers)
      Starling.new(servers)
    end
    
    def loop?
      true
    end
  end
end