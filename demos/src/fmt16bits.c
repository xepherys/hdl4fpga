#include <stdlib.h>
#include <stdio.h>

#define SIZE (128)

int main (int argc, char *argv[])
{
	unsigned char buffer[(2+SIZE)+(2+3)+(2+3)];
	unsigned char *const memdata = buffer;;
	unsigned char *const memaddr = memdata + (2+SIZE);
	unsigned char *const memlen  = memaddr + 5;

	memdata[0] = 0x18;
	memdata[1] = SIZE-1;

	memaddr[0] = 0x16;
	memaddr[1] = 0x02;

	memlen[0]  = 0x17;
	memlen[1]  = 0x02;
	memlen[2]  = 0x00;
	memlen[3]  = 0x00;
	memlen[4]  = SIZE/2-1;

	setbuf(stdin, NULL);
	setbuf(stdout, NULL);
	for(unsigned addr = 0; fread(buffer+2, sizeof(char), SIZE, stdin) > 0; addr += (SIZE/2)) {

		memaddr[2] = (addr >> 16) & 0xff;
		memaddr[3] = (addr >>  8) & 0xff;
		memaddr[4] = (addr >>  0) & 0xff;

		fwrite(buffer, sizeof(char), sizeof(buffer), stdout);

	}

	return 0;
}
