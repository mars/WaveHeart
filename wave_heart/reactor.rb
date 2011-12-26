require 'rubygems'
require 'active_support'
require 'eventmachine'

class WaveHeart
  
  # Response to events; the HTTP REST API
  class Reactor < EM::P::HeaderAndContentProtocol
    
    def self.start(opts=nil)
      opts = {} unless Hash==opts
      socket = opts[:socket]
      port = opts[:port] || 3333
      ip_address = opts[:ip_address] || '0.0.0.0'
      
      @thread = Thread.new do
        EM.kqueue
        EM.run do
          args = (socket ? [socket, nil] : [ip_address, port])
          Thread.current[:http_server_sig] = EM.start_server(*(args + [self]))
        end
      end
      
      @thread[:http_server_sig]
    end
    
    def self.stop
      EM.stop_server(@thread[:http_server_sig]) if @thread[:http_server_sig]
    end
    
    def self.thread
      @thread
    end
    
    def receive_request headers, content
      params = parse_request(headers, content)
      data = WaveHeart::AudioQueue.process_request(params)
      send_response( 
        :status => '200 OK',
        :data => ActiveSupport::JSON.encode(data),
        :type => 'application/json' )
    rescue
      data = {"error" => "#{$!.class} #{$!.message}"}
      send_response(
        :status => '500 Server Error',
        :data => ActiveSupport::JSON.encode(data),
        :type => 'application/json' )
    end
    
    def parse_request headers, body
      req_object = ActiveSupport::JSON.decode(body) rescue {}
      req_object.merge( :http_headers => headers )
    end
    
    def build_response(content)
      r = []
      r << "HTTP/1.0 #{content[:status]}\r\n"
      r << "Date: #{Time.now}\r\n"
      r << "Content-Type: #{content[:type]}\r\n"
      r << "Content-Length: #{content[:data].size}\r\n"
      r << "\r\n"
      [r, content[:data]]
    end
  
    def send_response(content)
      headers, body = build_response(content)
      send_data(headers.join)
      send_data(body)
      close_connection_after_writing
    end
    
  end
  
end
