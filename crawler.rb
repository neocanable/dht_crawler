# -*- encoding: utf-8 -*-

require 'socket'
require 'digest'
require 'pry'
require 'bencode'
require 'ipaddr'

require File.expand_path(File.dirname(__FILE__) + "/infohash")

BOOTSTRAP_NODES = [
  {host: "router.utorrent.com", port: 6881},
  {host: "router.bittorrent.com", port: 6881},
  {host: "dht.transmissionbt.com", port: 6881},
  {host: "router.bitcomet.com", port: 6881},
  {host: "dht.aelitis.com", port: 6881},
]

TID_LENGTH       = 2
RE_JOIN_INTERVAL = 2
TOKEN_LENGTH     = 2
SLEEP_INTERVAL   = 1

class Tool
	class << self
    # generate dht server node id
		def random_node_id(length = 20)
      random_id = random_str(length)
			Digest::SHA1.digest(random_id)
		end

		def random_str(length)
			length.times.collect{|i| Random.rand(255).chr }.join
		end

    def nid2long(nid)
      nid.unpack('H*').join.hex
    end

    def get_neighbor(target, nid, last = 10)
    	target[0..(last-1)] + nid[last..-1]
    end
	end
end

class Server
  attr_accessor :bind_ip, :bind_port, :socket, :nid, :list, :infohash_list

  def initialize(bind_ip, bind_port, max_node_size)
  	self.nid       = Tool.random_node_id
    self.bind_ip   = bind_ip
    self.bind_port = bind_port
    socket         = UDPSocket.new

    socket.setsockopt(Socket::SOL_SOCKET,Socket::SO_BROADCAST, 1)
    socket.bind(self.bind_ip, self.bind_port)
    self.socket = socket
    self.list   = []  # For route table
    self.infohash_list = []
  end

  def run
    i = 0
  	while true
  		data = nil
  		begin
  			data = self.socket.recvfrom_nonblock(65536)
        parse_recv_msg(data)
  		rescue IO::EAGAINWaitReadable => e
        #p e
      rescue Exception => e
        #p e
  		end
      sleep SLEEP_INTERVAL

  		self.join_dht if (i % RE_JOIN_INTERVAL) == 0
      i += 1
  	end
  end

  def join_dht
  	BOOTSTRAP_NODES.each do |address|
  		self.send_find_node(address)
  	end
  end


  def parse_recv_msg(data)
    decoded_msg = data.first.bdecode
    address     = {host: data.last[2], port: data.last[1]}
    key_y = decoded_msg['y']
    key_q = decoded_msg['q']

    if key_y == 'r'
      self.parse_nodes(decoded_msg)
    else
      if key_q == 'get_peers'
        self.parse_get_peers_request(decoded_msg, address)
      elsif key_q == 'find_node'
        # TODO
      elsif key_q == 'announce_peer'
        self.parse_get_announce_peer(decoded_msg)
      end
    end
  end

  def parse_get_peers_request(msg, address)
    infohash = msg["a"]["info_hash"]
    original = infohash.unpack('H*').first.upcase
    p "find original: #{original}"
    info_hash = Infohash.new(original) # do what your want

    tid = msg["t"]
    nid = msg["a"]["id"]
    token = infohash[0,TOKEN_LENGTH]

    msg = {
        "t" => tid,
        "y" => "r",
        "r" => {
            "id" => Tool.get_neighbor(infohash, self.nid),
            "nodes" => "",
            "token" => token
        }
    }
    self.send_krpc(msg, address)
  end

  def send_find_node(address, nid = nil)
  	nid = nid.nil? ? self.nid : Tool.get_neighbor(nid, self.nid)
  	tid = Tool.random_str(TID_LENGTH)
    msg = {
        "t" => tid,
        "y" => "q",
        "q" => "find_node",
        "a" => {
            "id" => nid,
            "target" => Tool.random_node_id
        }
    }
    self.send_krpc(msg, address)
  end

  def parse_nodes(msg)
    node_str = msg["r"]["nodes"]
    list     = []
    length   = node_str.to_s.length
    return list if (length % 26) != 0

    i = 0
    while i < length
      nid  = node_str[i,20]
      s    = node_str[(i+20),4]
      ip   = IPAddr.new(s.unpack("N").first, Socket::AF_INET).to_s
      port = node_str[(i+24), 2].unpack("H*").first.hex
      # p "#{ip}:#{port}"
      list << {host: ip, port: port, nid: nid}
      i += 26
    end

    list.uniq.each do |info|
      self.send_find_node({host: info[:host], port: info[:port]}, info[:nid])
    end

  end

  def send_krpc(msg, address)
  	begin
  		self.socket.send msg.bencode, 0, address[:host], address[:port]
  	rescue Exception => e
  		#p e.backtrace
  	end
  end

  def self.run(process_count = 5)
    start = 6881
    process_count.times.each_with_index do |i, index|
      fork do
        server = Server.new('0.0.0.0', start + i, 20)
        server.run
      end
    end
  end
end


Server.run(5)
