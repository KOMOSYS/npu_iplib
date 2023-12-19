RANDOM_SEED = $(shell echo $$((RANDOM+1)))
MODULE_NAME = $(notdir $(realpath ../))

SIM = vcs
TOPLEVEL = $(MODULE_NAME)
TOPLEVEL_LANG = verilog
MODULE = test_$(MODULE_NAME)

FILE_LIST = $(realpath ../rtl/file_list.f)
COMPILE_ARGS += -l ./vcs.comp.log -F $(FILE_LIST)
COMPILE_ARGS += -kdb #+vcs+fsdbon+all
SIM_ARGS = -l vcs.run.log
EXTRA_ARGS = -cm line+cond+fsm+tgl+branch

VERI_LIB_PATH = $(realpath ../../../lib)
VERI_SRC_PATH = $(realpath $(PWD))
export PYTHONPATH=$(VERI_LIB_PATH):$(VERI_SRC_PATH)
include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf results.xml
	rm -rf __pycache__
	rm -rf vcs.run.log

mrg_cov :
	if [ ! -d coverage/simv.vdb ]; then \
		mkdir -p coverage; \
		if [ -d sim_build/simv.vdb ]; then \
			cp -rf sim_build/simv.vdb coverage/; \
		fi; \
	else \
		urg -dir sim_build/simv.vdb coverage/simv.vdb -dbname coverage/simv.vdb; \
	fi

rpt_cov :
	urg -dir coverage/simv.vdb -format text
	cat urgReport/dashboard.txt

view_cov :
	verdi -cov -covdir coverage/simv.vdb
