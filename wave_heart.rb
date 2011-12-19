# MacRuby 0.10

framework 'AppKit'
framework 'AudioToolbox'

require "rubygems"
require "inline"
require "wave_heart/audio_queue"
require "wave_heart/audio_queue/state"

class WaveHeart
  
  # An AudioQueue pushing an audio stream into CoreAudio HAL.
  #
  class Vessel
    
    BufferCount = 3
    
    attr_reader :audio_queue, :audio_file_url
    
    def initialize(file_path=nil)
      puts "#{self.class}#initialize"
      @audio_file_url = file_path
      @audio_queue = AudioQueue.new
      load
    end
    
    def load(file_path=nil)
      puts "#{self.class}#load"
      @audio_file_url = file path if file_path
      @audio_queue.open(@audio_file_url)
      @audio_queue.play
    end
  end
  
  class AppDelegate
    def applicationDidFinishLaunching(notification)
      #v = Vessel.new('/Users/Shared/Jukebox/Music/Air/Talkie Walkie/10 Alone in Kyoto.m4a')
      v = Vessel.new('/System/Library/Sounds/Sosumi.aiff')
    end
  end
end

if $0 == __FILE__
  app = NSApplication.sharedApplication
  app.delegate = WaveHeart::AppDelegate.new
  app.run
end

