/*

OrchanixOS version detection utility.
Copyright (C) 2022 Xinc.

*/

#include <stdio.h>

int main() {
  int c;
  FILE *file;
  file = fopen("/etc/orchanixos-release","r");
  if (file) {
    while ((c = getc(file)) != EOF) {
      putchar(c);
    }
    fclose(file);
    return 0;
  } else {
    fprintf(stderr,"Error: Could not determine OrchanixOS Release.\n");
    return 1;
  }
}
