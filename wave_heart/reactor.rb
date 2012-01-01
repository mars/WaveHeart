module WaveHeart
  
  # Respond to external events.
  #
  module Reactor
    
    def self.start(opts=nil)
      opts = {} unless Hash==opts
      socket = opts[:socket]
      port = opts[:port] || 3333
      ip_address = opts[:ip_address] || '0.0.0.0'
      
      @thread = Thread.new do
        Thread.abort_on_exception = true
        EM.kqueue
        EM.error_handler do |e|
          puts "Error raised during event loop: #{e.class} #{e.message}\n      #{e.backtrace * "\n      "}"
        end
        EM.run do
          args = (socket ? [socket, nil] : [ip_address, port])
          Thread.current[:http_server_sig] = EM.start_server(*(args + [WaveHeart::Reactor::HttpServer]))
        end
      end
      
      @thread[:http_server_sig]
    end
    
    def self.stop
      EM.stop_server(@thread[:http_server_sig]) if @thread[:http_server_sig]
      EM.next_tick { EM.stop_event_loop }
    end
    
    def self.thread
      @thread
    end
    
  end
  
end
