static void CheckError(OSStatus error, const char *operation) {
  if (error == noErr) return;
  char errorString[20];
  // See if it appears to be a 4-char-code
  *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
  if (isprint(errorString[1]) && isprint(errorString[2]) &&
      isprint(errorString[3]) && isprint(errorString[4])) {
      errorString[0] = errorString[5] = '\'';
      errorString[6] = '\0';
  } else
      // No, format it as an integer
      sprintf(errorString, "%d", (int)error);
  rb_raise(rb_eRuntimeError, "%s (%s)", operation, errorString);
}
