# MacRuby 0.10

framework 'Cocoa'
framework 'AudioToolbox'

class WaveHeart
  
  # An AudioQueue pushing an audio stream into CoreAudio HAL.
  #
  class Vessel
    attr_reader( 
      :ptr,                       # Pointer to self              
      :data_format,               # AudioStreamBasicDescription  
      :data_format_ptr,           # AudioStreamBasicDescriptionPointer  
      :queue,                     # AudioQueueRef                
      :queue_ptr,                 # AudioQueueRefPointer         
      :buffers,                   # AudioQueueBufferRef          
      :audio_file,                # AudioFileID                  
      :audio_file_ptr,            # AudioFileIDPointer           
      :out_buffer_size_ptr,       # UInt32                       
      :max_packet_size_ptr,       # UInt32                       
      :current_packet,            # SInt64                       
      :num_packets_to_read,       # UInt32                       
      :packet_descs,              # AudioStreamPacketDescription 
      :is_running )               # bool                         
    
    def initialize(file_path=nil)
      @ptr = Pointer.new(:object)
      @ptr.assign(self)
      @queue_ptr = Pointer.new('^{OpaqueAudioQueue}')
      @audio_file_ptr = Pointer.new(AudioFileID.type)
      @data_format_ptr = Pointer.new(AudioStreamBasicDescription.type)
      @data_format_ptr.assign(AudioStreamBasicDescription.new)
      @max_packet_size_ptr = Pointer.new 'I'
      @out_buffer_size_ptr = Pointer.new 'I'
      @num_packets_to_read_ptr = Pointer.new 'I'
      load(file_path) if file_path
    end
    
    def stop
      AudioQueueStop(@queue, false)
      @is_running = false
    end
  
    # Callback from the AudioQueue to refill a playback buffer.
    #
    def handle_output_buffer(
      state,                      # State
      queue,                      # AudioQueueRef
      buffer )                    # AudioQueueBufferRef
    
      return unless @is_running
  
      AudioFileReadPackets( 
        @audio_file,
        false,
        bytes_read,
        @packet_descs,
        @current_packet,
        @num_packets_to_read_ptr,
        buffer )
  
      if (packets_read > 0)
        AudioQueueEnqueueBuffer(
          @queue,
          buffer,
          @packet_descs ? num_of_packets : 0,
          @packet_descs )
        @current_packet += num_of_packets
      else
        stop
      end
    end
    
    MaxBufferSize = 0x50000
    MinBufferSize = 0x4000
    
    # Calculate what to read as the audio queue drains.
    #
    def self.derive_buffer_size(
      data_format,                    # AudioStreamBasicDescription
      max_packet_size,                # UInt32                     
      seconds,                        # Float64                    
      out_buffer_size_ptr,            # => UInt32                  
      out_num_packets_to_read_ptr )   # => UInt32                  
      
      out_buffer_size = out_buffer_size_ptr[0]
      out_num_packets_to_read = out_num_packets_to_read_ptr[0]
      
      if data_format.mFramesPerPacket != 0
        num_packets_for_time =
          data_format.mSampleRate / data_format.mFramesPerPacket * seconds
        out_buffer_size = num_packets_for_time * max_packet_size
      else
        out_buffer_size =
          MaxBufferSize > max_packet_size ?
            MaxBufferSize : max_packet_size
      end
      
      if out_buffer_size > MaxBufferSize &&
        out_buffer_size > max_packet_size
          out_buffer_size = MaxBufferSize
      elsif out_buffer_size < MinBufferSize
        out_buffer_size = MinBufferSize
      end
      
      out_num_packets_to_read = out_buffer_size / max_packet_size;
      
      out_buffer_size_ptr.assign out_buffer_size
      out_num_packets_to_read_ptr.assign out_num_packets_to_read
      
      [out_buffer_size, out_num_packets_to_read]
    end
    
    def load(file_path)
      load_audio_file file_path
      get_audio_file_prop KAudioFilePropertyDataFormat, @data_format_ptr
      get_audio_file_prop KAudioFilePropertyPacketSizeUpperBound, @max_packet_size_ptr
      
      init_queue
      
      self.class.derive_buffer_size(
        @data_format_ptr[0], @max_packet_size_ptr[0], 0.5, @out_buffer_size_ptr, @num_packets_to_read_ptr )
      
      
    end
    
    def load_audio_file(file_path)
      audio_file_url = CFURLCreateFromFileSystemRepresentation(
        nil, file_path, file_path.bytesize, false )
      result = AudioFileOpenURL(
        audio_file_url, KAudioFileReadPermission, 0, @audio_file_ptr )
      CFRelease(audio_file_url)
      result
    end
    
    def get_audio_file_prop(name, return_ptr)
      raise RuntimeError, "An audio file must be loaded." unless @audio_file_ptr[0]
      
      size_ptr = Pointer.new 'I'
      return_ptr_klass = return_ptr[0].class
      size_ptr.assign( return_ptr_klass.respond_to?(:size) ? 
        return_ptr_klass.size : return_ptr[0].size )
      is_writable = Pointer.new 'I'
      
      AudioFileGetPropertyInfo(
        @audio_file_ptr[0], name, size_ptr, is_writable )
      
      AudioFileGetProperty(
        @audio_file_ptr[0], name, size_ptr, return_ptr )
    end
    
    def init_queue
      return if @queue_ptr[0]
      AudioQueueNewOutput(
        @data_format_ptr, :handle_output_buffer, @ptr, 
        CFRunLoopGetCurrent(), KCFRunLoopCommonModes, 0,
        @queue_ptr )
    end
    
    def allocate_packet_desc
      is_format_vbr = (
        @data_format_ptr[0].mBytesPerPacket == 0 ||
        @data_format_ptr[0].mFramesPerPacket == 0 )
      
      if is_format_vbr
         # @packet_descs =
         #   (AudioStreamPacketDescription*) malloc (
         #     @num_packets_to_read * sizeof (AudioStreamPacketDescription)
         #     );
       else
         @packet_descs = nil
       end
    end
  end
end

WaveHeart::Vessel.new('/Users/Shared/Jukebox/Music/Air/Talkie Walkie/10 Alone in Kyoto.m4a')
