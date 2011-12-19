class WaveHeart
  
  # An object-oriented interface for Apple's AudioToolbox audio queue
  #
  class AudioQueue
    
    BufferSeconds = 5
    MaxBufferSize = 327680 # 320KB
    MinBufferSize = 16384 # 16KB
    
    attr_reader :state, :data_format, :buffer_seconds, :is_primed
    
    def initialize
      puts "#{self.class}#initialize"
      @is_primed = false
      @data_format = Pointer.new AudioStreamBasicDescription.type
      @data_format.assign AudioStreamBasicDescription.new
      @state = State.new
      self
    end
    
    def open(audio_file_url)
      puts "#{self.class}#open"
      @is_primed = false
      puts "#{self.class}#open_audio_file_in_c"
      open_audio_file_in_c @state, audio_file_url
      
      puts "#{self.class}#get_data_format_in_c"
      get_data_format_in_c @state
    end
    
    def play
      puts "#{self.class}#play"
      
      puts "#{self.class}#new_output_in_c"
      new_output_in_c @state
      
      puts "#{self.class}#set_magic_cookie_in_c"
      set_magic_cookie_in_c @state
      
      puts "self.class.derive_buffer_size(#{@state.format_sample_rate}, #{@state.format_frames_per_packet}, #{@state.format_max_packet_size}, #{buffer_seconds})"
      @state.buffer_byte_size, @state.num_packets_to_read = self.class.derive_buffer_size(
        @state.format_sample_rate, @state.format_frames_per_packet, @state.format_max_packet_size, buffer_seconds)
      puts " => buffer_byte_size #{@state.buffer_byte_size} num_packets_to_read #{@state.num_packets_to_read}"
      
      @state.is_running = true
      prime unless @is_primed
      gain = 1.0
      start_in_c @state
      while @state.is_running do
         CFRunLoopRunInMode(KCFRunLoopDefaultMode, 0.25, false)
      end
      CFRunLoopRunInMode(KCFRunLoopDefaultMode, 1, false)
      cleanup
    end
    
    def stop
      puts "#{self.class}#stop"
      stop_in_c @state
      @state.is_running = false
      result
    end
    
    def gain=(f)
      puts "#{self.class}#gain=(#{f.inspect})"
      set_audio_queue_param_in_c @state, KAudioQueueParam_Volume, f
      result
    end
    
    def buffer_seconds
      @buffer_seconds ||= BufferSeconds
    end
    
    def prime
      puts "#{self.class}#prime"
      result = prime_buffers_in_c @state
      raise(RuntimeError, "AudioQueueAllocateBuffer returned #{result}") unless result==0
      @is_primed = true
      result
    end
    
    def cleanup
      puts "#{self.class}#cleanup"
      return if @state.is_running
      result = cleanup_in_c @state
      raise(RuntimeError, "AudioQueueDispose returned #{result}") unless result==0
      result
    end
    
    inline(:C) do |builder|
      builder.add_compile_flags '-x c++', '-lstdc++', '-I ./src'
      builder.include '<CoreFoundation/CoreFoundation.h>'
      builder.include '<CoreServices/CoreServices.h>'
      builder.include '<AudioToolbox/AudioToolbox.h>'
      builder.include '<AudioQueueState.h>'
      builder.prefix %{
        
        static void CheckError(OSStatus error, const char *operation) {
          if (error == noErr) return;
          char errorString[20];
          // See if it appears to be a 4-char-code
          *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
          if (isprint(errorString[1]) && isprint(errorString[2]) &&
              isprint(errorString[3]) && isprint(errorString[4])) {
              errorString[0] = errorString[5] = '\\'';
              errorString[6] = '\\0';
          } else
              // No, format it as an integer
              sprintf(errorString, "%d", (int)error);
          fprintf(stderr, "Error: %s (%s)\\n", operation, errorString);
          exit(1);
        }
        
        static void HandleOutputBuffer(
          void                          *aqState,
          AudioQueueRef                 inAQ, 
          AudioQueueBufferRef           inBuffer) {
          
          AudioQueueState *pAqData = (AudioQueueState *) aqState;
          if (!pAqData->mIsRunning) return;
          UInt32 numBytes;
          UInt32 numPackets = pAqData->mNumPacketsToRead;
          CheckError(AudioFileReadPackets(
            pAqData->mAudioFile,
            false,
            &numBytes,
            pAqData->mPacketDescs, 
            pAqData->mCurrentPacket,
            &numPackets,
            inBuffer->mAudioData 
          ), "AudioFileReadPackets failed");
          
          if (numPackets > 0) {
            inBuffer->mAudioDataByteSize = numBytes;
            CheckError(AudioQueueEnqueueBuffer( 
              pAqData->mQueue,
              inBuffer,
              (pAqData->mPacketDescs ? numPackets : 0),
              pAqData->mPacketDescs
            ), "AudioQueueEnqueueBuffer failed");
            pAqData->mCurrentPacket += numPackets;
          } else {
            AudioQueueStop(pAqData->mQueue, false);
            pAqData->mIsRunning = false; 
          }
        }
      }
       
      builder.c %{ 
        void set_audio_queue_param_in_c(VALUE state, VALUE param, VALUE value) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          CheckError(AudioQueueSetParameter(
            aqState->mQueue, param, value
          ), "AudioQueueSetParameter failed");
          return NULL;
        };
      }
       
      builder.c %{ 
        void start_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          CheckError(AudioQueueStart(
            aqState->mQueue, NULL
          ), "AudioQueueStart failed");
          return NULL;
        };
      }
       
      builder.c %{ 
        void stop_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          CheckError(AudioQueueStop(
            aqState->mQueue, false
          ), "AudioQueueStop failed");
          return NULL;
        };
      }
       
      builder.c %{ 
        int cleanup_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          int mResultCode;
          mResultCode = AudioQueueDispose(aqState->mQueue, true);
          AudioFileClose(aqState->mAudioFile);
          return mResultCode;
        };
      }
       
      builder.c %{ 
        void open_audio_file_in_c(VALUE state, VALUE filePath) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          
          VALUE str = StringValue(filePath);
          const char *fp = RSTRING_PTR(str);
          int str_len RSTRING_LEN(str);
          
          CFURLRef audioFileURL = CFURLCreateFromFileSystemRepresentation(
            NULL,
            (Byte *) fp,
            str_len,
            false);
          
          CheckError(AudioFileOpenURL(
            audioFileURL,
            fsRdPerm,
            0,
            &aqState->mAudioFile
          ), "AudioFileOpenURL failed");
          
          CFRelease(audioFileURL);
          return NULL;
        };
      }
      
      builder.c %{ 
        void setup_packet_descriptions_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          
          if (aqState->isFormatVBR) {
            aqState->mPacketDescs = ALLOC_N (
                AudioStreamPacketDescription, aqState->mNumPacketsToRead);
          } else {
            aqState->mPacketDescs = NULL;
          }
          
          return NULL;
        };
      }
       
      builder.c %{ 
        void get_data_format_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          
          UInt32 dataFormatSize = sizeof (aqState->mDataFormat);
          CheckError(AudioFileGetProperty(
            aqState->mAudioFile,
            kAudioFilePropertyDataFormat,
            &dataFormatSize,
            &aqState->mDataFormat
          ), "AudioFileGetProperty failed");
          aqState->mSampleRate = aqState->mDataFormat.mSampleRate;
          aqState->mFramesPerPacket = aqState->mDataFormat.mFramesPerPacket;
          aqState->mBytesPerPacket = aqState->mDataFormat.mBytesPerPacket;
          
          aqState->isFormatVBR = (
            aqState->mDataFormat.mBytesPerPacket == 0 ||
            aqState->mDataFormat.mFramesPerPacket == 0
          );
          
          UInt32 propertySize = sizeof (aqState->maxPacketSize);
          CheckError(AudioFileGetProperty(
            aqState->mAudioFile,
            kAudioFilePropertyPacketSizeUpperBound,
            &propertySize,
            &aqState->maxPacketSize
          ), "AudioFileGetProperty failed");
          
          return NULL;
        };
      }
       
      builder.c %{ 
        void new_output_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          
          CheckError(AudioQueueNewOutput(
            &aqState->mDataFormat, 
            HandleOutputBuffer, 
            &aqState, 
            NULL, 
            NULL, 
            0, 
            &aqState->mQueue
          ), "AudioQueueNewOutput failed");
          
          return NULL;
        };
      }
       
      builder.c %{ 
        void set_magic_cookie_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          
          UInt32 cookieSize = sizeof (UInt32);
          bool couldNotGetProperty =
            AudioFileGetPropertyInfo(
              aqState->mAudioFile,
              kAudioFilePropertyMagicCookieData,
              &cookieSize,
              NULL
            );
          
          if (!couldNotGetProperty && cookieSize) {
            char* magicCookie = ALLOC_N (char, cookieSize);
            
            CheckError(AudioFileGetProperty(
              aqState->mAudioFile,
              kAudioFilePropertyMagicCookieData,
              &cookieSize,
              magicCookie
            ), "AudioFileGetProperty failed");
            
            CheckError(AudioQueueSetProperty(
              aqState->mQueue,
              kAudioQueueProperty_MagicCookie,
              magicCookie,
              cookieSize
            ), "AudioQueueSetProperty failed");
          }
          
          return NULL;
        };
      }
       
      builder.c %{ 
        void prime_buffers_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          
          aqState->mCurrentPacket = 0;
          
          for (int i = 0; i < kNumberBuffers; ++i) {
            CheckError(AudioQueueAllocateBuffer(
              aqState->mQueue,
              aqState->bufferByteSize,
              &aqState->mBuffers[i]
            ), "AudioQueueAllocateBuffer failed");
            
            HandleOutputBuffer(
              &aqState,
              aqState->mQueue,
              aqState->mBuffers[i]);
          }
          
          return NULL;
        };
      }
    end
    
    # Calculate what to read as the audio queue drains.
    #
    def self.derive_buffer_size(
      sample_rate,                        # UInt32                     
      frames_per_packet,                  # UInt32                     
      max_packet_size,                    # UInt32                     
      seconds )                           # UInt32                     
      
      if frames_per_packet != 0
        num_packets_for_time =
          sample_rate / frames_per_packet * seconds
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
      
      [out_buffer_size, out_num_packets_to_read]
    end
  end
end
