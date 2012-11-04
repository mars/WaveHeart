# MacRuby 0.12

framework 'AppKit'
framework 'AudioToolbox'

require 'rubygems'
require "bundler/setup"
require 'inline'

require "wave_heart/audio_queue/operations"
require "wave_heart/audio_queue/parameters"
require "wave_heart/audio_queue/state"
require "wave_heart/audio_queue"

require "wave_heart/source"

module WaveHeart
  class AppDelegate
    attr_reader :reactor
    
    def applicationDidFinishLaunching(notification)
      #aq = AudioQueue.new('/Users/Shared/Jukebox/Music/Air/Talkie Walkie/10 Alone in Kyoto.m4a').play
      #aq2 = AudioQueue.new('/Users/Shared/Jukebox/Music/Kodo/sai-so/03 Wax Off.mp3').play
      #aq3 = AudioQueue.new('/System/Library/Sounds/Sosumi.aiff').play
    end
  end
end

if $0 == __FILE__
  app = NSApplication.sharedApplication
  app.delegate = WaveHeart::AppDelegate.new
  app.run
end

