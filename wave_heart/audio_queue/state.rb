class WaveHeart
  class AudioQueue
    
    # C-structure wrapped in a Ruby object
    class State
      
      class << self
        alias_method :new_in_ruby, :new
        
        def new
          new_in_c
        end
      end
      
      inline(:C) do |builder|
        builder.add_compile_flags '-x c++', '-lstdc++', '-I ./src'
        builder.include '<AudioToolbox/AudioToolbox.h>'
        builder.include '<AudioQueueState.h>'
        
        builder.struct_name = 'AudioQueueState'
        builder.accessor :is_running, 'VALUE', :mIsRunning
        builder.accessor :buffer_byte_size, 'unsigned int', :bufferByteSize
        builder.accessor :num_packets_to_read, 'unsigned int', :mNumPacketsToRead
        builder.reader :format_is_vbr, 'VALUE', :isFormatVBR
        builder.reader :format_sample_rate, 'unsigned int', :mSampleRate
        builder.reader :format_frames_per_packet, 'unsigned int', :mFramesPerPacket
        builder.reader :format_bytes_per_packet, 'unsigned int', :mBytesPerPacket
        builder.reader :format_max_packet_size, 'unsigned int', :maxPacketSize
        
        builder.c_singleton %{
          VALUE new_in_c() {
            AudioQueueState* aqState = ALLOC (AudioQueueState);
            VALUE aqs = Data_Wrap_Struct(self, NULL, NULL, aqState);
            rb_funcall(aqs, rb_intern("initialize"), 0);
            return aqs;
          };
        }
        
      end
    end
    
  end
end