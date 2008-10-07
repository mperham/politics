require 'socket'
require 'ipaddr'
require 'uri'
require 'drb'

require 'net/dns/mdns-sd'
require 'net/dns/resolv-mdns'
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
	module DiscoverableNode
	  
	  attr_accessor :group
	  attr_accessor :coordinator
	  
		def register(group='foo')
		  self.group = group
		  start_drb
		  register_with_bonjour(group)
		  Politics.log "Registered #{self} in group #{group} with RID #{rid}"
		  sleep 0.5
		  find_replicas(0)
		end
		
    def replicas
      @replicas ||= {}
    end
    
    def find_replicas(count)
      replicas.clear if count % 5 == 0
      return if count > 10 # Guaranteed to terminate, but not successfully :-(

      #puts "Finding replicas"
      peer_set = []
      bonjour_scan do |replica|
        (his_rid, his_peers) = replica.hello(rid)
        unless replicas.has_key?(his_rid)
          replicas[his_rid] = replica
        end
        his_peers.each do |peer|
          peer_set << peer unless peer_set.include? peer
        end
      end
      #p [peer_set.sort, replicas.keys.sort]
      if peer_set.sort != replicas.keys.sort
        # Recursively call ourselves until the network has settled down and all
        # peers have reached agreement on the peer group membership.
        sleep 0.2
        find_replicas(count + 1)
      end
      puts "Found #{replicas.size} peers: #{replicas.keys.sort.inspect}" if count == 0
      replicas
    end
    
    # Called for one peer to introduce itself to another peer.  The caller
    # sends his RID, the responder sends his RID and his list of current peer
    # RIDs.
    def hello(remote_rid)
      [rid, replicas.keys]
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
      handle = Net::DNS::MDNSSD.register("#{self.group}-#{local_ip}-#{$$}", 
          "_#{self.group}._tcp", 'local', @port)
          
      ['INT', 'TERM'].each { |signal| 
        trap(signal) { handle.stop }
      }
	  end
		
		def start_drb
		  server = DRb.start_service(nil, self)
		  @port = URI.parse(DRb.uri).port
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