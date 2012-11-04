module WaveHeart
  module Source
    
    # A library of audio files with meta data.
    # Subclasses adapt to different backend or remote libraries.
    #
    class Base

      attr_reader :data
      
      def initialize(*args)
        @data = {}
      end

    end

  end
end
