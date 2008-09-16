require 'logger'
require 'socket'
require 'ipaddr'
require 'drb'
require 'uri'

# For MDNSSD
require 'net/dns/mdns-sd'
# To make Resolv aware of mDNS
require 'net/dns/resolv-mdns'
# To make TCPSocket use Resolv, not the C library resolver.
require 'net/dns/resolv-replace'



# Implements the leader election protocol "Omega" as defined in
# _A Leader Election Protocol for Fault Recovery in Asynchronous Fully-Connected Networks. Franceschetti, M. and Bruck, J. (1998)_
# http://caltechparadise.library.caltech.edu/31/.
#
# Consider a fully-connected set of nodes.  We use Bonjour to detect the
# set of candidate nodes upon startup, which means the node topography is limited
# to the current subnet.
module Election
	module Candidate
	  
	  # The "party" we are trying to elect a leader for.  This allows you to have
	  # many types of daemons on the local network and elect a leader for each type
	  # independently.
	  attr_accessor :service
	  
	  # The port to use for the local messaging required for the election process.
	  attr_accessor :port
	  
	  attr_accessor :candidates
	  
	  LOG = Logger.new(STDOUT)
	  
	  def initialize
	    @service = 'default'
	    @port = 16999
	    @candidates = []
    end
    
    def log(msg)
      LOG.info(msg)
    end
	  
	  # A process's weight is its PID + a random 16-bit value.  We don't want
	  # weigh solely based on PID or IP as that may unduly load one machine.
	  def weight
	    @weight ||= begin
	      rand(65536) + $$
      end
    end
	  
		def elect
		  while true
        # Step 1. Ping the network for all candidates of our service type.
        @leader = false
        @votes = 0
  		  @candidates = []
        Net::DNS::MDNSSD.browse("_#{service}._tcp") do |b|
          Net::DNS::MDNSSD.resolve(b.name, b.type) do |r|
            @candidates << DRbObject.new(nil, "druby://#{r.target}:#{r.port}")
          end
        end
        log "Found #{candidates.size} candidates"

        sleep 1

        # Step 2. Now contact everyone and make sure everyone can see everyone else.
        counts = candidates.map do |politician|
          politician.candidates.size
        end
        next unless everyone_agrees_on_candidate_counts? counts, candidates.size
        
        log "Everyone agrees there are #{candidates.size} candidates"
      
        # Step 3. Get everyone's weight and find the candidate with the highest weight,
        # and give him our vote.
        weights = candidates.map do |politician|
          politician.weight
        end
      
        nominee = candidates.get(weights.index(weights.max))
        log "I'm voting for #{nominee.__drburi}"
        nominee.vote
      
        sleep 1

        # Step 4, once all votes have been counted, verify we have a new leader.
        # If not, start all over again.
        break if nominee.leader?
      end
      
      log "We have a new leader and it is #{@leader ? '' : 'NOT'} me!"
		end
		
		def leader?
		  @leader = @votes == candidates.size
	  end
		
		def vote
		  @votes += 1
	  end
		
		def register_to_run
		  log "Registering #{self} in process #{$$}"

		  # Start the local DRb service
		  server = DRb.start_service(nil, self)
		  
		  # Register our DRb server with Bonjour.
      handle = Net::DNS::MDNSSD.register("#{service}-#{local_ip.to_s}-#{$$}", 
          "_#{service}._tcp", 'local', URI.parse(DRb.uri).port)
      
      ['INT', 'TERM'].each { |signal| 
        trap(signal) { handle.stop; server.stop_service; puts "Exiting #{$$}"}
      }
		end
		
		private

		def everyone_agrees_on_candidate_counts?(counts, counter)
		  counts.size > 0 && counts.all? { |val| val == counter }
	  end

    # http://coderrr.wordpress.com/2008/05/28/get-your-local-ip-address/
    def local_ip
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily

      UDPSocket.open do |s|
        s.connect '64.233.187.99', 1
        IPAddr.new(s.addr.last)
      end
    ensure
      Socket.do_not_reverse_lookup = orig
    end
  end
end