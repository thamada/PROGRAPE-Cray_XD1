.SILENT:
include ../../makefile_vars

# List the source files in the order that they should be compiled
SOURCE = user_pkg delay block_ram bram_if reg_if qdr2_if rt_client user_app

sim:
        ifeq ($(SIMULATOR),modelsim)
		# Modelsim
		for d in *; do\
		   if test -f $$d/Makefile.sim; then\
		      (cd $$d; make -f Makefile.sim)\
		fi \
		done
		make -f Makefile.sim
        endif
        ifeq ($(SIMULATOR),riviera)
		# Aldec Riviera
		for f in $(SOURCE); do\
		  $(VSIMSACFG)/bin/vcom -93 -dbg $$f.vhd; \
		done
        endif

sim_setup:
        ifeq ($(SIMULATOR),modelsim)
		# Modelsim
		if [ ! -d ../../simlib/modelsim/src ] ; then \
		   vlib ../../simlib/modelsim/src; \
		fi
		vmap work ../../simlib/modelsim/src
		# Uncomment and modify the following vmap commands if not using Modelsim XE
		# vmap simprim c:/programs/xilinx/vhdl/mti/simprim
		# vmap unisim c:/programs/xilinx/vhdl/mti/unisim
		# vmap XilinxCoreLib c:/programs/xilinx/vhdl/mti/XilinxCoreLib
		for f in $(SOURCE); do\
		  vcom -93 $$f.vhd; \
		done
		vmake -fullsrcpath > Makefile.sim
        endif
        ifeq ($(SIMULATOR),riviera)
		# Aldec Riviera
		if [ ! -d ../../simlib/riviera/src ] ; then \
		   $(VSIMSACFG)/bin/vlib ../../simlib/riviera/src; \
		fi
		$(VSIMSACFG)/bin/vmap work ../../simlib/riviera/src
		$(VSIMSACFG)/bin/vmap simprim $(VSIMSACFG)/vlib/xilinx/simprim
		$(VSIMSACFG)/bin/vmap unisim $(VSIMSACFG)/vlib/xilinx/unisim
		$(VSIMSACFG)/bin/vmap XilinxCoreLib \
		  $(VSIMSACFG)/vlib/xilinx/xilinxcorelib
		for f in $(SOURCE); do\
		  $(VSIMSACFG)/bin/vcom -93 -dbg $$f.vhd; \
		done
		# $(VSIMSACFG)/bin/vmake > Makefile.sim
        endif

%.vhd:

clean:
	for d in *; do \
	   if test -f $$d/Makefile; then\
	      echo hdl/$$d; \
	      (cd $$d;make clean); \
	   fi; \
	done
	rm -f temp* *~ *.bak

dist_clean: clean
