# Compilers
CC = icc
CFLAGS	= -Wall -O3 

CC = gcc
CFLAGS = -O2 -Wall -m64







INC = -I/usr/local/include




pgrapi.o: pgrapi.c
	$(CC) -c $(INC) $(CFLAGS) pgrapi.c 

run: pgrapi.c
	$(CC) $(INC) -D DEBUG_MAIN=1  $(CFLAGS) pgrapi.c -L/usr/local/lib64 -lufp -lm -o $@ 



clean:
	\rm -rf *~ *.o run


f :
	\rm -f top.bin.ufp
	fcu -v -c top.bin hdr_xc2vp50_190
	fcu -v -l top.bin.ufp
