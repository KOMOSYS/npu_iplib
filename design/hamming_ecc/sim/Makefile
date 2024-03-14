SIM_TYPE = RTL_SIM
MODULE_NAME = $(notdir $(realpath ../))

ifeq ($(SIM_TYPE), RTL_SIM)
	FILE_LIST = $(realpath ./file_list.f)
	EXTRA_ARGS = -cm line+cond+fsm+branch
	export RANDOM_SEED = $(shell echo $$((RANDOM+1)))
	export MAX_ITER = 100
endif
ifeq ($(SIM_TYPE), PRE_SIM)
	PROCESS = 5nm
	FILE_LIST = $(realpath ./file_list.$(PROCESS).f)
	PLUSARGS += +define+SAIF_ON
	PLUSARGS += +define+SAIF_NAME=\"$(MODULE_NAME).$(PROCESS).saif\"
	export RANDOM_SEED = 1
	export MAX_ITER = 10
	TESTCASE=normal
endif
COMPILE_ARGS += +notimingcheck +nospecify 
COMPILE_ARGS += -l ./vcs.comp.log -F $(FILE_LIST)
COMPILE_ARGS += -kdb +vcs+fsdbon+all
PLUSARGS += +define+$(SIM_TYPE)

SIM = vcs
TOPLEVEL = top
TOPLEVEL_LANG = verilog
MODULE = test_$(MODULE_NAME)
VERI_LIB_PATH = $(realpath ../../../lib)
VERI_SRC_PATH = $(realpath $(PWD))
export PYTHONPATH=$(VERI_LIB_PATH):$(VERI_SRC_PATH)
include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf results.xml
	rm -rf __pycache__
	rm -rf vcs.run.log
	rm -rf novas*

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
