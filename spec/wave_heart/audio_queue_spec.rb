require 'wave_heart'

describe WaveHeart::AudioQueue, ".derive_buffer_size" do
  
  it "returns an array of integers" do
    lambda { WaveHeart::AudioQueue.derive_buffer_size }.should raise_error ArgumentError
    
    buffer_size = WaveHeart::AudioQueue.derive_buffer_size( 44100, 1024, 548, 1 )
    buffer_size.should be_kind_of Array
    buffer_size[0].should be_kind_of Integer
    buffer_size[1].should be_kind_of Integer
  end
  
end

describe WaveHeart::AudioQueue, "#initialize" do
  
  it "sets-up state" do
    aq = WaveHeart::AudioQueue.new
    aq.state.should be_kind_of WaveHeart::AudioQueue::State
    aq.state.is_running.should be_false
  end
  
end

describe WaveHeart::AudioQueue, "#open" do
  
  it "gets file format properties" do
    aq = WaveHeart::AudioQueue.new
    aq.open('/System/Library/Sounds/Purr.aiff')
    aq.should be_instance_of WaveHeart::AudioQueue
    aq.state.format_is_vbr.should be_false
    aq.state.format_max_packet_size.should == 4
    aq.state.format_sample_rate.should == 44100
    aq.state.format_frames_per_packet.should == 1
    aq.state.format_bytes_per_packet.should == 4
  end
  
end