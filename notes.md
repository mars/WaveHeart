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