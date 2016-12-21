#define u_64 unsigned long
void pgr_open               (int dummyid);
void pgr_reset              (int dummyid);
void pgr_close              (int dummyid);
void pgr_setjpset_one       (int dummyid, int j, unsigned int* jdata);
void pgr_clearjpset         (void);
void pgr_setipset_one       (int dummyid, unsigned int ipipe, unsigned int *idata, int idim);
void pgr_start_calc         (int dummyid, unsigned int n);
void pgr_calc_start         (int dummyid,unsigned int n);
void pgr_calc_finish        (int dummyid);
void pgr_set_nchip          (int n);
void pgr_set_npipe_per_chip (int dummyid, int n);
void pgr_set_jwidth         (int dummyid, int n);
void pgr_getfoset_one       (int dummyid, int i, u_64* fdata, int fdim);
