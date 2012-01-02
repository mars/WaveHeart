WaveHeart basics
================
1. `bin/bundle install`
2. `macrake spec`
3. `macruby wave_heart.rb`

HTTP/JSON REST API
==================
Example curl usage.

Get the index of existant audio queues:
`curl -vvv -X GET 127.0.0.1:3333/`

Create an audio queue with a local file:
`curl -vvv --data '{"audio_queue":{"audio_file_url":"/Users/Shared/Jukebox/Music/Kodo/sai-so/03 Wax Off.mp3"}}' 127.0.0.1:3333/`

Get attributes of that first queue:
`curl -vvv -X GET 127.0.0.1:3333/0`

Play (start from a stop or a pause):
`curl -vvv -X PUT 127.0.0.1:3333/0/play`

Pause (keeps buffers, retains hardware):
`curl -vvv -X PUT 127.0.0.1:3333/0/pause`

Stop (EXPERIMENTAL resets buffers when emptied, releases hardware):
`curl -vvv -X PUT 127.0.0.1:3333/0/stop`

Destroy the audio queue (stops immediately):
`curl -vvv -X DELETE 127.0.0.1:3333/0`

Set the volume ramp (fade time) and then lower the volume:
`curl -vvv -X PUT 127.0.0.1:3333/0/volume_ramp_seconds/3.5`
`curl -vvv -X PUT 127.0.0.1:3333/0/volume/0.5`