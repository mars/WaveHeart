require 'wave_heart'

describe WaveHeart::AudioQueue, ".calculate_buffer_for" do
  
  it "returns an array of integers" do
    lambda { WaveHeart::AudioQueue.calculate_buffer_for }.should raise_error ArgumentError
    
    buffer_size = WaveHeart::AudioQueue.calculate_buffer_for( 44100, 1024, 548, 1 )
    buffer_size.should be_kind_of Array
    buffer_size[0].should be_kind_of Integer
    buffer_size[1].should be_kind_of Integer
  end
  
end

describe WaveHeart::AudioQueue, "#initialize" do
  
  it "sets-up state" do
    aq = WaveHeart::AudioQueue.new
    aq.state.should be_kind_of WaveHeart::AudioQueue::State
    aq.state.is_running.should == 0
  end
  
end

describe WaveHeart::AudioQueue, "#open" do
  
  it "gets properties for small CBR file" do
    aq = WaveHeart::AudioQueue.new
    aq.open('/System/Library/Sounds/Purr.aiff')
    aq.should be_instance_of WaveHeart::AudioQueue
    aq.state.file_byte_size.should == 85556
    aq.state.file_total_packets.should == 21389
    aq.state.format_is_vbr.should == 0
    aq.state.format_max_packet_size.should == 4
    aq.state.format_sample_rate.should == 44100
    aq.state.format_frames_per_packet.should == 1
    aq.state.buffer_byte_size.should == 327680
    aq.state.num_packets_to_read.should == 21389
  end
  
end