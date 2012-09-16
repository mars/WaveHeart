WaveHeart basics
================

Requires Mac OS X 10.7+ with Macruby 0.12.

1. `bin/bundle install` (rename Germfile to Gemfile for this command)
2. `macrake spec` (Gemfile must not be present: http://lists.macosforge.org/pipermail/macruby-tickets/2010-October/000538.html)
3. `macruby wave_heart.rb`

IRB usage examples
==================

    $ macirb
    > require 'wave_heart.rb'
    > aq = WaveHeart::AudioQueue.new('/Users/Shared/Jukebox/Music/Air/Talkie Walkie/10 Alone in Kyoto.m4a')
    > aq.play

See: WaveHeart::AudioQueue::Operations & WaveHeart::AudioQueue::Parameters  