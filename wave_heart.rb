# MacRuby 0.10

require "rubygems"
require "inline"

framework 'AppKit'
framework 'CoreAudio'
framework 'AudioToolbox'

class WaveHeart
  
  # An AudioQueue pushing an audio stream into CoreAudio HAL.
  #
  class Vessel
    
    BufferCount = 3
    
    class AudioQueueState
    end
    
    inline do |builder|
      builder.include '<AudioToolbox/AudioToolbox.h>'
      builder.include '<MacRuby/MacRuby.h>'
      builder.add_compile_flags '-x c++', '-lstdc++'
      builder.prefix %{
        static const int kNumberBuffers = 3;
        struct AudioQueueState {
          AudioStreamBasicDescription   mDataFormat;
          AudioQueueRef                 mQueue;
          AudioQueueBufferRef           mBuffers[kNumberBuffers];
          AudioFileID                   mAudioFile;
          UInt32                        bufferByteSize;
          SInt64                        mCurrentPacket;
          UInt32                        mNumPacketsToRead;
          AudioStreamPacketDescription  *mPacketDescs;
          bool                          mIsRunning;
        };
        static void HandleOutputBuffer (
          void                          *aqData,
          AudioQueueRef                 inAQ, 
          AudioQueueBufferRef           inBuffer) {
          
          VALUE c = rb_cObject;
          c = rb_const_get(c, rb_intern("WaveHeart"));
          c = rb_const_get(c, rb_intern("Vessel"));
          
          rb_funcall(c, rb_intern("handle_output_buffer"), 3, aqData, inAQ, inBuffer);
        }
      }
      builder.struct_name = 'AudioQueueState'
      builder.accessor :is_running, 'VALUE', :mIsRunning
      builder.c %{
        VALUE init_state_in_c(VALUE klass) {
          AudioQueueState* aqData = NULL;
          VALUE v = Data_Wrap_Struct(klass, NULL, NULL, aqData);
          return v;
        };
      }
       
      builder.c %{ 
        int init_queue_in_c(VALUE state) {
          AudioQueueState* aqData;
          Data_Get_Struct(state, AudioQueueState, aqData);
          int mResultCode;
          mResultCode = AudioQueueNewOutput(
            &aqData->mDataFormat, 
            HandleOutputBuffer, 
            &aqData, 
            CFRunLoopGetCurrent(), 
            NULL, 
            0, 
            &aqData->mQueue);
          return mResultCode;
        };
      }
    end
    
    attr_reader( 
      :state,                     # Pointer to Ruby C AudioQueueState struct
      :ptr,                       # Pointer to self              
      :queue_ref_ptr,             # Pointer to Ruby C AudioQueueRef struct
      :data_format,               # AudioStreamBasicDescription  
      :data_format_ptr,           # AudioStreamBasicDescriptionPointer  
      :queue,                     # AudioQueueRef                
      :queue_ptr,                 # AudioQueueRefPointer         
      :buffers,                   # AudioQueueBufferRef          
      :audio_file_url,            # AudioFileURL                 
      :audio_file,                # AudioFileID                  
      :audio_file_ptr,            # AudioFileIDPointer           
      :out_buffer_size_ptr,       # UInt32                       
      :max_packet_size_ptr,       # UInt32                       
      :current_packet_ptr,        # SInt64                       
      :num_packets_to_read_ptr,   # UInt32                       
      :packet_descs_ptr,          # AudioStreamPacketDescriptionPointer 
      :is_running )               # bool                         
    
    def initialize(file_path=nil)
      puts "#{self.class}.new"
      @audio_file_url = file_path
      
      p = Pointer.new '@'
      p.assign AudioQueueState
      @state = init_state_in_c(AudioQueueState)
      # @ptr = Pointer.new '@'
      # @ptr.assign self
      # @buffers = (0...BufferCount).collect {|i| Pointer.new '^{AudioQueueBuffer}' }
      @audio_file_ptr = Pointer.new AudioFileID.type
      @data_format_ptr = Pointer.new AudioStreamBasicDescription.type
      @data_format_ptr.assign AudioStreamBasicDescription.new
      @max_packet_size_ptr = Pointer.new 'I'
      @out_buffer_size_ptr = Pointer.new 'I'
      @current_packet_ptr = Pointer.new 'l'
      @num_packets_to_read_ptr = Pointer.new 'I'
      
      load
    end
    
    def stop
      puts "stop"
      cAudioQueueStop(@queue_ref_ptr, false)
      @is_running = false
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
      puts "derive_buffer_size"            
      
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
    
    def load(file_path=nil)
      puts "load"
      @audio_file_url = file path if file_path
      load_audio_file @audio_file_url
      get_audio_file_prop KAudioFilePropertyDataFormat, @data_format_ptr
      get_audio_file_prop KAudioFilePropertyPacketSizeUpperBound, @max_packet_size_ptr
      
      self.class.derive_buffer_size(
        @data_format_ptr[0], @max_packet_size_ptr[0], 0.5, @out_buffer_size_ptr, @num_packets_to_read_ptr )
      
      init_packet_desc
      
      init_queue
      init_magic_cookie
      init_buffers
      gain = 1.0
      play
    end
    
    # sets @audio_file_ptr
    #
    def load_audio_file(file_path)
      puts "load_audio_file"
      audio_file_url = CFURLCreateFromFileSystemRepresentation(
        nil, file_path, file_path.bytesize, false )
      result = AudioFileOpenURL(
        audio_file_url, KAudioFileReadPermission, 0, @audio_file_ptr )
      CFRelease(audio_file_url)
      result
    end
    
    def get_audio_file_prop(name, return_ptr)
      puts "get_audio_file_prop"
      raise RuntimeError, "An audio file must be loaded." unless @audio_file_ptr[0]
      
      size_ptr = Pointer.new 'I'
      return_ptr_klass = return_ptr[0].class
      size_ptr.assign( return_ptr_klass.respond_to?(:size) ? 
        return_ptr_klass.size : return_ptr[0].size )
      is_writable = Pointer.new 'I'
      
      AudioFileGetPropertyInfo(
        @audio_file_ptr[0], name, size_ptr, is_writable )
      result = AudioFileGetProperty(
        @audio_file_ptr[0], name, size_ptr, return_ptr )
      raise(RuntimeError, "AudioFileGetProperty returned #{result}") unless result==0
      result
    end
    
    def init_packet_desc
      puts "init_packet_desc"
      is_format_vbr = (
        @data_format_ptr[0].mBytesPerPacket == 0 ||
        @data_format_ptr[0].mFramesPerPacket == 0 )
      
      @packet_descs_ptr = is_format_vbr ?
        Pointer.new(AudioStreamPacketDescription.type, @num_packets_to_read_ptr[0]) : nil
    end
    
    def init_magic_cookie
      puts "init_magic_cookie"
      cookie_size = Pointer.new 'I'
      result = AudioFileGetPropertyInfo(
        @audio_file_ptr[0],
        KAudioFilePropertyMagicCookieData,
        cookie_size,
        nil )
      
      if result == 0 && cookie_size[0] > 0
        magic_cookie = Pointer.new :char
        
        AudioFileGetProperty(
          @audio_file_ptr[0],
          KAudioFilePropertyMagicCookieData,
          cookie_size,
          magic_cookie )
        
        result = AudioQueueSetProperty(
          @queue_ref_ptr,
          KAudioQueueProperty_MagicCookie,
          magic_cookie,
          cookie_size[0] )
        raise(RuntimeError, "AudioQueueSetProperty returned #{result}") unless result==0
      end
    end
    
    def handle_output_buffer(state, queue, buffer_ptr)
      self.class.handle_output_buffer(state, queue, buffer_ptr)
    end
    
    def init_queue
      puts "init_queue"
      #return if @queue_ref_ptr[0]
      result = init_queue_in_c(@state)
      raise(RuntimeError, "AudioQueueNewOutput returned #{result}") unless result==0
      result
    end
    
    def init_buffers
      puts "init_buffers"
      @current_packet_ptr.assign 0
      
      @buffers.each do |buffer_ptr|
        result = AudioQueueAllocateBuffer(
          @queue_ref_ptr, @out_buffer_size_ptr[0], buffer_ptr )
        raise(RuntimeError, "AudioQueueAllocateBuffer returned #{result}") unless result==0
        handle_output_buffer(
          @ptr, @queue_ref_ptr, buffer_ptr )
      end
    end
    
    def gain=(f=1.0)
      puts "gain="
      AudioQueueSetParameter(@queue_ref_ptr, KAudioQueueParam_Volume, f)
    end
    
    def play
      puts "play"
      @is_running = true
      result = AudioQueueStart(@queue_ref_ptr, nil)
      raise(RuntimeError, "AudioQueueStart returned #{result}") unless result==0
      while @is_running do
         CFRunLoopRunInMode(KCFRunLoopDefaultMode, 0.25, false)
      end
      CFRunLoopRunInMode(KCFRunLoopDefaultMode, 1, false)
      clean_up
    end
    
    def clean_up
      puts "clean_up"
      AudioQueueDispose(@queue_ref_ptr, true)
      AudioFileClose(@audio_file_ptr)
    end
    
    # Callback from the AudioQueue to refill a playback buffer.
    #
    def self.handle_output_buffer(
      state,                      # State
      queue,                      # AudioQueueRef
      buffer_ptr )                # AudioQueueBufferRef
      puts "handle_output_buffer"
      
      state.cast!('@')[0]
      
      return unless state.is_running
      
      bytes_read_ptr = Pointer.new 'I'
      
      result = AudioFileReadPackets( 
        state.audio_file_ptr[0],
        false,
        bytes_read_ptr,
        state.packet_descs_ptr,
        state.current_packet_ptr[0],
        state.num_packets_to_read_ptr,
        buffer_ptr )
      raise(RuntimeError, "AudioFileReadPackets returned #{result}") unless result==0
      
      if (bytes_read_ptr[0] > 0)
        result = AudioQueueEnqueueBuffer(
          queue,
          buffer_ptr,
          state.packet_descs_ptr[0] ? state.num_packets_to_read_ptr[0] : 0,
          state.packet_descs_ptr )
        raise(RuntimeError, "AudioQueueEnqueueBuffer returned #{result}") unless result==0
        state.current_packet_ptr.assign = 
          state.current_packet_ptr[0] + state.num_packets_to_read_ptr[0]
      else
        stop
      end
    end
  end
  
  class AppDelegate
    def applicationDidFinishLaunching(notification)
      v = Vessel.new('/Users/Shared/Jukebox/Music/Air/Talkie Walkie/10 Alone in Kyoto.m4a')
    end
  end
end

app = NSApplication.sharedApplication
app.delegate = WaveHeart::AppDelegate.new
app.run

