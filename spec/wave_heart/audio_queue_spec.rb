require 'wave_heart'

describe WaveHeart::AudioQueue, "#initialize" do
  
  before(:all) do
    @aq = WaveHeart::AudioQueue.new
  end
  
  after(:all) do
    WaveHeart::AudioQueue.clear_all
  end
  
  it "sets-up state" do
    @aq.should be_kind_of WaveHeart::AudioQueue
    @aq.state.should be_kind_of WaveHeart::AudioQueue::State
    @aq.state.is_running.should == 0
  end
  
  it "c-methods are private" do
    lambda { @aq.get_data_format_in_c(@aq.state) }.should raise_error(NoMethodError)
  end
  
end

describe WaveHeart::AudioQueue, "#open" do
  
  before(:all) do
    @aq = WaveHeart::AudioQueue.new
    @aq.open('/System/Library/Sounds/Purr.aiff')
  end
  
  after(:all) do
    WaveHeart::AudioQueue.clear_all
  end
  
  it "gets properties for small CBR file" do
    @aq.should be_instance_of WaveHeart::AudioQueue
    @aq.state.file_byte_size.should == 85556
    @aq.state.file_total_packets.should == 21389
    @aq.state.format_is_vbr.should == 0
    @aq.state.format_max_packet_size.should == 4
    @aq.state.format_sample_rate.should == 44100
    @aq.state.format_frames_per_packet.should == 1
    @aq.state.buffer_byte_size.should == 327680
    @aq.state.num_packets_to_read.should == 21389
  end
  
  it "parameters are nil until primed" do
    @aq.is_primed.should be_false
    @aq.pan.should be_nil
    @aq.volume.should be_nil
    @aq.volume_ramp_seconds.should be_nil
  end
  
end

describe WaveHeart::AudioQueue, "#prime" do
  
  before(:all) do
    @aq = WaveHeart::AudioQueue.new
    @aq.open('/System/Library/Sounds/Purr.aiff')
    @aq.prime
  end
  
  after(:all) do
    WaveHeart::AudioQueue.clear_all
  end
  
  it "sets attribute flag" do
    @aq.is_primed.should be_true
  end
  
  it "has parameter defaults" do
    @aq.pan.should == 0.0
    @aq.volume.should == 1.0
    @aq.volume_ramp_seconds.should == 0.0
  end
  
end

describe WaveHeart::AudioQueue, "#play" do
  
  before(:all) do
    @aq = WaveHeart::AudioQueue.new
  end
  
  after(:all) do
    WaveHeart::AudioQueue.clear_all
  end
  
  it "runs the queue then stops" do
    @aq.open('/System/Library/Sounds/Purr.aiff')
    @aq.play
    @aq.state.is_running.should == 0
  end
  
end

describe WaveHeart::AudioQueue::Parameters do
  
  before(:all) do
    @aq = WaveHeart::AudioQueue.new
    @aq.open('/System/Library/Sounds/Purr.aiff')
    @aq.prime
  end
  
  after(:all) do
    WaveHeart::AudioQueue.clear_all
  end
  
  it "sets and gets" do
    @aq.volume_ramp_seconds = 1.0
    @aq.volume = 0.8
    @aq.pan = -0.9
    
    @aq.volume_ramp_seconds.should be_within(0.00001).of(1.0)
    @aq.volume.should be_within(0.00001).of(0.8)
    @aq.pan.should be_within(0.00001).of(-0.9)
  end
  
end

describe WaveHeart::AudioQueue, ".calculate_buffer_for" do
  
  it "returns an array of integers" do
    lambda { WaveHeart::AudioQueue.calculate_buffer_for }.should raise_error ArgumentError
    
    buffer_size = WaveHeart::AudioQueue.calculate_buffer_for( 44100, 1024, 548, 1 )
    buffer_size.should be_kind_of Array
    buffer_size[0].should be_kind_of Integer
    buffer_size[1].should be_kind_of Integer
  end
  
end
