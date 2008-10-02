require 'starling'

module Politics
  module BucketWorker
    
    def self.included(model)
      model.class_eval do
        attr_accessor :starling_client, :bucket_count, :queue_name
      end
    end
    
    def register_worker(name, bucket_count, init=false, config={})
      options = { :servers => ['localhost:22122'] }
      options.merge!(config)

      self.queue_name = "#{name}"
      self.starling_client = client_for(Array(options[:servers]))
      
      initialize_buckets(bucket_count) if init
    end
    
    def process(&block)
      begin
        bucket = starling_client.get(queue_name)
        block.call(bucket)
      ensure
        starling_client.set(queue_name, bucket)
      end while loop?
    end
    
    private
    
    def initialize_buckets
      starling_client.flush(queue_name)
      bucket_count.times do |count|
        starling_client.set(queue_name, count)
      end
    end
    
    def client_for(servers)
      Starling.new(servers)
    end
    
    def loop?
      true
    end
  end
end