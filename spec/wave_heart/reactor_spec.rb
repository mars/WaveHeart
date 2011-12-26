require 'wave_heart'
require 'httparty'

# describe WaveHeart::Reactor, ".start" do
#   
#   before(:all) do
#     WaveHeart::Reactor.start
#   end
#   
#   after(:all) do
#     WaveHeart::Reactor.stop
#   end
#   
#   it "runs its own thread" do
#     WaveHeart::Reactor.thread.should be_instance_of Thread
#     WaveHeart::Reactor.thread.should be_alive
#     WaveHeart::Reactor.thread.should_not == Thread.current
#     EM.should be_reactor_running
#   end
#   
# end
# 
# describe WaveHeart::Reactor, ".stop" do
#   
#   it "kills the server" do
#     WaveHeart::Reactor.start
#     WaveHeart::Reactor.stop
#     sleep 1
#     WaveHeart::Reactor.thread.should_not be_alive
#   end
#   
# end

describe WaveHeart::Reactor, "#receive_request" do
  
  before(:all) do
    @server = WaveHeart::Reactor.start
    sleep 1
  end
  
  after(:all) do
    WaveHeart::Reactor.stop
  end
  
  it "responds for HTTP GET /" do
    t = Thread.new do
      resp = HTTParty.get 'http://127.0.0.1:3333/'
      resp.should be_kind_of Net::HTTP::Response
    end
    t.join
  end
  
end
