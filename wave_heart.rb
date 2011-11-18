# MacRuby 0.10

framework 'Cocoa'
framework 'AudioToolbox'
load_bridge_support_file 'Files.bridgesupport'

class WaveHeart
  
  # An AudioQueue pushing an audio stream into CoreAudio HAL.
  #
  class Vessel
    attr_reader :state
    
    State = Struct.new('State', 
      :data_format,               # AudioStreamBasicDescription  
      :queue,                     # AudioQueueRef                
      :buffers,                   # AudioQueueBufferRef          
      :audio_file,                # AudioFileID                  
      :buffer_byte_size,          # UInt32                       
      :current_packet,            # SInt64                       
      :num_packets_to_read,       # UInt32                       
      :packet_descs,              # AudioStreamPacketDescription 
      :is_running )               # bool                         
    
    def initialize(file_path=nil)
      @state = State.new
      load(file_path) if file_path
    end
  
    # Callback from the AudioQueue to refill a playback buffer.
    #
    def handle_output_buffer(
      state,                      # State
      queue,                      # AudioQueueRef
      buffer )                    # AudioQueueBufferRef
    
      return unless @state.is_running
      num_of_packets = @state.num_packets_to_read
  
      AudioFileReadPackets( 
        @state.audio_file,
        false,
        bytes_read,
        @state.packet_descs,
        @state.current_packet,
        num_of_packets,
        buffer )
  
      if (packets_read > 0)
        AudioQueueEnqueueBuffer(
          @state.queue,
          buffer,
          @state.packet_descs ? num_of_packets : 0,
          @state.packet_descs )
        @state.current_packet += num_of_packets
      else
        AudioQueueStop(@state.queue, false)
        @state.is_running = false
      end
    end
    
    MaxBufferSize = 0x50000
    MinBufferSize = 0x4000
    
    # Calculate what to read as the audio queue drains.
    #
    # Returns array of buffer size & number of packets to read.
    #
    def derive_buffer_size(
      data_format,                    # AudioStreamBasicDescription
      max_packet_size,                # UInt32                     
      seconds,                        # Float64                    
      out_buffer_size=nil,            # UInt32                     
      out_num_packets_to_read=nil )   # UInt32                     
      
      
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
        out_buffer_size = MinBufferSize;
      end
      
      out_num_packets_to_read = out_buffer_size / max_packet_size;
      
      [out_buffer_size, out_num_packets_to_read]
    end
    
    def load(file_path)
      audio_file_url = CFURLCreateFromFileSystemRepresentation(
        nil, file_path, file_path.size, false )
      result = AudioFileOpenURL(
        audio_file_url, FsRdPerm, 0, @state.audio_file )
      CFRelease(audio_file_url)
      
      # get @data_format_size
      AudioFileGetPropertyInfo(
        @state.audio_file, KAudioFilePropertyDataFormat, @data_format_size, @is_writable )
      
      # get @state.data_format
      AudioFileGetProperty(
        @state.audio_file, KAudioFilePropertyDataFormat, @data_format_size, @state.data_format )
      
      init_queue
      
      # get @max_packet_size
      AudioFileGetProperty(
        @state.audio_file, KAudioFilePropertyPacketSizeUpperBound, @property_size, @max_packet_size )
      
      @state.buffer_byte_size, @state.num_packets_to_read = derive_buffer_size(
        @state.data_format, @max_packet_size, 0.5 )
    end
    
    def init_queue
      return if @state.queue
      AudioQueueNewOutput(
        @state.data_format, :handle_output_buffer, @state, 
        CFRunLoopGetCurrent(), KCFRunLoopCommonModes, 0,
        @state.queue )
    end
    
    def allocate_packet_desc
      is_format_vbr = (
        @state.data_format.mBytesPerPacket == 0 ||
        @state.data_format.mFramesPerPacket == 0 )
      
      # if is_format_vbr
      #    @state.packet_descs =
      #      (AudioStreamPacketDescription*) malloc (
      #        @state.num_packets_to_read * sizeof (AudioStreamPacketDescription)
      #        );
      #  else
      #    @state.packet_descs = nil;
      #  end
    end
  end
end