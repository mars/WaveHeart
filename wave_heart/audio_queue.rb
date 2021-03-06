module WaveHeart
  
  # An object-oriented interface for Apple's AudioToolbox audio queue
  #
  # http://developer.apple.com/library/mac/#documentation/MusicAudio/Reference/AudioQueueReference
  #
  class AudioQueue
    include Operations
    include Parameters
    
    def self.api_methods
      @api_methods = Operations.instance_methods + Parameters.instance_methods
    end
    
    def self.api_method?(v)
      api_methods.include?(v.to_sym)
    end
    
    # Thread safety for access to the collection of all queues.
    #
    def self.with_lock
      AllLock.lock
      yield
    ensure
      AllLock.unlock
    end
    
    # Thread safe execution of a block with the collection all audio 
    # queues as the argument.
    #
    def self.with_all
      with_lock do
        yield All
      end
    end
    
    def self.clear_all
      with_all do |all|
        all.each do |aq|
          aq.stop.cleanup if aq.respond_to?(:stop)
        end
        all.slice!(0..-1)
      end
    end
    
    AllLock = NSLock.alloc.init
    All = []
    
    BufferSeconds = 5
    MaxBufferSize = 327680 # 320KB
    MinBufferSize = 16384 # 16KB
    
    attr_reader :audio_file_url, :state, :data_format, :buffer_seconds, :is_primed
    
    # Accepts a block to do work during the All lock.
    #
    def initialize(audio_file_url=nil)
      @is_primed = false
      @state = State.new
      open audio_file_url if audio_file_url
      self.class.with_lock do
        All << self
        yield(self) if block_given?
      end
    end
    
    def to_h
      @state.with_lock do
        {
          "audio_file_url" => @audio_file_url,
          "is_running" => @state.is_running > 0,
          "volume" => volume,
          "pan" => pan,
          "volume_ramp_seconds" => volume_ramp_seconds
        }
      end
    end
    
    inline(:C) do |builder|
      builder.add_compile_flags '-x c++', '-lstdc++', '-I ./src'
      builder.include '<CoreFoundation/CoreFoundation.h>'
      builder.include '<CoreServices/CoreServices.h>'
      builder.include '<AudioToolbox/AudioToolbox.h>'
      builder.include '<utils.h>'
      builder.include '<AudioQueueState.h>'
      builder.prefix %{
        static void Beat(CFRunLoopTimerRef timer, void *aqState) {}
        
        static void HandleOutputBuffer(
          void                          *inUserData,
          AudioQueueRef                 inAQ, 
          AudioQueueBufferRef           inBuffer) {
          
          AudioQueueState *aqs = (AudioQueueState *) inUserData;
          if (!aqs->mIsRunning) return;
          
          UInt32 numBytes = 0;
          UInt32 numPackets = aqs->mNumPacketsToRead;
          
          //fprintf(stderr, "Reading %d packets from position %lld in HandleOutputBuffer.\\n", numPackets, aqs->mCurrentPacket);
          
          CheckError(AudioFileReadPackets(
            aqs->mAudioFile,
            false,
            &numBytes,
            aqs->mPacketDescs, 
            aqs->mCurrentPacket,
            &numPackets,
            inBuffer->mAudioData 
          ), "HandleOutputBuffer AudioFileReadPackets failed");
          
          if (numPackets > 0) {
            inBuffer->mAudioDataByteSize = numBytes;
            //fprintf(stderr, "Enqueuing buffer of %d bytes.\\n", numBytes);
            CheckError(AudioQueueEnqueueBuffer( 
              aqs->mQueue,
              inBuffer,
              (aqs->mPacketDescs ? numPackets : 0),
              aqs->mPacketDescs
            ), "HandleOutputBuffer AudioQueueEnqueueBuffer failed");
            if (aqs->mCurrentPacket < 1) {
              CheckError(AudioQueuePrime( 
                aqs->mQueue,
                0,
                NULL
              ), "HandleOutputBuffer AudioQueuePrime failed");
            }
            aqs->mCurrentPacket += numPackets;
          } else {
            //fprintf(stderr, "No more packets.\\n");
            AudioQueueStop(aqs->mQueue, false);
            aqs->mIsRunning = 0; 
          }
        }
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
        void pause_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          CheckError(AudioQueuePause(
            aqState->mQueue
          ), "AudioQueuePause failed");
          return NULL;
        };
      }
       
      builder.c %{ 
        void cleanup_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          CheckError(AudioQueueDispose(
            aqState->mQueue, true
          ), "AudioQueueDispose failed");
          CheckError(AudioFileClose(
            aqState->mAudioFile
          ), "AudioFileClose failed");
          //CFRelease(aqState->mRunLoop);
          return NULL;
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
          ), "AudioFileGetProperty kAudioFilePropertyDataFormat failed");
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
          ), "AudioFileGetProperty kAudioFilePropertyPacketSizeUpperBound failed");
          
          AudioFileGetPropertyInfo (
            aqState->mAudioFile,
            kAudioFilePropertyAudioDataByteCount,
            &propertySize,
            NULL
          );
          CheckError(AudioFileGetProperty(
            aqState->mAudioFile,
            kAudioFilePropertyAudioDataByteCount,
            &propertySize,
            &aqState->mAudioFileByteSize
          ), "AudioFileGetProperty kAudioFilePropertyAudioDataByteCount in HandleOutputBuffer");
          
          AudioFileGetPropertyInfo (
            aqState->mAudioFile,
            kAudioFilePropertyAudioDataPacketCount,
            &propertySize,
            NULL
          );
          CheckError(AudioFileGetProperty(
            aqState->mAudioFile,
            kAudioFilePropertyAudioDataPacketCount,
            &propertySize,
            &aqState->mAudioFileTotalPackets
          ), "AudioFileGetProperty kAudioFilePropertyAudioDataPacketCount in HandleOutputBuffer");
          
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
            aqState, 
            aqState->mRunLoop, 
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
          
          AudioQueueBufferRef buffers[kNumberPlaybackBuffers];
          aqState->mCurrentPacket = 0;
          
          for (int i = 0; i < kNumberPlaybackBuffers; ++i) {
            CheckError(AudioQueueAllocateBuffer(
              aqState->mQueue,
              aqState->bufferByteSize,
              &buffers[i]
            ), "AudioQueueAllocateBuffer failed");
            
            HandleOutputBuffer(
              aqState,
              aqState->mQueue,
              buffers[i]);
          }
          
          return NULL;
        };
      }
    end
    
    # All inline-C (*_in_c) methods are private throughout WaveHeart.
    instance_methods.each do |m|
      private m.to_sym if /_in_c$/===m.to_s
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
      
      [out_buffer_size, out_num_packets_to_read]
    end
    
    # Calculate what to read as the audio queue drains for the opened audio file.
    #
    def calculate_buffer
      raise(RuntimeError, "An audio file containing data must be opened first.") unless 
        @state.file_byte_size && @state.file_byte_size > 0
      
      out_buffer_size, num_packets = self.class.calculate_buffer_for(
        @state.format_sample_rate, @state.format_frames_per_packet, @state.format_max_packet_size, buffer_seconds)
      
      out_num_packets_to_read = num_packets > @state.file_total_packets ? 
        @state.file_total_packets : num_packets
      
      @state.buffer_byte_size, @state.num_packets_to_read = out_buffer_size, out_num_packets_to_read
    end
    
    def buffer_seconds
      @buffer_seconds ||= BufferSeconds
    end
  end
end
