module WaveHeart
  module Reactor
  
    # The HTTP REST API server
    class HttpServer < EM::Connection
      include EM::HttpServer
      
      class ResponseError < StandardError; end
      class NotFound < ResponseError; end
      class BadRequest < ResponseError; end
      
      CollectionUriMatch = /^\/$/
      MemberUriMatch = /^\/(\d+)\/?$/
      MemberActionUriMatch = /^\/(\d+)\/([^\?\#\/]+)(\/([^\?\#\/]+)|)/
    
      def post_init
        super
        no_environment_strings
      end
    
      def process_http_request
        # the http request details are available via the following instance variables:
        #   @http_protocol
        #   @http_request_method
        #   @http_cookie
        #   @http_if_none_match
        #   @http_content_type
        #   @http_path_info
        #   @http_request_uri
        #   @http_query_string
        #   @http_post_content
        #   @http_headers
        
        response = EM::DelegatedHttpResponse.new(self)
        response.content_type 'application/json'
        
        status, headers, data = process_request!
        response.content = MultiJson.encode(data)
        response.headers = headers || {}
        response.status = status || 200
      rescue
        response.content = MultiJson.encode({
          "error" => {
            "type" => $!.class,
            "message" => $!.message,
            "backtrace" => $!.backtrace }})
        response.status = case $!
          when BadRequest, ArgumentError then 400
          when NotFound then 404
          else 500
        end
      ensure
        response.send_response
      end
      
      def process_request!
        # puts @http_headers.inspect
        # puts @http_request_method.inspect
        # puts @http_path_info.inspect
        # puts @http_request_uri.inspect
        # puts @http_query_string.inspect
        # puts @http_post_content.inspect
        
        case @http_request_method
        when /GET/i
          case @http_path_info
          when CollectionUriMatch
            [200, nil, { "audio_queues" => WaveHeart::AudioQueue.with_all {|all| all.collect {|aq| aq.audio_file_url }} }]
          when MemberUriMatch
            id = $~[1].to_i
            queue = WaveHeart::AudioQueue::All[id]
            raise(NotFound, "Audio Queue ID #{id} not found") unless queue
            [200, nil, { "audio_queue" => queue.to_h }]
          else
            raise(NotFound, "Resource not found: #{@http_request_method} #{@http_path_info}")
          end
        when /PUT/i
          case @http_path_info
          when MemberActionUriMatch
            id = $~[1].to_i
            queue = WaveHeart::AudioQueue::All[id]
            raise(NotFound, "Audio Queue ID #{id} not found") unless queue
            action = $~[2]
            value = $~[4]
            action += '=' if value
            raise(BadRequest, "Unsupported action: #{action}") unless 
              WaveHeart::AudioQueue.api_method?(action)
            action_args = value ? [action, value] : [action]
            queue.send(*action_args)
            [200, nil, { "audio_queue" => queue.to_h }]
          else
            raise(NotFound, "Resource not found: #{@http_request_method} #{@http_path_info}")
          end
        when /POST/i
          case @http_path_info
          when CollectionUriMatch
            queue_attributes = MultiJson.decode(@http_post_content)
            queue_index = nil
            queue = AudioQueue.new(queue_attributes["audio_queue"]["audio_file_url"]) do |q|
              queue_index = WaveHeart::AudioQueue::All.size-1
            end
            [201, {'Location' => "/#{queue_index}"}, { "audio_queue" => queue.to_h }]
          else
            raise(NotFound, "Resource not found: #{@http_request_method} #{@http_path_info}")
          end
        when /DELETE/i
          case @http_path_info
          when MemberUriMatch
            id = $~[1].to_i
            queue = WaveHeart::AudioQueue::All[id]
            raise(NotFound, "Audio Queue ID #{id} not found") unless queue
            queue.stop.cleanup
            WaveHeart::AudioQueue.with_all {|all| all[all.index(queue)] = nil }
            [204, nil, {}]
          else
            raise(NotFound, "Resource not found: #{@http_request_method} #{@http_path_info}")
          end
        else
          raise(BadRequest, "Unsupported HTTP verb: #{@http_request_method}")
        end
      end
      
    end
  end
end

