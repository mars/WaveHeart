require 'wave_heart'
require 'net/http'

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
  end
  
end

describe WaveHeart::Reactor, "#receive_request" do
  
  it "responds for HTTP GET /" do
    @server = WaveHeart::Reactor.start
    sleep 1
    url = URI.parse('http://0.0.0.0:3333/')
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    resp.should be_kind_of Net::HTTP::Response
    WaveHeart::Reactor.stop
  end
  
end
