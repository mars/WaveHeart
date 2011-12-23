class WaveHeart
  class AudioQueue
    
    # C-structure wrapped in a Ruby object
    class State
      
      inline(:C) do |builder|
        builder.add_compile_flags '-x c++', '-lstdc++', '-I ./src'
        builder.include '<AudioToolbox/AudioToolbox.h>'
        builder.include '<AudioQueueState.h>'
        
        builder.prefix %{
          static VALUE aqs_alloc(VALUE klass) { 
            AudioQueueState *aqState = ALLOC (AudioQueueState);
            VALUE aqs = Data_Wrap_Struct(klass, 0, NULL, aqState);
            return aqs;
          }
        }
        
        builder.add_to_init %{
          rb_define_alloc_func(c, aqs_alloc);
        }
        
        builder.c %{
          VALUE is_running() {
            AudioQueueState *pointer;
            Data_Get_Struct(self, AudioQueueState, pointer);
            return (UINT2NUM(pointer->mIsRunning));
          };
        }
        
        builder.c %{
          VALUE is_running_equals(VALUE value) {
            AudioQueueState *pointer;
            Data_Get_Struct(self, AudioQueueState, pointer);
            pointer->mIsRunning = NUM2UINT(value);
            return (value);
          };
        }
        
        builder.c %{
          VALUE buffer_byte_size() {
            AudioQueueState *pointer;
            Data_Get_Struct(self, AudioQueueState, pointer);
            return (UINT2NUM(pointer->bufferByteSize));
          };
        }
        
        builder.c %{
          VALUE buffer_byte_size_equals(VALUE value) {
            AudioQueueState *pointer;
            Data_Get_Struct(self, AudioQueueState, pointer);
            pointer->bufferByteSize = NUM2UINT(value);
            return (value);
          };
        }
        
        builder.c %{
          VALUE num_packets_to_read() {
            AudioQueueState *pointer;
            Data_Get_Struct(self, AudioQueueState, pointer);
            return (UINT2NUM(pointer->mNumPacketsToRead));
          };
        }
        
        builder.c %{
          VALUE num_packets_to_read_equals(VALUE value) {
            AudioQueueState *pointer;
            Data_Get_Struct(self, AudioQueueState, pointer);
            pointer->mNumPacketsToRead = NUM2UINT(value);
            return (value);
          };
        }
        
        builder.c %{
          VALUE file_byte_size() {
            AudioQueueState *pointer;
            Data_Get_Struct(self, AudioQueueState, pointer);
            return (UINT2NUM(pointer->mAudioFileByteSize));
          };
        }
        
        builder.c %{
          VALUE file_total_packets() {
            AudioQueueState *pointer;
            Data_Get_Struct(self, AudioQueueState, pointer);
            return (UINT2NUM(pointer->mAudioFileTotalPackets));
          };
        }
        
        builder.c %{
          VALUE format_is_vbr() {
            AudioQueueState *pointer;
            Data_Get_Struct(self, AudioQueueState, pointer);
            return (UINT2NUM(pointer->isFormatVBR));
          };
        }
        
        builder.c %{
          VALUE format_sample_rate() {
            AudioQueueState *pointer;
            Data_Get_Struct(self, AudioQueueState, pointer);
            return (LONG2NUM(pointer->mSampleRate));
          };
        }
        
        builder.c %{
          VALUE format_frames_per_packet() {
            AudioQueueState *pointer;
            Data_Get_Struct(self, AudioQueueState, pointer);
            return (UINT2NUM(pointer->mFramesPerPacket));
          };
        }
        
        builder.c %{
          VALUE format_bytes_per_packet() {
            AudioQueueState *pointer;
            Data_Get_Struct(self, AudioQueueState, pointer);
            return (UINT2NUM(pointer->mBytesPerPacket));
          };
        }
        
        builder.c %{
          VALUE format_max_packet_size() {
            AudioQueueState *pointer;
            Data_Get_Struct(self, AudioQueueState, pointer);
            return (UINT2NUM(pointer->maxPacketSize));
          };
        }
      end
    end
    
  end
end