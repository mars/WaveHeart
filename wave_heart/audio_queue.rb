class WaveHeart
  
  # An object-oriented interface for Apple's AudioToolbox audio queue
  #
  class AudioQueue
    
    BufferSeconds = 5
    MaxBufferSize = 327680 # 320KB
    MinBufferSize = 16384 # 16KB
    
    attr_reader :state, :data_format, :buffer_seconds, :is_primed, :run_loop_thread
    
    def initialize
      puts "#{self.class}#initialize"
      @is_primed = false
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
      
      
      puts "sample rate #{@state.format_sample_rate}, frames per packet #{@state.format_frames_per_packet}, max packet size #{@state.format_max_packet_size}, buffer seconds #{buffer_seconds}"
      puts "#{self.class}#calculate_buffer(#{@state.format_sample_rate}, #{@state.format_frames_per_packet}, #{@state.format_max_packet_size}, #{buffer_seconds})"
      calculate_buffer
      puts " => buffer_byte_size #{@state.buffer_byte_size} num_packets_to_read #{@state.num_packets_to_read}"
      
      puts "#{self.class}#setup_packet_descriptions_in_c"
      setup_packet_descriptions_in_c @state
    end
    
    def play
      puts "#{self.class}#play"
      get_run_loop
      
      puts "#{self.class}#new_output_in_c"
      new_output_in_c @state
      
      puts "#{self.class}#set_magic_cookie_in_c"
      set_magic_cookie_in_c @state
      
      @state.is_running = 1
      
      puts "@state.is_running #{@state.is_running.inspect}"
      prime unless @is_primed
      gain = 1.0
      start_in_c @state
      while @state.is_running > 0 do
         CFRunLoopRunInMode(KCFRunLoopDefaultMode, 0.25, false)
      end
      CFRunLoopRunInMode(KCFRunLoopDefaultMode, 1, false)
      cleanup
    end
    
    def stop
      puts "#{self.class}#stop"
      stop_in_c @state
      @state.is_running = 0
    end
    
    def gain=(f)
      puts "#{self.class}#gain=(#{f.inspect})"
      set_audio_queue_param_in_c @state, KAudioQueueParam_Volume, f
    end
    
    def buffer_seconds
      @buffer_seconds ||= BufferSeconds
    end
    
    def get_run_loop
      puts "#{self.class}#get_run_loop"
      @run_loop_thread ||= begin
        thread = NSThread.alloc.initWithTarget( 
          self, selector: 'get_run_loop_in_c:', object: @state )
        thread.start
        thread
      end
    end
    
    def prime
      puts "#{self.class}#prime"
      puts "RunLoop executing #{@run_loop_thread.executing?} finished #{@run_loop_thread.finished?} cancelled #{@run_loop_thread.cancelled?}"
      prime_buffers_in_c @state
      @is_primed = true
    end
    
    def cleanup
      puts "#{self.class}#cleanup"
      return if @state.is_running > 0
      cleanup_in_c @state
    end
    
    inline(:C) do |builder|
      builder.add_compile_flags '-x c++', '-lstdc++', '-I ./src'
      builder.include '<CoreFoundation/CoreFoundation.h>'
      builder.include '<CoreServices/CoreServices.h>'
      builder.include '<AudioToolbox/AudioToolbox.h>'
      builder.include '<AudioQueueState.h>'
      builder.prefix %{
        static AudioFileID theAudioFile;
        
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
        
        static void Beat(CFRunLoopTimerRef timer, void *aqState) {
          
        }
        
        static void HandleOutputBuffer(
          void                          *inUserData,
          AudioQueueRef                 inAQ, 
          AudioQueueBufferRef           inBuffer) {
          
          AudioQueueState aqs = *((AudioQueueState *) inUserData);
          
          fprintf(stderr, "aqs.mAudioFileByteSize => %d\\n", aqs.mAudioFileByteSize);
          fprintf(stderr, "aqs.isFormatVBR => %d\\n", aqs.isFormatVBR);
          fprintf(stderr, "aqs.mIsRunning => %d\\n", aqs.mIsRunning);
          
          if (!aqs.mIsRunning) {
            fprintf(stderr, "Not running, so HandleOutputBuffer returns.\\n");
            return;
          } else {
            fprintf(stderr, "Running, so HandleOutputBuffer is gettin' er done.\\n");
          }
          UInt32 numBytes = 0;
          UInt32 numPackets = aqs.mNumPacketsToRead;
          
          fprintf(stderr, "Reading %d packets from position %f in HandleOutputBuffer.\\n", numPackets, aqs.mCurrentPacket);
          
          CheckError(AudioFileReadPackets(
            theAudioFile,
            false,
            &numBytes,
            aqs.mPacketDescs, 
            aqs.mCurrentPacket,
            &numPackets,
            inBuffer->mAudioData 
          ), "HandleOutputBuffer AudioFileReadPackets failed");
          
          if (numPackets > 0) {
            inBuffer->mAudioDataByteSize = numBytes;
            CheckError(AudioQueueEnqueueBuffer( 
              aqs.mQueue,
              inBuffer,
              (aqs.mPacketDescs ? numPackets : 0),
              aqs.mPacketDescs
            ), "HandleOutputBuffer AudioQueueEnqueueBuffer failed");
            aqs.mCurrentPacket += numPackets;
          } else {
            fprintf(stderr, "Out of packets, so HandleOutputBuffer is stoppin'.\\n");
            AudioQueueStop(aqs.mQueue, false);
            aqs.mIsRunning = 0; 
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
          AudioFileClose(theAudioFile);
          CFRelease(aqState->mRunLoop);
          return mResultCode;
        };
      }
       
      builder.c %{ 
        void open_audio_file_in_c(VALUE state, VALUE filePath) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          AudioQueueState aqs = *aqState;
          
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
            &theAudioFile
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
          AudioQueueState aqs = *aqState;
          
          UInt32 dataFormatSize = sizeof (aqState->mDataFormat);
          CheckError(AudioFileGetProperty(
            theAudioFile,
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
            theAudioFile,
            kAudioFilePropertyPacketSizeUpperBound,
            &propertySize,
            &aqState->maxPacketSize
          ), "AudioFileGetProperty kAudioFilePropertyPacketSizeUpperBound failed");
          
          AudioFileGetPropertyInfo (
            theAudioFile,
            kAudioFilePropertyAudioDataByteCount,
            &propertySize,
            NULL
          );
          CheckError(AudioFileGetProperty(
            theAudioFile,
            kAudioFilePropertyAudioDataByteCount,
            &propertySize,
            &aqState->mAudioFileByteSize
          ), "AudioFileGetProperty kAudioFilePropertyAudioDataByteCount in HandleOutputBuffer");
          
          AudioFileGetPropertyInfo (
            theAudioFile,
            kAudioFilePropertyAudioDataPacketCount,
            &propertySize,
            NULL
          );
          CheckError(AudioFileGetProperty(
            theAudioFile,
            kAudioFilePropertyAudioDataPacketCount,
            &propertySize,
            &aqState->mAudioFileTotalPackets
          ), "AudioFileGetProperty kAudioFilePropertyAudioDataPacketCount in HandleOutputBuffer");
          
          fprintf(stderr, "Audio file has %d total packets.\\n", aqState->mAudioFileTotalPackets);
          fprintf(stderr, "Audio file has %d bytes.\\n", aqState->mAudioFileByteSize);
          fprintf(stderr, "Audio file has %f sample rate.\\n", aqState->mSampleRate);
          fprintf(stderr, "Audio file has %d frames per packet.\\n", aqState->mFramesPerPacket);
          fprintf(stderr, "Audio file has %d bytes per packet.\\n", aqState->mBytesPerPacket);
          
          return NULL;
        };
      }
       
      builder.c %{ 
        void get_run_loop_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          aqState->mRunLoop = CFRunLoopGetCurrent();
          CFRetain(aqState->mRunLoop);
          Boolean done = false;
          CFRunLoopTimerContext context = {0, &aqState, NULL, NULL, NULL};
          CFRunLoopTimerRef timer = CFRunLoopTimerCreate(
            kCFAllocatorDefault, 0.1, 10, 0, 0, Beat, &context);
          CFRunLoopAddTimer(aqState->mRunLoop, timer, kCFRunLoopCommonModes);
          do {
              SInt32 result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 10, true);
              if ((result == kCFRunLoopRunStopped) || (result == kCFRunLoopRunFinished))
                  done = true;
          } while (!done);
          
          CFRelease(timer);
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
            kCFRunLoopCommonModes, 
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
              theAudioFile,
              kAudioFilePropertyMagicCookieData,
              &cookieSize,
              NULL
            );
          
          if (!couldNotGetProperty && cookieSize) {
            char* magicCookie = ALLOC_N (char, cookieSize);
            
            CheckError(AudioFileGetProperty(
              theAudioFile,
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
          AudioQueueState aqs = *aqState;
          
          AudioQueueBufferRef buffers[kNumberPlaybackBuffers];
          aqState->mCurrentPacket = 0;
          
          fprintf(stderr, "aqState->mAudioFileByteSize => %d\\n", aqState->mAudioFileByteSize);
          fprintf(stderr, "aqState->isFormatVBR => %d\\n", aqState->isFormatVBR);
          fprintf(stderr, "aqState->mIsRunning => %d\\n", aqState->mIsRunning);
          
          for (int i = 0; i < kNumberPlaybackBuffers; ++i) {
            CheckError(AudioQueueAllocateBuffer(
              aqState->mQueue,
              aqState->bufferByteSize,
              &buffers[i]
            ), "AudioQueueAllocateBuffer failed");
            
            HandleOutputBuffer(
              &aqs,
              aqState->mQueue,
              buffers[i]);
          }
          
          return NULL;
        };
      }
    end
    
    # Calculate what to read as the audio queue drains.
    #
    def self.calculate_buffer_for(
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
      
      out_num_packets_to_read = out_buffer_size / max_packet_size
      
      puts "class calculate_buffer => out_buffer_size #{out_buffer_size} out_num_packets_to_read #{out_num_packets_to_read}"
      [out_buffer_size, out_num_packets_to_read]
    end
    
    # Calculate what to read as the audio queue drains for the opened audio file.
    #
    def calculate_buffer
      raise(RuntimeError, "An audio file containing data must be opened first.") unless 
        @state.file_byte_size && @state.file_byte_size > 0
      
      out_buffer_size, num_packets = self.class.calculate_buffer_for(
        @state.format_sample_rate, @state.format_frames_per_packet, @state.format_max_packet_size, buffer_seconds)
      
      puts "in calculate_buffer => out_buffer_size #{out_buffer_size} num_packets #{num_packets} total_packets #{@state.file_total_packets}"
      
      out_num_packets_to_read = num_packets > @state.file_total_packets ? 
        @state.file_total_packets : num_packets
      
      puts "out calculate_buffer => out_buffer_size #{out_buffer_size} out_num_packets_to_read #{out_num_packets_to_read}"
      
      @state.buffer_byte_size, @state.num_packets_to_read = out_buffer_size, out_num_packets_to_read
    end
  end
end
