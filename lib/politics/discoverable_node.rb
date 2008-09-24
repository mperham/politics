require 'socket'
require 'ipaddr'
require 'uri'

# For MDNSSD
require 'net/dns/mdns-sd'
# To make Resolv aware of mDNS
require 'net/dns/resolv-mdns'
# To make TCPSocket use Resolv, not the C library resolver.
require 'net/dns/resolv-replace'

=begin
IRB setup:
require 'lib/politics'
require 'lib/politics/discoverable_node'
require 'lib/politics/convention'
Object.send(:include, Election::Candidate)
p = Object.new
p.register
=end

module Politics

  # A module to solve the Group Membership problem in distributed computing.
  # The "group" is the cloud of processes which are replicas and need to coordinate.
  # Handling group membership is the first step in solving distributed computing
  # problems.  There are two issues:
  # 1) replica discovery
  # 2) controlling and maintaining a consistent group of replicas in each replica
  #
  # Peer discovery is implemented using Bonjour for local network auto-discovery.
  # Each process registers itself on the network as a process of a given type.
  # Each process then queries the network for other replicas of the same type.
  #
  # The replicas then run the Multi-Paxos algorithm to provide consensus on a given
  # replica set.  The algorithm is robust in the face of crash failures, but not
  # Byzantine failures.
	class DiscoverableNode
	  
    # include PluginAWeek::StateMachine
	  
	  attr_accessor :group
	  attr_accessor :coordinator
	  attr_accessor :latest_sequence_number
	  
    # state_machine :group do
    #   event :join do
    #     transition :to => :active, :from => :proposed
    #       end
    #       
    #       event :invited do
    #     transition :to => :active, :from => :lone    
    #       end
    #     end
    
    def initialize
      self.recent_sequence_number = 0
      self.coordinator = nil
    end
    
    def next_sequence_number
      weight + recent_sequence_number
    end
    
    
    def propose(value = next_sequence_number)
      promises = []
      replicas.each do |peer|
        promises << peer.proposal(rid, value)
      end
    end
    
    def proposal(peer, value)
      # Respond to a value proposal with a promise 
      if value > latest_sequence_number
        coordinator, latest_sequence_number = peer, value
      end
      [coordinator, latest_sequence_number]
    end
    
    
	  
		def register(group='foo')
		  self.group = group
		  start_drb
		  register_with_bonjour(group)
		  Politics.log "Registered #{self} in group #{service} with weight #{weight}"
		  sleep 1
		  find_replicas
		end
		
    def replicas
      @replicas ||= []
    end
    
    def find_replicas
		  replicas.clear

      puts "Finding replicas"
      # We need to wait for the network to stablize so we repeat 
      # the replica check once per second until the # of replicas
      # does not change.
      while true
        current_replicas = []
        bonjour_scan do |replica|
          begin
            current_replicas[replica] = replica.weight
          rescue => e
          end
        end
        if replicas.size == current_replicas.size
          break
        end
      end
      replicas
    end
    
	  # A process's Replica ID is its PID + a random 16-bit value.  We don't want
	  # weigh solely based on PID or IP as that may unduly load one machine.
	  def rid
	    @rid ||= begin
	      rand(65536) + $$
      end
    end

		private
		
		def register_with_bonjour(group)
		  # Register our DRb server with Bonjour.
      handle = Net::DNS::MDNSSD.register("#{group}-#{ip}-#{$$}", 
          "_#{group}._paxos._tcp", 'local', port)
          
      ['INT', 'TERM'].each { |signal| 
        trap(signal) { handle.stop }
      }
	  end
		
		def start_drb
		  server = DRb.start_service(nil, self)
      ['INT', 'TERM'].each { |signal| 
        trap(signal) { server.stop_service }
      }
	  end
		
		def bonjour_scan
      Net::DNS::MDNSSD.browse("_#{@group}._tcp") do |b|
        Net::DNS::MDNSSD.resolve(b.name, b.type) do |r|
          drburl = "druby://#{r.target}:#{r.port}"
          replica = DRbObject.new(nil, drburl)
          yield replica
        end
      end
	  end

    def cloud_size
      replicas.size
    end

		def vote
		  @votes += 1
	  end

		def leader?
		  @leader = @votes == replicas.size
	  end
  end
end