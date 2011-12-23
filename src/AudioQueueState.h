static const int kNumberPlaybackBuffers = 3;

typedef struct {
  AudioStreamBasicDescription   mDataFormat;
  AudioQueueRef                 mQueue;
  CFRunLoopRef                  mRunLoop;
  AudioFileID                   mAudioFile;
  UInt32                        mAudioFileByteSize;
  UInt32                        mAudioFileTotalPackets;
  UInt32                        bufferByteSize;
  SInt64                        mCurrentPacket;
  UInt32                        mNumPacketsToRead;
  AudioStreamPacketDescription  *mPacketDescs;
  UInt32                        mIsRunning;
  UInt32                        isFormatVBR;
  double                        mSampleRate;
  UInt32                        mFramesPerPacket;
  UInt32                        mBytesPerPacket;
  UInt32                        maxPacketSize;
} AudioQueueState;
