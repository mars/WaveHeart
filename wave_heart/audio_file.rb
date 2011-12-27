module WaveHeart
  
  # audio file utilities
  #
  class AudioFile
    
    attr_reader :ptr
    
    def initialize(file_path)
      @ptr = Pointer.new AudioFileID.type
      audio_file_url = CFURLCreateFromFileSystemRepresentation(
        nil, file_path, file_path.bytesize, false )
      result = AudioFileOpenURL(
        audio_file_url, KAudioFileReadPermission, 0, @ptr )
      CFRelease(audio_file_url)
      result
    end
    
    def get_audio_file_prop(name, return_ptr)
      puts "get_audio_file_prop"
      raise RuntimeError, "An audio file must be loaded." unless @ptr[0]
      
      size_ptr = Pointer.new 'I'
      return_ptr_klass = return_ptr[0].class
      size_ptr.assign( return_ptr_klass.respond_to?(:size) ? 
        return_ptr_klass.size : return_ptr[0].size )
      is_writable = Pointer.new 'I'
      
      AudioFileGetPropertyInfo(
        @ptr[0], name, size_ptr, is_writable )
      result = AudioFileGetProperty(
        @ptr[0], name, size_ptr, return_ptr )
      raise(RuntimeError, "AudioFileGetProperty returned #{result}") unless result==0
      result
    end
    
  end
end
