extern "C" void entry() {
  unsigned short *buffer = (unsigned short*)0xb8000;
  buffer[0] = 0xa53a;
  while(true) {}
}
