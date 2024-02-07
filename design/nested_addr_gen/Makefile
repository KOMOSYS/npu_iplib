PROCESS = 5nm

all:
	cd sim; \
	make clean; make sim SIM_TYPE=RTL_SIM; \
	make mrg_cov; make rpt_cov; \
	cd ../; \
	make ppa

ppa:
	cd syn; \
	make all PROCESS=$(PROCESS); \
	cd ../sim; \
	make clean; make sim SIM_TYPE=PRE_SIM PROCESS=$(PROCESS); \
	cd ../pwr; \
	make clean; make all PROCESS=$(PROCESS); \
	cd ..; \
	make summary

summary:
	python3 ../../script/summary/make_md.py -u sim/urgReport -a syn -p pwr