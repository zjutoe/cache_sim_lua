#include <stdio.h>

int main(int argc, char* argv[])
{
	printf("%x %x %x\n", 
	       0xffffffff << 31, 
	       0xffffffff << 32, 
	       0xffffffff << 33);
	return 0;
}
