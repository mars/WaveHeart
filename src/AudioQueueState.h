static const int kNumberBuffers = 3;

typedef struct AudioQueueState {
  AudioStreamBasicDescription   mDataFormat;
  AudioQueueRef                 mQueue;
  AudioQueueBufferRef           mBuffers[kNumberBuffers];
  AudioFileID                   mAudioFile;
  UInt32                        bufferByteSize;
  SInt64                        mCurrentPacket;
  UInt32                        mNumPacketsToRead;
  AudioStreamPacketDescription  *mPacketDescs;
  Boolean                       mIsRunning;
  Boolean                       isFormatVBR;
  UInt32                        mSampleRate;
  UInt32                        mFramesPerPacket;
  UInt32                        mBytesPerPacket;
  UInt32                        maxPacketSize;
} AudioQueueState;
