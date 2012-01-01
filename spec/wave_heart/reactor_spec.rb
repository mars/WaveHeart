require 'wave_heart'
require 'httparty'

# NOTE, Warnings like the following are normal:
# macruby(96815,0x108df1000) malloc: *** auto malloc[96815]: error: GC operation on unregistered thread. Thread registered implicitly. Break on auto_zone_thread_registration_error() to debug.

# Heartbeat MP3 from Internet Archive http://www.archive.org/details/BabyHeartbeat1

class ThisHTTParty
  include HTTParty
  base_uri 'http://0.0.0.0:3333'
  format :json
end

describe WaveHeart::Reactor, ".start" do
  
  before(:all) do
    WaveHeart::Reactor.start
  end
  
  after(:all) do
    WaveHeart::Reactor.stop
  end
  
  it "runs its own thread" do
    WaveHeart::Reactor.thread.should be_instance_of Thread
    WaveHeart::Reactor.thread.should be_alive
    WaveHeart::Reactor.thread.should_not == Thread.current
    EM.should be_reactor_running
  end
  
end

describe WaveHeart::Reactor, ".stop" do
  
  it "kills the server" do
    WaveHeart::Reactor.start
    WaveHeart::Reactor.stop
    sleep 1
    WaveHeart::Reactor.thread.should_not be_alive
    EM.should_not be_reactor_running
  end
  
end

describe WaveHeart::Reactor::HttpServer, "#process_http_request" do
  let(:audio_file) { File.expand_path(File.join(File.dirname(__FILE__), '..', 'Johanna St. Chimes 3.m4a')) }
  #let(:audio_file) { File.expand_path(File.join(File.dirname(__FILE__), '..', 'Heartbeat.wav')) }
  
  before(:all) do
    WaveHeart::Reactor.start
    WaveHeart::AudioQueue.new(audio_file)
  end
  
  after(:all) do
    WaveHeart::Reactor.stop
  end
  
  it "responds with index" do
    resp = ThisHTTParty.get('/')
    resp.code.should equal(200), "Expected 200; got #{resp.code}; #{resp.inspect}"
    resp["audio_queues"].size == 1
  end
  
  it "responds as not found" do
    resp = ThisHTTParty.get('/99')
    resp.code.should equal(404), "Expected 404; got #{resp.code}; #{resp.inspect}"
    
    resp = ThisHTTParty.get('/0/foibles')
    resp.code.should equal(404), "Expected 404; got #{resp.code}; #{resp.inspect}"
    
    resp = ThisHTTParty.put('/99')
    resp.code.should equal(404), "Expected 404; got #{resp.code}; #{resp.inspect}"
  end
  
  it "responds with queue" do
    resp = ThisHTTParty.get('/0')
    resp.code.should equal(200), "Expected 200; got #{resp.code}; #{resp.inspect}"
    resp["audio_queue"]["is_running"].should be_false
  end
  
  it "responds as bad request" do
    resp = ThisHTTParty.put('/0/foibles')
    resp.code.should equal(400), "Expected 400; got #{resp.code}; #{resp.inspect}"
  end
  
  it "plays and pauses a queue" do
    resp = ThisHTTParty.put('/0/play')
    resp.code.should equal(200), "Expected 200; got #{resp.code}; #{resp.inspect}"
    resp["audio_queue"]["is_running"].should be_true
    
    resp = ThisHTTParty.put('/0/pause')
    resp.code.should equal(200), "Expected 200; got #{resp.code}; #{resp.inspect}"
    resp["audio_queue"]["is_running"].should be_false
  end
  
  it "sets queue parameters" do
    resp = ThisHTTParty.put('/0/volume/0.8')
    resp.code.should equal(200), "Expected 200; got #{resp.code}; #{resp.inspect}"
    resp = ThisHTTParty.put('/0/volume_ramp_seconds/3.5')
    resp.code.should equal(200), "Expected 200; got #{resp.code}; #{resp.inspect}"
    resp = ThisHTTParty.put('/0/pan/-0.5')
    resp.code.should equal(200), "Expected 200; got #{resp.code}; #{resp.inspect}"
    
    resp["audio_queue"]["volume"].should be_within(0.00001).of(0.8)
    resp["audio_queue"]["volume_ramp_seconds"].should be_within(0.00001).of(3.5)
    resp["audio_queue"]["pan"].should be_within(0.00001).of(-0.5)
  end
  
  it "does not allow bad queue parameters" do
    resp = ThisHTTParty.put('/0/volume/-8')
    resp.code.should equal(400), "Expected 400; got #{resp.code}; #{resp.inspect}"
    
    resp = ThisHTTParty.put('/0/volume_ramp_seconds/-0.1')
    resp.code.should equal(400), "Expected 400; got #{resp.code}; #{resp.inspect}"
    
    resp = ThisHTTParty.put('/0/pan/87264592783465298')
    resp.code.should equal(400), "Expected 400; got #{resp.code}; #{resp.inspect}"
  end
  
  it "creates and deletes a queue" do
    resp = ThisHTTParty.post('/', :body => MultiJson.encode(
      "audio_queue" => { "audio_file_url" => audio_file }))
    resp.code.should equal(201), "Expected 201; got #{resp.code}; #{resp.inspect}"
    resp.headers['Location'].should == '/1'
    resp["audio_queue"]["is_running"].should be_false
    
    resp = ThisHTTParty.get('/')
    resp.code.should equal(200), "Expected 200; got #{resp.code}; #{resp.inspect}"
    resp["audio_queues"].size == 2
    
    resp = ThisHTTParty.delete('/1')
    resp.code.should equal(204), "Expected 204; got #{resp.code}; #{resp.inspect}"
    
    resp = ThisHTTParty.get('/1')
    resp.code.should equal(404), "Expected 404; got #{resp.code}; #{resp.inspect}"
  end
  
  it "deletes a queue during play" do
    resp = ThisHTTParty.post('/', :body => MultiJson.encode(
      "audio_queue" => { "audio_file_url" => audio_file }))
    resp.code.should equal(201), "Expected 201; got #{resp.code}; #{resp.inspect}"
    new_url = resp.headers['Location']
    
    resp = ThisHTTParty.put("#{new_url}/play")
    resp.code.should equal(200), "Expected 200; got #{resp.code}; #{resp.inspect}"
    resp["audio_queue"]["is_running"].should be_true
    
    resp = ThisHTTParty.delete(new_url)
    resp.code.should equal(204), "Expected 204; got #{resp.code}; #{resp.inspect}"
    
    resp = ThisHTTParty.get(new_url)
    resp.code.should equal(404), "Expected 404; got #{resp.code}; #{resp.inspect}"
  end
  
end
