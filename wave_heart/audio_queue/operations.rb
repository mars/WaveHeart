module WaveHeart
  class AudioQueue
    
    # Control the audio queue
    module Operations
    
      def open(audio_file_url)
        @state.with_lock do
          @audio_file_url = audio_file_url
          open_audio_file_in_c @state, @audio_file_url
          get_data_format_in_c @state
          calculate_buffer
          setup_packet_descriptions_in_c @state
          @is_primed = false
        end
        self
      end
    
      def prime
        @state.with_lock do
          new_output_in_c @state
          set_magic_cookie_in_c @state
          @state.is_running = 1
          prime_buffers_in_c @state
          @is_primed = true
        end
        self
      end
    
      def play
        prime unless @is_primed
        @state.with_lock do
          start_in_c @state
          # TODO while @state.is_running > 0 do
          #    CFRunLoopRunInMode(KCFRunLoopDefaultMode, 0.25, false)
          # end
          # CFRunLoopRunInMode(KCFRunLoopDefaultMode, 1, false)
          # cleanup
        end
        self
      end
    
      def pause
        @state.with_lock do
          pause_in_c @state
          @state.is_running = 0
        end
        self
      end
    
      def stop
        @state.with_lock do
          return self if @state.is_running < 1
          stop_in_c @state
          @state.is_running = 0
        end
        self
      end
    
      def cleanup
        @state.with_lock do
          return self if !@is_primed || @state.is_running > 0
          cleanup_in_c @state
        end
        self
      end
      
    end
    
  end
end
