// Dump the inotify flag values to a scheme hash table.
// I assume these values are the same on every linux kernel
#include <stdio.h>
#include <sys/inotify.h>

void print_flag(const char *name, unsigned int val) {
  printf(" (%s . %u)", name, val);
}

#define prf(flag) print_flag(#flag, flag)

int main(void) {
  fputs("(define flags '#hasheq(", stdout);
  prf(IN_ACCESS);
  prf(IN_ATTRIB);
  prf(IN_CLOSE_WRITE);
  prf(IN_CLOSE_NOWRITE);
  prf(IN_CREATE);
  prf(IN_DELETE);
  prf(IN_DELETE_SELF);
  prf(IN_MODIFY);
  prf(IN_MOVE_SELF);
  prf(IN_MOVED_FROM);
  prf(IN_MOVED_TO);
  prf(IN_OPEN);
  prf(IN_MOVE);
  prf(IN_CLOSE);
  prf(IN_DONT_FOLLOW);
  prf(IN_EXCL_UNLINK);
  prf(IN_MASK_ADD);
  prf(IN_ONESHOT);
  prf(IN_ONLYDIR);
  prf(IN_IGNORED);
  prf(IN_ISDIR);
  prf(IN_Q_OVERFLOW);
  prf(IN_UNMOUNT);
  prf(IN_ALL_EVENTS);
  puts("))");

  return 0;
}
