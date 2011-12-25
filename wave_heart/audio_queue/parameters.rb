class WaveHeart
  class AudioQueue
    
    # Set and Get AudioQueue parameters
    module Parameters
      
      # The linearly scaled gain for the audio queue, in the range 0.0 through 1.0. 
      # A value of 1.0 (the default) indicates unity gain.
      # A value of 0.0 indicates zero gain, or silence.
      #
      def volume=(f)
        raise ArgumentError, "Volume must be between 0.0 & 1.0" unless (0.0..1.0).include? f.to_f
        set_audio_queue_param_in_c @state, KAudioQueueParam_Volume, f.to_f
        self
      end
      
      def volume
        return unless @is_primed
        get_audio_queue_param_in_c @state, KAudioQueueParam_Volume
      end
      
      # The number of seconds over which a volume change is ramped.
      # For example, to fade from unity gain down to silence over the course of 1 second, 
      # set this parameter to 1 and then set the kAudioQueueParam_Volume parameter to 0.
      #
      def volume_ramp_seconds=(f)
        raise ArgumentError, "Volume ramp time must be 0.0 or greater" unless f.to_f >= 0.0
        set_audio_queue_param_in_c @state, KAudioQueueParam_VolumeRampTime, f.to_f
        self
      end
      
      def volume_ramp_seconds
        return unless @is_primed
        get_audio_queue_param_in_c @state, KAudioQueueParam_VolumeRampTime
      end
      
      # The stereo panning position of a source. For a monophonic source, panning is determined as follows:
      #   –1 = hard left
      #    0 = center
      #   +1 = hard right
      # For a stereophonic source, this parameter affects the left/right balance.
      # For a multichannel source, this parameter has no effect.
      #
      def pan=(f)
        raise ArgumentError, "Pan must be between -1.0 & 1.0" unless (-1.0..1.0).include? f.to_f
        set_audio_queue_param_in_c @state, KAudioQueueParam_Pan, f.to_f
        self
      end
      
      def pan
        return unless @is_primed
        get_audio_queue_param_in_c @state, KAudioQueueParam_Pan
      end
    
      inline(:C) do |builder|
        builder.add_compile_flags '-x c++', '-lstdc++', '-I ./src'
        builder.include '<AudioToolbox/AudioToolbox.h>'
        builder.include '<utils.h>'
        builder.include '<AudioQueueState.h>'
       
        builder.c %{ 
          void get_audio_queue_param_in_c(VALUE state, VALUE param) {
            AudioQueueState* aqState;
            Data_Get_Struct(state, AudioQueueState, aqState);
            int p = NUM2INT(param);
            AudioQueueParameterValue aqpv;
            CheckError(AudioQueueGetParameter(
              aqState->mQueue, p, &aqpv
            ), "AudioQueueGetParameter failed");
            return rb_float_new(aqpv);
          };
        }
       
        builder.c %{ 
          void set_audio_queue_param_in_c(VALUE state, VALUE param, VALUE value) {
            AudioQueueState* aqState;
            Data_Get_Struct(state, AudioQueueState, aqState);
            int p = NUM2INT(param);
            AudioQueueParameterValue aqpv = NUM2DBL(value);
            CheckError(AudioQueueSetParameter(
              aqState->mQueue, p, aqpv
            ), "AudioQueueSetParameter failed");
            return value;
          };
        }
      end
      
    end
    
  end
end