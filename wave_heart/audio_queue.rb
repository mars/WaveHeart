require "rubygems"
require "inline"

class WaveHeart
  
  # An object-oriented interface for Apple's AudioToolbox audio queue
  #
  class AudioQueue
    
    class State; end
    
    attr_reader :state, :data_format, :is_primed
    
    def initialize
      puts "#{self.class}#initialize"
      @is_primed = false
      @data_format = Pointer.new AudioStreamBasicDescription.type
      @data_format.assign AudioStreamBasicDescription.new
      @state = init_state_in_c State
      self
    end
    
    def open(audio_file_url)
      puts "#{self.class}#open"
      @is_primed = false
      puts "#{self.class}#open_audio_file_in_c"
      result = open_audio_file_in_c @state, audio_file_url
      raise(RuntimeError, "AudioFileOpenURL returned #{result}") unless result==0
      puts "#{self.class}#get_data_format_in_c"
      result = get_data_format_in_c @state
      raise(RuntimeError, "AudioFileGetProperty returned #{result}") unless result==0
      puts "#{self.class}#new_output_in_c"
      result = new_output_in_c @state
      raise(RuntimeError, "AudioQueueNewOutput returned #{result}") unless result==0
      puts "#{self.class}#setup_buffers_in_c"
      result = setup_buffers_in_c @state
      raise(RuntimeError, "AudioFileGetProperty returned #{result}") unless result==0
      puts "#{self.class}#set_magic_cookie_in_c"
      set_magic_cookie_in_c @state
    end
    
    def play
      puts "#{self.class}#play"
      is_running = true
      prime unless @is_primed
      gain = 1.0
      result = start_in_c @state
      raise(RuntimeError, "AudioQueueStart returned #{result}") unless result==0
      while is_running do
         CFRunLoopRunInMode(KCFRunLoopDefaultMode, 0.25, false)
      end
      CFRunLoopRunInMode(KCFRunLoopDefaultMode, 1, false)
      cleanup
    end
    
    def stop
      puts "#{self.class}#stop"
      result = stop_in_c @state
      raise(RuntimeError, "AudioQueueStop returned #{result}") unless result==0
      is_running = false
      result
    end
    
    def gain=(f)
      puts "#{self.class}#gain=(#{f.inspect})"
      result = set_audio_queue_param_in_c @state, KAudioQueueParam_Volume, f
      raise(RuntimeError, "AudioQueueSetParameter returned #{result}") unless result==0
      result
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
      return if is_running
      result = cleanup_in_c @state
      raise(RuntimeError, "AudioQueueDispose returned #{result}") unless result==0
      result
    end
    
    inline do |builder|
      builder.include '<CoreFoundation/CoreFoundation.h>'
      builder.include '<CoreServices/CoreServices.h>'
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
        
        static void HandleOutputBuffer(
          void                          *aqState,
          AudioQueueRef                 inAQ, 
          AudioQueueBufferRef           inBuffer) {
            
          AudioQueueState *pAqData = (AudioQueueState *) aqState;
          if (pAqData->mIsRunning == 0) return;
          UInt32 numBytesReadFromFile;
          UInt32 numPackets = pAqData->mNumPacketsToRead;
          AudioFileReadPackets(
            pAqData->mAudioFile,
            false,
            &numBytesReadFromFile,
            pAqData->mPacketDescs, 
            pAqData->mCurrentPacket,
            &numPackets,
            inBuffer->mAudioData 
          );
          if (numPackets > 0) {
            inBuffer->mAudioDataByteSize = numBytesReadFromFile;
            AudioQueueEnqueueBuffer( 
              pAqData->mQueue,
              inBuffer,
              (pAqData->mPacketDescs ? numPackets : 0),
              pAqData->mPacketDescs
            );
            pAqData->mCurrentPacket += numPackets;
          } else {
            AudioQueueStop(pAqData->mQueue, false);
            pAqData->mIsRunning = false; 
          }
        }
        
        void DeriveBufferSize(
          AudioStreamBasicDescription &ASBDesc,
          UInt32                      maxPacketSize,
          Float64                     seconds,
          UInt32                      *outBufferSize,
          UInt32                      *outNumPacketsToRead) {
          
          static const int maxBufferSize = 0x50000;
          static const int minBufferSize = 0x4000;
          
          if (ASBDesc.mFramesPerPacket != 0) {
            Float64 numPacketsForTime =
              ASBDesc.mSampleRate / ASBDesc.mFramesPerPacket * seconds;
            *outBufferSize = numPacketsForTime * maxPacketSize;
          } else {
            *outBufferSize =
              maxBufferSize > maxPacketSize ?
                maxBufferSize : maxPacketSize;
          }
          
          if (
            *outBufferSize > maxBufferSize &&
            *outBufferSize > maxPacketSize
          )
            *outBufferSize = maxBufferSize;
          else {
            if (*outBufferSize < minBufferSize)
              *outBufferSize = minBufferSize;
          }
          
          *outNumPacketsToRead = *outBufferSize / maxPacketSize;
        }
      }
      builder.struct_name = 'AudioQueueState'
      builder.accessor :is_running, 'VALUE', :mIsRunning
      
      builder.c %{
        VALUE init_state_in_c(VALUE klass) {
          AudioQueueState* aqState = ALLOC (AudioQueueState);
          VALUE v = Data_Wrap_Struct(klass, NULL, NULL, aqState);
          return v;
        };
      }
       
      builder.c %{ 
        int new_output_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          int mResultCode;
          mResultCode = AudioQueueNewOutput(
            &aqState->mDataFormat, 
            HandleOutputBuffer, 
            &aqState, 
            CFRunLoopGetCurrent(), 
            NULL, 
            0, 
            &aqState->mQueue);
          return mResultCode;
        };
      }
       
      builder.c %{ 
        int set_audio_queue_param_in_c(VALUE state, VALUE param, VALUE value) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          int mResultCode;
          mResultCode = AudioQueueSetParameter(aqState->mQueue, param, value);
          return mResultCode;
        };
      }
       
      builder.c %{ 
        int start_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          int mResultCode;
          mResultCode = AudioQueueStart(aqState->mQueue, NULL);
          return mResultCode;
        };
      }
       
      builder.c %{ 
        int stop_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          int mResultCode;
          mResultCode = AudioQueueStop(aqState->mQueue, false);
          return mResultCode;
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
        int open_audio_file_in_c(VALUE state, VALUE filePath) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          
          VALUE str = StringValue(filePath);
          const char *fp = RSTRING_PTR(str);
          int str_len RSTRING_LEN(str);
          
          int mResultCode;
          CFURLRef audioFileURL = CFURLCreateFromFileSystemRepresentation(
            NULL,
            (Byte *) fp,
            str_len,
            false);
          mResultCode = AudioFileOpenURL(
            audioFileURL,
            fsRdPerm,
            0,
            &aqState->mAudioFile);
          CFRelease(audioFileURL);
          return mResultCode;
        };
      }
       
      builder.c %{ 
        int get_data_format_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          int mResultCode;
          UInt32 dataFormatSize = sizeof (aqState->mDataFormat);
          mResultCode = AudioFileGetProperty(
            aqState->mAudioFile,
            kAudioFilePropertyDataFormat,
            &dataFormatSize,
            &aqState->mDataFormat
          );
          return mResultCode;
        };
      }
       
      builder.c %{ 
        int setup_buffers_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          int mResultCode;
          
          UInt32 maxPacketSize;
          UInt32 propertySize = sizeof (maxPacketSize);
          mResultCode = AudioFileGetProperty(
            aqState->mAudioFile,
            kAudioFilePropertyPacketSizeUpperBound,
            &propertySize,
            &maxPacketSize);
          
          DeriveBufferSize(
            aqState->mDataFormat,
            maxPacketSize,
            0.5,
            &aqState->bufferByteSize,
            &aqState->mNumPacketsToRead);
          
          bool isFormatVBR = (
            aqState->mDataFormat.mBytesPerPacket == 0 ||
            aqState->mDataFormat.mFramesPerPacket == 0
          );
          
          if (isFormatVBR) {
            aqState->mPacketDescs =
              (AudioStreamPacketDescription*) ALLOC_N (
                AudioStreamPacketDescription*,
                aqState->mNumPacketsToRead * sizeof (AudioStreamPacketDescription));
          } else {
            aqState->mPacketDescs = NULL;
          }
          
          return mResultCode;
        };
      }
       
      builder.c %{ 
        int set_magic_cookie_in_c(VALUE state) {
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
            char* magicCookie =
              (char *) ALLOC_N (char *, cookieSize);
            
            AudioFileGetProperty(
              aqState->mAudioFile,
              kAudioFilePropertyMagicCookieData,
              &cookieSize,
              magicCookie);
            
            AudioQueueSetProperty(
              aqState->mQueue,
              kAudioQueueProperty_MagicCookie,
              magicCookie,
              cookieSize);
          }
          
          return NULL;
        };
      }
       
      builder.c %{ 
        int prime_buffers_in_c(VALUE state) {
          AudioQueueState* aqState;
          Data_Get_Struct(state, AudioQueueState, aqState);
          int mResultCode;
          
          aqState->mCurrentPacket = 0;
          
          for (int i = 0; i < kNumberBuffers; ++i) {
            mResultCode = AudioQueueAllocateBuffer(
              aqState->mQueue,
              aqState->bufferByteSize,
              &aqState->mBuffers[i]);
            
            HandleOutputBuffer(
              &aqState,
              aqState->mQueue,
              aqState->mBuffers[i]);
          }
          
          return mResultCode;
        };
      }
    end
  end
end
