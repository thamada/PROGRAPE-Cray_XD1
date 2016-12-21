#include "einlib.h"
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string.h> // memcpy()

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
// THIS PART IS SAME AS "b3.c"   &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
/* Define the FPGA write types (address or data value) */
#define TYPE_VAL  0x0UL
#define TYPE_ADDR 0x1UL
/* Define the size of the Block RAM for the Hello FPGA (in bytes). */
#define BRAM_OFFSET 0           /* Offset into the FPGA memory space. */ 
//#define BRAM_SIZE   (16 * 1024) /* 16 Kbyte of RAM. */
#define BRAM_SIZE   (4096 * 1024) /* 4 Mbyte of RAM. */
/* Declare a type for a 64 bit unsigned integer. */
//typedef unsigned long u_64;
#define u_64 unsigned long
//-----------------------------------------------------------------
static int fd = -1;
u_64* pgr_ptr; // same as b1ptr
//-----------------------------------------------------------------
u_64* pgr_mapbase(int fp_id) {
  err_e e;
  u_64* bram_ptr64;
  bram_ptr64 = fpga_memmap (fp_id, BRAM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, BRAM_OFFSET, &e);
  if (e != NOERR) {
    printf ("fpga_memmap() call failed.\n");
    exit(1);
  }
  return(bram_ptr64);
}
//-----------------------------------------------------------------
void pgr_open(dummyid)
{
  err_e e;
  fd = fpga_open ("/dev/ufp0", O_RDWR|O_SYNC, &e);
  if (e != NOERR) {printf ("Failed to open FPGA device. Exiting.\n"); exit(-1);}
  pgr_ptr = pgr_mapbase(fd);
}
//-----------------------------------------------------------------
void pgr_reset(dummyid)
{
  //  err_e e;
  //  fpga_reset(fd, &e);
  //  if (e != NOERR) {printf ("Failed to open FPGA device. Exiting.\n"); exit(-1);}
}
//-----------------------------------------------------------------
void pgr_close(dummyid)
{
  err_e e;
  fpga_close (fd, &e);
}
//-----------------------------------------------------------------
u_64 pgr_read_acore(unsigned int index)
{
 return  *(pgr_ptr + index);
}
//-----------------------------------------------------------------
void pgr_write_acore(unsigned int index, u_64 val)
{
  *(pgr_ptr + index) = val;
}

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
// THIS PART IS SAME AS "pgrapi.c"  &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
#define ADR_JPSET 0x40000
#define ADR_IPSET 0x5000
#define ADR_FOSET 0x6000
#define ADR_SETN  0x7000
#define ADR_RUN   0x7007
#define ADR_STS   0x6fff

#define JDIM 4
static int jwidth = JDIM;

void pgr_setjpset_one(int dummyid, int j, unsigned int* jdata)
{
  unsigned int adr64  = (j*JDIM*sizeof(unsigned int))>>3;
  memcpy(pgr_ptr+ADR_JPSET+adr64, jdata, jwidth*sizeof(unsigned int));
}

void pgr_clearjpset(void)
{
  int j,jmax;
  jmax = 16384*2;
  for(j=0;j<jmax;j++){
    //    pgr_write_acore(ADR_JPSET+j, (u_64) 0xFFFFFFFFFFFFFFFFULL);
    pgr_write_acore(ADR_JPSET+j, (u_64) 0);
  }
}

#define XI_AWIDTH (4)
#define XI_AWIDTH_XD1 (XI_AWIDTH-1)
void pgr_setipset_one(int dummyid, unsigned int ipipe, unsigned int *idata, int idim)
{
  unsigned int offset = ADR_IPSET | (ipipe<<XI_AWIDTH_XD1);
  memcpy(pgr_ptr+offset, idata, sizeof(unsigned int)*idim);
}


void pgr_start_calc(int dummyid, unsigned int n)
{
  int i;
  for(i=0;i < 16; i++){
    pgr_write_acore(ADR_SETN+i,n);
  }
  while(pgr_read_acore(ADR_STS) == 0){
    pgr_write_acore(ADR_STS,0);  // kill "WRITE-COMBINED" !!
  }
}

void pgr_calc_start(int dummyid,unsigned int n)
{
  int i;
  for(i=0;i < 16; i++){
    pgr_write_acore(ADR_SETN+i,n);
  }
}

void pgr_calc_finish(int dummyid)
{
  while(pgr_read_acore(ADR_STS) == 0){
    pgr_write_acore(ADR_STS,0);  // kill "WRITE-COMBINED" !!
    //    printf("sts %016lX\n",pgr_read_acore(ADR_STS));
  }
}

#define NCHIP  (1);                   // used in pgr_getfoset
void pgr_set_nchip(int n){ return; }  // dummy function

static int npipe_per_chip = 1;
void pgr_set_npipe_per_chip(int dummyid, int n)
{
  if(n>256){
    fprintf(stderr,"pgr api error, NPIPE/chip must be < 257.\n");
    fprintf(stderr,"[NPIPE/chip %d ?]\n",n);
    exit(-1);
  }else if(n<1){
    fprintf(stderr,"pgr api error, NPIPE/chip must be > 0.\n");
    fprintf(stderr,"[NPIPE/chip %d ?]\n",n);
    exit(-1);
  }
  npipe_per_chip = n;                 // used in pgr_getfoset().
}

void pgr_set_jwidth(int dummyid, int n)
{
  if(n < 1) {
    fprintf(stderr,"pgr api error, JWIDTH be > 0.\n");
    exit(-1);
  }
  jwidth = n;
}

#define FI_AWIDTH_XD1 (3)
void pgr_getfoset_one(int dummyid, int i, u_64* fdata, int fdim)
{
  memcpy(fdata, pgr_ptr+ADR_FOSET+(i<<FI_AWIDTH_XD1), sizeof(u_64)*fdim);
}




//#define DEBUG_MAIN 1
//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
// DEBUG  &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
#ifdef DEBUG_MAIN
int main (int argc, char **argv) {
  int devid = 0;  // dummy devid
  int n;
  unsigned int xj[1024][4];
  unsigned int xi[1024][4];

  pgr_open(devid);
  pgr_reset(devid);

  xj[0][0] = 0x7D70A3D7;
  xj[0][1] = 0x80000000;
  xj[0][2] = 0x80000000;
  xj[0][3] = 0x00008000; // mj

  xj[1][0] = 0x828F5C29;
  xj[1][1] = 0x80000000;
  xj[1][2] = 0x80000000;
  xj[1][3] = 0x00008000; // mj

  pgr_setjpset_one(devid,0,xj[0]);
  pgr_setjpset_one(devid,1,xj[1]);

  //  pgr_clearjpset();

  // ---------------- i = 0;
  xi[0][0] = 0x828F5C29;
  xi[0][1] = 0x80000000;
  xi[0][2] = 0x80000000;
  xi[0][3] = 0x00008000;

  // ---------------- i = 1;
  xi[1][0] = 0x7D70A3D7;
  xi[1][1] = 0x80000000;
  xi[1][2] = 0x80000000;
  xi[1][3] = 0x00008000;

  n = 2;
  {
    u_64 fodata[200];
    unsigned ipipe;
    int idim = 4;
    ipipe=0;
    pgr_setipset_one(devid,ipipe, xi[0], idim);
    ipipe=1;
    pgr_setipset_one(devid,ipipe, xi[1], idim);

    pgr_calc_start(devid,n);
    pgr_calc_finish(devid);


    pgr_getfoset_one(devid, 0, fodata, 3);

    
    printf("i=%d\t",0);             // i=0                 i=1  
    printf("0x%016lX\t",fodata[0]); // 0x0013900000000000, 0xFFEC700000000000
    printf("0x%016lX\t",fodata[1]); // 0x0               , 0x0
    printf("0x%016lX\n",fodata[2]); // 0x0               , 0x0

    pgr_getfoset_one(devid, 1, fodata, 3);

    printf("i=%d\t",1);             // i=0                 i=1  
    printf("0x%016lX\t",fodata[0]); // 0x0013900000000000, 0xFFEC700000000000
    printf("0x%016lX\t",fodata[1]); // 0x0               , 0x0
    printf("0x%016lX\n",fodata[2]); // 0x0               , 0x0

  }

  pgr_close(devid);
  return 0;
}
#endif
