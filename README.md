WaveHeart basics
================
1. `bin/bundle install`
2. `macrake spec`
3. `macruby wave_heart.rb`

IRB usage examples
==================

    $ macirb
    > require 'wave_heart.rb'
    > aq = WaveHeart::AudioQueue.new('/Users/Shared/Jukebox/Music/Air/Talkie Walkie/10 Alone in Kyoto.m4a')
    > aq.play

See: WaveHeart::AudioQueue::Operations & WaveHeart::AudioQueue::Parameters  