#include "stdint.h"
#include "stdio.h"

void _cdecl cstart_(uint16_t bootDrive)
{
    puts("HELLO WORLF FROM C!");
    printf("Formatted %% %c %s\r\n",'a',"string");
    printf("Formatted %d %i %x %p %o\r\n",1234,-5678,0xdead,0xbeef,012345,(short)27,(short)-42,(unsigned char)20,(char)-10);
    printf("Formatted %6d %lx %lld %llx\r\n",-10000000001,0xdeadbeeful,012340005000,0xddddeebdull);
    for(;;);
}