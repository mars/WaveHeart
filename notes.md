Loading a missing enumerated constant `fsRdPerm`
------------------------------------------------

In the shell:

    gen_bridge_metadata -o Files.bridgesupport -c "-I/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/CarbonCore.framework/Headers" Files.h

Then in MacRuby:

    load_bridge_support_file 'Files.bridgesupport'


    gen_bridge_metadata -o malloc.bridgesupport -c "-I/usr/include/malloc/malloc.h" malloc.h
    
    
    
    
Audio queue property debugging:

    UInt32 p;
    UInt32 ps = sizeof (UInt32);
    AudioQueueGetProperty (
      aqState->mQueue,
      kAudioQueueDeviceProperty_NumberChannels,
      &p,
      &ps );
    
    rb_raise(rb_eRuntimeError, "kAudioQueueDeviceProperty_NumberChannels %d", p);
    
    
          
              rb_raise(rb_eRuntimeError, 
                "aqState->maxPacketSize %d mSampleRate %d mBytesPerPacket %d mFramesPerPacket %d", 
                aqState->maxPacketSize,
                aqState->mSampleRate, 
                aqState->mBytesPerPacket, 
                aqState->mFramesPerPacket);
                
                
                
                
                
            if (aqState->isFormatVBR) {
              mResultCode = AudioQueueAllocateBufferWithPacketDescriptions(
                aqState->mQueue,
                aqState->bufferByteSize,
                aqState->mNumPacketsToRead,
                &aqState->mBuffers[i]);
            } else {
              mResultCode = AudioQueueAllocateBuffer(
                aqState->mQueue,
                aqState->bufferByteSize,
                &aqState->mBuffers[i]);
            }
            
            
            
            
          
          
            UInt32 numBytes;
            UInt32 numPackets = aqState->mNumPacketsToRead;
            UInt32 currentPacket = 1;
          
            CheckError(AudioFileReadPackets(
              aqState->mAudioFile,
              false,
              &numBytes,
              aqState->mPacketDescs, 
              currentPacket,
              &numPackets,
              aqState->mBuffers[i]
            ), "prime (test) AudioFileReadPackets failed");
            
            
            
            
            
            
          
          Boolean done = false;
          CFRunLoopTimerContext context = {0, &aqState, NULL, NULL, NULL};
          CFRunLoopTimerRef timer = CFRunLoopTimerCreate(
            kCFAllocatorDefault, 0.1, 10, 0, 0, Beat, &context);
          CFRunLoopAddTimer(aqState->mRunLoop, timer, kCFRunLoopCommonModes);
          
          do {
              SInt32 result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 10, true);
              if ((result == kCFRunLoopRunStopped) || (result == kCFRunLoopRunFinished))
                  done = true;
          } while (!done);
          
          CFRelease(timer);